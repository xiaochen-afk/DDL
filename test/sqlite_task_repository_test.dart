import 'dart:io';

import 'package:ddl_survival/src/core/app_failure.dart';
import 'package:ddl_survival/src/data/database/app_database.dart';
import 'package:ddl_survival/src/data/database/schema.dart';
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

  test('creates v2 schema, indexes, and system categories', () async {
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
    expect(await db.getVersion(), 2);

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

  test('accepts 80-character titles and 1000-character notes', () async {
    final draft = TaskDraft(
      title: 't' * 80,
      dueAt: DateTime.utc(2026, 9, 20),
      category: TaskCategory.study,
      isImportant: true,
      estimatedMinutes: 30,
      notes: 'n' * 1000,
    );
    final created = await repository.createTask(draft);
    expect(created.title.length, 80);
    expect(created.notes.length, 1000);

    for (final invalidDraft in [
      TaskDraft(
        title: 't' * 81,
        dueAt: draft.dueAt,
        category: draft.category,
        isImportant: draft.isImportant,
        estimatedMinutes: draft.estimatedMinutes,
      ),
      TaskDraft(
        title: draft.title,
        dueAt: draft.dueAt,
        category: draft.category,
        isImportant: draft.isImportant,
        estimatedMinutes: draft.estimatedMinutes,
        notes: 'n' * 1001,
      ),
    ]) {
      expect(
        () => repository.createTask(invalidDraft),
        throwsA(
          isA<AppFailure>().having(
            (failure) => failure.code,
            'code',
            'VALIDATION_FAILED',
          ),
        ),
      );
    }
  });

  test('upgrades v1 while preserving tasks, events, and reminders', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'ddl-survival-migration-test-',
    );
    final databasePath = path.join(temporaryDirectory.path, 'migration.db');
    final oldDatabase = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => createSchemaV1(db),
      ),
    );
    AppDatabase? upgradedDatabase;

    try {
      const taskId = 'v1-task';
      final timestamp = DateTime.utc(2026, 9, 18).millisecondsSinceEpoch;
      await oldDatabase.insert('tasks', {
        'id': taskId,
        'title': '旧版任务',
        'category_id': 'study',
        'important': 1,
        'due_at': timestamp + const Duration(days: 2).inMilliseconds,
        'estimated_minutes': 60,
        'notes': '旧版备注',
        'status': 'PENDING',
        'risk_config_version': 1,
        'version': 1,
        'created_at': timestamp,
        'updated_at': timestamp,
      });
      await oldDatabase.insert('task_events', {
        'id': 'v1-event',
        'task_id': taskId,
        'event_type': 'TASK_CREATED',
        'occurred_at': timestamp,
      });
      await oldDatabase.insert('reminders', {
        'id': 'v1-reminder',
        'platform_notification_id': '123',
        'task_id': taskId,
        'scheduled_at': timestamp + const Duration(days: 1).inMilliseconds,
        'channel': 'normal',
        'status': 'SCHEDULED',
        'created_at': timestamp,
        'updated_at': timestamp,
      });
      await oldDatabase.close();

      upgradedDatabase = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: databasePath,
      );
      final upgraded = await upgradedDatabase.database;
      expect(await upgraded.getVersion(), 2);
      expect(await upgraded.query('tasks'), hasLength(1));
      expect(await upgraded.query('task_events'), hasLength(1));
      expect(await upgraded.query('reminders'), hasLength(1));
      expect(await upgraded.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      final meta = await upgraded.query(
        'app_meta',
        where: 'key = ?',
        whereArgs: ['schema_version'],
      );
      expect(meta.single['value'], '2');

      await upgraded.update(
        'tasks',
        {'title': 't' * 80, 'notes': 'n' * 1000},
        where: 'id = ?',
        whereArgs: [taskId],
      );
      final task = (await upgraded.query('tasks')).single;
      expect(task['title'], 't' * 80);
      expect(task['notes'], 'n' * 1000);
    } finally {
      await oldDatabase.close();
      await upgradedDatabase?.close();
      if (temporaryDirectory.existsSync()) {
        await temporaryDirectory.delete(recursive: true);
      }
    }
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

  test(
    'reconciles exact-deadline tasks once and leaves terminal tasks alone',
    () async {
      final dueAt = DateTime.utc(2026, 9, 18, 9);
      final due = await repository.createTask(
        TaskDraft(
          title: '刚好到期',
          dueAt: dueAt,
          category: TaskCategory.study,
          isImportant: true,
          estimatedMinutes: 30,
        ),
      );
      final future = await repository.createTask(
        TaskDraft(
          title: '尚未到期',
          dueAt: dueAt.add(const Duration(minutes: 1)),
          category: TaskCategory.study,
          isImportant: true,
          estimatedMinutes: 30,
        ),
      );
      final completed = await repository.createTask(
        TaskDraft(
          title: '已完成',
          dueAt: dueAt,
          category: TaskCategory.work,
          isImportant: false,
          estimatedMinutes: 20,
        ),
      );
      await repository.transitionTask(completed.id, TaskStatus.completed);

      clock.value = dueAt;
      expect(await repository.reconcileOverdue(clock.now()), 1);
      expect(await repository.reconcileOverdue(clock.now()), 0);
      expect(
        (await repository.getTask(due.id))!.status,
        TaskStatus.overdueReview,
      );
      expect((await repository.getTask(due.id))!.version, 2);
      expect((await repository.getTask(future.id))!.status, TaskStatus.active);
      expect(
        (await repository.getTask(completed.id))!.status,
        TaskStatus.completed,
      );

      final db = await database.database;
      final overdueEvents = await db.query(
        'task_events',
        where: 'task_id = ? AND event_type = ?',
        whereArgs: [due.id, 'TASK_OVERDUE'],
      );
      expect(overdueEvents, hasLength(1));
      expect(overdueEvents.single['occurred_at'], dueAt.millisecondsSinceEpoch);

      await repository.transitionTask(due.id, TaskStatus.missed);
      expect((await repository.getTask(due.id))!.status, TaskStatus.missed);
      expect(await repository.reconcileOverdue(clock.now()), 0);
    },
  );

  test('completion at the deadline becomes overdue, not on-time', () async {
    final dueAt = DateTime.utc(2026, 9, 18, 9);
    final task = await repository.createTask(
      TaskDraft(
        title: '到点完成',
        dueAt: dueAt,
        category: TaskCategory.life,
        isImportant: true,
        estimatedMinutes: 15,
      ),
    );
    clock.value = dueAt;

    final result = await repository.transitionTask(
      task.id,
      TaskStatus.completed,
    );
    expect(result.status, TaskStatus.overdueReview);
    expect(result.completedAt, isNull);
    final db = await database.database;
    final events = await db.query(
      'task_events',
      where: 'task_id = ?',
      whereArgs: [task.id],
      orderBy: 'occurred_at',
    );
    expect(events.map((event) => event['event_type']), [
      'TASK_CREATED',
      'TASK_OVERDUE',
    ]);
  });

  test(
    'repeating either confession decision writes no duplicate event',
    () async {
      for (final target in [TaskStatus.missed, TaskStatus.completedLate]) {
        final task = await repository.createTask(
          TaskDraft(
            title: '结案 ${target.name}',
            dueAt: DateTime.utc(2026, 9, 18, 9),
            category: TaskCategory.study,
            isImportant: true,
            estimatedMinutes: 30,
          ),
        );
        clock.value = task.dueAt;
        await repository.reconcileOverdue(clock.now());
        final settled = await repository.transitionTask(task.id, target);
        final repeated = await repository.transitionTask(task.id, target);
        expect(repeated.version, settled.version);
        expect(repeated.status, target);

        final db = await database.database;
        final events = await db.query(
          'task_events',
          where: 'task_id = ?',
          whereArgs: [task.id],
        );
        expect(events, hasLength(3));
      }
    },
  );

  test('rolls back every overdue transition if one event fails', () async {
    final dueAt = DateTime.utc(2026, 9, 18, 9);
    for (final title in ['任务甲', '任务乙']) {
      await repository.createTask(
        TaskDraft(
          title: title,
          dueAt: dueAt,
          category: TaskCategory.study,
          isImportant: true,
          estimatedMinutes: 30,
        ),
      );
    }
    final db = await database.database;
    await db.execute('''
      CREATE TRIGGER reject_overdue_event
      BEFORE INSERT ON task_events
      WHEN NEW.event_type = 'TASK_OVERDUE'
      BEGIN
        SELECT RAISE(ABORT, 'test overdue event failure');
      END
    ''');
    clock.value = dueAt;

    expect(
      () => repository.reconcileOverdue(clock.now()),
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.code,
          'code',
          'DATABASE_UNAVAILABLE',
        ),
      ),
    );
    final tasks = await db.query('tasks');
    expect(tasks.every((task) => task['status'] == 'PENDING'), isTrue);
    expect(tasks.every((task) => task['version'] == 1), isTrue);
    expect(
      await db.query(
        'task_events',
        where: 'event_type = ?',
        whereArgs: ['TASK_OVERDUE'],
      ),
      isEmpty,
    );
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

  test(
    'editing persists event, risk snapshot, and archive-safe history',
    () async {
      final first = await repository.createTask(
        TaskDraft(
          title: '第一项',
          dueAt: clock.value.add(const Duration(days: 3)),
          category: TaskCategory.study,
          isImportant: false,
          estimatedMinutes: 30,
        ),
      );
      expect(await repository.hasMeaningfulHistory(first.id), isFalse);
      final edited = await repository.updateTask(
        first.copyWith(
          title: '修改任务',
          dueAt: clock.value.add(const Duration(hours: 2)),
          category: TaskCategory.work,
          isImportant: true,
          estimatedMinutes: 120,
          notes: '编辑备注',
        ),
      );
      expect(await repository.hasMeaningfulHistory(first.id), isTrue);
      final db = await database.database;
      final rows = await db.query(
        'tasks',
        where: 'id = ?',
        whereArgs: [first.id],
      );
      expect(rows.single['title'], '修改任务');
      expect(rows.single['notes'], '编辑备注');
      expect(rows.single['version'], edited.version);
      expect(rows.single['risk_config_version'], riskConfigVersion);
      expect(rows.single['risk_score_snapshot'], greaterThan(0));
      final events = await db.query(
        'task_events',
        where: 'task_id = ?',
        whereArgs: [first.id],
      );
      expect(
        events.map((event) => event['event_type']),
        contains('TASK_UPDATED'),
      );
    },
  );

  test('missed history rate survives archive', () async {
    final missed = await repository.createTask(
      TaskDraft(
        title: '错过的任务',
        dueAt: clock.value.add(const Duration(minutes: 1)),
        category: TaskCategory.study,
        isImportant: true,
        estimatedMinutes: 30,
      ),
    );
    clock.value = missed.dueAt;
    await repository.reconcileOverdue(clock.value);
    await repository.transitionTask(missed.id, TaskStatus.missed);
    await repository.transitionTask(missed.id, TaskStatus.archived);
    expect((await repository.missedRatesByCategory())[TaskCategory.study], 1);
    expect(await repository.hasMeaningfulHistory(missed.id), isTrue);
  });
}
