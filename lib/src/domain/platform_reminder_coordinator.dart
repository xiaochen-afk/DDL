import 'dart:convert';

import 'local_data.dart';
import 'ports.dart';
import 'task.dart';

class PlatformSyncResult {
  const PlatformSyncResult(this.capabilities, {this.errorCode});

  final NotificationCapabilities capabilities;
  final String? errorCode;
}

/// Repairs device pending notifications from the committed SQLite plan.
class PlatformReminderCoordinator {
  const PlatformReminderCoordinator(this._reminders, this._notifications);

  final ReminderRepository _reminders;
  final NotificationPort _notifications;

  Future<PlatformSyncResult> reconcile(
    Iterable<TaskItem> tasks,
    AppPreferences preferences,
    DateTime now, {
    bool forceReschedule = false,
    NotificationCapabilities? previousCapabilities,
  }) async {
    final capabilities = await _notifications.inspect();
    forceReschedule =
        forceReschedule ||
        (previousCapabilities != null &&
            previousCapabilities.exact != capabilities.exact);
    final taskById = {for (final task in tasks) task.id: task};
    final outstanding = await _reminders.listOutstanding();
    final future = outstanding.where((record) {
      final task = taskById[record.taskId];
      return task?.status == TaskStatus.active &&
          record.scheduledAt.isAfter(now);
    }).toList()..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final desired = preferences.notificationsEnabled && capabilities.authorized
        ? future.take(capabilities.pendingLimit).toList()
        : <ReminderRecord>[];
    final ids = <int, ReminderRecord>{};
    String? errorCode;
    for (final record in desired) {
      final id = platformNotificationIdFor(record.id);
      if (ids.containsKey(id) && ids[id]!.id != record.id) {
        await _reminders.updateStatus(
          record.id,
          ReminderStatus.scheduleFailed,
          lastErrorCode: 'NOTIFICATION_ID_COLLISION',
        );
        errorCode = 'NOTIFICATION_ID_COLLISION';
      } else {
        ids[id] = record;
      }
    }

    final pending = await _notifications.pendingIds();
    for (final id in pending) {
      if (forceReschedule || !ids.containsKey(id)) {
        await _notifications.cancel(id);
      }
    }
    final effectivePending = forceReschedule ? <int>{} : pending;

    if (!capabilities.authorized && preferences.notificationsEnabled) {
      for (final record in future) {
        await _reminders.updateStatus(
          record.id,
          ReminderStatus.scheduleFailed,
          lastErrorCode: 'NOTIFICATION_PERMISSION_DENIED',
        );
      }
      return PlatformSyncResult(capabilities);
    }
    if (!preferences.notificationsEnabled) {
      return PlatformSyncResult(capabilities);
    }
    for (final entry in ids.entries) {
      final id = entry.key;
      final record = entry.value;
      if (effectivePending.contains(id)) {
        if (record.status != ReminderStatus.scheduled ||
            record.platformNotificationId != '$id') {
          await _reminders.updateStatus(
            record.id,
            ReminderStatus.scheduled,
            platformNotificationId: '$id',
          );
        }
        continue;
      }
      try {
        await _notifications.schedule(
          id: id,
          fireAt: record.scheduledAt,
          channel: record.channel,
          taskId: record.taskId,
          exact: capabilities.exact,
        );
      } catch (_) {
        await _reminders.updateStatus(
          record.id,
          ReminderStatus.scheduleFailed,
          lastErrorCode: 'NOTIFICATION_SCHEDULE_FAILED',
        );
        errorCode = 'NOTIFICATION_SCHEDULE_FAILED';
        continue;
      }
      await _reminders.updateStatus(
        record.id,
        ReminderStatus.scheduled,
        platformNotificationId: '$id',
      );
    }
    return PlatformSyncResult(capabilities, errorCode: errorCode);
  }
}

int platformNotificationIdFor(String businessId) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(businessId)) {
    hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}
