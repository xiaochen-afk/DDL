import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/app_failure.dart';
import '../domain/ports.dart';
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
      );

      await db.transaction((transaction) async {
        await transaction.insert('tasks', _taskToRow(task));
        await _insertEvent(
          transaction,
          taskId: task.id,
          eventType: 'TASK_CREATED',
          occurredAt: now,
        );
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
        if (current.status != task.status) {
          throw const AppFailure(
            code: 'VALIDATION_FAILED',
            message: 'Status changes must use transitionTask.',
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
        if (!_canTransition(current.status, target)) {
          throw const AppFailure(
            code: 'VALIDATION_FAILED',
            message: 'Task status transition is not allowed.',
          );
        }

        final now = _clock.now();
        final isCompleted =
            target == TaskStatus.completed ||
            target == TaskStatus.completedLate;
        final updated = current.copyWith(
          status: target,
          completedAt: isCompleted ? now : current.completedAt,
          updatedAt: now,
          version: current.version + 1,
        );
        final row = _taskToRow(updated);
        row['archived_at'] = target == TaskStatus.archived
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
          eventType: _eventTypeFor(target),
          occurredAt: now,
          metadata: {
            'from': _statusToDatabase(current.status),
            'to': _statusToDatabase(target),
          },
        );
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
      });
    });
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
      'risk_score_snapshot': task.riskScoreAt(_clock.now()),
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
        titleLength > 60 ||
        draft.estimatedMinutes <= 0 ||
        draft.notes.length > 300) {
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
      ),
    );
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
