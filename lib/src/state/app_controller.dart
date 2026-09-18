import 'package:flutter/foundation.dart';

import '../domain/ports.dart';
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
  AppController(this._repository, this._installationStore);

  final TaskRepository _repository;
  final InstallationStore _installationStore;
  List<TaskItem> _tasks = const [];
  DateTime? _firstLaunchDate;
  bool _loading = true;
  int _navigationIndex = 0;
  TaskQuadrant? _selectedQuadrant;
  TodoScope _todoScope = TodoScope.all;
  bool _notificationsEnabled = true;
  CopyTone _copyTone = CopyTone.standard;

  bool get loading => _loading;
  int get navigationIndex => _navigationIndex;
  TaskQuadrant? get selectedQuadrant => _selectedQuadrant;
  TodoScope get todoScope => _todoScope;
  bool get notificationsEnabled => _notificationsEnabled;
  CopyTone get copyTone => _copyTone;
  List<TaskItem> get tasks => List.unmodifiable(_tasks);

  DateTime get now => DateTime.now();

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
    items.sort((a, b) => b.riskScoreAt(now).compareTo(a.riskScoreAt(now)));
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
      ...activeTasks.map((task) => task.riskScoreAt(now)),
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
        (task) => task.quadrantAt(current) == _selectedQuadrant,
      );
    }

    final result = items.toList();
    result.sort(
      (a, b) => b.riskScoreAt(current).compareTo(a.riskScoreAt(current)),
    );
    return result;
  }

  int quadrantCount(TaskQuadrant quadrant) =>
      activeTasks.where((task) => task.quadrantAt(now) == quadrant).length;

  int get rescuedCount => completedTasks.length * 12;
  int get defeatedCount => completedTasks.length;

  Future<void> load() async {
    final tasksFuture = _repository.listTasks();
    final firstLaunchFuture = _installationStore.getOrCreateFirstLaunchDate();
    _tasks = await tasksFuture;
    _firstLaunchDate = await firstLaunchFuture;
    _loading = false;
    notifyListeners();
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

  void setNotificationsEnabled(bool value) {
    _notificationsEnabled = value;
    notifyListeners();
  }

  void setCopyTone(CopyTone tone) {
    _copyTone = tone;
    notifyListeners();
  }

  Future<TaskItem> addTask(TaskDraft draft) async {
    final created = await _repository.createTask(draft);
    await _reload();
    return created;
  }

  Future<void> completeTask(String id) async {
    await _repository.transitionTask(id, TaskStatus.completed);
    await _reload();
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

  Future<void> deleteTask(String id) async {
    await _repository.deleteTask(id);
    await _reload();
  }

  Future<void> _reload() async {
    _tasks = await _repository.listTasks();
    notifyListeners();
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
