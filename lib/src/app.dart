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
    this.onDispose,
  });

  final TaskRepository? repository;
  final InstallationStore? installationStore;
  final Future<void> Function()? onDispose;

  @override
  State<DdlSurvivalApp> createState() => _DdlSurvivalAppState();
}

class _DdlSurvivalAppState extends State<DdlSurvivalApp> {
  late final AppController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AppController(
      widget.repository ?? InMemoryTaskRepository(),
      widget.installationStore ?? SharedPreferencesInstallationStore(),
    );
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    final disposeCallback = widget.onDispose;
    if (disposeCallback != null) unawaited(disposeCallback());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      floatingActionButton: controller.navigationIndex <= 1
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
