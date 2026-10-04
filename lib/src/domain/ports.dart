import 'local_data.dart';
import 'task.dart';

abstract interface class PreferenceRepository {
  Future<AppPreferences> getOrCreate();
  Future<AppPreferences> save(AppPreferences preferences);
}

abstract interface class ProfileRepository {
  Future<UserProfile> getOrCreate();
  Future<UserProfile> save(UserProfile profile);
}

abstract interface class ReminderRepository {
  Future<List<ReminderRecord>> listForTask(String taskId);
  Future<List<ReminderRecord>> listOutstanding();
  Future<void> replaceForTask(String taskId, List<ReminderRecord> records);
  Future<int> syncPlanForTask(String taskId, List<ReminderRecord> desired);
  Future<ReminderRecord> updateStatus(
    String id,
    ReminderStatus status, {
    String? platformNotificationId,
    String? lastErrorCode,
  });
  Future<int> cancelForTask(String taskId);
}

abstract interface class TaskRepository {
  Future<List<TaskItem>> listTasks();

  Future<int> reconcileOverdue(DateTime asOf);

  Future<TaskItem?> getTask(String id);

  Future<TaskItem> createTask(TaskDraft draft);

  Future<TaskItem> updateTask(TaskItem task);

  Future<TaskItem> transitionTask(String id, TaskStatus target);

  Future<void> deleteTask(String id);

  Future<bool> hasMeaningfulHistory(String id);

  Future<Map<TaskCategory, double>> missedRatesByCategory();
}

class NotificationCapabilities {
  const NotificationCapabilities({
    required this.authorized,
    required this.exact,
    required this.exactPermissionRequired,
    required this.pendingLimit,
  });

  final bool authorized;
  final bool exact;
  final bool exactPermissionRequired;
  final int pendingLimit;
}

abstract interface class NotificationPort {
  Future<NotificationCapabilities> inspect();
  Future<bool> requestPermission();
  Future<bool> requestExactPermission();
  Future<bool> openSettings();
  Future<String> deviceTimezone();
  Future<Set<int>> pendingIds();
  Future<void> schedule({
    required int id,
    required DateTime fireAt,
    required ReminderChannel channel,
    required String taskId,
    required bool exact,
  });
  Future<void> cancel(int id);
  Stream<String> get selectedTaskIds;
  String? takeInitialTaskId();
}

abstract interface class FilePort {
  Future<String?> exportJson(String suggestedName, String content);

  Future<String?> pickJson();
}

abstract interface class ClockPort {
  DateTime now();
}

class SystemClock implements ClockPort {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

abstract interface class InstallationStore {
  Future<DateTime> getOrCreateFirstLaunchDate();
}
