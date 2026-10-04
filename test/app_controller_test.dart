import 'package:ddl_survival/src/core/app_failure.dart';
import 'package:ddl_survival/src/data/in_memory_task_repository.dart';
import 'package:ddl_survival/src/data/installation_store.dart';
import 'package:ddl_survival/src/data/local_settings_repository.dart';
import 'package:ddl_survival/src/data/reminder_repository.dart';
import 'package:ddl_survival/src/domain/local_data.dart';
import 'package:ddl_survival/src/domain/ports.dart';
import 'package:ddl_survival/src/domain/task.dart';
import 'package:ddl_survival/src/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _MutableClock implements ClockPort {
  _MutableClock(this.value);

  DateTime value;

  @override
  DateTime now() => value;
}

class _FailingReminderRepository extends InMemoryReminderRepository {
  bool fail = true;

  @override
  Future<int> syncPlanForTask(String taskId, List<ReminderRecord> desired) {
    if (fail) {
      throw const AppFailure(
        code: 'DATABASE_UNAVAILABLE',
        message: 'Reminder storage temporarily unavailable.',
      );
    }
    return super.syncPlanForTask(taskId, desired);
  }
}

void main() {
  test('task lifecycle updates controller projections', () async {
    final controller = AppController(
      InMemoryTaskRepository(),
      InMemoryInstallationStore(),
    );
    await controller.load();
    final initialCount = controller.activeTasks.length;

    final created = await controller.addTask(
      TaskDraft(
        title: '控制器测试任务',
        dueAt: DateTime.now().add(const Duration(days: 2)),
        category: TaskCategory.work,
        isImportant: true,
        estimatedMinutes: 60,
      ),
    );

    expect(controller.activeTasks.length, initialCount + 1);
    await controller.completeTask(created.id);
    expect(
      controller.completedTasks.any((task) => task.id == created.id),
      isTrue,
    );
  });

  test('survival days start at one and increase by calendar day', () async {
    final today = DateTime.now();
    final controller = AppController(
      InMemoryTaskRepository(),
      InMemoryInstallationStore(
        firstLaunchDate: DateTime(
          today.year,
          today.month,
          today.day,
        ).subtract(const Duration(days: 2)),
      ),
    );

    await controller.load();

    expect(controller.survivalDays, 3);
    expect(controller.tasks, isEmpty);
    expect(controller.pressureScore, 0);
    expect(controller.defeatedCount, 0);
  });

  test('load and refresh move due tasks into confession once', () async {
    final clock = _MutableClock(DateTime.utc(2026, 9, 22, 8));
    final repository = InMemoryTaskRepository(clock: clock);
    final task = await repository.createTask(
      TaskDraft(
        title: '到期任务',
        dueAt: DateTime.utc(2026, 9, 22, 9),
        category: TaskCategory.study,
        isImportant: true,
        estimatedMinutes: 30,
      ),
    );
    clock.value = task.dueAt;
    final controller = AppController(
      repository,
      InMemoryInstallationStore(),
      clock: clock,
    );

    await controller.load();
    expect(controller.activeTasks, isEmpty);
    expect(controller.overdueTasks.single.id, task.id);
    expect(controller.overdueTasks.single.version, 2);
    expect(await controller.refreshOverdue(), 0);
    expect(controller.overdueTasks.single.version, 2);
    expect(await controller.completeTask(task.id), isFalse);

    await controller.completeLate(task.id);
    expect(controller.overdueTasks, isEmpty);
    expect(controller.completedTasks.single.status, TaskStatus.completedLate);
    expect(controller.defeatedCount, 1);
    expect(controller.pressureScore, 0);
  });

  test('a past-due task created now enters confession immediately', () async {
    final clock = _MutableClock(DateTime.utc(2026, 9, 22, 10));
    final controller = AppController(
      InMemoryTaskRepository(clock: clock),
      InMemoryInstallationStore(),
      clock: clock,
    );
    await controller.load();

    final created = await controller.addTask(
      TaskDraft(
        title: '补记的旧 DDL',
        dueAt: DateTime.utc(2026, 9, 22, 9),
        category: TaskCategory.work,
        isImportant: false,
        estimatedMinutes: 30,
      ),
    );
    expect(created.status, TaskStatus.overdueReview);
    expect(controller.activeTasks, isEmpty);
    expect(controller.overdueTasks.single.id, created.id);

    await controller.markMissed(created.id);
    expect(controller.overdueTasks, isEmpty);
    expect(controller.pressureScore, 0);
    expect(controller.defeatedCount, 0);
  });

  test(
    'editing every user field recalculates risk and preserves identity',
    () async {
      final clock = _MutableClock(DateTime.utc(2026, 10, 3, 8));
      final repository = InMemoryTaskRepository(clock: clock);
      final controller = AppController(
        repository,
        InMemoryInstallationStore(),
        clock: clock,
      );
      await controller.load();
      final created = await controller.addTask(
        TaskDraft(
          title: '原任务',
          dueAt: clock.value.add(const Duration(days: 5)),
          category: TaskCategory.study,
          isImportant: false,
          estimatedMinutes: 30,
        ),
      );
      final before = controller.riskFor(created).score;
      final updated = await controller.updateTask(
        created.copyWith(
          title: '修改后',
          dueAt: clock.value.add(const Duration(hours: 2)),
          category: TaskCategory.work,
          isImportant: true,
          estimatedMinutes: 120,
          notes: '精确到分钟',
        ),
      );
      expect(updated.id, created.id);
      expect(updated.version, 2);
      expect(updated.title, '修改后');
      expect(updated.category, TaskCategory.work);
      expect(updated.notes, '精确到分钟');
      expect(controller.riskFor(updated).score, greaterThan(before));
      expect(await controller.hasMeaningfulHistory(updated.id), isTrue);
      expect(await controller.deleteTask(updated.id), isTrue);
      expect(
        (await repository.getTask(updated.id))!.status,
        TaskStatus.archived,
      );
    },
  );

  test('new untouched task can be physically deleted', () async {
    final controller = AppController(
      InMemoryTaskRepository(),
      InMemoryInstallationStore(),
    );
    await controller.load();
    final created = await controller.addTask(
      TaskDraft(
        title: '临时任务',
        dueAt: DateTime.now().add(const Duration(days: 2)),
        category: TaskCategory.life,
        isImportant: false,
        estimatedMinutes: 30,
      ),
    );
    expect(await controller.deleteTask(created.id), isFalse);
    expect(controller.tasks.where((task) => task.id == created.id), isEmpty);
  });

  test(
    'editing deadline into the past enters confession and cannot be edited again',
    () async {
      final clock = _MutableClock(DateTime.utc(2026, 10, 3, 8));
      final repository = InMemoryTaskRepository(clock: clock);
      final controller = AppController(
        repository,
        InMemoryInstallationStore(),
        clock: clock,
      );
      await controller.load();
      final created = await controller.addTask(
        TaskDraft(
          title: '改期任务',
          dueAt: clock.value.add(const Duration(days: 1)),
          category: TaskCategory.study,
          isImportant: true,
          estimatedMinutes: 30,
        ),
      );
      final changed = await controller.updateTask(
        created.copyWith(
          dueAt: clock.value.subtract(const Duration(minutes: 1)),
        ),
      );
      expect(changed.status, TaskStatus.overdueReview);
      expect(controller.overdueTasks.single.id, created.id);
      expect(
        () => controller.updateTask(changed.copyWith(title: '绕过结案')),
        throwsA(isA<AppFailure>()),
      );
    },
  );

  test(
    'task actions and preference changes reconcile reminder records',
    () async {
      final clock = _MutableClock(DateTime(2026, 10, 4, 8));
      final reminders = InMemoryReminderRepository();
      final preferences = InMemoryPreferenceRepository();
      final controller = AppController(
        InMemoryTaskRepository(clock: clock),
        InMemoryInstallationStore(),
        clock: clock,
        reminderRepository: reminders,
        preferenceRepository: preferences,
      );
      await controller.load();
      final created = await controller.addTask(
        TaskDraft(
          title: '控制器提醒',
          dueAt: DateTime(2026, 10, 6, 18),
          category: TaskCategory.study,
          isImportant: false,
          estimatedMinutes: 60,
        ),
      );
      expect((await reminders.listOutstanding()).length, 2);

      await controller.setNotificationsEnabled(false);
      expect(await reminders.listOutstanding(), isEmpty);
      await controller.setNotificationsEnabled(true);
      expect((await reminders.listOutstanding()).length, 2);

      await controller.setDefaultReminderOffsets([30]);
      expect((await reminders.listOutstanding()).length, 1);
      expect(
        (await reminders.listForTask(
          created.id,
        )).where((record) => record.status == ReminderStatus.cancelled).length,
        2,
      );
      await controller.completeTask(created.id);
      expect(await reminders.listOutstanding(), isEmpty);
      expect(controller.reminderSyncErrorCode, isNull);
    },
  );

  test('foreground overdue reconciliation cancels pending plan', () async {
    final clock = _MutableClock(DateTime(2026, 10, 4, 8));
    final reminders = InMemoryReminderRepository();
    final controller = AppController(
      InMemoryTaskRepository(clock: clock),
      InMemoryInstallationStore(),
      clock: clock,
      reminderRepository: reminders,
    );
    await controller.load();
    final task = await controller.addTask(
      TaskDraft(
        title: '到期取消',
        dueAt: DateTime(2026, 10, 6, 18),
        category: TaskCategory.work,
        isImportant: false,
        estimatedMinutes: 60,
      ),
    );
    expect(await reminders.listOutstanding(), isNotEmpty);
    clock.value = task.dueAt;
    expect(await controller.refreshOverdue(), 1);
    expect(await reminders.listOutstanding(), isEmpty);
    expect(controller.overdueTasks.single.id, task.id);
  });

  test(
    'reminder sync failure does not block tasks and retries on refresh',
    () async {
      final clock = _MutableClock(DateTime(2026, 10, 4, 8));
      final tasks = InMemoryTaskRepository(clock: clock);
      final reminders = _FailingReminderRepository();
      await tasks.createTask(
        TaskDraft(
          title: '同步失败仍可看任务',
          dueAt: DateTime(2026, 10, 6, 18),
          category: TaskCategory.study,
          isImportant: false,
          estimatedMinutes: 60,
        ),
      );
      final controller = AppController(
        tasks,
        InMemoryInstallationStore(),
        clock: clock,
        reminderRepository: reminders,
      );
      await controller.load();
      expect(controller.loading, isFalse);
      expect(controller.activeTasks.length, 1);
      expect(controller.reminderSyncErrorCode, 'DATABASE_UNAVAILABLE');
      reminders.fail = false;
      await controller.refreshOverdue();
      expect(controller.reminderSyncErrorCode, isNull);
      expect((await reminders.listOutstanding()).length, 2);
    },
  );
}
