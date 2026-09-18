import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
        children: [
          const SectionHeader(eyebrow: 'Survivor profile', title: '我的生存档案'),
          const SizedBox(height: 18),
          PaperCard(
            color: AppColors.ink,
            borderColor: AppColors.ink,
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.sentiment_satisfied_alt_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DDL 幸存者',
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '今天也在努力把事情做完。',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showStub(context, '个人资料编辑将在数据层接入后开放。'),
                  icon: const Icon(Icons.edit_outlined, color: Colors.white),
                  tooltip: '编辑资料',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  value: '${controller.rescuedCount}',
                  label: '拯救的头发',
                  unit: '根（趣味值）',
                  color: AppColors.mint,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  value: '${controller.defeatedCount}',
                  label: '击败的 DDL',
                  unit: '个',
                  color: AppColors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Text('提醒设置', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          PaperCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  value: controller.notificationsEnabled,
                  onChanged: controller.setNotificationsEnabled,
                  title: const Text('系统通知'),
                  subtitle: Text(
                    controller.notificationsEnabled
                        ? '已开启，等待系统权限接入'
                        : '已关闭，仅保留应用内提醒',
                  ),
                  secondary: const Icon(Icons.notifications_active_outlined),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.bedtime_outlined),
                  title: const Text('免打扰时间'),
                  subtitle: const Text('23:00 — 07:30'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showStub(context, '免打扰时间编辑交互已预留。'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text('危机文案强度', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          SegmentedButton<CopyTone>(
            segments: CopyTone.values
                .map(
                  (tone) => ButtonSegment(value: tone, label: Text(tone.label)),
                )
                .toList(),
            selected: {controller.copyTone},
            onSelectionChanged: (values) =>
                controller.setCopyTone(values.first),
          ),
          const SizedBox(height: 22),
          Text('工具箱', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          PaperCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _MenuTile(
                  icon: Icons.auto_graph_rounded,
                  title: '学术生涯回顾',
                  subtitle: '查看任务完成趋势与复盘',
                  onTap: () => _showStub(context, '统计页面属于下一阶段。'),
                ),
                const Divider(height: 1),
                _MenuTile(
                  icon: Icons.menu_book_rounded,
                  title: '生存指南',
                  subtitle: '了解风险分和四象限规则',
                  onTap: () => _showRules(context),
                ),
                const Divider(height: 1),
                _MenuTile(
                  icon: Icons.inventory_2_outlined,
                  title: '本地数据管理',
                  subtitle: '导出、导入与清除本机数据',
                  onTap: () => _showDataTools(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showStub(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showRules(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '风险分怎么算？',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 10),
            Text('时间压力最高 45 分，重要度 20 分，工作量冲突 15 分，其余来自任务密度与历史。所有原因都会在任务详情中展示。'),
          ],
        ),
      ),
    );
  }

  void _showDataTools(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('本地数据管理', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text('当前前端使用内存数据演示。SQLite 接入后，这里将提供 JSON 导出、覆盖导入和清除确认。'),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => _showStub(context, '导出接口已写入接口文档，等待数据层实现。'),
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('导出全部数据'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.unit,
    required this.color,
  });

  final String value;
  final String label;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      borderColor: color.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineLarge?.copyWith(color: color),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(unit, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.orangeDark),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
