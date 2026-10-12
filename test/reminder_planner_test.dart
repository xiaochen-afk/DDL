import 'package:ddl_survival/src/domain/local_data.dart';
import 'package:ddl_survival/src/domain/reminder_planner.dart';
import 'package:ddl_survival/src/domain/task.dart';
import 'package:flutter_test/flutter_test.dart';

TaskItem _task(
  DateTime due, {
  bool important = false,
  int minutes = 60,
  int? taskReminderOffsetMinutes,
}) => TaskItem(
  id: 'task-1',
  title: 'DDL',
  dueAt: due,
  category: TaskCategory.study,
  isImportant: important,
  estimatedMinutes: minutes,
  taskReminderOffsetMinutes: taskReminderOffsetMinutes,
  status: TaskStatus.active,
  createdAt: due.subtract(const Duration(days: 3)),
);

void main() {
  test('offers task reminder only after every global default point passes', () {
    final due = DateTime(2026, 10, 6, 18);
    expect(
      ReminderPlanner.needsTaskReminder(due, [
        180,
        1440,
      ], DateTime(2026, 10, 6, 14, 59)),
      false,
    );
    expect(
      ReminderPlanner.needsTaskReminder(due, [
        180,
        1440,
      ], DateTime(2026, 10, 6, 15, 1)),
      true,
    );
    expect(ReminderPlanner.needsTaskReminder(due, [180], due), false);
  });

  test('task-specific offset replaces only global default reminders', () {
    final due = DateTime(2026, 10, 6, 18);
    final task = _task(due, taskReminderOffsetMinutes: 5);
    const preferences = AppPreferences(
      defaultReminderOffsetsMinutes: [180, 1440],
    );
    final now = DateTime(2026, 10, 6, 16);
    final plans = ReminderPlanner.plan(task, preferences, now, [task]);
    expect(plans.map((plan) => plan.scheduledAt), [
      DateTime(2026, 10, 6, 17, 55),
    ]);
    expect(preferences.defaultReminderOffsetsMinutes, [180, 1440]);
  });

  test('task-specific point in the past is not falsely scheduled', () {
    final due = DateTime(2026, 10, 6, 18);
    final task = _task(due, taskReminderOffsetMinutes: 5);
    final plans = ReminderPlanner.plan(
      task,
      const AppPreferences(),
      DateTime(2026, 10, 6, 17, 58),
      [task],
    );
    expect(plans, isEmpty);
  });

  test(
    'default reminders target exact minutes and move out of quiet hours',
    () {
      final due = DateTime(2026, 10, 6, 8);
      final task = _task(due);
      final plans = ReminderPlanner.plan(
        task,
        const AppPreferences(),
        DateTime(2026, 10, 4, 8),
        [task],
      );
      expect(plans.map((plan) => plan.scheduledAt), [
        DateTime(2026, 10, 5, 8),
        DateTime(2026, 10, 6, 7, 30),
      ]);
      expect(
        plans.every((plan) => plan.status == ReminderStatus.pending),
        true,
      );
      expect(plans.every((plan) => plan.scheduledAt.second == 0), true);
    },
  );

  test('high risk adds one-hour alert and long task start, deduplicated', () {
    final due = DateTime(2026, 10, 6, 18);
    final task = _task(due, important: true, minutes: 240);
    final plans = ReminderPlanner.plan(
      task,
      const AppPreferences(defaultReminderOffsetsMinutes: [60, 180, 1440]),
      DateTime(2026, 10, 5, 10),
      [task],
    );
    expect(plans.map((plan) => plan.scheduledAt), [
      DateTime(2026, 10, 5, 18),
      DateTime(2026, 10, 6, 13),
      DateTime(2026, 10, 6, 15),
      DateTime(2026, 10, 6, 17),
    ]);
    expect(plans.last.channel, ReminderChannel.critical);
    expect(plans.map((plan) => plan.id).toSet().length, plans.length);
  });

  test('quiet-hours delay past deadline is omitted', () {
    final due = DateTime(2026, 10, 6, 7);
    final task = _task(due);
    final plans = ReminderPlanner.plan(
      task,
      const AppPreferences(defaultReminderOffsetsMinutes: [60]),
      DateTime(2026, 10, 5, 8),
      [task],
    );
    expect(plans, isEmpty);
  });

  test('terminal, disabled, and overdue tasks have no future plan', () {
    final due = DateTime(2026, 10, 6, 18);
    final task = _task(due);
    final now = DateTime(2026, 10, 5, 10);
    expect(
      ReminderPlanner.plan(task, const AppPreferences(), due, [task]),
      isEmpty,
    );
    expect(
      ReminderPlanner.plan(
        task,
        const AppPreferences(notificationsEnabled: false),
        now,
        [task],
      ),
      isEmpty,
    );
    expect(
      ReminderPlanner.plan(
        task.copyWith(status: TaskStatus.completed),
        const AppPreferences(),
        now,
        [task],
      ),
      isEmpty,
    );
  });
}
