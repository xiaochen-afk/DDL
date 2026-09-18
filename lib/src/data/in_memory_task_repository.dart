import '../domain/ports.dart';
import '../domain/task.dart';
import '../core/app_failure.dart';

class InMemoryTaskRepository implements TaskRepository {
  InMemoryTaskRepository({ClockPort clock = const SystemClock()})
    : _clock = clock;

  final ClockPort _clock;
  final List<TaskItem> _tasks = [];
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
    if (!_canTransition(current.status, target)) {
      throw const AppFailure(
        code: 'VALIDATION_FAILED',
        message: 'Task status transition is not allowed.',
      );
    }
    final completed =
        target == TaskStatus.completed || target == TaskStatus.completedLate;
    final now = _clock.now();
    final updated = current.copyWith(
      status: target,
      completedAt: completed ? now : current.completedAt,
      updatedAt: now,
      version: current.version + 1,
    );
    _tasks[index] = updated;
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
    _validateTask(task);
    final updated = task.copyWith(
      updatedAt: _clock.now(),
      version: task.version + 1,
    );
    _tasks[index] = updated;
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
        title.length > 60 ||
        draft.estimatedMinutes <= 0 ||
        draft.notes.length > 300) {
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
      ),
    );
  }
}
