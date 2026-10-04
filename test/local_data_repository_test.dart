import 'dart:io';

import 'package:ddl_survival/src/core/app_failure.dart';
import 'package:ddl_survival/src/data/database/app_database.dart';
import 'package:ddl_survival/src/data/local_settings_repository.dart';
import 'package:ddl_survival/src/data/reminder_repository.dart';
import 'package:ddl_survival/src/data/sqlite_task_repository.dart';
import 'package:ddl_survival/src/domain/local_data.dart';
import 'package:ddl_survival/src/domain/task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as path;

void main() {
  sqfliteFfiInit();
  late AppDatabase database;
  late SqlitePreferenceRepository preferences;
  late SqliteProfileRepository profiles;
  late SqliteReminderRepository reminders;
  late SqliteTaskRepository tasks;

  setUp(() {
    database = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    preferences = SqlitePreferenceRepository(database);
    profiles = SqliteProfileRepository(database);
    reminders = SqliteReminderRepository(database);
    tasks = SqliteTaskRepository(database);
  });

  tearDown(() async => database.close());

  test('preferences initialize once and persist edits in SQLite', () async {
    final initial = await preferences.getOrCreate();
    expect(initial.copyTone, 'standard');
    expect(initial.quietHoursStartMinute, 1380);
    expect(initial.defaultReminderOffsetsMinutes, [1440, 180]);
    final saved = await preferences.save(
      initial.copyWith(
        copyTone: 'gentle',
        notificationsEnabled: false,
        quietHoursStartMinute: 22 * 60 + 15,
        quietHoursEndMinute: 6 * 60 + 45,
        defaultReminderOffsetsMinutes: [60, 15],
      ),
    );
    final reloaded = await preferences.getOrCreate();
    expect(reloaded.copyTone, 'gentle');
    expect(reloaded.notificationsEnabled, isFalse);
    expect(reloaded.quietHoursStartMinute, 1335);
    expect(reloaded.quietHoursEndMinute, 405);
    expect(reloaded.defaultReminderOffsetsMinutes, [60, 15]);
    expect(reloaded.updatedAt, saved.updatedAt);
    final db = await database.database;
    expect((await db.query('preferences')).length, 1);
  });

  test('invalid preferences do not replace persisted values', () async {
    await preferences.getOrCreate();
    expect(
      () => preferences.save(
        const AppPreferences(defaultReminderOffsetsMinutes: [0]),
      ),
      throwsA(
        isA<AppFailure>().having((e) => e.code, 'code', 'VALIDATION_FAILED'),
      ),
    );
    expect((await preferences.getOrCreate()).defaultReminderOffsetsMinutes, [
      1440,
      180,
    ]);
  });

  test(
    'profile initializes and preserves creation timestamp on edits',
    () async {
      final initial = await profiles.getOrCreate();
      expect(initial.nickname, 'DDL 幸存者');
      final changed = await profiles.save(
        initial.copyWith(nickname: '  vivo 用户  ', motto: '继续前进'),
      );
      expect(changed.nickname, 'vivo 用户');
      final reloaded = await profiles.getOrCreate();
      expect(reloaded.motto, '继续前进');
      expect(reloaded.createdAt, initial.createdAt);
      expect((await (await database.database).query('profile')).length, 1);
    },
  );

  test(
    'reminder replacement, status and cancellation are transactional',
    () async {
      final task = await tasks.createTask(
        TaskDraft(
          title: '提醒记录测试',
          dueAt: DateTime.now().add(const Duration(days: 2)),
          category: TaskCategory.study,
          isImportant: true,
          estimatedMinutes: 30,
        ),
      );
      final due = task.dueAt.subtract(const Duration(hours: 3));
      final first = ReminderRecord(
        id: 'r1',
        taskId: task.id,
        scheduledAt: due,
        channel: ReminderChannel.normal,
        status: ReminderStatus.pending,
      );
      await reminders.replaceForTask(task.id, [first]);
      expect((await reminders.listForTask(task.id)).single.id, 'r1');
      final scheduled = await reminders.updateStatus(
        'r1',
        ReminderStatus.scheduled,
        platformNotificationId: 'android-1',
      );
      expect(scheduled.platformNotificationId, 'android-1');
      expect(
        (await reminders.listOutstanding()).single.status,
        ReminderStatus.scheduled,
      );
      final failed = await reminders.updateStatus(
        'r1',
        ReminderStatus.scheduleFailed,
        lastErrorCode: 'TEMPORARY_FAILURE',
      );
      expect(failed.platformNotificationId, 'android-1');
      expect(failed.lastErrorCode, 'TEMPORARY_FAILURE');
      final retried = await reminders.updateStatus(
        'r1',
        ReminderStatus.scheduled,
      );
      expect(retried.platformNotificationId, 'android-1');
      expect(retried.lastErrorCode, isNull);
      expect(await reminders.cancelForTask(task.id), 1);
      expect(await reminders.cancelForTask(task.id), 0);
      expect(await reminders.listOutstanding(), isEmpty);
      expect(
        (await reminders.listForTask(task.id)).single.status,
        ReminderStatus.cancelled,
      );
    },
  );

  test('failed replacement rolls back old reminder rows', () async {
    final firstTask = await tasks.createTask(
      TaskDraft(
        title: '任务一',
        dueAt: DateTime.now().add(const Duration(days: 2)),
        category: TaskCategory.work,
        isImportant: false,
        estimatedMinutes: 30,
      ),
    );
    final secondTask = await tasks.createTask(
      TaskDraft(
        title: '任务二',
        dueAt: DateTime.now().add(const Duration(days: 2)),
        category: TaskCategory.life,
        isImportant: false,
        estimatedMinutes: 30,
      ),
    );
    ReminderRecord plan(String id, String taskId) => ReminderRecord(
      id: id,
      taskId: taskId,
      scheduledAt: DateTime.now(),
      channel: ReminderChannel.normal,
      status: ReminderStatus.pending,
    );
    await reminders.replaceForTask(firstTask.id, [plan('old', firstTask.id)]);
    await reminders.replaceForTask(secondTask.id, [
      plan('collision', secondTask.id),
    ]);
    expect(
      () => reminders.replaceForTask(firstTask.id, [
        plan('new', firstTask.id),
        plan('collision', firstTask.id),
      ]),
      throwsA(isA<AppFailure>()),
    );
    expect((await reminders.listForTask(firstTask.id)).map((r) => r.id), [
      'old',
    ]);
  });

  test('settings and profile survive closing and reopening database', () async {
    final directory = await Directory.systemTemp.createTemp('ddl_local_data_');
    final dbPath = path.join(directory.path, 'persistent.db');
    final first = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: dbPath,
    );
    final second = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: dbPath,
    );
    try {
      final pref = SqlitePreferenceRepository(first);
      final profile = SqliteProfileRepository(first);
      await pref.save(
        const AppPreferences(
          notificationsEnabled: false,
          copyTone: 'off',
          defaultReminderOffsetsMinutes: [15],
        ),
      );
      await profile.save(const UserProfile(nickname: '重启仍在', motto: '离线保存'));
      await first.close();
      expect(
        (await SqlitePreferenceRepository(
          second,
        ).getOrCreate()).notificationsEnabled,
        isFalse,
      );
      expect(
        (await SqlitePreferenceRepository(
          second,
        ).getOrCreate()).defaultReminderOffsetsMinutes,
        [15],
      );
      expect(
        (await SqliteProfileRepository(second).getOrCreate()).nickname,
        '重启仍在',
      );
    } finally {
      await first.close();
      await second.close();
      await directory.delete(recursive: true);
    }
  });
}
