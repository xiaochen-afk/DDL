import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/app_failure.dart';
import '../domain/ports.dart';
import '../domain/risk_engine.dart';
import '../domain/task.dart';
import 'database/app_database.dart';
import 'database/schema.dart';

class SqliteTaskRepository implements TaskRepository {
  SqliteTaskRepository(
    this._appDatabase, {
    ClockPort clock = const SystemClock(),
    Uuid uuid = const Uuid(),
  }) : _clock = clock,
       _uuid = uuid;

  final AppDatabase _appDatabase;
  final ClockPort _clock;
  final Uuid _uuid;

  @override
  Future<List<TaskItem>> listTasks() {
    return _guard(() async {
      final db = await _appDatabase.database;
      final rows = await db.query('tasks');
      return List.unmodifiable(rows.map(_taskFromRow));
    });
  }

  @override
  Future<int> reconcileOverdue(DateTime asOf) {
    return _guard(() async {
      final db = await _appDatabase.database;
      return db.transaction((transaction) async {
        final dueTasks = await transaction.query(
          'tasks',
          where: 'status = ? AND due_at <= ?',
          whereArgs: ['PENDING', _toUtcMilliseconds(asOf)],
        );
        for (final row in dueTasks) {
          final task = _taskFromRow(row);
          final changed = await transaction.update(
            'tasks',
            {
              'status': 'OVERDUE_REVIEW',
              'updated_at': _toUtcMilliseconds(asOf),
              'risk_score_snapshot': 0,
              'version': task.version + 1,
            },
            where: 'id = ? AND status = ? AND version = ?',
            whereArgs: [task.id, 'PENDING', task.version],
          );
          if (changed != 1) {
            throw const AppFailure(
              code: 'VALIDATION_FAILED',
              message: 'Task changed during overdue reconciliation.',
            );
          }
          await _insertEvent(
            transaction,
            taskId: task.id,
            eventType: 'TASK_OVERDUE',
            occurredAt: asOf,
            metadata: {'from': 'PENDING', 'to': 'OVERDUE_REVIEW'},
          );
        }
        await _refreshRiskSnapshots(transaction, asOf);
        return dueTasks.length;
      });
    });
  }

  @override
  Future<TaskItem?> getTask(String id) {
    return _guard(() async {
      final db = await _appDatabase.database;
      final rows = await db.query(
        'tasks',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return rows.isEmpty ? null : _taskFromRow(rows.first);
    });
  }

  @override
  Future<bool> hasMeaningfulHistory(String id) {
    return _guard(() async {
      final db = await _appDatabase.database;
      final rows = await db.query(
        'tasks',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw const AppFailure(
          code: 'TASK_NOT_FOUND',
          message: 'Task does not exist.',
        );
      }
      if (_taskFromRow(rows.first).status != TaskStatus.active) return true;
      final events = await db.query(
        'task_events',
        columns: ['id'],
        where: 'task_id = ? AND event_type != ?',
        whereArgs: [id, 'TASK_CREATED'],
        limit: 1,
      );
      return events.isNotEmpty;
    });
  }

  @override
  Future<Map<TaskCategory, double>> missedRatesByCategory() {
    return _guard(() async {
      final db = await _appDatabase.database;
      final rows = await db.rawQuery('''
        SELECT t.category_id AS category,
          SUM(CASE WHEN e.event_type = 'TASK_MISSED' THEN 1 ELSE 0 END) AS missed,
          COUNT(*) AS settled
        FROM task_events e JOIN tasks t ON t.id = e.task_id
        WHERE e.event_type IN ('TASK_MISSED', 'TASK_COMPLETED', 'TASK_COMPLETED_LATE')
        GROUP BY t.category_id
      ''');
      return {
        for (final row in rows)
          _categoryFromDatabase(row['category']! as String):
              (row['missed']! as int) / (row['settled']! as int),
      };
    });
  }

  @override
  Future<TaskItem> createTask(TaskDraft draft) {
    _validateDraft(draft);
    return _guard(() async {
      final db = await _appDatabase.database;
      final now = _clock.now();
      final task = TaskItem(
        id: _uuid.v4(),
        title: draft.title.trim(),
        dueAt: draft.dueAt,
        category: draft.category,
        isImportant: draft.isImportant,
        estimatedMinutes: draft.estimatedMinutes,
        status: TaskStatus.active,
        createdAt: now,
        updatedAt: now,
        notes: draft.notes,
        customCategoryLabel: draft.category == TaskCategory.custom
            ? draft.customCategoryLabel!.trim()
            : null,
        taskReminderOffsetMinutes: draft.taskReminderOffsetMinutes,
      );

      await db.transaction((transaction) async {
        await transaction.insert('tasks', _taskToRow(task));
        await _insertEvent(
          transaction,
          taskId: task.id,
          eventType: 'TASK_CREATED',
          occurredAt: now,
        );
        await _refreshRiskSnapshots(transaction, now);
      });
      return task;
    });
  }

  @override
  Future<TaskItem> updateTask(TaskItem task) {
    _validateTask(task);
    return _guard(() async {
      final db = await _appDatabase.database;
      return db.transaction((transaction) async {
        final current = await _findRequired(transaction, task.id);
        if (current.status != TaskStatus.active ||
            current.status != task.status) {
          throw const AppFailure(
            code: 'VALIDATION_FAILED',
            message: 'Only active tasks can be edited.',
          );
        }
        if (current.version != task.version) {
          throw const AppFailure(
            code: 'VALIDATION_FAILED',
            message: 'Task was changed by another operation.',
          );
        }

        final updated = task.copyWith(
          title: task.title.trim(),
          customCategoryLabel: task.category == TaskCategory.custom
              ? task.customCategoryLabel!.trim()
              : null,
          clearCustomCategoryLabel: task.category != TaskCategory.custom,
          updatedAt: _clock.now(),
          version: task.version + 1,
        );
        final changed = await transaction.update(
          'tasks',
          _taskToRow(updated),
          where: 'id = ? AND version = ?',
          whereArgs: [task.id, task.version],
        );
        if (changed != 1) {
          throw const AppFailure(
            code: 'VALIDATION_FAILED',
            message: 'Task was changed by another operation.',
          );
        }
        await _insertEvent(
          transaction,
          taskId: task.id,
          eventType: 'TASK_UPDATED',
          occurredAt: updated.updatedAt,
          metadata: {'version': updated.version},
        );
        await _refreshRiskSnapshots(transaction, updated.updatedAt);
        return updated;
      });
    });
  }

  @override
  Future<TaskItem> transitionTask(String id, TaskStatus target) {
    return _guard(() async {
      final db = await _appDatabase.database;
      return db.transaction((transaction) async {
        final current = await _findRequired(transaction, id);
        if (current.status == target) return current;
        final now = _clock.now();
        final effectiveTarget =
            current.status == TaskStatus.active &&
                target == TaskStatus.completed &&
                !now.isBefore(current.dueAt)
            ? TaskStatus.overdueReview
            : target;
        if (!_canTransition(current.status, effectiveTarget) ||
            (effectiveTarget == TaskStatus.overdueReview &&
                now.isBefore(current.dueAt))) {
          throw const AppFailure(
            code: 'VALIDATION_FAILED',
            message: 'Task status transition is not allowed.',
          );
        }

        final isCompleted =
            effectiveTarget == TaskStatus.completed ||
            effectiveTarget == TaskStatus.completedLate;
        final updated = current.copyWith(
          status: effectiveTarget,
          completedAt: isCompleted ? now : current.completedAt,
          updatedAt: now,
          version: current.version + 1,
        );
        final row = _taskToRow(updated);
        row['archived_at'] = effectiveTarget == TaskStatus.archived
            ? _toUtcMilliseconds(now)
            : null;

        final changed = await transaction.update(
          'tasks',
          row,
          where: 'id = ? AND version = ?',
          whereArgs: [id, current.version],
        );
        if (changed != 1) {
          throw const AppFailure(
            code: 'VALIDATION_FAILED',
            message: 'Task was changed by another operation.',
          );
        }
        await _insertEvent(
          transaction,
          taskId: id,
          eventType: _eventTypeFor(effectiveTarget),
          occurredAt: now,
          metadata: {
            'from': _statusToDatabase(current.status),
            'to': _statusToDatabase(effectiveTarget),
          },
        );
        await _refreshRiskSnapshots(transaction, now);
        return updated;
      });
    });
  }

  @override
  Future<void> deleteTask(String id) {
    return _guard(() async {
      final db = await _appDatabase.database;
      await db.transaction((transaction) async {
        await _findRequired(transaction, id);
        final deleted = await transaction.delete(
          'tasks',
          where: 'id = ?',
          whereArgs: [id],
        );
        if (deleted != 1) {
          throw const AppFailure(
            code: 'TASK_NOT_FOUND',
            message: 'Task does not exist.',
          );
        }
        await _refreshRiskSnapshots(transaction, _clock.now());
      });
    });
  }

  Future<void> _refreshRiskSnapshots(
    Transaction transaction,
    DateTime asOf,
  ) async {
    final rows = await transaction.query('tasks');
    final tasks = rows.map(_taskFromRow).toList();
    final history = await transaction.rawQuery('''
      SELECT t.category_id AS category,
        SUM(CASE WHEN e.event_type = 'TASK_MISSED' THEN 1 ELSE 0 END) AS missed,
        COUNT(*) AS settled
      FROM task_events e JOIN tasks t ON t.id = e.task_id
      WHERE e.event_type IN ('TASK_MISSED', 'TASK_COMPLETED', 'TASK_COMPLETED_LATE')
      GROUP BY t.category_id
    ''');
    final rates = {
      for (final row in history)
        _categoryFromDatabase(row['category']! as String):
            (row['missed']! as int) / (row['settled']! as int),
    };
    for (final task in tasks) {
      final score = RiskEngine.assess(
        task,
        asOf,
        tasks,
        missedRate: rates[task.category] ?? 0,
      ).score;
      await transaction.update(
        'tasks',
        {
          'risk_score_snapshot': score,
          'risk_config_version': riskConfigVersion,
        },
        where: 'id = ?',
        whereArgs: [task.id],
      );
    }
    await transaction.update(
      'app_meta',
      {'value': riskConfigVersion.toString()},
      where: 'key = ?',
      whereArgs: ['risk_config_version'],
    );
  }

  Future<TaskItem> _findRequired(DatabaseExecutor executor, String id) async {
    final rows = await executor.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const AppFailure(
        code: 'TASK_NOT_FOUND',
        message: 'Task does not exist.',
      );
    }
    return _taskFromRow(rows.first);
  }

  Future<void> _insertEvent(
    DatabaseExecutor executor, {
    required String taskId,
    required String eventType,
    required DateTime occurredAt,
    Map<String, Object?>? metadata,
  }) {
    return executor.insert('task_events', {
      'id': _uuid.v4(),
      'task_id': taskId,
      'event_type': eventType,
      'occurred_at': _toUtcMilliseconds(occurredAt),
      'metadata_json': metadata == null ? null : jsonEncode(metadata),
    });
  }

  Map<String, Object?> _taskToRow(TaskItem task) {
    return {
      'id': task.id,
      'title': task.title,
      'category_id': task.category.name,
      'custom_category_label': task.customCategoryLabel,
      'task_reminder_offset_minutes': task.taskReminderOffsetMinutes,
      'important': task.isImportant ? 1 : 0,
      'due_at': _toUtcMilliseconds(task.dueAt),
      'estimated_minutes': task.estimatedMinutes,
      'notes': task.notes,
      'status': _statusToDatabase(task.status),
      'completed_at': task.completedAt == null
          ? null
          : _toUtcMilliseconds(task.completedAt!),
      'archived_at': task.status == TaskStatus.archived
          ? _toUtcMilliseconds(task.updatedAt)
          : null,
      'risk_score_snapshot': RiskEngine.assess(task, _clock.now(), [
        task,
      ]).score,
      'risk_config_version': riskConfigVersion,
      'version': task.version,
      'created_at': _toUtcMilliseconds(task.createdAt),
      'updated_at': _toUtcMilliseconds(task.updatedAt),
    };
  }

  static TaskItem _taskFromRow(Map<String, Object?> row) {
    return TaskItem(
      id: row['id']! as String,
      title: row['title']! as String,
      dueAt: _dateTimeFromRow(row['due_at']),
      category: _categoryFromDatabase(row['category_id']! as String),
      customCategoryLabel: row['custom_category_label'] as String?,
      taskReminderOffsetMinutes: row['task_reminder_offset_minutes'] as int?,
      isImportant: row['important'] == 1,
      estimatedMinutes: row['estimated_minutes']! as int,
      status: _statusFromDatabase(row['status']! as String),
      createdAt: _dateTimeFromRow(row['created_at']),
      updatedAt: _dateTimeFromRow(row['updated_at']),
      version: row['version']! as int,
      notes: row['notes']! as String,
      completedAt: row['completed_at'] == null
          ? null
          : _dateTimeFromRow(row['completed_at']),
    );
  }

  static DateTime _dateTimeFromRow(Object? value) {
    return DateTime.fromMillisecondsSinceEpoch(
      value! as int,
      isUtc: true,
    ).toLocal();
  }

  static int _toUtcMilliseconds(DateTime value) =>
      value.toUtc().millisecondsSinceEpoch;

  static TaskCategory _categoryFromDatabase(String value) {
    return TaskCategory.values.firstWhere(
      (category) => category.name == value,
      orElse: () => throw const AppFailure(
        code: 'DATABASE_UNAVAILABLE',
        message: 'Stored task category is invalid.',
      ),
    );
  }

  static String _statusToDatabase(TaskStatus status) {
    return switch (status) {
      TaskStatus.active => 'PENDING',
      TaskStatus.completed => 'COMPLETED',
      TaskStatus.overdueReview => 'OVERDUE_REVIEW',
      TaskStatus.completedLate => 'COMPLETED_LATE',
      TaskStatus.missed => 'MISSED',
      TaskStatus.archived => 'ARCHIVED',
    };
  }

  static TaskStatus _statusFromDatabase(String value) {
    return switch (value) {
      'PENDING' => TaskStatus.active,
      'COMPLETED' => TaskStatus.completed,
      'OVERDUE_REVIEW' => TaskStatus.overdueReview,
      'COMPLETED_LATE' => TaskStatus.completedLate,
      'MISSED' => TaskStatus.missed,
      'ARCHIVED' => TaskStatus.archived,
      _ => throw const AppFailure(
        code: 'DATABASE_UNAVAILABLE',
        message: 'Stored task status is invalid.',
      ),
    };
  }

  static String _eventTypeFor(TaskStatus target) {
    return switch (target) {
      TaskStatus.completed => 'TASK_COMPLETED',
      TaskStatus.overdueReview => 'TASK_OVERDUE',
      TaskStatus.completedLate => 'TASK_COMPLETED_LATE',
      TaskStatus.missed => 'TASK_MISSED',
      TaskStatus.archived => 'TASK_ARCHIVED',
      TaskStatus.active => throw const AppFailure(
        code: 'VALIDATION_FAILED',
        message: 'Task cannot transition back to active.',
      ),
    };
  }

  static bool _canTransition(TaskStatus from, TaskStatus to) {
    return switch (from) {
      TaskStatus.active =>
        to == TaskStatus.completed ||
            to == TaskStatus.overdueReview ||
            to == TaskStatus.archived,
      TaskStatus.overdueReview =>
        to == TaskStatus.missed || to == TaskStatus.completedLate,
      TaskStatus.completed ||
      TaskStatus.missed ||
      TaskStatus.completedLate => to == TaskStatus.archived,
      TaskStatus.archived => false,
    };
  }

  static void _validateDraft(TaskDraft draft) {
    final titleLength = draft.title.trim().length;
    if (titleLength < 1 ||
        titleLength > taskTitleMaxLength ||
        draft.estimatedMinutes <= 0 ||
        draft.notes.length > taskNotesMaxLength ||
        !_hasValidCustomCategory(draft) ||
        (draft.taskReminderOffsetMinutes != null &&
            draft.taskReminderOffsetMinutes! <= 0)) {
      throw const AppFailure(
        code: 'VALIDATION_FAILED',
        message: 'Task fields are invalid.',
      );
    }
  }

  static void _validateTask(TaskItem task) {
    _validateDraft(
      TaskDraft(
        title: task.title,
        dueAt: task.dueAt,
        category: task.category,
        isImportant: task.isImportant,
        estimatedMinutes: task.estimatedMinutes,
        notes: task.notes,
        customCategoryLabel: task.customCategoryLabel,
        taskReminderOffsetMinutes: task.taskReminderOffsetMinutes,
      ),
    );
  }

  static bool _hasValidCustomCategory(TaskDraft draft) {
    final label = draft.customCategoryLabel?.trim() ?? '';
    if (draft.category == TaskCategory.custom) {
      return label.isNotEmpty && label.length <= taskCustomCategoryMaxLength;
    }
    return label.isEmpty;
  }

  static Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on AppFailure {
      rethrow;
    } catch (error) {
      final value = error.toString().toLowerCase();
      throw AppFailure(
        code:
            value.contains('database or disk is full') ||
                value.contains('sqlite_full')
            ? 'STORAGE_FULL'
            : 'DATABASE_UNAVAILABLE',
        message: 'The local database operation failed.',
        cause: error,
      );
    }
  }
}
