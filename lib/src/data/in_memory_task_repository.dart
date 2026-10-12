import '../domain/ports.dart';
import '../domain/task.dart';
import '../core/app_failure.dart';

class InMemoryTaskRepository implements TaskRepository {
  InMemoryTaskRepository({ClockPort clock = const SystemClock()})
    : _clock = clock;

  final ClockPort _clock;
  final List<TaskItem> _tasks = [];
  final Set<String> _history = {};
  final Map<String, TaskStatus> _settledOutcomes = {};
  int _sequence = 1;

  @override
  Future<TaskItem> createTask(TaskDraft draft) async {
    _validateDraft(draft);
    final now = _clock.now();
    final task = TaskItem(
      id: 'task-${_sequence++}',
      title: draft.title,
      dueAt: draft.dueAt,
      category: draft.category,
      isImportant: draft.isImportant,
      estimatedMinutes: draft.estimatedMinutes,
      status: TaskStatus.active,
      createdAt: now,
      updatedAt: now,
      notes: draft.notes,
      customCategoryLabel: draft.category == TaskCategory.custom
          ? draft.customCategoryLabel!.trim()
          : null,
      taskReminderOffsetMinutes: draft.taskReminderOffsetMinutes,
    );
    _tasks.add(task);
    return task;
  }

  @override
  Future<void> deleteTask(String id) async {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index < 0) {
      throw const AppFailure(
        code: 'TASK_NOT_FOUND',
        message: 'Task does not exist.',
      );
    }
    _tasks.removeAt(index);
    _history.remove(id);
    _settledOutcomes.remove(id);
  }

  @override
  Future<bool> hasMeaningfulHistory(String id) async {
    final task = await getTask(id);
    if (task == null) {
      throw const AppFailure(
        code: 'TASK_NOT_FOUND',
        message: 'Task does not exist.',
      );
    }
    return _history.contains(id) || task.status != TaskStatus.active;
  }

  @override
  Future<Map<TaskCategory, double>> missedRatesByCategory() async {
    final result = <TaskCategory, double>{};
    for (final category in TaskCategory.values) {
      final settled = _tasks.where(
        (task) =>
            task.category == category && _settledOutcomes.containsKey(task.id),
      );
      final count = settled.length;
      final missed = settled
          .where((task) => _settledOutcomes[task.id] == TaskStatus.missed)
          .length;
      result[category] = count == 0 ? 0 : missed / count;
    }
    return result;
  }

  @override
  Future<TaskItem?> getTask(String id) async {
    for (final task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  @override
  Future<List<TaskItem>> listTasks() async => List.unmodifiable(_tasks);

  @override
  Future<int> reconcileOverdue(DateTime asOf) async {
    var changed = 0;
    for (var index = 0; index < _tasks.length; index++) {
      final task = _tasks[index];
      if (task.status != TaskStatus.active || asOf.isBefore(task.dueAt)) {
        continue;
      }
      _tasks[index] = task.copyWith(
        status: TaskStatus.overdueReview,
        updatedAt: asOf,
        version: task.version + 1,
      );
      _history.add(task.id);
      changed++;
    }
    return changed;
  }

  @override
  Future<TaskItem> transitionTask(String id, TaskStatus target) async {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index < 0) {
      throw const AppFailure(
        code: 'TASK_NOT_FOUND',
        message: 'Task does not exist.',
      );
    }
    final current = _tasks[index];
    if (current.status == target) return current;
    final now = _clock.now();
    final effectiveTarget =
        current.status == TaskStatus.active &&
            target == TaskStatus.completed &&
            !now.isBefore(current.dueAt)
        ? TaskStatus.overdueReview
        : target;
    if (!_canTransition(current.status, effectiveTarget) ||
        (effectiveTarget == TaskStatus.overdueReview &&
            now.isBefore(current.dueAt))) {
      throw const AppFailure(
        code: 'VALIDATION_FAILED',
        message: 'Task status transition is not allowed.',
      );
    }
    final completed =
        effectiveTarget == TaskStatus.completed ||
        effectiveTarget == TaskStatus.completedLate;
    final updated = current.copyWith(
      status: effectiveTarget,
      completedAt: completed ? now : current.completedAt,
      updatedAt: now,
      version: current.version + 1,
    );
    _tasks[index] = updated;
    _history.add(id);
    if (effectiveTarget == TaskStatus.completed ||
        effectiveTarget == TaskStatus.completedLate ||
        effectiveTarget == TaskStatus.missed) {
      _settledOutcomes[id] = effectiveTarget;
    }
    return updated;
  }

  @override
  Future<TaskItem> updateTask(TaskItem task) async {
    final index = _tasks.indexWhere((item) => item.id == task.id);
    if (index < 0) {
      throw const AppFailure(
        code: 'TASK_NOT_FOUND',
        message: 'Task does not exist.',
      );
    }
    final current = _tasks[index];
    if (current.version != task.version) {
      throw const AppFailure(
        code: 'VALIDATION_FAILED',
        message: 'Task was changed by another operation.',
      );
    }
    if (current.status != TaskStatus.active || task.status != current.status) {
      throw const AppFailure(
        code: 'VALIDATION_FAILED',
        message: 'Only active tasks can be edited.',
      );
    }
    _validateTask(task);
    final updated = task.copyWith(
      title: task.title.trim(),
      customCategoryLabel: task.category == TaskCategory.custom
          ? task.customCategoryLabel!.trim()
          : null,
      clearCustomCategoryLabel: task.category != TaskCategory.custom,
      updatedAt: _clock.now(),
      version: task.version + 1,
    );
    _tasks[index] = updated;
    _history.add(task.id);
    return updated;
  }

  static bool _canTransition(TaskStatus from, TaskStatus to) {
    return switch (from) {
      TaskStatus.active =>
        to == TaskStatus.completed ||
            to == TaskStatus.overdueReview ||
            to == TaskStatus.archived,
      TaskStatus.overdueReview =>
        to == TaskStatus.missed || to == TaskStatus.completedLate,
      TaskStatus.completed ||
      TaskStatus.missed ||
      TaskStatus.completedLate => to == TaskStatus.archived,
      TaskStatus.archived => false,
    };
  }

  static void _validateDraft(TaskDraft draft) {
    final title = draft.title.trim();
    if (title.isEmpty ||
        title.length > taskTitleMaxLength ||
        draft.estimatedMinutes <= 0 ||
        draft.notes.length > taskNotesMaxLength ||
        !_hasValidCustomCategory(draft) ||
        (draft.taskReminderOffsetMinutes != null &&
            draft.taskReminderOffsetMinutes! <= 0)) {
      throw const AppFailure(
        code: 'VALIDATION_FAILED',
        message: 'Task fields are invalid.',
      );
    }
  }

  static void _validateTask(TaskItem task) {
    _validateDraft(
      TaskDraft(
        title: task.title,
        dueAt: task.dueAt,
        category: task.category,
        isImportant: task.isImportant,
        estimatedMinutes: task.estimatedMinutes,
        notes: task.notes,
        customCategoryLabel: task.customCategoryLabel,
        taskReminderOffsetMinutes: task.taskReminderOffsetMinutes,
      ),
    );
  }

  static bool _hasValidCustomCategory(TaskDraft draft) {
    final label = draft.customCategoryLabel?.trim() ?? '';
    if (draft.category == TaskCategory.custom) {
      return label.isNotEmpty && label.length <= taskCustomCategoryMaxLength;
    }
    return label.isEmpty;
  }
}
