import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../core/app_failure.dart';
import '../domain/local_data.dart';
import '../domain/ports.dart';
import 'database/app_database.dart';

void validatePreferences(AppPreferences value) {
  final offsets = value.defaultReminderOffsetsMinutes;
  if (!['off', 'gentle', 'standard'].contains(value.copyTone) ||
      value.quietHoursStartMinute < 0 ||
      value.quietHoursStartMinute >= 1440 ||
      value.quietHoursEndMinute < 0 ||
      value.quietHoursEndMinute >= 1440 ||
      offsets.isEmpty ||
      offsets.any((offset) => offset <= 0 || offset > 525600) ||
      offsets.toSet().length != offsets.length ||
      value.urgentThresholdMinutes < 1 ||
      value.urgentThresholdMinutes > 10080 ||
      value.bufferMinutes < 0 ||
      value.bufferMinutes > 10080 ||
      !RegExp(
        r'^(?:UTC|[A-Za-z0-9_+.-]+(?:/[A-Za-z0-9_+.-]+)+)$',
      ).hasMatch(value.timezone)) {
    throw const AppFailure(
      code: 'VALIDATION_FAILED',
      message: 'Preference fields are invalid.',
    );
  }
}

void validateProfile(UserProfile value) {
  if (value.nickname.trim().isEmpty ||
      value.nickname.trim().length > 40 ||
      value.motto.trim().length > 140) {
    throw const AppFailure(
      code: 'VALIDATION_FAILED',
      message: 'Profile fields are invalid.',
    );
  }
}

class SqlitePreferenceRepository implements PreferenceRepository {
  SqlitePreferenceRepository(
    this._database, {
    ClockPort clock = const SystemClock(),
  }) : _clock = clock;

  final AppDatabase _database;
  final ClockPort _clock;

  @override
  Future<AppPreferences> getOrCreate() => _guard(() async {
    final db = await _database.database;
    return db.transaction((tx) async {
      final rows = await tx.query('preferences', where: 'id = 1', limit: 1);
      if (rows.isNotEmpty) return _fromRow(rows.first);
      final created = const AppPreferences().copyWith(
        updatedAt: _storageNow(_clock),
      );
      await tx.insert('preferences', _toRow(created));
      return created;
    });
  });

  @override
  Future<AppPreferences> save(AppPreferences preferences) {
    validatePreferences(preferences);
    return _guard(() async {
      final db = await _database.database;
      final saved = preferences.copyWith(updatedAt: _storageNow(_clock));
      await db.transaction((tx) async {
        await tx.insert(
          'preferences',
          _toRow(saved),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });
      return saved;
    });
  }

  static Map<String, Object?> _toRow(AppPreferences value) => {
    'id': 1,
    'copy_tone': value.copyTone,
    'notifications_enabled': value.notificationsEnabled ? 1 : 0,
    'quiet_hours_start': _formatMinute(value.quietHoursStartMinute),
    'quiet_hours_end': _formatMinute(value.quietHoursEndMinute),
    'default_reminder_offsets_json': jsonEncode(
      value.defaultReminderOffsetsMinutes,
    ),
    'urgent_threshold_minutes': value.urgentThresholdMinutes,
    'buffer_minutes': value.bufferMinutes,
    'timezone': value.timezone,
    'updated_at': value.updatedAt!.toUtc().millisecondsSinceEpoch,
  };

  static AppPreferences _fromRow(Map<String, Object?> row) => AppPreferences(
    copyTone: row['copy_tone']! as String,
    notificationsEnabled: row['notifications_enabled'] == 1,
    quietHoursStartMinute: _parseMinute(row['quiet_hours_start']! as String),
    quietHoursEndMinute: _parseMinute(row['quiet_hours_end']! as String),
    defaultReminderOffsetsMinutes: List<int>.unmodifiable(
      (jsonDecode(row['default_reminder_offsets_json']! as String) as List)
          .cast<int>(),
    ),
    urgentThresholdMinutes: row['urgent_threshold_minutes']! as int,
    bufferMinutes: row['buffer_minutes']! as int,
    timezone: row['timezone']! as String,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      row['updated_at']! as int,
      isUtc: true,
    ).toLocal(),
  );

  static String _formatMinute(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

  static int _parseMinute(String value) {
    final parts = value.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}

class SqliteProfileRepository implements ProfileRepository {
  SqliteProfileRepository(
    this._database, {
    ClockPort clock = const SystemClock(),
  }) : _clock = clock;

  final AppDatabase _database;
  final ClockPort _clock;

  @override
  Future<UserProfile> getOrCreate() => _guard(() async {
    final db = await _database.database;
    return db.transaction((tx) async {
      final rows = await tx.query('profile', where: 'id = 1', limit: 1);
      if (rows.isNotEmpty) return _fromRow(rows.first);
      final now = _storageNow(_clock);
      final created = const UserProfile().copyWith(
        createdAt: now,
        updatedAt: now,
      );
      await tx.insert('profile', _toRow(created));
      return created;
    });
  });

  @override
  Future<UserProfile> save(UserProfile profile) {
    validateProfile(profile);
    return _guard(() async {
      final db = await _database.database;
      final now = _storageNow(_clock);
      return db.transaction((tx) async {
        final rows = await tx.query('profile', where: 'id = 1', limit: 1);
        final createdAt = rows.isEmpty
            ? now
            : DateTime.fromMillisecondsSinceEpoch(
                rows.first['created_at']! as int,
                isUtc: true,
              ).toLocal();
        final saved = profile.copyWith(
          nickname: profile.nickname.trim(),
          motto: profile.motto.trim(),
          createdAt: createdAt,
          updatedAt: now,
        );
        await tx.insert(
          'profile',
          _toRow(saved),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return saved;
      });
    });
  }

  static Map<String, Object?> _toRow(UserProfile value) => {
    'id': 1,
    'nickname': value.nickname,
    'motto': value.motto,
    'avatar_uri': value.avatarUri,
    'created_at': value.createdAt!.toUtc().millisecondsSinceEpoch,
    'updated_at': value.updatedAt!.toUtc().millisecondsSinceEpoch,
  };

  static UserProfile _fromRow(Map<String, Object?> row) => UserProfile(
    nickname: row['nickname']! as String,
    motto: row['motto']! as String,
    avatarUri: row['avatar_uri'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      row['created_at']! as int,
      isUtc: true,
    ).toLocal(),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      row['updated_at']! as int,
      isUtc: true,
    ).toLocal(),
  );
}

Future<T> _guard<T>(Future<T> Function() operation) async {
  try {
    return await operation();
  } on AppFailure {
    rethrow;
  } catch (error) {
    final text = error.toString().toLowerCase();
    throw AppFailure(
      code:
          text.contains('database or disk is full') ||
              text.contains('sqlite_full')
          ? 'STORAGE_FULL'
          : 'DATABASE_UNAVAILABLE',
      message: 'The local database operation failed.',
      cause: error,
    );
  }
}

DateTime _storageNow(ClockPort clock) =>
    DateTime.fromMillisecondsSinceEpoch(clock.now().millisecondsSinceEpoch);

class InMemoryPreferenceRepository implements PreferenceRepository {
  AppPreferences? _value;

  @override
  Future<AppPreferences> getOrCreate() async =>
      _value ??= const AppPreferences();

  @override
  Future<AppPreferences> save(AppPreferences preferences) async {
    validatePreferences(preferences);
    return _value = preferences;
  }
}

class InMemoryProfileRepository implements ProfileRepository {
  UserProfile? _value;

  @override
  Future<UserProfile> getOrCreate() async => _value ??= const UserProfile();

  @override
  Future<UserProfile> save(UserProfile profile) async {
    validateProfile(profile);
    return _value = profile.copyWith(
      nickname: profile.nickname.trim(),
      motto: profile.motto.trim(),
    );
  }
}
