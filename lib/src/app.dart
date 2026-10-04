import 'dart:async';

import 'package:flutter/material.dart';

import 'data/in_memory_task_repository.dart';
import 'data/installation_store.dart';
import 'domain/ports.dart';
import 'screens/confession_screen.dart';
import 'screens/create_task_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/task_detail_sheet.dart';
import 'screens/todo_screen.dart';
import 'state/app_controller.dart';
import 'theme/app_theme.dart';
import 'widgets/common.dart';

class DdlSurvivalApp extends StatefulWidget {
  const DdlSurvivalApp({
    super.key,
    this.repository,
    this.installationStore,
    this.clock,
    this.preferenceRepository,
    this.profileRepository,
    this.reminderRepository,
    this.notificationPort,
    this.onDispose,
  });

  final TaskRepository? repository;
  final InstallationStore? installationStore;
  final ClockPort? clock;
  final PreferenceRepository? preferenceRepository;
  final ProfileRepository? profileRepository;
  final ReminderRepository? reminderRepository;
  final NotificationPort? notificationPort;
  final Future<void> Function()? onDispose;

  @override
  State<DdlSurvivalApp> createState() => _DdlSurvivalAppState();
}

class _DdlSurvivalAppState extends State<DdlSurvivalApp>
    with WidgetsBindingObserver {
  late final AppController _controller;
  Timer? _deadlineTimer;
  bool _checkingDeadline = false;
  bool _appIsActive = true;
  StreamSubscription<String>? _notificationSelection;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  String? _pendingNotificationTaskId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AppController(
      widget.repository ?? InMemoryTaskRepository(),
      widget.installationStore ?? SharedPreferencesInstallationStore(),
      clock: widget.clock ?? const SystemClock(),
      preferenceRepository: widget.preferenceRepository,
      profileRepository: widget.profileRepository,
      reminderRepository: widget.reminderRepository,
      notificationPort: widget.notificationPort,
    );
    _controller.addListener(_scheduleDeadlineCheck);
    _controller.addListener(_openPendingNotificationTask);
    _notificationSelection = widget.notificationPort?.selectedTaskIds.listen(
      _queueNotificationTask,
    );
    _pendingNotificationTaskId = widget.notificationPort?.takeInitialTaskId();
    unawaited(_controller.load());
  }

  void _queueNotificationTask(String taskId) {
    _pendingNotificationTaskId = taskId;
    _openPendingNotificationTask();
  }

  void _openPendingNotificationTask() {
    if (_controller.loading || _pendingNotificationTaskId == null) return;
    final taskId = _pendingNotificationTaskId!;
    _pendingNotificationTaskId = null;
    _controller.setNavigationIndex(1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final matches = _controller.tasks.where((task) => task.id == taskId);
      final navigatorContext = _navigatorKey.currentContext;
      if (matches.isEmpty || navigatorContext == null) return;
      showModalBottomSheet<void>(
        context: navigatorContext,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) =>
            TaskDetailSheet(task: matches.first, controller: _controller),
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appIsActive = state == AppLifecycleState.resumed;
    if (!_appIsActive) {
      _deadlineTimer?.cancel();
      return;
    }
    if (!_controller.loading) unawaited(_refreshOverdue());
  }

  void _scheduleDeadlineCheck() {
    _deadlineTimer?.cancel();
    if (_controller.loading || _checkingDeadline || !_appIsActive) return;
    final active = _controller.activeTasks;
    if (active.isEmpty) return;
    final now = _controller.now;
    final nextDue = active
        .map((task) => task.dueAt)
        .reduce((first, second) => first.isBefore(second) ? first : second);
    var delay = nextDue.difference(now);
    if (delay.isNegative) delay = Duration.zero;
    if (delay > const Duration(minutes: 1)) delay = const Duration(minutes: 1);
    _deadlineTimer = Timer(delay, () => unawaited(_refreshOverdue()));
  }

  Future<void> _refreshOverdue() async {
    if (_checkingDeadline || _controller.loading) return;
    _checkingDeadline = true;
    _deadlineTimer?.cancel();
    var failed = false;
    try {
      await _controller.refreshOverdue();
    } catch (error, stack) {
      failed = true;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'DDL task lifecycle',
          context: ErrorDescription('while reconciling overdue tasks'),
        ),
      );
    } finally {
      _checkingDeadline = false;
      if (mounted && _appIsActive) {
        _deadlineTimer = failed
            ? Timer(
                const Duration(minutes: 1),
                () => unawaited(_refreshOverdue()),
              )
            : null;
        if (!failed) _scheduleDeadlineCheck();
      }
    }
  }

  @override
  void dispose() {
    _deadlineTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_scheduleDeadlineCheck);
    _controller.removeListener(_openPendingNotificationTask);
    unawaited(_notificationSelection?.cancel());
    _controller.dispose();
    final disposeCallback = widget.onDispose;
    if (disposeCallback != null) unawaited(disposeCallback());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'DDL 生存指南',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.loading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return _AppShell(controller: _controller);
        },
      ),
    );
  }
}

class _AppShell extends StatelessWidget {
  const _AppShell({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        controller: controller,
        onCreateTask: () => _openCreate(context),
        onShowAll: () => controller.setNavigationIndex(1),
        onTaskTap: (id) => _showTask(context, id),
      ),
      TodoScreen(
        controller: controller,
        onCreateTask: () => _openCreate(context),
        onTaskTap: (id) => _showTask(context, id),
      ),
      ConfessionScreen(controller: controller),
      ProfileScreen(controller: controller),
    ];

    return Scaffold(
      extendBody: true,
      body: SurvivalBackdrop(
        child: IndexedStack(index: controller.navigationIndex, children: pages),
      ),
      floatingActionButton:
          controller.navigationIndex == 1 && controller.filteredTodos.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _openCreate(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('新任务'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: controller.navigationIndex,
        onDestinationSelected: controller.setNavigationIndex,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.radar_outlined),
            selectedIcon: Icon(Icons.radar_rounded),
            label: '主页',
          ),
          const NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: '待办',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: controller.overdueTasks.isNotEmpty,
              label: Text('${controller.overdueTasks.length}'),
              child: const Icon(Icons.history_edu_outlined),
            ),
            selectedIcon: const Icon(Icons.history_edu_rounded),
            label: '忏悔录',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: '我的',
          ),
        ],
      ),
    );
  }

  Future<void> _openCreate(BuildContext context) async {
    final title = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CreateTaskScreen(controller: controller),
      ),
    );
    if (title == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已记录：$title'),
        action: SnackBarAction(
          label: '去待办',
          onPressed: () => controller.setNavigationIndex(1),
        ),
      ),
    );
  }

  void _showTask(BuildContext context, String id) {
    final matches = controller.tasks.where((task) => task.id == id);
    if (matches.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          TaskDetailSheet(task: matches.first, controller: controller),
    );
  }
}
