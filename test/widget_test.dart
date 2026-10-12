import 'dart:async';

import 'package:ddl_survival/src/app.dart';
import 'package:ddl_survival/src/data/in_memory_task_repository.dart';
import 'package:ddl_survival/src/data/installation_store.dart';
import 'package:ddl_survival/src/data/local_settings_repository.dart';
import 'package:ddl_survival/src/domain/local_data.dart';
import 'package:ddl_survival/src/domain/ports.dart';
import 'package:ddl_survival/src/domain/task.dart';
import 'package:ddl_survival/src/screens/create_task_screen.dart';
import 'package:ddl_survival/src/screens/profile_screen.dart';
import 'package:ddl_survival/src/screens/todo_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MutableClock implements ClockPort {
  _MutableClock(this.value);

  DateTime value;

  @override
  DateTime now() => value;
}

class _TapNotifications implements NotificationPort {
  _TapNotifications(this.initialTaskId);

  String? initialTaskId;
  final StreamController<String> taps = StreamController<String>.broadcast();

  @override
  Future<NotificationCapabilities> inspect() async =>
      const NotificationCapabilities(
        authorized: true,
        exact: false,
        exactPermissionRequired: true,
        pendingLimit: 60,
      );

  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<bool> requestExactPermission() async => false;
  @override
  Future<bool> openSettings() async => true;
  @override
  Future<String> deviceTimezone() async => 'Asia/Shanghai';
  @override
  Future<Set<int>> pendingIds() async => {};
  @override
  Future<void> schedule({
    required int id,
    required DateTime fireAt,
    required ReminderChannel channel,
    required String taskId,
    required bool exact,
  }) async {}
  @override
  Future<void> cancel(int id) async {}
  @override
  Stream<String> get selectedTaskIds => taps.stream;
  @override
  String? takeInitialTaskId() {
    final value = initialTaskId;
    initialTaskId = null;
    return value;
  }
}

void main() {
  testWidgets('notification cold-start and live tap open task detail', (
    tester,
  ) async {
    final repository = InMemoryTaskRepository();
    final task = await repository.createTask(
      TaskDraft(
        title: '通知点按目标',
        dueAt: DateTime.now().add(const Duration(days: 2)),
        category: TaskCategory.study,
        isImportant: false,
        estimatedMinutes: 30,
      ),
    );
    final notifications = _TapNotifications(task.id);
    await tester.pumpWidget(
      DdlSurvivalApp(
        repository: repository,
        installationStore: InMemoryInstallationStore(),
        notificationPort: notifications,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('通知点按目标'), findsWidgets);
    expect(find.text('编辑任务'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    notifications.taps.add(task.id);
    await tester.pumpAndSettle();
    expect(find.text('编辑任务'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await notifications.taps.close();
  });

  testWidgets('can navigate and create a task', (tester) async {
    final repository = InMemoryTaskRepository();
    await tester.pumpWidget(
      DdlSurvivalApp(
        repository: repository,
        installationStore: InMemoryInstallationStore(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('生存第 1 天'), findsOneWidget);
    expect(find.text('今天没有警报'), findsOneWidget);
    expect(find.text('最近的雷区'), findsOneWidget);

    await tester.tap(find.text('待办'));
    await tester.pumpAndSettle();
    expect(find.text('四象限作战图'), findsOneWidget);
    expect(find.widgetWithText(FloatingActionButton, '新任务'), findsNothing);
    final filters = find.byKey(const Key('todo_scope_filters'));
    final todoScroll = find
        .descendant(
          of: find.byType(TodoScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(filters, 160, scrollable: todoScroll);
    await tester.pumpAndSettle();
    final gridBottom = tester
        .getBottomLeft(find.byKey(const Key('todo_quadrant_grid')))
        .dy;
    final filtersTop = tester.getTopLeft(filters).dy;
    expect(filtersTop - gridBottom, closeTo(12, 0.1));

    await tester.scrollUntilVisible(
      find.text('新增'),
      -160,
      scrollable: todoScroll,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增'));
    await tester.pumpAndSettle();
    expect(find.text('签下生死状'), findsWidgets);
    expect(find.text('今天 23:00'), findsNothing);
    expect(find.text('明天 18:00'), findsNothing);
    expect(find.text('三天后'), findsNothing);

    await tester.enterText(find.byType(TextFormField).first, '测试新的 DDL');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    final createScroll = find
        .descendant(
          of: find.byType(CreateTaskScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('自定义'),
      220,
      scrollable: createScroll,
    );
    await tester.tap(find.text('自定义'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('custom_category_field')),
      '社团',
    );
    final submit = find.byKey(const Key('create_task_submit'));
    await tester.scrollUntilVisible(submit, 300, scrollable: createScroll);
    await tester.pumpAndSettle();
    expect(submit, findsOneWidget);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.textContaining('已记录：测试新的 DDL'), findsOneWidget);
    final saved = (await repository.listTasks()).single;
    expect(saved.category, TaskCategory.custom);
    expect(saved.customCategoryLabel, '社团');
    expect(saved.categoryLabel, '社团');
  });

  testWidgets('can resolve an overdue task', (tester) async {
    final repository = InMemoryTaskRepository();
    final overdue = await repository.createTask(
      TaskDraft(
        title: '测试逾期任务',
        dueAt: DateTime.now().subtract(const Duration(hours: 1)),
        category: TaskCategory.study,
        isImportant: true,
        estimatedMinutes: 30,
      ),
    );
    await tester.pumpWidget(
      DdlSurvivalApp(
        repository: repository,
        installationStore: InMemoryInstallationStore(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('忏悔录'));
    await tester.pumpAndSettle();
    expect(find.text('测试逾期任务'), findsOneWidget);

    await tester.tap(find.text('做完了，只是忘记打勾'));
    await tester.pumpAndSettle();
    expect(find.text('案底清空'), findsOneWidget);
    expect(
      (await repository.getTask(overdue.id))!.status,
      TaskStatus.completedLate,
    );
  });

  testWidgets('task detail opens prefilled edit form and saves changes', (
    tester,
  ) async {
    final repository = InMemoryTaskRepository();
    final original = await repository.createTask(
      TaskDraft(
        title: '可编辑任务',
        dueAt: DateTime.now().add(const Duration(days: 2)),
        category: TaskCategory.study,
        isImportant: true,
        estimatedMinutes: 60,
        notes: '原备注',
      ),
    );
    await tester.pumpWidget(
      DdlSurvivalApp(
        repository: repository,
        installationStore: InMemoryInstallationStore(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('可编辑任务').first);
    await tester.pumpAndSettle();
    expect(find.text('风险解释'), findsOneWidget);
    await tester.ensureVisible(find.text('编辑任务'));
    await tester.tap(find.text('编辑任务'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '已编辑任务');
    final submit = find.byKey(const Key('edit_task_submit'));
    await tester.scrollUntilVisible(
      submit,
      300,
      scrollable: find
          .descendant(
            of: find.byType(CreateTaskScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect((await repository.getTask(original.id))!.title, '已编辑任务');
    expect((await repository.getTask(original.id))!.notes, '原备注');
    expect((await repository.getTask(original.id))!.version, 2);
  });

  testWidgets('short-deadline edit offers a task-only five-minute reminder', (
    tester,
  ) async {
    final repository = InMemoryTaskRepository();
    final original = await repository.createTask(
      TaskDraft(
        title: '短截止任务',
        dueAt: DateTime.now().add(const Duration(minutes: 90)),
        category: TaskCategory.study,
        isImportant: false,
        estimatedMinutes: 30,
      ),
    );
    final preferences = InMemoryPreferenceRepository();
    await tester.pumpWidget(
      DdlSurvivalApp(
        repository: repository,
        installationStore: InMemoryInstallationStore(),
        preferenceRepository: preferences,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('短截止任务').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('编辑任务'));
    await tester.tap(find.text('编辑任务'));
    await tester.pumpAndSettle();

    expect(find.text('本任务提醒时间'), findsOneWidget);
    expect(find.text('未单独设置：默认截止前 5 分钟'), findsOneWidget);
    final formScroll = find
        .descendant(
          of: find.byType(CreateTaskScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    final submit = find.byKey(const Key('edit_task_submit'));
    await tester.scrollUntilVisible(submit, 300, scrollable: formScroll);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(
      (await repository.getTask(original.id))!.taskReminderOffsetMinutes,
      5,
    );
    expect((await preferences.getOrCreate()).defaultReminderOffsetsMinutes, [
      1440,
      180,
    ]);
  });

  testWidgets(
    'short-deadline creation saves fallback without changing defaults',
    (tester) async {
      final repository = InMemoryTaskRepository();
      final preferences = InMemoryPreferenceRepository();
      await preferences.save(
        const AppPreferences(defaultReminderOffsetsMinutes: [2880]),
      );
      await tester.pumpWidget(
        DdlSurvivalApp(
          repository: repository,
          installationStore: InMemoryInstallationStore(),
          preferenceRepository: preferences,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('待办'));
      await tester.pumpAndSettle();
      final todoScroll = find
          .descendant(
            of: find.byType(TodoScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('新增'),
        -160,
        scrollable: todoScroll,
      );
      await tester.tap(find.text('新增'));
      await tester.pumpAndSettle();
      expect(find.text('本任务提醒时间'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '创建短截止任务');
      final formScroll = find
          .descendant(
            of: find.byType(CreateTaskScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      final submit = find.byKey(const Key('create_task_submit'));
      await tester.scrollUntilVisible(submit, 300, scrollable: formScroll);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(
        (await repository.listTasks()).single.taskReminderOffsetMinutes,
        5,
      );
      expect((await preferences.getOrCreate()).defaultReminderOffsetsMinutes, [
        2880,
      ]);
    },
  );

  testWidgets('missed confirmation can be cancelled, then closes the task', (
    tester,
  ) async {
    final repository = InMemoryTaskRepository();
    final task = await repository.createTask(
      TaskDraft(
        title: '需要确认的逾期任务',
        dueAt: DateTime.now().subtract(const Duration(hours: 1)),
        category: TaskCategory.study,
        isImportant: true,
        estimatedMinutes: 30,
      ),
    );
    await tester.pumpWidget(
      DdlSurvivalApp(
        repository: repository,
        installationStore: InMemoryInstallationStore(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('忏悔录'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('这次确实没完成'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('再想想'));
    await tester.pumpAndSettle();
    expect(
      (await repository.getTask(task.id))!.status,
      TaskStatus.overdueReview,
    );

    await tester.tap(find.text('这次确实没完成'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认结案'));
    await tester.pumpAndSettle();
    expect(find.text('案底清空'), findsOneWidget);
    expect((await repository.getTask(task.id))!.status, TaskStatus.missed);
  });

  testWidgets('foreground deadline timer moves a task into confession', (
    tester,
  ) async {
    final clock = _MutableClock(DateTime.utc(2026, 9, 22, 10));
    final repository = InMemoryTaskRepository(clock: clock);
    final task = await repository.createTask(
      TaskDraft(
        title: '前台到点任务',
        dueAt: clock.value.add(const Duration(minutes: 1)),
        category: TaskCategory.work,
        isImportant: true,
        estimatedMinutes: 15,
      ),
    );
    await tester.pumpWidget(
      DdlSurvivalApp(
        repository: repository,
        installationStore: InMemoryInstallationStore(),
        clock: clock,
      ),
    );
    await tester.pumpAndSettle();

    clock.value = task.dueAt;
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(
      (await repository.getTask(task.id))!.status,
      TaskStatus.overdueReview,
    );
    await tester.tap(find.text('忏悔录'));
    await tester.pumpAndSettle();
    expect(find.text('前台到点任务'), findsOneWidget);
  });

  testWidgets('returning to foreground reconciles elapsed deadlines', (
    tester,
  ) async {
    final clock = _MutableClock(DateTime.utc(2026, 9, 22, 10));
    final repository = InMemoryTaskRepository(clock: clock);
    final task = await repository.createTask(
      TaskDraft(
        title: '恢复前台任务',
        dueAt: clock.value.add(const Duration(minutes: 5)),
        category: TaskCategory.life,
        isImportant: false,
        estimatedMinutes: 15,
      ),
    );
    await tester.pumpWidget(
      DdlSurvivalApp(
        repository: repository,
        installationStore: InMemoryInstallationStore(),
        clock: clock,
      ),
    );
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    clock.value = task.dueAt.add(const Duration(minutes: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(
      (await repository.getTask(task.id))!.status,
      TaskStatus.overdueReview,
    );
  });

  testWidgets('profile and notification preferences survive app rebuild', (
    tester,
  ) async {
    final preferences = InMemoryPreferenceRepository();
    final profiles = InMemoryProfileRepository();
    final repository = InMemoryTaskRepository();
    Future<void> openApp() async {
      await tester.pumpWidget(
        DdlSurvivalApp(
          repository: repository,
          installationStore: InMemoryInstallationStore(),
          preferenceRepository: preferences,
          profileRepository: profiles,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('我的'));
      await tester.pumpAndSettle();
    }

    await openApp();
    await tester.tap(find.byTooltip('编辑资料'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '真机用户');
    await tester.enterText(find.byType(TextField).last, '继续前进');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('真机用户'), findsOneWidget);
    expect((await profiles.getOrCreate()).motto, '继续前进');
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect((await preferences.getOrCreate()).notificationsEnabled, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await openApp();
    expect(find.text('真机用户'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
  });

  testWidgets('default reminder settings use hour and minute wheels', (
    tester,
  ) async {
    final preferences = InMemoryPreferenceRepository();
    await tester.pumpWidget(
      DdlSurvivalApp(
        repository: InMemoryTaskRepository(),
        installationStore: InMemoryInstallationStore(),
        preferenceRepository: preferences,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();

    final profileScroll = find
        .descendant(
          of: find.byType(ProfileScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('默认提前提醒'),
      180,
      scrollable: profileScroll,
    );
    await tester.drag(profileScroll, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(of: find.text('默认提前提醒'), matching: find.byType(ListTile)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reminder-duration-dialog')), findsOneWidget);
    expect(find.byType(ListWheelScrollView), findsNWidgets(2));
    expect(find.textContaining('逗号'), findsNothing);
    expect(find.text('小时'), findsOneWidget);
    expect(find.text('分钟'), findsOneWidget);

    final secondWheel = tester.widget<ListWheelScrollView>(
      find.byType(ListWheelScrollView).at(1),
    );
    final secondController =
        secondWheel.controller! as FixedExtentScrollController;
    secondController.jumpToItem(secondController.selectedItem + 1);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect((await preferences.getOrCreate()).defaultReminderOffsetsMinutes, [
      1441,
    ]);
    expect(find.text('24 小时 1 分钟前'), findsOneWidget);
  });
}
