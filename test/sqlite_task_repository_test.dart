import 'dart:io';

import 'package:ddl_survival/src/core/app_failure.dart';
import 'package:ddl_survival/src/data/database/app_database.dart';
import 'package:ddl_survival/src/data/sqlite_task_repository.dart';
import 'package:ddl_survival/src/domain/ports.dart';
import 'package:ddl_survival/src/domain/task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FixedClock implements ClockPort {
  _FixedClock(this.value);

  DateTime value;

  @override
  DateTime now() => value;
}

void main() {
  sqfliteFfiInit();

  late AppDatabase database;
  late _FixedClock clock;
  late SqliteTaskRepository repository;

  setUp(() {
    clock = _FixedClock(DateTime.utc(2026, 9, 18, 8));
    database = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    repository = SqliteTaskRepository(database, clock: clock);
  });

  tearDown(() async {
    await database.close();
  });

  test('creates v1 schema, indexes, and system categories', () async {
    final db = await database.database;
    final tableRows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final tables = tableRows.map((row) => row['name']).toSet();

    expect(
      tables,
      containsAll([
        'tasks',
        'task_events',
        'categories',
        'reminders',
        'preferences',
        'profile',
        'app_meta',
      ]),
    );
    expect(await db.getVersion(), 1);

    final categories = await db.query(
      'categories',
      columns: ['id'],
      orderBy: 'sort_order',
    );
    expect(categories.map((row) => row['id']), [
      'study',
      'work',
      'life',
      'fun',
    ]);

    final indexRows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index'",
    );
    final indexes = indexRows.map((row) => row['name']).toSet();
    expect(
      indexes,
      containsAll([
        'tasks_status_due_at',
        'tasks_archived_updated_at',
        'task_events_task_occurred_at',
        'reminders_task_scheduled_at',
        'categories_name_unique',
      ]),
    );
  });

  test('creates task and event atomically, then reads it back', () async {
    final dueAt = DateTime.utc(2026, 9, 20, 9, 30);
    final created = await repository.createTask(
      TaskDraft(
        title: '  数据库作业  ',
        dueAt: dueAt,
        category: TaskCategory.study,
        isImportant: true,
        estimatedMinutes: 90,
        notes: '完成 SQLite 接入',
      ),
    );

    final loaded = await repository.getTask(created.id);
    expect(loaded, isNotNull);
    expect(loaded!.title, '数据库作业');
    expect(loaded.dueAt.isAtSameMomentAs(dueAt), isTrue);
    expect(loaded.status, TaskStatus.active);
    expect(loaded.version, 1);

    final db = await database.database;
    final events = await db.query(
      'task_events',
      where: 'task_id = ?',
      whereArgs: [created.id],
    );
    expect(events, hasLength(1));
    expect(events.single['event_type'], 'TASK_CREATED');
  });

  test('persists tasks after the database connection is reopened', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'ddl-survival-sqlite-test-',
    );
    final databasePath = path.join(temporaryDirectory.path, 'persistence.db');
    final firstDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    final firstRepository = SqliteTaskRepository(firstDatabase, clock: clock);

    try {
      final created = await firstRepository.createTask(
        TaskDraft(
          title: '跨重启保留',
          dueAt: DateTime.utc(2026, 9, 24),
          category: TaskCategory.study,
          isImportant: true,
          estimatedMinutes: 50,
        ),
      );
      await firstDatabase.close();

      final reopenedDatabase = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: databasePath,
      );
      final reopenedRepository = SqliteTaskRepository(
        reopenedDatabase,
        clock: clock,
      );
      final loaded = await reopenedRepository.getTask(created.id);

      expect(loaded, isNotNull);
      expect(loaded!.title, '跨重启保留');
      await reopenedDatabase.close();
    } finally {
      await firstDatabase.close();
      if (temporaryDirectory.existsSync()) {
        await temporaryDirectory.delete(recursive: true);
      }
    }
  });

  test(
    'validates transitions and keeps repeated terminal request idempotent',
    () async {
      final created = await repository.createTask(
        TaskDraft(
          title: '状态流转',
          dueAt: DateTime.utc(2026, 9, 19),
          category: TaskCategory.work,
          isImportant: true,
          estimatedMinutes: 30,
        ),
      );

      clock.value = DateTime.utc(2026, 9, 18, 9);
      final completed = await repository.transitionTask(
        created.id,
        TaskStatus.completed,
      );
      final repeated = await repository.transitionTask(
        created.id,
        TaskStatus.completed,
      );

      expect(completed.version, 2);
      expect(repeated.version, 2);
      expect(repeated.completedAt, isNotNull);

      final db = await database.database;
      final events = await db.query(
        'task_events',
        where: 'task_id = ?',
        whereArgs: [created.id],
      );
      expect(events, hasLength(2));

      expect(
        () => repository.transitionTask(created.id, TaskStatus.missed),
        throwsA(
          isA<AppFailure>().having(
            (failure) => failure.code,
            'code',
            'VALIDATION_FAILED',
          ),
        ),
      );
    },
  );

  test('rejects stale updates with optimistic version check', () async {
    final created = await repository.createTask(
      TaskDraft(
        title: '初始标题',
        dueAt: DateTime.utc(2026, 9, 22),
        category: TaskCategory.life,
        isImportant: false,
        estimatedMinutes: 45,
      ),
    );

    final updated = await repository.updateTask(created.copyWith(title: '新标题'));
    expect(updated.title, '新标题');
    expect(updated.version, 2);

    expect(
      () => repository.updateTask(created.copyWith(title: '过期页面写入')),
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.code,
          'code',
          'VALIDATION_FAILED',
        ),
      ),
    );
  });

  test('rolls back task creation when event insertion fails', () async {
    final db = await database.database;
    await db.execute('''
      CREATE TRIGGER reject_task_event
      BEFORE INSERT ON task_events
      BEGIN
        SELECT RAISE(ABORT, 'test event failure');
      END
    ''');

    expect(
      () => repository.createTask(
        TaskDraft(
          title: '必须回滚',
          dueAt: DateTime.utc(2026, 9, 23),
          category: TaskCategory.fun,
          isImportant: false,
          estimatedMinutes: 15,
        ),
      ),
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.code,
          'code',
          'DATABASE_UNAVAILABLE',
        ),
      ),
    );

    expect(await db.query('tasks'), isEmpty);
  });

  test('returns stable not-found error when deleting missing task', () {
    expect(
      () => repository.deleteTask('missing-task'),
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.code,
          'code',
          'TASK_NOT_FOUND',
        ),
      ),
    );
  });
}
