import 'package:flutter/foundation.dart';

import '../core/app_failure.dart';
import '../data/local_settings_repository.dart';
import '../data/reminder_repository.dart';
import '../domain/local_data.dart';
import '../domain/ports.dart';
import '../domain/platform_reminder_coordinator.dart';
import '../domain/reminder_coordinator.dart';
import '../domain/risk_engine.dart';
import '../domain/task.dart';

enum TodoScope { all, today, threeDays, completed }

extension TodoScopeLabel on TodoScope {
  String get label => switch (this) {
    TodoScope.all => '全部',
    TodoScope.today => '今天',
    TodoScope.threeDays => '三天内',
    TodoScope.completed => '已完成',
  };
}

enum CopyTone { off, gentle, standard }

extension CopyToneLabel on CopyTone {
  String get label => switch (this) {
    CopyTone.off => '关闭',
    CopyTone.gentle => '温和',
    CopyTone.standard => '标准',
  };
}

class AppController extends ChangeNotifier {
  AppController(
    this._repository,
    this._installationStore, {
    ClockPort clock = const SystemClock(),
    PreferenceRepository? preferenceRepository,
    ProfileRepository? profileRepository,
    ReminderRepository? reminderRepository,
    NotificationPort? notificationPort,
  }) : _clock = clock,
       _preferenceRepository =
           preferenceRepository ?? InMemoryPreferenceRepository(),
       _profileRepository = profileRepository ?? InMemoryProfileRepository(),
       _notificationPort = notificationPort {
    _reminderRepository = reminderRepository ?? InMemoryReminderRepository();
    _reminderCoordinator = ReminderCoordinator(_reminderRepository);
    _platformReminderCoordinator = notificationPort == null
        ? null
        : PlatformReminderCoordinator(_reminderRepository, notificationPort);
  }

  final TaskRepository _repository;
  final InstallationStore _installationStore;
  final ClockPort _clock;
  final PreferenceRepository _preferenceRepository;
  final ProfileRepository _profileRepository;
  late final ReminderRepository _reminderRepository;
  late final ReminderCoordinator _reminderCoordinator;
  late final PlatformReminderCoordinator? _platformReminderCoordinator;
  final NotificationPort? _notificationPort;
  List<TaskItem> _tasks = const [];
  Map<TaskCategory, double> _missedRates = const {};
  DateTime? _firstLaunchDate;
  bool _loading = true;
  int _navigationIndex = 0;
  TaskQuadrant? _selectedQuadrant;
  TodoScope _todoScope = TodoScope.all;
  bool _notificationsEnabled = true;
  CopyTone _copyTone = CopyTone.standard;
  AppPreferences _preferences = const AppPreferences();
  UserProfile _profile = const UserProfile();
  String? _reminderSyncErrorCode;
  NotificationCapabilities? _notificationCapabilities;

  bool get loading => _loading;
  int get navigationIndex => _navigationIndex;
  TaskQuadrant? get selectedQuadrant => _selectedQuadrant;
  TodoScope get todoScope => _todoScope;
  bool get notificationsEnabled => _notificationsEnabled;
  CopyTone get copyTone => _copyTone;
  AppPreferences get preferences => _preferences;
  UserProfile get profile => _profile;
  String? get reminderSyncErrorCode => _reminderSyncErrorCode;
  NotificationCapabilities? get notificationCapabilities =>
      _notificationCapabilities;
  List<TaskItem> get tasks => List.unmodifiable(_tasks);

  RiskAssessment riskFor(TaskItem task) => RiskEngine.assess(
    task,
    now,
    _tasks,
    missedRate: _missedRates[task.category] ?? 0,
  );

  DateTime get now => _clock.now();

  int get survivalDays {
    final today = DateTime(now.year, now.month, now.day);
    final firstLaunch = _firstLaunchDate ?? today;
    final start = DateTime(
      firstLaunch.year,
      firstLaunch.month,
      firstLaunch.day,
    );
    final elapsedDays = today.difference(start).inDays + 1;
    return elapsedDays < 1 ? 1 : elapsedDays;
  }

  List<TaskItem> get activeTasks {
    final items = _tasks
        .where((task) => task.status == TaskStatus.active)
        .toList();
    items.sort((a, b) => riskFor(b).score.compareTo(riskFor(a).score));
    return items;
  }

  List<TaskItem> get overdueTasks =>
      _tasks.where((task) => task.status == TaskStatus.overdueReview).toList()
        ..sort((a, b) => a.dueAt.compareTo(b.dueAt));

  List<TaskItem> get completedTasks => _tasks
      .where(
        (task) =>
            task.status == TaskStatus.completed ||
            task.status == TaskStatus.completedLate,
      )
      .toList();

  int get pressureScore {
    final risks = [
      ...activeTasks.map((task) => riskFor(task).score),
      ...overdueTasks.map((_) => 75),
    ]..sort((a, b) => b.compareTo(a));
    if (risks.isEmpty) return 0;
    final top = risks.take(5).toList();
    final average = top.reduce((a, b) => a + b) / top.length;
    return (average + (activeTasks.length * 1.5)).round().clamp(0, 100);
  }

  String get pressureLabel => switch (pressureScore) {
    < 25 => '安全巡航',
    < 50 => '轻微冒烟',
    < 75 => '进入警戒',
    _ => '红色警报',
  };

  List<TaskItem> get filteredTodos {
    final current = now;
    Iterable<TaskItem> items = _tasks.where((task) {
      if (_todoScope == TodoScope.completed) return task.isDone;
      return task.status == TaskStatus.active;
    });

    if (_todoScope == TodoScope.today) {
      items = items.where((task) => _sameDay(task.dueAt, current));
    } else if (_todoScope == TodoScope.threeDays) {
      final limit = current.add(const Duration(days: 3));
      items = items.where((task) => task.dueAt.isBefore(limit));
    }

    if (_selectedQuadrant != null && _todoScope != TodoScope.completed) {
      items = items.where(
        (task) => riskFor(task).quadrant == _selectedQuadrant,
      );
    }

    final result = items.toList();
    result.sort((a, b) => riskFor(b).score.compareTo(riskFor(a).score));
    return result;
  }

  int quadrantCount(TaskQuadrant quadrant) =>
      activeTasks.where((task) => riskFor(task).quadrant == quadrant).length;

  int get rescuedCount => completedTasks.length * 12;
  int get defeatedCount => completedTasks.length;

  Future<void> load() async {
    final firstLaunchFuture = _installationStore.getOrCreateFirstLaunchDate();
    await _repository.reconcileOverdue(now);
    _tasks = await _repository.listTasks();
    _missedRates = await _repository.missedRatesByCategory();
    _firstLaunchDate = await firstLaunchFuture;
    _preferences = await _preferenceRepository.getOrCreate();
    _profile = await _profileRepository.getOrCreate();
    _notificationsEnabled = _preferences.notificationsEnabled;
    _copyTone = CopyTone.values.byName(_preferences.copyTone);
    await _reconcileReminderPlans();
    _loading = false;
    notifyListeners();
  }

  Future<int> refreshOverdue() async {
    final changed = await _repository.reconcileOverdue(now);
    await _reload();
    return changed;
  }

  void setNavigationIndex(int index) {
    _navigationIndex = index;
    notifyListeners();
  }

  void setQuadrant(TaskQuadrant? quadrant) {
    _selectedQuadrant = _selectedQuadrant == quadrant ? null : quadrant;
    notifyListeners();
  }

  void setTodoScope(TodoScope scope) {
    _todoScope = scope;
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    if (value && _notificationPort != null) {
      try {
        final capabilities = await _notificationPort.inspect();
        if (!capabilities.authorized) {
          await _notificationPort.requestPermission();
        }
      } catch (_) {
        // The user's local preference can still be saved when the platform
        // permission API is unavailable; reconciliation reports the failure.
      }
    }
    _preferences = await _preferenceRepository.save(
      _preferences.copyWith(notificationsEnabled: value),
    );
    _notificationsEnabled = _preferences.notificationsEnabled;
    await _reconcileReminderPlans();
    notifyListeners();
  }

  Future<void> requestExactReminderPermission() async {
    if (_notificationPort == null) return;
    await _notificationPort.requestExactPermission();
    await _reconcileReminderPlans(forceReschedule: true);
    notifyListeners();
  }

  Future<void> requestNotificationPermission() async {
    if (_notificationPort == null) return;
    await _notificationPort.requestPermission();
    await _reconcileReminderPlans();
    notifyListeners();
  }

  Future<void> openNotificationSettings() async {
    await _notificationPort?.openSettings();
  }

  Future<void> setCopyTone(CopyTone tone) async {
    _preferences = await _preferenceRepository.save(
      _preferences.copyWith(copyTone: tone.name),
    );
    _copyTone = tone;
    notifyListeners();
  }

  Future<void> setQuietHours(int startMinute, int endMinute) async {
    _preferences = await _preferenceRepository.save(
      _preferences.copyWith(
        quietHoursStartMinute: startMinute,
        quietHoursEndMinute: endMinute,
      ),
    );
    await _reconcileReminderPlans();
    notifyListeners();
  }

  Future<void> setDefaultReminderOffsets(List<int> offsets) async {
    _preferences = await _preferenceRepository.save(
      _preferences.copyWith(
        defaultReminderOffsetsMinutes: List.unmodifiable(offsets),
      ),
    );
    await _reconcileReminderPlans();
    notifyListeners();
  }

  Future<void> saveProfile(String nickname, String motto) async {
    _profile = await _profileRepository.save(
      _profile.copyWith(nickname: nickname, motto: motto),
    );
    notifyListeners();
  }

  Future<TaskItem> addTask(TaskDraft draft) async {
    final created = await _repository.createTask(draft);
    await _repository.reconcileOverdue(now);
    await _reload();
    return _tasks.firstWhere((task) => task.id == created.id);
  }

  Future<TaskItem> updateTask(TaskItem task) async {
    final updated = await _repository.updateTask(task);
    await _repository.reconcileOverdue(now);
    await _reload();
    return _tasks.firstWhere((item) => item.id == updated.id);
  }

  Future<bool> completeTask(String id) async {
    await _repository.reconcileOverdue(now);
    final current = await _repository.getTask(id);
    if (current == null) {
      throw const AppFailure(
        code: 'TASK_NOT_FOUND',
        message: 'Task does not exist.',
      );
    }
    if (current.status == TaskStatus.overdueReview) {
      await _reload();
      return false;
    }
    final completed = await _repository.transitionTask(
      id,
      TaskStatus.completed,
    );
    await _reload();
    return completed.status == TaskStatus.completed;
  }

  Future<void> completeLate(String id) async {
    await _repository.transitionTask(id, TaskStatus.completedLate);
    await _reload();
  }

  Future<void> markMissed(String id) async {
    await _repository.transitionTask(id, TaskStatus.missed);
    await _reload();
  }

  Future<void> archiveTask(String id) async {
    await _repository.transitionTask(id, TaskStatus.archived);
    await _reload();
  }

  Future<bool> deleteTask(String id) async {
    final hasHistory = await _repository.hasMeaningfulHistory(id);
    if (hasHistory) {
      await _repository.transitionTask(id, TaskStatus.archived);
    } else {
      await _repository.deleteTask(id);
    }
    await _reload();
    return hasHistory;
  }

  Future<bool> hasMeaningfulHistory(String id) =>
      _repository.hasMeaningfulHistory(id);

  Future<void> _reload() async {
    _tasks = await _repository.listTasks();
    _missedRates = await _repository.missedRatesByCategory();
    await _reconcileReminderPlans();
    notifyListeners();
  }

  Future<void> _reconcileReminderPlans({bool forceReschedule = false}) async {
    try {
      if (_notificationPort != null) {
        final timezone = await _notificationPort.deviceTimezone();
        if (timezone != _preferences.timezone) {
          _preferences = await _preferenceRepository.save(
            _preferences.copyWith(timezone: timezone),
          );
          forceReschedule = true;
        }
      }
      await _reminderCoordinator.reconcile(
        _tasks,
        _preferences,
        now,
        missedRates: _missedRates,
      );
      final platform = await _platformReminderCoordinator?.reconcile(
        _tasks,
        _preferences,
        now,
        forceReschedule: forceReschedule,
        previousCapabilities: _notificationCapabilities,
      );
      _notificationCapabilities = platform?.capabilities;
      _reminderSyncErrorCode = platform?.errorCode;
    } on AppFailure catch (failure) {
      _reminderSyncErrorCode = failure.code;
    } catch (_) {
      _reminderSyncErrorCode = 'DATABASE_UNAVAILABLE';
    }
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
