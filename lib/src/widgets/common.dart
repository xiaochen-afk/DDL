import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/task.dart';
import '../theme/app_theme.dart';

String compactDeadline(DateTime dueAt, DateTime now) {
  final difference = dueAt.difference(now);
  if (difference.isNegative) {
    final hours = difference.abs().inHours;
    return hours < 24 ? '已逾期 $hours 小时' : '已逾期 ${difference.abs().inDays} 天';
  }
  if (difference.inMinutes < 60) return '剩 ${difference.inMinutes} 分钟';
  if (difference.inHours < 24) return '剩 ${difference.inHours} 小时';
  return '剩 ${difference.inDays} 天';
}

String dateTimeLabel(DateTime value) {
  const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.month}月${value.day}日 周${weekdays[value.weekday - 1]}  ${value.hour}:$minute';
}

Color riskColor(int score) {
  if (score >= 75) return AppColors.red;
  if (score >= 50) return AppColors.orange;
  if (score >= 25) return AppColors.yellow;
  return AppColors.mint;
}

class SurvivalBackdrop extends StatelessWidget {
  const SurvivalBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter(), child: child);
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ink.withValues(alpha: 0.025)
      ..strokeWidth = 1;
    const gap = 24.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = AppColors.paperStrong,
    this.borderColor = AppColors.line,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.05),
            offset: const Offset(0, 5),
            blurRadius: 0,
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: content,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String eyebrow;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.orangeDark,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class StatusStamp extends StatelessWidget {
  const StatusStamp({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.now,
    required this.risk,
    required this.onTap,
    this.onComplete,
    this.compact = false,
  });

  final TaskItem task;
  final DateTime now;
  final int risk;
  final VoidCallback onTap;
  final VoidCallback? onComplete;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = task.isDone ? AppColors.mint : riskColor(risk);
    return PaperCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      borderColor: color.withValues(alpha: 0.42),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            height: compact ? 62 : 76,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    StatusStamp(
                      label: task.category.label,
                      color: AppColors.inkSoft,
                    ),
                    if (!task.isDone)
                      StatusStamp(label: '风险 $risk', color: color),
                    if (task.isDone)
                      const StatusStamp(
                        label: '已拆弹',
                        color: AppColors.mint,
                        icon: Icons.check_rounded,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    decoration: task.isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${compactDeadline(task.dueAt, now)} · ${dateTimeLabel(task.dueAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color == AppColors.yellow
                        ? AppColors.inkSoft
                        : color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (onComplete != null) ...[
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: '完成任务 ${task.title}',
              child: IconButton.filledTonal(
                onPressed: onComplete,
                icon: const Icon(Icons.check_rounded),
                tooltip: '完成',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class EmptyMission extends StatelessWidget {
  const EmptyMission({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFDFF8EF),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.mint, size: 32),
          ),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
          if (actionLabel != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class PressureDial extends StatelessWidget {
  const PressureDial({super.key, required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = riskColor(value);
    return Semantics(
      label: '生存压力指数 $value，状态 $label',
      child: SizedBox(
        width: 128,
        height: 128,
        child: CustomPaint(
          painter: _DialPainter(value: value, color: color),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$value',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 40,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  const _DialPainter({required this.value, required this.color});

  final int value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 7;
    final track = Paint()
      ..color = AppColors.ink.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    final progress = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10;
    const start = -math.pi * 0.75;
    const sweep = math.pi * 1.5;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      track,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep * value / 100,
      false,
      progress,
    );
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}
