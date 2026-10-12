import 'package:flutter/material.dart';

const _ink = Color(0xFF24211E);
const _mutedInk = Color(0xFF77716A);
const _paper = Color(0xFFFFFBF4);
const _accent = Color(0xFFFF6739);
const _accentSoft = Color(0xFFFFE2D7);

String formatReminderDuration(int minutes) {
  if (minutes <= 0) {
    return '未设置';
  }
  if (minutes % 1440 == 0) {
    return '${minutes ~/ 1440} 天前';
  }
  if (minutes % 60 == 0) {
    return '${minutes ~/ 60} 小时前';
  }
  if (minutes >= 60) {
    return '${minutes ~/ 60} 小时 ${minutes % 60} 分钟前';
  }
  return '$minutes 分钟前';
}

class ReminderDurationPickerDialog extends StatefulWidget {
  const ReminderDurationPickerDialog({
    super.key,
    required this.initialOffsets,
    this.title = '默认提前提醒',
  });

  final List<int> initialOffsets;
  final String title;

  @override
  State<ReminderDurationPickerDialog> createState() =>
      _ReminderDurationPickerDialogState();
}

class _ReminderDurationPickerDialogState
    extends State<ReminderDurationPickerDialog> {
  late final FixedExtentScrollController _hoursController;
  late final FixedExtentScrollController _minutesController;
  late int _hours;
  late int _minutes;

  int get _totalMinutes => _hours * 60 + _minutes;

  @override
  void initState() {
    super.initState();
    final rawMinutes = widget.initialOffsets.isEmpty
        ? 1440
        : widget.initialOffsets.first;
    final cappedMinutes = rawMinutes.clamp(0, 1500).toInt();
    _hours = cappedMinutes >= 1440 ? 24 : cappedMinutes ~/ 60;
    _minutes = cappedMinutes >= 1440
        ? cappedMinutes - 1440
        : cappedMinutes % 60;
    _hoursController = FixedExtentScrollController(initialItem: _hours);
    _minutesController = FixedExtentScrollController(initialItem: _minutes);
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _totalMinutes > 0;
    return Dialog(
      key: const Key('reminder-duration-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      backgroundColor: _paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                color: _ink,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '左侧选择小时（0–24），右侧选择分钟（0–60）',
              textAlign: TextAlign.center,
              style: TextStyle(color: _mutedInk, fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 18),
            Container(
              height: 230,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE5DDD2)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  IgnorePointer(
                    child: Container(
                      height: 54,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: _accentSoft,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _accent.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _DurationWheel(
                          key: const Key('reminder-hours-wheel'),
                          title: '小时',
                          count: 25,
                          suffix: '时',
                          controller: _hoursController,
                          selectedValue: _hours,
                          onChanged: (value) => setState(() => _hours = value),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 160,
                        color: const Color(0xFFE5DDD2),
                      ),
                      Expanded(
                        child: _DurationWheel(
                          key: const Key('reminder-minutes-wheel'),
                          title: '分钟',
                          count: 61,
                          suffix: '分',
                          controller: _minutesController,
                          selectedValue: _minutes,
                          onChanged: (value) =>
                              setState(() => _minutes = value),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Text(
                canSave
                    ? '将在截止前 ${formatReminderDuration(_totalMinutes).replaceFirst('前', '')}提醒'
                    : '至少提前 1 分钟',
                key: ValueKey(canSave ? _totalMinutes : 0),
                style: TextStyle(
                  color: canSave ? _mutedInk : _accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(foregroundColor: _mutedInk),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: canSave
                        ? () => Navigator.of(context).pop(<int>[_totalMinutes])
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      disabledBackgroundColor: const Color(0xFFD9D2CA),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      '保存',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DurationWheel extends StatelessWidget {
  const _DurationWheel({
    super.key,
    required this.title,
    required this.count,
    required this.suffix,
    required this.controller,
    required this.selectedValue,
    required this.onChanged,
  });

  final String title;
  final int count;
  final String suffix;
  final FixedExtentScrollController controller;
  final int selectedValue;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            color: _mutedInk,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        Expanded(
          child: ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: 54,
            diameterRatio: 1.55,
            perspective: 0.0025,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: onChanged,
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: count,
              builder: (context, index) {
                final isSelected = index == selectedValue;
                return Center(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 140),
                    style: TextStyle(
                      color: isSelected
                          ? _ink
                          : _mutedInk.withValues(alpha: 0.45),
                      fontSize: isSelected ? 23 : 17,
                      fontWeight: isSelected
                          ? FontWeight.w900
                          : FontWeight.w600,
                    ),
                    child: Text('${index.toString().padLeft(2, '0')} $suffix'),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
