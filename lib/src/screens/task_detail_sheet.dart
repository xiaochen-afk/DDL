import 'package:flutter/material.dart';

import '../domain/task.dart';
import 'create_task_screen.dart';
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
    final assessment = controller.riskFor(task);
    final risk = assessment.score;
    final quadrant = assessment.quadrant;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: SingleChildScrollView(
        child: Padding(
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
                  StatusStamp(
                    label: task.categoryLabel,
                    color: AppColors.inkSoft,
                  ),
                  StatusStamp(label: quadrant.title, color: riskColor(risk)),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                task.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(dateTimeLabel(task.dueAt)),
              const SizedBox(height: 18),
              PaperCard(
                color: riskColor(risk).withValues(alpha: 0.08),
                borderColor: riskColor(risk).withValues(alpha: 0.35),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '风险解释',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '风险 $risk 分 · ${quadrant.subtitle}。预计需要 ${task.estimatedMinutes} 分钟，${compactDeadline(task.dueAt, now)}。',
                    ),
                    if (assessment.reasons.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      for (final reason in assessment.reasons)
                        Text('${reason.description}：+${reason.points} 分'),
                    ],
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
              if (task.status == TaskStatus.active) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      final saved = await navigator.push<String>(
                        MaterialPageRoute(
                          builder: (_) => CreateTaskScreen(
                            controller: controller,
                            initialTask: task,
                          ),
                        ),
                      );
                      if (saved != null && context.mounted) navigator.pop();
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('编辑任务'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (!task.isDone && task.status == TaskStatus.active)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final completed = await controller.completeTask(task.id);
                      if (!context.mounted) return;
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(context);
                      if (!completed) {
                        controller.setNavigationIndex(2);
                        messenger.showSnackBar(
                          const SnackBar(content: Text('任务已到期，请在忏悔录选择结案方式。')),
                        );
                      }
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('完成任务'),
                  ),
                ),
              const SizedBox(height: 8),
              if (task.status != TaskStatus.overdueReview &&
                  task.status != TaskStatus.archived)
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
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.red,
                        ),
                        child: const Text('删除'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final hasHistory = await controller.hasMeaningfulHistory(task.id);
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(hasHistory ? '确认归档？' : '确认删除？'),
        content: Text(
          hasHistory
              ? '此任务已有操作或结案历史，将保留记录并归档，不再参与压力计算。'
              : '此任务只有创建记录，将永久删除且无法恢复。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: Text(hasHistory ? '归档' : '删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final archived = await controller.deleteTask(task.id);
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text(archived ? '任务已归档，历史已保留。' : '任务已删除。')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('操作失败，请刷新任务后重试。')));
    }
  }
}
