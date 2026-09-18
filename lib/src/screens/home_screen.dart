import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.onCreateTask,
    required this.onShowAll,
    required this.onTaskTap,
  });

  final AppController controller;
  final VoidCallback onCreateTask;
  final VoidCallback onShowAll;
  final ValueChanged<String> onTaskTap;

  @override
  Widget build(BuildContext context) {
    final now = controller.now;
    final dangerous = controller.activeTasks.take(3).toList();
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${now.month}月${now.day}日 · 生存第 ${controller.survivalDays} 天',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.orangeDark,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '早安，别让 DDL\n先找到你。',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineLarge?.copyWith(fontSize: 31),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => _showNotifications(context),
                icon: Badge(
                  isLabelVisible: controller.overdueTasks.isNotEmpty,
                  label: Text('${controller.overdueTasks.length}'),
                  child: const Icon(Icons.notifications_none_rounded),
                ),
                tooltip: '通知中心',
              ),
            ],
          ),
          const SizedBox(height: 22),
          _PressureBoard(controller: controller),
          const SizedBox(height: 26),
          SectionHeader(
            eyebrow: 'Next 72 hours',
            title: '最近的雷区',
            actionLabel: '查看全部',
            onAction: onShowAll,
          ),
          const SizedBox(height: 12),
          if (dangerous.isEmpty)
            EmptyMission(
              icon: Icons.celebration_rounded,
              title: '今天没有警报',
              message: '很好，先喝口水。也可以顺手记录下一个任务。',
              actionLabel: '新建任务',
              onAction: onCreateTask,
            )
          else
            ...dangerous.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TaskCard(
                  task: task,
                  now: now,
                  onTap: () => onTaskTap(task.id),
                  onComplete: () => _complete(context, task.id, task.title),
                ),
              ),
            ),
          const SizedBox(height: 14),
          _QuickCreate(onPressed: onCreateTask),
        ],
      ),
    );
  }

  Future<void> _complete(BuildContext context, String id, String title) async {
    await controller.completeTask(id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已拆除：$title'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('通知中心', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              controller.overdueTasks.isEmpty
                  ? '没有新的警报。通知调度器一切正常。'
                  : '有 ${controller.overdueTasks.length} 个任务已经越过 DDL，请前往忏悔录处理。',
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                controller.setNavigationIndex(2);
              },
              child: const Text('查看忏悔录'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PressureBoard extends StatelessWidget {
  const _PressureBoard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: AppColors.orange,
            offset: Offset(6, 7),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const StatusStamp(
                label: 'LIVE STATUS',
                color: AppColors.orange,
                icon: Icons.bolt_rounded,
              ),
              const Spacer(),
              Text(
                '${controller.activeTasks.length} 个未完成',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              PressureDial(
                value: controller.pressureScore,
                label: controller.pressureLabel,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.pressureScore >= 70
                          ? '现在就动手，\n还能抢救。'
                          : '局面可控，\n按顺序拆弹。',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: Colors.white, height: 1.08),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '系统根据截止时间、工作量和任务密度动态计算。',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickCreate extends StatelessWidget {
  const _QuickCreate({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.orange,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.add_circle_outline_rounded,
              color: Colors.white,
              size: 30,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '签下一份新的生死状',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                  Text(
                    '先记下来，焦虑就少一半。',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
