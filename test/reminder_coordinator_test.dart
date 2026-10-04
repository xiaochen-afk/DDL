import 'dart:io';

import 'package:ddl_survival/src/data/database/app_database.dart';
import 'package:ddl_survival/src/data/local_settings_repository.dart';
import 'package:ddl_survival/src/data/reminder_repository.dart';
import 'package:ddl_survival/src/data/sqlite_task_repository.dart';
import 'package:ddl_survival/src/domain/local_data.dart';
import 'package:ddl_survival/src/domain/ports.dart';
import 'package:ddl_survival/src/domain/reminder_coordinator.dart';
import 'package:ddl_survival/src/domain/task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Clock implements ClockPort {
  _Clock(this.value);
  DateTime value;
  @override
  DateTime now() => value;
}

void main() {
  sqfliteFfiInit();
  late AppDatabase database;
  late _Clock clock;
  late SqliteTaskRepository tasks;
  late SqliteReminderRepository reminders;
  late SqlitePreferenceRepository preferences;
  late ReminderCoordinator coordinator;

  setUp(() {
    clock = _Clock(DateTime(2026, 10, 4, 8));
    database = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    tasks = SqliteTaskRepository(database, clock: clock);
    reminders = SqliteReminderRepository(database, clock: clock);
    preferences = SqlitePreferenceRepository(database, clock: clock);
    coordinator = ReminderCoordinator(reminders);
  });
  tearDown(() async => database.close());

  test(
    'startup reconciliation is idempotent and retains failed records',
    () async {
      final task = await tasks.createTask(
        TaskDraft(
          title: '测试排程',
          dueAt: DateTime(2026, 10, 6, 18),
          category: TaskCategory.work,
          isImportant: false,
          estimatedMinutes: 60,
        ),
      );
      final prefs = await preferences.getOrCreate();
      expect(await coordinator.reconcile([task], prefs, clock.value), 2);
      final first = await reminders.listForTask(task.id);
      expect(await coordinator.reconcile([task], prefs, clock.value), 0);
      expect(
        (await reminders.listForTask(task.id)).map((r) => r.id),
        first.map((r) => r.id),
      );

      await reminders.updateStatus(
        first.first.id,
        ReminderStatus.scheduleFailed,
        lastErrorCode: 'NOTIFICATION_SCHEDULE_FAILED',
      );
      expect(await coordinator.reconcile([task], prefs, clock.value), 0);
      final failed = (await reminders.listForTask(task.id)).first;
      expect(failed.status, ReminderStatus.scheduleFailed);
      expect(failed.lastErrorCode, 'NOTIFICATION_SCHEDULE_FAILED');
    },
  );

  test(
    'edit cancels old plan, completion cancels new plan without erasing history',
    () async {
      final task = await tasks.createTask(
        TaskDraft(
          title: '调整截止',
          dueAt: DateTime(2026, 10, 6, 18),
          category: TaskCategory.study,
          isImportant: false,
          estimatedMinutes: 60,
        ),
      );
      final prefs = await preferences.getOrCreate();
      await coordinator.reconcile([task], prefs, clock.value);
      final originalIds = (await reminders.listForTask(
        task.id,
      )).map((record) => record.id).toSet();

      final edited = await tasks.updateTask(
        task.copyWith(dueAt: DateTime(2026, 10, 7, 18)),
      );
      expect(await coordinator.reconcile([edited], prefs, clock.value), 4);
      final afterEdit = await reminders.listForTask(task.id);
      expect(afterEdit.length, 4);
      expect(
        afterEdit
            .where((record) => originalIds.contains(record.id))
            .every((record) => record.status == ReminderStatus.cancelled),
        true,
      );

      final completed = await tasks.transitionTask(
        task.id,
        TaskStatus.completed,
      );
      expect(await coordinator.reconcile([completed], prefs, clock.value), 2);
      expect(await reminders.listOutstanding(), isEmpty);
      expect((await reminders.listForTask(task.id)).length, 4);
    },
  );

  test(
    'notification switch cancels then can re-arm the same desired plan',
    () async {
      final task = await tasks.createTask(
        TaskDraft(
          title: '通知开关',
          dueAt: DateTime(2026, 10, 6, 18),
          category: TaskCategory.life,
          isImportant: false,
          estimatedMinutes: 60,
        ),
      );
      final enabled = await preferences.getOrCreate();
      await coordinator.reconcile([task], enabled, clock.value);
      expect(
        await coordinator.reconcile(
          [task],
          enabled.copyWith(notificationsEnabled: false),
          clock.value,
        ),
        2,
      );
      expect(await reminders.listOutstanding(), isEmpty);
      expect(await coordinator.reconcile([task], enabled, clock.value), 2);
      expect((await reminders.listOutstanding()).length, 2);
    },
  );

  test('persisted plan survives reopen and startup sync is a no-op', () async {
    final directory = await Directory.systemTemp.createTemp('ddl_reminder_');
    final dbPath = path.join(directory.path, 'reminders.db');
    final first = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: dbPath,
    );
    final second = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: dbPath,
    );
    try {
      final firstTasks = SqliteTaskRepository(first, clock: clock);
      final firstReminders = SqliteReminderRepository(first, clock: clock);
      final firstPreferences = SqlitePreferenceRepository(first, clock: clock);
      final task = await firstTasks.createTask(
        TaskDraft(
          title: '冷启动提醒',
          dueAt: DateTime(2026, 10, 6, 18),
          category: TaskCategory.study,
          isImportant: false,
          estimatedMinutes: 60,
        ),
      );
      await ReminderCoordinator(
        firstReminders,
      ).reconcile([task], await firstPreferences.getOrCreate(), clock.value);
      final originalIds = (await firstReminders.listForTask(
        task.id,
      )).map((record) => record.id).toList();
      await first.close();

      final reopenedTask = (await SqliteTaskRepository(
        second,
      ).listTasks()).single;
      final reopenedReminders = SqliteReminderRepository(second, clock: clock);
      expect(
        await ReminderCoordinator(reopenedReminders).reconcile(
          [reopenedTask],
          await SqlitePreferenceRepository(second).getOrCreate(),
          clock.value,
        ),
        0,
      );
      expect(
        (await reopenedReminders.listForTask(
          task.id,
        )).map((record) => record.id),
        originalIds,
      );
    } finally {
      await first.close();
      await second.close();
      await directory.delete(recursive: true);
    }
  });
}
