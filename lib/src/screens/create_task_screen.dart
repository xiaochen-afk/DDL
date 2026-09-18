import 'package:flutter/material.dart';

import '../domain/task.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  late DateTime _dueAt;
  TaskCategory _category = TaskCategory.study;
  bool _important = true;
  int _estimatedMinutes = 60;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _dueAt = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 18);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = TaskItem(
      id: 'preview',
      title: _titleController.text.isEmpty ? '新任务' : _titleController.text,
      dueAt: _dueAt,
      category: _category,
      isImportant: _important,
      estimatedMinutes: _estimatedMinutes,
      status: TaskStatus.active,
      createdAt: DateTime.now(),
    );
    final quadrant = preview.quadrantAt(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('签下生死状'), centerTitle: false),
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
                        '先写下来，再决定怎么拆。必填只有名称、截止时间和重要度。',
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
                maxLength: 60,
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
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text('今天 23:00'),
                    onPressed: () => _setQuickDue(0, 23),
                  ),
                  ActionChip(
                    label: const Text('明天 18:00'),
                    onPressed: () => _setQuickDue(1, 18),
                  ),
                  ActionChip(
                    label: const Text('三天后'),
                    onPressed: () => _setQuickDue(3, 18),
                  ),
                ],
              ),
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
                        onSelected: (_) => setState(() => _category = category),
                      ),
                    )
                    .toList(),
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
                        onSelected: (_) =>
                            setState(() => _estimatedMinutes = minutes),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 22),
              const _FieldLabel('备注'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                maxLength: 300,
                decoration: const InputDecoration(
                  hintText: '补充提交格式、资料位置或下一步行动……',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  key: const Key('create_task_submit'),
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.draw_rounded),
                  label: Text(_submitting ? '正在保存…' : '签下生死状'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setQuickDue(int days, int hour) {
    final target = DateTime.now().add(Duration(days: days));
    setState(
      () => _dueAt = DateTime(target.year, target.month, target.day, hour),
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dueAt.isBefore(DateTime.now())) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('截止时间已经过去'),
          content: const Text('仍然保存会让任务立即进入高风险状态。确定继续吗？'),
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
    final created = await widget.controller.addTask(
      TaskDraft(
        title: _titleController.text.trim(),
        dueAt: _dueAt,
        category: _category,
        isImportant: _important,
        estimatedMinutes: _estimatedMinutes,
        notes: _notesController.text.trim(),
      ),
    );
    if (!mounted) return;
    Navigator.pop(context, created.title);
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
