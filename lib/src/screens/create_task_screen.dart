import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/task.dart';
import '../domain/reminder_planner.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'reminder_duration_picker_dialog.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({
    super.key,
    required this.controller,
    this.initialTask,
  });

  final AppController controller;
  final TaskItem? initialTask;

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _minutesController = TextEditingController(text: '60');
  final _customCategoryController = TextEditingController();
  final _customCategoryFocusNode = FocusNode();
  late DateTime _dueAt;
  TaskCategory _category = TaskCategory.study;
  bool _important = true;
  int _estimatedMinutes = 60;
  int? _taskReminderOffsetMinutes;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTask;
    if (initial != null) {
      _titleController.text = initial.title;
      _notesController.text = initial.notes;
      _minutesController.text = initial.estimatedMinutes.toString();
      _dueAt = initial.dueAt;
      _category = initial.category;
      _customCategoryController.text = initial.customCategoryLabel ?? '';
      _important = initial.isImportant;
      _estimatedMinutes = initial.estimatedMinutes;
      _taskReminderOffsetMinutes = initial.taskReminderOffsetMinutes;
      return;
    }
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _dueAt = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 18);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _minutesController.dispose();
    _customCategoryController.dispose();
    _customCategoryFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.controller.now;
    final needsTaskReminder = ReminderPlanner.needsTaskReminder(
      _dueAt,
      widget.controller.preferences.defaultReminderOffsetsMinutes,
      now,
    );
    final reminderOffset = _taskReminderOffsetMinutes ?? 5;
    final reminderPoint = _dueAt.subtract(Duration(minutes: reminderOffset));
    final preview = TaskItem(
      id: 'preview',
      title: _titleController.text.isEmpty ? '新任务' : _titleController.text,
      dueAt: _dueAt,
      category: _category,
      customCategoryLabel: _category == TaskCategory.custom
          ? _customCategoryController.text.trim()
          : null,
      isImportant: _important,
      estimatedMinutes: _estimatedMinutes,
      status: TaskStatus.active,
      createdAt: DateTime.now(),
    );
    final quadrant = preview.quadrantAt(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialTask == null ? '签下生死状' : '编辑任务'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.edit_calendar_rounded,
                      color: AppColors.orange,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.initialTask == null
                            ? '先写下来，再决定怎么拆。必填只有名称、截止时间和重要度。'
                            : '调整任务内容后，风险与排序会立即重算。',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const _FieldLabel('任务名称', required: true),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                maxLength: taskTitleMaxLength,
                decoration: const InputDecoration(
                  hintText: '例如：提交交互设计期末作业',
                  prefixIcon: Icon(Icons.task_alt_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return '请写下任务名称';
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              const _FieldLabel('截止时间', required: true),
              const SizedBox(height: 8),
              PaperCard(
                onTap: _pickDateTime,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.alarm_rounded, color: AppColors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateTimeLabel(_dueAt),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(compactDeadline(_dueAt, DateTime.now())),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
              if (needsTaskReminder) ...[
                const SizedBox(height: 16),
                const _FieldLabel('本任务提醒时间'),
                const SizedBox(height: 6),
                Text(
                  '默认提醒点已过去。此设置只影响本任务，不会修改全局提前提醒。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                PaperCard(
                  onTap: _pickTaskReminder,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notifications_active_outlined,
                        color: AppColors.orange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _taskReminderOffsetMinutes == null
                              ? '未单独设置：默认截止前 5 分钟'
                              : formatReminderDuration(reminderOffset),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
                if (_taskReminderOffsetMinutes != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () =>
                          setState(() => _taskReminderOffsetMinutes = null),
                      child: const Text('恢复默认 5 分钟'),
                    ),
                  ),
                if (!reminderPoint.isAfter(now))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '该提醒时间已过去，保存后不会补发；请调整截止时间或提醒提前量。',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.red),
                    ),
                  ),
              ],
              const SizedBox(height: 22),
              const _FieldLabel('重要度', required: true),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.star_rounded),
                    label: Text('重要'),
                  ),
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.circle_outlined),
                    label: Text('普通'),
                  ),
                ],
                selected: {_important},
                onSelectionChanged: (value) =>
                    setState(() => _important = value.first),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '当前会进入「${quadrant.title}」；紧急度会随时间自动变化。',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 22),
              const _FieldLabel('分类'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TaskCategory.values
                    .map(
                      (category) => ChoiceChip(
                        label: Text(category.label),
                        selected: _category == category,
                        avatar: category == TaskCategory.custom
                            ? const Icon(Icons.add_rounded, size: 18)
                            : null,
                        onSelected: (_) {
                          setState(() => _category = category);
                          if (category == TaskCategory.custom) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) return;
                              _customCategoryFocusNode.requestFocus();
                            });
                          }
                        },
                      ),
                    )
                    .toList(),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _category == TaskCategory.custom
                    ? Padding(
                        key: const ValueKey('custom_category_input'),
                        padding: const EdgeInsets.only(top: 10),
                        child: TextFormField(
                          key: const Key('custom_category_field'),
                          controller: _customCategoryController,
                          focusNode: _customCategoryFocusNode,
                          textInputAction: TextInputAction.next,
                          maxLength: taskCustomCategoryMaxLength,
                          decoration: const InputDecoration(
                            labelText: '自定义标签',
                            hintText: '例如：社团、考试、健身',
                            prefixIcon: Icon(Icons.sell_outlined),
                          ),
                          validator: (value) {
                            if (_category == TaskCategory.custom &&
                                (value == null || value.trim().isEmpty)) {
                              return '请输入自定义标签';
                            }
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      )
                    : const SizedBox.shrink(
                        key: ValueKey('custom_category_empty'),
                      ),
              ),
              const SizedBox(height: 22),
              const _FieldLabel('预计耗时'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [30, 60, 120, 180]
                    .map(
                      (minutes) => ChoiceChip(
                        label: Text(
                          minutes < 60 ? '$minutes 分钟' : '${minutes ~/ 60} 小时',
                        ),
                        selected: _estimatedMinutes == minutes,
                        onSelected: (_) => setState(() {
                          _estimatedMinutes = minutes;
                          _minutesController.text = minutes.toString();
                        }),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _minutesController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: '自定义分钟数',
                  suffixText: '分钟',
                ),
                onChanged: (value) => setState(() {
                  _estimatedMinutes = int.tryParse(value) ?? 0;
                }),
                validator: (value) => (int.tryParse(value ?? '') ?? 0) > 0
                    ? null
                    : '预计耗时必须大于 0 分钟',
              ),
              const SizedBox(height: 22),
              const _FieldLabel('备注'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                maxLength: taskNotesMaxLength,
                decoration: const InputDecoration(
                  hintText: '补充提交格式、资料位置或下一步行动……',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  key: Key(
                    widget.initialTask == null
                        ? 'create_task_submit'
                        : 'edit_task_submit',
                  ),
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.draw_rounded),
                  label: Text(
                    _submitting
                        ? '正在保存…'
                        : widget.initialTask == null
                        ? '签下生死状'
                        : '保存修改',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate:
          _dueAt.isBefore(DateTime.now().subtract(const Duration(days: 1)))
          ? _dueAt
          : DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt),
    );
    if (time == null) return;
    setState(
      () => _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _pickTaskReminder() async {
    final selected = await showDialog<List<int>>(
      context: context,
      builder: (_) => ReminderDurationPickerDialog(
        title: '本任务提醒时间',
        initialOffsets: [_taskReminderOffsetMinutes ?? 5],
      ),
    );
    if (selected != null && mounted) {
      setState(() => _taskReminderOffsetMinutes = selected.single);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final needsTaskReminder = ReminderPlanner.needsTaskReminder(
      _dueAt,
      widget.controller.preferences.defaultReminderOffsetsMinutes,
      widget.controller.now,
    );
    final taskReminderOffsetMinutes = needsTaskReminder
        ? (_taskReminderOffsetMinutes ?? 5)
        : null;
    if (_dueAt.isBefore(DateTime.now())) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('截止时间已经过去'),
          content: const Text('仍然保存会让任务立即进入忏悔录，等待你选择结案方式。确定继续吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('返回修改'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('仍然保存'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _submitting = true);
    try {
      final draft = TaskDraft(
        title: _titleController.text.trim(),
        dueAt: _dueAt,
        category: _category,
        isImportant: _important,
        estimatedMinutes: _estimatedMinutes,
        notes: _notesController.text.trim(),
        customCategoryLabel: _category == TaskCategory.custom
            ? _customCategoryController.text.trim()
            : null,
        taskReminderOffsetMinutes: taskReminderOffsetMinutes,
      );
      final initial = widget.initialTask;
      final saved = initial == null
          ? await widget.controller.addTask(draft)
          : await widget.controller.updateTask(
              initial.copyWith(
                title: draft.title,
                dueAt: draft.dueAt,
                category: draft.category,
                customCategoryLabel: draft.customCategoryLabel,
                clearCustomCategoryLabel: draft.category != TaskCategory.custom,
                isImportant: draft.isImportant,
                estimatedMinutes: draft.estimatedMinutes,
                notes: draft.notes,
                taskReminderOffsetMinutes: draft.taskReminderOffsetMinutes,
                clearTaskReminderOffset:
                    draft.taskReminderOffsetMinutes == null,
              ),
            );
      if (!mounted) return;
      Navigator.pop(context, saved.title);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存失败，任务可能已变化，请返回刷新后重试。')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label, {this.required = false});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        if (required) ...[
          const SizedBox(width: 4),
          const Text(
            '*',
            style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w900),
          ),
        ],
      ],
    );
  }
}
