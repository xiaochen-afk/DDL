import 'local_data.dart';
import 'ports.dart';
import 'reminder_planner.dart';
import 'task.dart';

/// Reconciles SQLite's desired plan. Platform notifications are a later stage.
class ReminderCoordinator {
  const ReminderCoordinator(this._reminders);

  final ReminderRepository _reminders;

  Future<int> reconcile(
    Iterable<TaskItem> tasks,
    AppPreferences preferences,
    DateTime now, {
    Map<TaskCategory, double> missedRates = const {},
  }) async {
    final all = tasks.toList();
    var changes = 0;
    for (final task in all) {
      if (task.status == TaskStatus.active &&
          preferences.notificationsEnabled) {
        changes += await _reminders.syncPlanForTask(
          task.id,
          ReminderPlanner.plan(
            task,
            preferences,
            now,
            all,
            missedRate: missedRates[task.category] ?? 0,
          ),
        );
      } else {
        changes += await _reminders.cancelForTask(task.id);
      }
    }
    return changes;
  }
}
