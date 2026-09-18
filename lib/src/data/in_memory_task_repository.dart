import '../domain/ports.dart';
import '../domain/task.dart';

class InMemoryTaskRepository implements TaskRepository {
  final List<TaskItem> _tasks = [];
  int _sequence = 1;

  @override
  Future<TaskItem> createTask(TaskDraft draft) async {
    final task = TaskItem(
      id: 'task-${_sequence++}',
      title: draft.title,
      dueAt: draft.dueAt,
      category: draft.category,
      isImportant: draft.isImportant,
      estimatedMinutes: draft.estimatedMinutes,
      status: TaskStatus.active,
      createdAt: DateTime.now(),
      notes: draft.notes,
    );
    _tasks.add(task);
    return task;
  }

  @override
  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((task) => task.id == id);
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
    if (index < 0) throw StateError('TASK_NOT_FOUND');
    final completed =
        target == TaskStatus.completed || target == TaskStatus.completedLate;
    final updated = _tasks[index].copyWith(
      status: target,
      completedAt: completed ? DateTime.now() : null,
    );
    _tasks[index] = updated;
    return updated;
  }

  @override
  Future<TaskItem> updateTask(TaskItem task) async {
    final index = _tasks.indexWhere((item) => item.id == task.id);
    if (index < 0) throw StateError('TASK_NOT_FOUND');
    _tasks[index] = task;
    return task;
  }
}
