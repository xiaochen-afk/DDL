import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
                        controller.profile.nickname,
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        controller.profile.motto,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _editProfile(context),
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
                  onChanged: (value) => _save(
                    context,
                    () => controller.setNotificationsEnabled(value),
                  ),
                  title: const Text('提醒计划'),
                  subtitle: Text(_notificationSubtitle()),
                  secondary: const Icon(Icons.notifications_active_outlined),
                ),
                if (controller.notificationsEnabled &&
                    controller.notificationCapabilities != null &&
                    !controller.notificationCapabilities!.authorized)
                  ListTile(
                    leading: const Icon(Icons.notifications_off_outlined),
                    title: const Text('系统通知未授权'),
                    subtitle: const Text('提醒计划已保存，但手机不会弹出通知'),
                    trailing: TextButton(
                      onPressed: () => _save(
                        context,
                        controller.requestNotificationPermission,
                      ),
                      child: const Text('申请权限'),
                    ),
                    onTap: controller.openNotificationSettings,
                  ),
                if (controller.notificationsEnabled &&
                    controller.notificationCapabilities?.authorized == true &&
                    controller
                            .notificationCapabilities
                            ?.exactPermissionRequired ==
                        true &&
                    controller.notificationCapabilities?.exact == false)
                  ListTile(
                    leading: const Icon(Icons.schedule_outlined),
                    title: const Text('当前为非精确提醒'),
                    subtitle: const Text('系统可能延迟送达，无法保证指定分钟'),
                    trailing: TextButton(
                      onPressed: () => _save(
                        context,
                        controller.requestExactReminderPermission,
                      ),
                      child: const Text('申请精确'),
                    ),
                  ),
                if (controller.notificationsEnabled &&
                    controller.notificationCapabilities?.authorized == true)
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('系统通知设置'),
                    subtitle: const Text(
                      '横幅、锁屏及勿扰仍由手机系统控制；vivo/OPPO 还需检查后台耗电限制',
                    ),
                    onTap: controller.openNotificationSettings,
                  ),
                if (controller.reminderSyncErrorCode != null)
                  ListTile(
                    leading: const Icon(Icons.error_outline_rounded),
                    title: const Text('提醒计划同步失败'),
                    subtitle: Text(
                      '错误码：${controller.reminderSyncErrorCode}；下次启动或返回应用时重试',
                    ),
                  ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.bedtime_outlined),
                  title: const Text('免打扰时间'),
                  subtitle: Text(
                    '${_minuteLabel(controller.preferences.quietHoursStartMinute)} — '
                    '${_minuteLabel(controller.preferences.quietHoursEndMinute)}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _editQuietHours(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.schedule_outlined),
                  title: const Text('默认提前提醒'),
                  subtitle: Text(
                    controller.preferences.defaultReminderOffsetsMinutes
                        .map(
                          (minutes) => minutes >= 60 && minutes % 60 == 0
                              ? '${minutes ~/ 60} 小时'
                              : '$minutes 分钟',
                        )
                        .join('、'),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _editReminderOffsets(context),
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
                _save(context, () => controller.setCopyTone(values.first)),
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

  String _notificationSubtitle() {
    if (!controller.notificationsEnabled) return '已关闭，不生成新的提醒计划';
    final capabilities = controller.notificationCapabilities;
    if (capabilities == null) return '本机计划已保存；设备通知能力尚不可用';
    if (!capabilities.authorized) return '本机计划已保存；等待系统通知授权';
    if (capabilities.exactPermissionRequired && !capabilities.exact) {
      return '已降级为非精确排程，无法保证指定分钟送达';
    }
    return '已排程目标分钟；实际送达受系统设置影响';
  }

  void _showStub(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _minuteLabel(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:'
      '${(minute % 60).toString().padLeft(2, '0')}';

  Future<void> _save(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (_) {
      if (!context.mounted) return;
      _showStub(context, '保存失败，请稍后重试。');
    }
  }

  Future<void> _editProfile(BuildContext context) async {
    var name = controller.profile.nickname;
    var motto = controller.profile.motto;
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('编辑本地资料'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: name,
              onChanged: (value) => name = value,
              maxLength: 40,
              decoration: const InputDecoration(labelText: '昵称'),
            ),
            TextFormField(
              initialValue: motto,
              onChanged: (value) => motto = value,
              maxLength: 140,
              decoration: const InputDecoration(labelText: '个性签名'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (name.trim().isEmpty) return;
              Navigator.pop(dialogContext, (name.trim(), motto.trim()));
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result != null && context.mounted) {
      await _save(context, () => controller.saveProfile(result.$1, result.$2));
    }
  }

  Future<void> _editQuietHours(BuildContext context) async {
    final current = controller.preferences;
    final start = await showTimePicker(
      context: context,
      helpText: '免打扰开始时间',
      initialTime: TimeOfDay(
        hour: current.quietHoursStartMinute ~/ 60,
        minute: current.quietHoursStartMinute % 60,
      ),
    );
    if (start == null || !context.mounted) return;
    final end = await showTimePicker(
      context: context,
      helpText: '免打扰结束时间',
      initialTime: TimeOfDay(
        hour: current.quietHoursEndMinute ~/ 60,
        minute: current.quietHoursEndMinute % 60,
      ),
    );
    if (end == null || !context.mounted) return;
    await _save(
      context,
      () => controller.setQuietHours(
        start.hour * 60 + start.minute,
        end.hour * 60 + end.minute,
      ),
    );
  }

  Future<void> _editReminderOffsets(BuildContext context) async {
    var input = controller.preferences.defaultReminderOffsetsMinutes.join(',');
    final offsets = await showDialog<List<int>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('默认提前提醒'),
        content: TextFormField(
          initialValue: input,
          onChanged: (value) => input = value,
          keyboardType: TextInputType.text,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9,， ]')),
          ],
          decoration: const InputDecoration(
            labelText: '提前分钟数，以逗号分隔',
            helperText: '例如 1440,180 代表提前 24 小时和 3 小时',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = input
                  .replaceAll('，', ',')
                  .split(',')
                  .map((part) => int.tryParse(part.trim()))
                  .toList();
              if (parsed.isEmpty ||
                  parsed.any((value) => value == null || value <= 0)) {
                return;
              }
              Navigator.pop(dialogContext, parsed.cast<int>());
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (offsets != null && context.mounted) {
      await _save(context, () => controller.setDefaultReminderOffsets(offsets));
    }
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
            const Text('任务已保存在本机 SQLite。JSON 导出、导入和清除功能尚未接入。'),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => _showStub(context, 'JSON 导出功能尚未接入。'),
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
