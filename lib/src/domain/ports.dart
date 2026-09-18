import 'task.dart';

abstract interface class TaskRepository {
  Future<List<TaskItem>> listTasks();

  Future<TaskItem?> getTask(String id);

  Future<TaskItem> createTask(TaskDraft draft);

  Future<TaskItem> updateTask(TaskItem task);

  Future<TaskItem> transitionTask(String id, TaskStatus target);

  Future<void> deleteTask(String id);
}

class ReminderPlan {
  const ReminderPlan({
    required this.taskId,
    required this.notificationId,
    required this.fireAt,
    required this.title,
    required this.body,
  });

  final String taskId;
  final String notificationId;
  final DateTime fireAt;
  final String title;
  final String body;
}

abstract interface class NotificationPort {
  Future<bool> requestPermission();

  Future<void> replaceTaskReminders(String taskId, List<ReminderPlan> plans);

  Future<void> cancelTaskReminders(String taskId);

  Future<void> reconcile(List<ReminderPlan> expected);
}

abstract interface class FilePort {
  Future<String?> exportJson(String suggestedName, String content);

  Future<String?> pickJson();
}

abstract interface class ClockPort {
  DateTime now();
}

abstract interface class InstallationStore {
  Future<DateTime> getOrCreateFirstLaunchDate();
}
