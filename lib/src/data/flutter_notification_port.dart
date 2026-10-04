import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/local_data.dart';
import '../domain/ports.dart';

class FlutterNotificationPort implements NotificationPort {
  FlutterNotificationPort({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<String> _selectedTasks =
      StreamController<String>.broadcast();
  String? _initialTaskId;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    timezone_data.initializeTimeZones();
    await deviceTimezone();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final taskId = response.payload;
        if (taskId != null && taskId.isNotEmpty) {
          _selectedTasks.add(taskId);
        }
      },
    );
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          'ddl_critical',
          'DDL 紧急提醒',
          description: '临近截止时间的高风险任务提醒',
          importance: Importance.high,
        ),
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          'ddl_normal',
          'DDL 普通提醒',
          description: '提前安排任务的普通提醒',
          importance: Importance.defaultImportance,
        ),
      );
    }
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      final payload = launch?.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) _initialTaskId = payload;
    }
    _initialized = true;
  }

  @override
  Future<NotificationCapabilities> inspect() async {
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return NotificationCapabilities(
        authorized: await android?.areNotificationsEnabled() ?? false,
        exact: await android?.canScheduleExactNotifications() ?? false,
        exactPermissionRequired: true,
        pendingLimit: 120,
      );
    }
    if (Platform.isIOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final permissions = await ios?.checkPermissions();
      return NotificationCapabilities(
        authorized: permissions?.isEnabled ?? false,
        exact: true,
        exactPermissionRequired: false,
        pendingLimit: 60,
      );
    }
    return const NotificationCapabilities(
      authorized: false,
      exact: false,
      exactPermissionRequired: false,
      pendingLimit: 0,
    );
  }

  @override
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? false;
    }
    if (Platform.isIOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  @override
  Future<bool> requestExactPermission() async {
    if (!Platform.isAndroid) return true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestExactAlarmsPermission() ?? false;
  }

  @override
  Future<bool> openSettings() async =>
      await _plugin.openAppNotificationSettings() ?? false;

  @override
  Future<String> deviceTimezone() async {
    final info = await FlutterTimezone.getLocalTimezone();
    try {
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
    return tz.local.name;
  }

  @override
  Future<Set<int>> pendingIds() async =>
      (await _plugin.pendingNotificationRequests())
          .map((request) => request.id)
          .toSet();

  @override
  Future<void> schedule({
    required int id,
    required DateTime fireAt,
    required ReminderChannel channel,
    required String taskId,
    required bool exact,
  }) async {
    final critical = channel == ReminderChannel.critical;
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          critical ? 'ddl_critical' : 'ddl_normal',
          critical ? 'DDL 紧急提醒' : 'DDL 普通提醒',
          channelDescription: critical ? '临近截止时间的高风险任务提醒' : '提前安排任务的普通提醒',
          importance: critical ? Importance.high : Importance.defaultImportance,
          priority: critical ? Priority.high : Priority.defaultPriority,
          visibility: NotificationVisibility.private,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      title: critical ? 'DDL 紧急提醒' : 'DDL 提醒',
      body: '有一项任务即将截止，点按查看详情。',
      payload: taskId,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Stream<String> get selectedTaskIds => _selectedTasks.stream;

  @override
  String? takeInitialTaskId() {
    final value = _initialTaskId;
    _initialTaskId = null;
    return value;
  }

  Future<void> dispose() => _selectedTasks.close();
}
