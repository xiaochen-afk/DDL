import 'package:flutter/material.dart';

import '../domain/task.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class TodoScreen extends StatelessWidget {
  const TodoScreen({
    super.key,
    required this.controller,
    required this.onCreateTask,
    required this.onTaskTap,
  });

  final AppController controller;
  final VoidCallback onCreateTask;
  final ValueChanged<String> onTaskTap;

  @override
  Widget build(BuildContext context) {
    final tasks = controller.filteredTodos;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
        children: [
          SectionHeader(
            eyebrow: 'Survival map',
            title: '四象限作战图',
            actionLabel: '新增',
            onAction: onCreateTask,
          ),
          const SizedBox(height: 8),
          Text(
            '重要度由你决定，紧急度会随时间自动漂移。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          GridView.count(
            key: const Key('todo_quadrant_grid'),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.42,
            shrinkWrap: true,
            primary: false,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            children: TaskQuadrant.values
                .map(
                  (quadrant) => _QuadrantCard(
                    quadrant: quadrant,
                    count: controller.quadrantCount(quadrant),
                    selected: controller.selectedQuadrant == quadrant,
                    onTap: () => controller.setQuadrant(quadrant),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            key: const Key('todo_scope_filters'),
            scrollDirection: Axis.horizontal,
            child: Row(
              children: TodoScope.values
                  .map(
                    (scope) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(scope.label),
                        selected: controller.todoScope == scope,
                        onSelected: (_) => controller.setTodoScope(scope),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '${tasks.length} 个任务',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              if (controller.selectedQuadrant != null)
                TextButton.icon(
                  onPressed: () => controller.setQuadrant(null),
                  icon: const Icon(Icons.close_rounded, size: 17),
                  label: const Text('清除象限'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (tasks.isEmpty)
            EmptyMission(
              icon: Icons.done_all_rounded,
              title: '这一格暂时安全',
              message: '没有符合当前筛选的任务。换个筛选，或者记录新的 DDL。',
              actionLabel: '新建任务',
              onAction: onCreateTask,
            )
          else
            ...tasks.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TaskCard(
                  task: task,
                  now: controller.now,
                  risk: controller.riskFor(task).score,
                  onTap: () => onTaskTap(task.id),
                  onComplete: task.isDone
                      ? null
                      : () => _complete(context, task.id),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _complete(BuildContext context, String id) async {
    final completed = await controller.completeTask(id);
    if (!context.mounted || completed) return;
    controller.setNavigationIndex(2);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('任务已到期，请在忏悔录选择结案方式。')));
  }
}

class _QuadrantCard extends StatelessWidget {
  const _QuadrantCard({
    required this.quadrant,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final TaskQuadrant quadrant;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  Color get color => switch (quadrant) {
    TaskQuadrant.urgentImportant => AppColors.red,
    TaskQuadrant.planned => AppColors.blue,
    TaskQuadrant.quickWin => AppColors.orange,
    TaskQuadrant.later => AppColors.mint,
  };

  IconData get icon => switch (quadrant) {
    TaskQuadrant.urgentImportant => Icons.local_fire_department_rounded,
    TaskQuadrant.planned => Icons.event_note_rounded,
    TaskQuadrant.quickWin => Icons.flash_on_rounded,
    TaskQuadrant.later => Icons.spa_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${quadrant.subtitle}，$count 个任务',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? color : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: selected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: selected ? Colors.white : color),
                  const Spacer(),
                  Text(
                    '$count',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: selected ? Colors.white : color,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                quadrant.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: selected ? Colors.white : AppColors.ink,
                ),
              ),
              Text(
                quadrant.subtitle,
                maxLines: 1,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? Colors.white70 : AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
