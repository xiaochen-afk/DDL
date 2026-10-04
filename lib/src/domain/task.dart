const int taskTitleMaxLength = 80;
const int taskNotesMaxLength = 1000;

enum TaskCategory { study, work, life, fun }

extension TaskCategoryLabel on TaskCategory {
  String get label => switch (this) {
    TaskCategory.study => '学习',
    TaskCategory.work => '工作',
    TaskCategory.life => '生活',
    TaskCategory.fun => '娱乐',
  };
}

enum TaskStatus {
  active,
  completed,
  overdueReview,
  missed,
  completedLate,
  archived,
}

enum TaskQuadrant { urgentImportant, planned, quickWin, later }

extension TaskQuadrantLabel on TaskQuadrant {
  String get title => switch (this) {
    TaskQuadrant.urgentImportant => '立刻做',
    TaskQuadrant.planned => '计划做',
    TaskQuadrant.quickWin => '快速处理',
    TaskQuadrant.later => '可以缓缓',
  };

  String get subtitle => switch (this) {
    TaskQuadrant.urgentImportant => '紧急且重要',
    TaskQuadrant.planned => '重要但不紧急',
    TaskQuadrant.quickWin => '紧急但不重要',
    TaskQuadrant.later => '不重要且不紧急',
  };
}

class TaskDraft {
  const TaskDraft({
    required this.title,
    required this.dueAt,
    required this.category,
    required this.isImportant,
    required this.estimatedMinutes,
    this.notes = '',
  });

  final String title;
  final DateTime dueAt;
  final TaskCategory category;
  final bool isImportant;
  final int estimatedMinutes;
  final String notes;
}

class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.dueAt,
    required this.category,
    required this.isImportant,
    required this.estimatedMinutes,
    required this.status,
    required this.createdAt,
    DateTime? updatedAt,
    this.version = 1,
    this.notes = '',
    this.completedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  final String id;
  final String title;
  final DateTime dueAt;
  final TaskCategory category;
  final bool isImportant;
  final int estimatedMinutes;
  final TaskStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final String notes;
  final DateTime? completedAt;

  bool get isDone =>
      status == TaskStatus.completed || status == TaskStatus.completedLate;

  bool get isVisibleTodo =>
      status == TaskStatus.active || status == TaskStatus.completed;

  bool isUrgent(DateTime now) {
    final latestStart = dueAt.subtract(
      Duration(minutes: estimatedMinutes + 60),
    );
    return !now.isBefore(latestStart);
  }

  TaskQuadrant quadrantAt(DateTime now) {
    final urgent = isUrgent(now);
    if (urgent && isImportant) return TaskQuadrant.urgentImportant;
    if (!urgent && isImportant) return TaskQuadrant.planned;
    if (urgent && !isImportant) return TaskQuadrant.quickWin;
    return TaskQuadrant.later;
  }

  TaskItem copyWith({
    String? title,
    DateTime? dueAt,
    TaskCategory? category,
    bool? isImportant,
    int? estimatedMinutes,
    TaskStatus? status,
    String? notes,
    DateTime? completedAt,
    DateTime? updatedAt,
    int? version,
  }) {
    return TaskItem(
      id: id,
      title: title ?? this.title,
      dueAt: dueAt ?? this.dueAt,
      category: category ?? this.category,
      isImportant: isImportant ?? this.isImportant,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      notes: notes ?? this.notes,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
