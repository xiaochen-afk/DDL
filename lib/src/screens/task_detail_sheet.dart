import 'package:flutter/material.dart';

import '../domain/task.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class TaskDetailSheet extends StatelessWidget {
  const TaskDetailSheet({
    super.key,
    required this.task,
    required this.controller,
  });

  final TaskItem task;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final now = controller.now;
    final risk = task.riskScoreAt(now);
    final quadrant = task.quadrantAt(now);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 26,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusStamp(label: task.category.label, color: AppColors.inkSoft),
              StatusStamp(label: quadrant.title, color: riskColor(risk)),
            ],
          ),
          const SizedBox(height: 14),
          Text(task.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(dateTimeLabel(task.dueAt)),
          const SizedBox(height: 18),
          PaperCard(
            color: riskColor(risk).withValues(alpha: 0.08),
            borderColor: riskColor(risk).withValues(alpha: 0.35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('风险解释', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  '风险 $risk 分 · ${quadrant.subtitle}。预计需要 ${task.estimatedMinutes} 分钟，${compactDeadline(task.dueAt, now)}。',
                ),
              ],
            ),
          ),
          if (task.notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('备注', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 5),
            Text(task.notes),
          ],
          const SizedBox(height: 22),
          if (!task.isDone && task.status == TaskStatus.active)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  await controller.completeTask(task.id);
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('完成任务'),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await controller.archiveTask(task.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('归档'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextButton(
                  onPressed: () => _confirmDelete(context),
                  style: TextButton.styleFrom(foregroundColor: AppColors.red),
                  child: const Text('删除'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除？'),
        content: const Text('删除后无法恢复。已有历史记录的正式版本将优先提供归档。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await controller.deleteTask(task.id);
    if (context.mounted) Navigator.pop(context);
  }
}
