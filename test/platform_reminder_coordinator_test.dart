import 'package:ddl_survival/src/data/in_memory_task_repository.dart';
import 'package:ddl_survival/src/data/installation_store.dart';
import 'package:ddl_survival/src/data/local_settings_repository.dart';
import 'package:ddl_survival/src/data/reminder_repository.dart';
import 'package:ddl_survival/src/domain/local_data.dart';
import 'package:ddl_survival/src/domain/platform_reminder_coordinator.dart';
import 'package:ddl_survival/src/domain/ports.dart';
import 'package:ddl_survival/src/domain/task.dart';
import 'package:ddl_survival/src/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNotifications implements NotificationPort {
  bool authorized = true;
  bool exact = true;
  bool failSchedule = false;
  int pendingLimit = 60;
  final Set<int> pending = {};
  final List<bool> scheduledExact = [];
  int permissionRequests = 0;

  @override
  Future<NotificationCapabilities> inspect() async => NotificationCapabilities(
    authorized: authorized,
    exact: exact,
    exactPermissionRequired: true,
    pendingLimit: pendingLimit,
  );

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return authorized;
  }

  @override
  Future<bool> requestExactPermission() async => exact;

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<String> deviceTimezone() async => 'Asia/Shanghai';

  @override
  Future<Set<int>> pendingIds() async => pending.toSet();

  @override
  Future<void> schedule({
    required int id,
    required DateTime fireAt,
    required ReminderChannel channel,
    required String taskId,
    required bool exact,
  }) async {
    if (failSchedule) throw StateError('test schedule failure');
    pending.add(id);
    scheduledExact.add(exact);
  }

  @override
  Future<void> cancel(int id) async {
    pending.remove(id);
  }

  @override
  Stream<String> get selectedTaskIds => const Stream.empty();

  @override
  String? takeInitialTaskId() => null;
}

class _FixedClock implements ClockPort {
  const _FixedClock(this.value);
  final DateTime value;

  @override
  DateTime now() => value;
}

TaskItem _task(DateTime now) => TaskItem(
  id: 'task-1',
  title: '平台通知测试',
  dueAt: now.add(const Duration(days: 2)),
  category: TaskCategory.study,
  isImportant: true,
  estimatedMinutes: 60,
  status: TaskStatus.active,
  createdAt: now,
);

ReminderRecord _record(String id, DateTime when) => ReminderRecord(
  id: id,
  taskId: 'task-1',
  scheduledAt: when,
  channel: ReminderChannel.normal,
  status: ReminderStatus.pending,
);

void main() {
  late DateTime now;
  late InMemoryReminderRepository reminders;
  late _FakeNotifications notifications;
  late PlatformReminderCoordinator coordinator;
  late TaskItem task;

  setUp(() {
    now = DateTime(2026, 10, 5, 8);
    reminders = InMemoryReminderRepository();
    notifications = _FakeNotifications();
    coordinator = PlatformReminderCoordinator(reminders, notifications);
    task = _task(now);
  });

  test(
    'schedules once, records platform id, and cancels stale device alarm',
    () async {
      final record = _record('r1', now.add(const Duration(hours: 3)));
      await reminders.syncPlanForTask(task.id, [record]);
      final first = await coordinator.reconcile(
        [task],
        const AppPreferences(),
        now,
      );
      expect(first.capabilities.authorized, true);
      expect(notifications.pending, {platformNotificationIdFor('r1')});
      expect(
        (await reminders.listForTask(task.id)).single.status,
        ReminderStatus.scheduled,
      );
      expect(
        (await reminders.listForTask(task.id)).single.platformNotificationId,
        '${platformNotificationIdFor('r1')}',
      );

      await coordinator.reconcile([task], const AppPreferences(), now);
      expect(notifications.scheduledExact, [true]);
      await reminders.cancelForTask(task.id);
      await coordinator.reconcile([task], const AppPreferences(), now);
      expect(notifications.pending, isEmpty);
    },
  );

  test(
    'denied permission records failure and retries after authorization',
    () async {
      await reminders.syncPlanForTask(task.id, [
        _record('r1', now.add(const Duration(hours: 3))),
      ]);
      notifications.authorized = false;
      await coordinator.reconcile([task], const AppPreferences(), now);
      final denied = (await reminders.listForTask(task.id)).single;
      expect(denied.status, ReminderStatus.scheduleFailed);
      expect(denied.lastErrorCode, 'NOTIFICATION_PERMISSION_DENIED');
      expect(notifications.pending, isEmpty);
      expect(notifications.permissionRequests, 0);

      notifications.authorized = true;
      notifications.exact = false;
      await coordinator.reconcile([task], const AppPreferences(), now);
      expect(notifications.scheduledExact, [false]);
      expect(
        (await reminders.listForTask(task.id)).single.status,
        ReminderStatus.scheduled,
      );
    },
  );

  test('schedule failure remains retryable', () async {
    await reminders.syncPlanForTask(task.id, [
      _record('r1', now.add(const Duration(hours: 3))),
    ]);
    notifications.failSchedule = true;
    final failed = await coordinator.reconcile(
      [task],
      const AppPreferences(),
      now,
    );
    expect(failed.errorCode, 'NOTIFICATION_SCHEDULE_FAILED');
    expect(
      (await reminders.listForTask(task.id)).single.status,
      ReminderStatus.scheduleFailed,
    );
    notifications.failSchedule = false;
    await coordinator.reconcile([task], const AppPreferences(), now);
    expect(
      (await reminders.listForTask(task.id)).single.status,
      ReminderStatus.scheduled,
    );
  });

  test(
    'rolling window schedules only earliest pending notifications',
    () async {
      notifications.pendingLimit = 2;
      await reminders.syncPlanForTask(task.id, [
        _record('r3', now.add(const Duration(hours: 3))),
        _record('r1', now.add(const Duration(hours: 1))),
        _record('r2', now.add(const Duration(hours: 2))),
      ]);
      await coordinator.reconcile([task], const AppPreferences(), now);
      expect(notifications.pending, {
        platformNotificationIdFor('r1'),
        platformNotificationIdFor('r2'),
      });
      expect(
        (await reminders.listForTask(
          task.id,
        )).where((record) => record.status == ReminderStatus.pending).single.id,
        'r3',
      );
    },
  );

  test('exact capability change forces re-schedule in inexact mode', () async {
    await reminders.syncPlanForTask(task.id, [
      _record('r1', now.add(const Duration(hours: 3))),
    ]);
    final first = await coordinator.reconcile(
      [task],
      const AppPreferences(),
      now,
    );
    notifications.exact = false;
    await coordinator.reconcile(
      [task],
      const AppPreferences(),
      now,
      previousCapabilities: first.capabilities,
    );
    expect(notifications.scheduledExact, [true, false]);
  });

  test(
    'controller startup does not prompt; user enable prompts and retries',
    () async {
      notifications.authorized = false;
      final clock = _FixedClock(now);
      final preferences = InMemoryPreferenceRepository();
      final controller = AppController(
        InMemoryTaskRepository(clock: clock),
        InMemoryInstallationStore(),
        clock: clock,
        preferenceRepository: preferences,
        reminderRepository: reminders,
        notificationPort: notifications,
      );
      await controller.load();
      expect(notifications.permissionRequests, 0);
      expect(controller.preferences.timezone, 'Asia/Shanghai');
      await controller.addTask(
        TaskDraft(
          title: '权限流程',
          dueAt: now.add(const Duration(days: 2)),
          category: TaskCategory.study,
          isImportant: false,
          estimatedMinutes: 30,
        ),
      );
      expect(
        (await reminders.listOutstanding()).every(
          (record) => record.status == ReminderStatus.scheduleFailed,
        ),
        isTrue,
      );
      await controller.setNotificationsEnabled(false);
      await controller.setNotificationsEnabled(true);
      expect(notifications.permissionRequests, 1);
      notifications.authorized = true;
      await controller.refreshOverdue();
      expect(notifications.pending, isNotEmpty);
      expect(controller.reminderSyncErrorCode, isNull);
      controller.dispose();
    },
  );
}
