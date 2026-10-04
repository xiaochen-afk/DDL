class AppPreferences {
  const AppPreferences({
    this.copyTone = 'standard',
    this.notificationsEnabled = true,
    this.quietHoursStartMinute = 23 * 60,
    this.quietHoursEndMinute = 7 * 60 + 30,
    this.defaultReminderOffsetsMinutes = const [1440, 180],
    this.urgentThresholdMinutes = 60,
    this.bufferMinutes = 60,
    this.timezone = 'Asia/Shanghai',
    this.updatedAt,
  });

  final String copyTone;
  final bool notificationsEnabled;
  final int quietHoursStartMinute;
  final int quietHoursEndMinute;
  final List<int> defaultReminderOffsetsMinutes;
  final int urgentThresholdMinutes;
  final int bufferMinutes;
  final String timezone;
  final DateTime? updatedAt;

  AppPreferences copyWith({
    String? copyTone,
    bool? notificationsEnabled,
    int? quietHoursStartMinute,
    int? quietHoursEndMinute,
    List<int>? defaultReminderOffsetsMinutes,
    int? urgentThresholdMinutes,
    int? bufferMinutes,
    String? timezone,
    DateTime? updatedAt,
  }) => AppPreferences(
    copyTone: copyTone ?? this.copyTone,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    quietHoursStartMinute: quietHoursStartMinute ?? this.quietHoursStartMinute,
    quietHoursEndMinute: quietHoursEndMinute ?? this.quietHoursEndMinute,
    defaultReminderOffsetsMinutes:
        defaultReminderOffsetsMinutes ?? this.defaultReminderOffsetsMinutes,
    urgentThresholdMinutes:
        urgentThresholdMinutes ?? this.urgentThresholdMinutes,
    bufferMinutes: bufferMinutes ?? this.bufferMinutes,
    timezone: timezone ?? this.timezone,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

class UserProfile {
  const UserProfile({
    this.nickname = 'DDL 幸存者',
    this.motto = '今天也在努力把事情做完。',
    this.avatarUri,
    this.createdAt,
    this.updatedAt,
  });

  final String nickname;
  final String motto;
  final String? avatarUri;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserProfile copyWith({
    String? nickname,
    String? motto,
    String? avatarUri,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => UserProfile(
    nickname: nickname ?? this.nickname,
    motto: motto ?? this.motto,
    avatarUri: avatarUri ?? this.avatarUri,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

enum ReminderChannel { critical, normal }

enum ReminderStatus { pending, scheduled, scheduleFailed, cancelled, fired }

class ReminderRecord {
  const ReminderRecord({
    required this.id,
    required this.taskId,
    required this.scheduledAt,
    required this.channel,
    required this.status,
    this.platformNotificationId,
    this.lastErrorCode,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String taskId;
  final DateTime scheduledAt;
  final ReminderChannel channel;
  final ReminderStatus status;
  final String? platformNotificationId;
  final String? lastErrorCode;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ReminderRecord copyWith({
    ReminderStatus? status,
    String? platformNotificationId,
    String? lastErrorCode,
    DateTime? updatedAt,
  }) => ReminderRecord(
    id: id,
    taskId: taskId,
    scheduledAt: scheduledAt,
    channel: channel,
    status: status ?? this.status,
    platformNotificationId:
        platformNotificationId ?? this.platformNotificationId,
    lastErrorCode: lastErrorCode ?? this.lastErrorCode,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
