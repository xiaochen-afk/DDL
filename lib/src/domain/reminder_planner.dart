import 'local_data.dart';
import 'risk_engine.dart';
import 'task.dart';

/// Produces desired local reminder records; it never schedules a device alert.
class ReminderPlanner {
  const ReminderPlanner._();

  static List<ReminderRecord> plan(
    TaskItem task,
    AppPreferences preferences,
    DateTime now,
    Iterable<TaskItem> allTasks, {
    double missedRate = 0,
  }) {
    if (!preferences.notificationsEnabled || task.status != TaskStatus.active) {
      return const [];
    }
    final due = task.dueAt.toLocal();
    final current = now.toLocal();
    if (!due.isAfter(current)) return const [];

    final candidates = <(DateTime, ReminderChannel)>[
      for (final offset in preferences.defaultReminderOffsetsMinutes)
        (due.subtract(Duration(minutes: offset)), ReminderChannel.normal),
      if (task.estimatedMinutes > 180)
        (
          due.subtract(
            Duration(
              minutes: task.estimatedMinutes + preferences.bufferMinutes,
            ),
          ),
          ReminderChannel.normal,
        ),
    ];
    final criticalAt = due.subtract(
      Duration(minutes: preferences.urgentThresholdMinutes),
    );
    if (RiskEngine.assess(
          task,
          criticalAt,
          allTasks,
          missedRate: missedRate,
        ).level ==
        '极高') {
      candidates.add((criticalAt, ReminderChannel.critical));
    }

    final byMinute = <int, ReminderChannel>{};
    for (final (candidate, channel) in candidates) {
      final fireAt = _afterQuietHours(candidate, preferences);
      if (fireAt.isBefore(current) || !fireAt.isBefore(due)) continue;
      final minute = fireAt.millisecondsSinceEpoch ~/ 60000;
      final previous = byMinute[minute];
      if (previous == null || channel == ReminderChannel.critical) {
        byMinute[minute] = channel;
      }
    }

    final minutes = byMinute.keys.toList()..sort();
    return List.unmodifiable([
      for (final minute in minutes)
        ReminderRecord(
          id: '${task.id}:${task.version}:$minute:${byMinute[minute]!.name}',
          taskId: task.id,
          scheduledAt: DateTime.fromMillisecondsSinceEpoch(minute * 60000),
          channel: byMinute[minute]!,
          status: ReminderStatus.pending,
        ),
    ]);
  }

  static DateTime _afterQuietHours(DateTime value, AppPreferences preferences) {
    final minute = value.hour * 60 + value.minute;
    final start = preferences.quietHoursStartMinute;
    final end = preferences.quietHoursEndMinute;
    if (start == end) return _onMinute(value);
    final crossesMidnight = start > end;
    final isQuiet = crossesMidnight
        ? minute >= start || minute < end
        : minute >= start && minute < end;
    if (!isQuiet) return _onMinute(value);
    final nextDay = crossesMidnight && minute >= start ? 1 : 0;
    return DateTime(
      value.year,
      value.month,
      value.day + nextDay,
      end ~/ 60,
      end % 60,
    );
  }

  static DateTime _onMinute(DateTime value) =>
      DateTime(value.year, value.month, value.day, value.hour, value.minute);
}
