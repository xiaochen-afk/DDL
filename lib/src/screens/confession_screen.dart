import 'package:flutter/material.dart';

import '../domain/task.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class ConfessionScreen extends StatelessWidget {
  const ConfessionScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final overdue = controller.overdueTasks;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
        children: [
          const SectionHeader(eyebrow: 'No shame zone', title: 'DDL 忏悔录'),
          const SizedBox(height: 8),
          Text(
            '错过不等于失败。把状态说清楚，下一次才知道怎么赢。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.red.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.history_toggle_off_rounded,
                  color: AppColors.red,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${overdue.length} 个任务等待处理',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (overdue.isEmpty)
            const EmptyMission(
              icon: Icons.auto_awesome_rounded,
              title: '案底清空',
              message: '没有需要处理的逾期任务。保持这个节奏。',
            )
          else
            ...overdue.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _ConfessionCard(task: task, controller: controller),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConfessionCard extends StatelessWidget {
  const _ConfessionCard({required this.task, required this.controller});

  final TaskItem task;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      borderColor: AppColors.red.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StatusStamp(
            label: '等待结案',
            color: AppColors.red,
            icon: Icons.priority_high_rounded,
          ),
          const SizedBox(height: 12),
          Text(task.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 5),
          Text(
            '${compactDeadline(task.dueAt, controller.now)} · 原定 ${dateTimeLabel(task.dueAt)}',
          ),
          if (task.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(task.notes, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _completeLate(context),
              icon: const Icon(Icons.task_alt_rounded),
              label: const Text('做完了，只是忘记打勾'),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => _confirmMissed(context),
              style: TextButton.styleFrom(foregroundColor: AppColors.red),
              child: const Text('这次确实没完成'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _completeLate(BuildContext context) async {
    await controller.completeLate(task.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已记为逾期完成。没有批评，只有记录。')));
  }

  Future<void> _confirmMissed(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.flag_outlined, color: AppColors.red),
        title: const Text('确认结案？'),
        content: const Text('任务会记为“未完成”。这只是一次记录，不会产生无限惩罚。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('再想想'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('确认结案'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.markMissed(task.id);
  }
}
