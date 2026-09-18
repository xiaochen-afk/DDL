import 'package:shared_preferences/shared_preferences.dart';

import '../domain/ports.dart';

class SharedPreferencesInstallationStore implements InstallationStore {
  static const _firstLaunchDateKey = 'installation.first_launch_date';

  @override
  Future<DateTime> getOrCreateFirstLaunchDate() async {
    final preferences = await SharedPreferences.getInstance();
    final storedValue = preferences.getString(_firstLaunchDateKey);
    final storedDate = storedValue == null
        ? null
        : DateTime.tryParse(storedValue);
    if (storedDate != null) return _dateOnly(storedDate);

    final today = _dateOnly(DateTime.now());
    await preferences.setString(_firstLaunchDateKey, today.toIso8601String());
    return today;
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}

class InMemoryInstallationStore implements InstallationStore {
  InMemoryInstallationStore({DateTime? firstLaunchDate})
    : _firstLaunchDate = firstLaunchDate;

  DateTime? _firstLaunchDate;

  @override
  Future<DateTime> getOrCreateFirstLaunchDate() async {
    final current = _firstLaunchDate;
    if (current != null) return current;
    final now = DateTime.now();
    return _firstLaunchDate = DateTime(now.year, now.month, now.day);
  }
}
