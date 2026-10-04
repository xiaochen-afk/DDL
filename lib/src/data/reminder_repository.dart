import '../core/app_failure.dart';
import '../domain/local_data.dart';
import '../domain/ports.dart';
import 'database/app_database.dart';

class SqliteReminderRepository implements ReminderRepository {
  SqliteReminderRepository(
    this._database, {
    ClockPort clock = const SystemClock(),
  }) : _clock = clock;

  final AppDatabase _database;
  final ClockPort _clock;

  @override
  Future<List<ReminderRecord>> listForTask(String taskId) => _guard(() async {
    final db = await _database.database;
    final rows = await db.query(
      'reminders',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'scheduled_at ASC',
    );
    return List.unmodifiable(rows.map(_fromRow));
  });

  @override
  Future<List<ReminderRecord>> listOutstanding() => _guard(() async {
    final db = await _database.database;
    final rows = await db.query(
      'reminders',
      where: 'status IN (?, ?, ?)',
      whereArgs: ['PENDING', 'SCHEDULED', 'SCHEDULE_FAILED'],
      orderBy: 'scheduled_at ASC',
    );
    return List.unmodifiable(rows.map(_fromRow));
  });

  @override
  Future<void> replaceForTask(String taskId, List<ReminderRecord> records) {
    _validateDesired(taskId, records);
    return _guard(() async {
      final db = await _database.database;
      await db.transaction((tx) async {
        final task = await tx.query(
          'tasks',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [taskId],
          limit: 1,
        );
        if (task.isEmpty) {
          throw const AppFailure(
            code: 'TASK_NOT_FOUND',
            message: 'Task does not exist.',
          );
        }
        await tx.delete('reminders', where: 'task_id = ?', whereArgs: [taskId]);
        final now = _clock.now();
        for (final record in records) {
          await tx.insert(
            'reminders',
            _toRow(
              ReminderRecord(
                id: record.id,
                taskId: record.taskId,
                scheduledAt: record.scheduledAt,
                channel: record.channel,
                status: record.status,
                createdAt: now,
                updatedAt: now,
              ),
            ),
          );
        }
      });
    });
  }

  @override
  Future<int> syncPlanForTask(String taskId, List<ReminderRecord> desired) {
    _validateDesired(taskId, desired);
    return _guard(() async {
      final db = await _database.database;
      return db.transaction((tx) async {
        final task = await tx.query(
          'tasks',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [taskId],
          limit: 1,
        );
        if (task.isEmpty) {
          throw const AppFailure(
            code: 'TASK_NOT_FOUND',
            message: 'Task does not exist.',
          );
        }
        final existing = (await tx.query(
          'reminders',
          where: 'task_id = ?',
          whereArgs: [taskId],
        )).map(_fromRow).toList();
        final wanted = {for (final record in desired) record.id: record};
        final previous = {for (final record in existing) record.id: record};
        final now = _clock.now().toUtc().millisecondsSinceEpoch;
        var changed = 0;
        for (final record in existing) {
          final target = wanted[record.id];
          if (target != null &&
              (record.scheduledAt.millisecondsSinceEpoch !=
                      target.scheduledAt.millisecondsSinceEpoch ||
                  record.channel != target.channel)) {
            throw const AppFailure(
              code: 'VALIDATION_FAILED',
              message: 'Reminder identity conflicts with its plan.',
            );
          }
          if (target == null && _isOutstanding(record.status)) {
            await tx.update(
              'reminders',
              {'status': 'CANCELLED', 'updated_at': now},
              where: 'id = ?',
              whereArgs: [record.id],
            );
            changed++;
          } else if (target != null &&
              record.status == ReminderStatus.cancelled) {
            await tx.update(
              'reminders',
              {
                'status': 'PENDING',
                'platform_notification_id': null,
                'last_error_code': null,
                'updated_at': now,
              },
              where: 'id = ?',
              whereArgs: [record.id],
            );
            changed++;
          }
        }
        for (final record in desired) {
          if (previous.containsKey(record.id)) continue;
          await tx.insert(
            'reminders',
            _toRow(
              ReminderRecord(
                id: record.id,
                taskId: taskId,
                scheduledAt: record.scheduledAt,
                channel: record.channel,
                status: ReminderStatus.pending,
                createdAt: DateTime.fromMillisecondsSinceEpoch(
                  now,
                  isUtc: true,
                ),
                updatedAt: DateTime.fromMillisecondsSinceEpoch(
                  now,
                  isUtc: true,
                ),
              ),
            ),
          );
          changed++;
        }
        return changed;
      });
    });
  }

  @override
  Future<ReminderRecord> updateStatus(
    String id,
    ReminderStatus status, {
    String? platformNotificationId,
    String? lastErrorCode,
  }) => _guard(() async {
    final db = await _database.database;
    return db.transaction((tx) async {
      final rows = await tx.query(
        'reminders',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw const AppFailure(
          code: 'REMINDER_NOT_FOUND',
          message: 'Reminder does not exist.',
        );
      }
      final current = _fromRow(rows.first);
      if (!_canTransition(current.status, status)) {
        throw const AppFailure(
          code: 'VALIDATION_FAILED',
          message: 'Reminder status transition is invalid.',
        );
      }
      final nextPlatformId =
          platformNotificationId ?? current.platformNotificationId;
      final nextErrorCode = status == ReminderStatus.scheduleFailed
          ? lastErrorCode ?? current.lastErrorCode
          : null;
      if (current.status == status &&
          current.platformNotificationId == nextPlatformId &&
          current.lastErrorCode == nextErrorCode)
        return current;
      final now = _clock.now();
      await tx.update(
        'reminders',
        {
          'status': _statusToDb(status),
          'platform_notification_id': nextPlatformId,
          'last_error_code': nextErrorCode,
          'updated_at': now.toUtc().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      return ReminderRecord(
        id: current.id,
        taskId: current.taskId,
        scheduledAt: current.scheduledAt,
        channel: current.channel,
        status: status,
        platformNotificationId: nextPlatformId,
        lastErrorCode: nextErrorCode,
        createdAt: current.createdAt,
        updatedAt: now,
      );
    });
  });

  @override
  Future<int> cancelForTask(String taskId) => _guard(() async {
    final db = await _database.database;
    return db.transaction(
      (tx) async => tx.update(
        'reminders',
        {
          'status': 'CANCELLED',
          'updated_at': _clock.now().toUtc().millisecondsSinceEpoch,
        },
        where: 'task_id = ? AND status IN (?, ?, ?)',
        whereArgs: [taskId, 'PENDING', 'SCHEDULED', 'SCHEDULE_FAILED'],
      ),
    );
  });

  static bool _canTransition(ReminderStatus from, ReminderStatus to) {
    if (from == to) return true;
    return switch (from) {
      ReminderStatus.pending =>
        to == ReminderStatus.scheduled ||
            to == ReminderStatus.scheduleFailed ||
            to == ReminderStatus.cancelled,
      ReminderStatus.scheduled =>
        to == ReminderStatus.fired ||
            to == ReminderStatus.scheduleFailed ||
            to == ReminderStatus.cancelled,
      ReminderStatus.scheduleFailed =>
        to == ReminderStatus.pending ||
            to == ReminderStatus.scheduled ||
            to == ReminderStatus.cancelled,
      ReminderStatus.cancelled || ReminderStatus.fired => false,
    };
  }

  static Map<String, Object?> _toRow(ReminderRecord value) => {
    'id': value.id,
    'task_id': value.taskId,
    'scheduled_at': value.scheduledAt.toUtc().millisecondsSinceEpoch,
    'channel': value.channel.name,
    'status': _statusToDb(value.status),
    'platform_notification_id': value.platformNotificationId,
    'last_error_code': value.lastErrorCode,
    'created_at': value.createdAt!.toUtc().millisecondsSinceEpoch,
    'updated_at': value.updatedAt!.toUtc().millisecondsSinceEpoch,
  };

  static ReminderRecord _fromRow(Map<String, Object?> row) => ReminderRecord(
    id: row['id']! as String,
    taskId: row['task_id']! as String,
    scheduledAt: DateTime.fromMillisecondsSinceEpoch(
      row['scheduled_at']! as int,
      isUtc: true,
    ).toLocal(),
    channel: ReminderChannel.values.byName(row['channel']! as String),
    status: _statusFromDb(row['status']! as String),
    platformNotificationId: row['platform_notification_id'] as String?,
    lastErrorCode: row['last_error_code'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      row['created_at']! as int,
      isUtc: true,
    ).toLocal(),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      row['updated_at']! as int,
      isUtc: true,
    ).toLocal(),
  );

  static String _statusToDb(ReminderStatus status) => switch (status) {
    ReminderStatus.pending => 'PENDING',
    ReminderStatus.scheduled => 'SCHEDULED',
    ReminderStatus.scheduleFailed => 'SCHEDULE_FAILED',
    ReminderStatus.cancelled => 'CANCELLED',
    ReminderStatus.fired => 'FIRED',
  };

  static ReminderStatus _statusFromDb(String status) => switch (status) {
    'PENDING' => ReminderStatus.pending,
    'SCHEDULED' => ReminderStatus.scheduled,
    'SCHEDULE_FAILED' => ReminderStatus.scheduleFailed,
    'CANCELLED' => ReminderStatus.cancelled,
    'FIRED' => ReminderStatus.fired,
    _ => throw const AppFailure(
      code: 'DATABASE_UNAVAILABLE',
      message: 'Stored reminder status is invalid.',
    ),
  };
}

void _validateDesired(String taskId, List<ReminderRecord> records) {
  if (records.any(
        (record) =>
            record.taskId != taskId ||
            record.id.isEmpty ||
            record.status != ReminderStatus.pending,
      ) ||
      records.map((record) => record.id).toSet().length != records.length) {
    throw const AppFailure(
      code: 'VALIDATION_FAILED',
      message: 'Reminder plan is invalid.',
    );
  }
}

bool _isOutstanding(ReminderStatus status) =>
    status == ReminderStatus.pending ||
    status == ReminderStatus.scheduled ||
    status == ReminderStatus.scheduleFailed;

Future<T> _guard<T>(Future<T> Function() operation) async {
  try {
    return await operation();
  } on AppFailure {
    rethrow;
  } catch (error) {
    final text = error.toString().toLowerCase();
    throw AppFailure(
      code:
          text.contains('database or disk is full') ||
              text.contains('sqlite_full')
          ? 'STORAGE_FULL'
          : 'DATABASE_UNAVAILABLE',
      message: 'The local database operation failed.',
      cause: error,
    );
  }
}

class InMemoryReminderRepository implements ReminderRepository {
  final List<ReminderRecord> _records = [];

  @override
  Future<List<ReminderRecord>> listForTask(String taskId) async =>
      List.unmodifiable(_records.where((record) => record.taskId == taskId));

  @override
  Future<List<ReminderRecord>> listOutstanding() async => List.unmodifiable(
    _records.where(
      (record) =>
          record.status == ReminderStatus.pending ||
          record.status == ReminderStatus.scheduled ||
          record.status == ReminderStatus.scheduleFailed,
    ),
  );

  @override
  Future<void> replaceForTask(
    String taskId,
    List<ReminderRecord> records,
  ) async {
    _validateDesired(taskId, records);
    _records.removeWhere((record) => record.taskId == taskId);
    _records.addAll(records);
  }

  @override
  Future<int> syncPlanForTask(
    String taskId,
    List<ReminderRecord> desired,
  ) async {
    _validateDesired(taskId, desired);
    final wanted = {for (final record in desired) record.id: record};
    final previous = {
      for (final record in _records.where((record) => record.taskId == taskId))
        record.id: record,
    };
    for (final record in previous.values) {
      final target = wanted[record.id];
      if (target != null &&
          (record.scheduledAt.millisecondsSinceEpoch !=
                  target.scheduledAt.millisecondsSinceEpoch ||
              record.channel != target.channel)) {
        throw const AppFailure(
          code: 'VALIDATION_FAILED',
          message: 'Reminder identity conflicts with its plan.',
        );
      }
    }
    var changed = 0;
    for (var i = 0; i < _records.length; i++) {
      final record = _records[i];
      if (record.taskId != taskId) continue;
      final target = wanted[record.id];
      if (target == null && _isOutstanding(record.status)) {
        _records[i] = record.copyWith(status: ReminderStatus.cancelled);
        changed++;
      } else if (target != null && record.status == ReminderStatus.cancelled) {
        _records[i] = ReminderRecord(
          id: record.id,
          taskId: record.taskId,
          scheduledAt: record.scheduledAt,
          channel: record.channel,
          status: ReminderStatus.pending,
          createdAt: record.createdAt,
          updatedAt: DateTime.now(),
        );
        changed++;
      }
    }
    for (final record in desired) {
      if (previous.containsKey(record.id)) continue;
      _records.add(record);
      changed++;
    }
    return changed;
  }

  @override
  Future<ReminderRecord> updateStatus(
    String id,
    ReminderStatus status, {
    String? platformNotificationId,
    String? lastErrorCode,
  }) async {
    final index = _records.indexWhere((record) => record.id == id);
    if (index < 0) {
      throw const AppFailure(
        code: 'REMINDER_NOT_FOUND',
        message: 'Reminder does not exist.',
      );
    }
    final current = _records[index];
    if (!SqliteReminderRepository._canTransition(current.status, status)) {
      throw const AppFailure(
        code: 'VALIDATION_FAILED',
        message: 'Reminder status transition is invalid.',
      );
    }
    return _records[index] = ReminderRecord(
      id: current.id,
      taskId: current.taskId,
      scheduledAt: current.scheduledAt,
      channel: current.channel,
      status: status,
      platformNotificationId:
          platformNotificationId ?? current.platformNotificationId,
      lastErrorCode: status == ReminderStatus.scheduleFailed
          ? lastErrorCode ?? current.lastErrorCode
          : null,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<int> cancelForTask(String taskId) async {
    var changed = 0;
    for (var i = 0; i < _records.length; i++) {
      final record = _records[i];
      if (record.taskId == taskId &&
          record.status != ReminderStatus.cancelled &&
          record.status != ReminderStatus.fired) {
        _records[i] = record.copyWith(status: ReminderStatus.cancelled);
        changed++;
      }
    }
    return changed;
  }
}
