import 'task.dart';

class RiskReason {
  const RiskReason(this.code, this.points, this.description);

  final String code;
  final int points;
  final String description;
}

class RiskAssessment {
  const RiskAssessment({
    required this.score,
    required this.level,
    required this.reasons,
    required this.quadrant,
    required this.urgent,
    required this.nextRecomputeAt,
  });

  final int score;
  final String level;
  final List<RiskReason> reasons;
  final TaskQuadrant quadrant;
  final bool urgent;
  final DateTime? nextRecomputeAt;
}

class RiskEngine {
  const RiskEngine._();

  static RiskAssessment assess(
    TaskItem task,
    DateTime now,
    Iterable<TaskItem> allTasks, {
    double missedRate = 0,
  }) {
    final competingMinutes = allTasks
        .where(
          (other) =>
              other.id != task.id &&
              other.status == TaskStatus.active &&
              !other.dueAt.isBefore(now) &&
              !other.dueAt.isAfter(task.dueAt) &&
              task.dueAt.difference(other.dueAt) <= const Duration(hours: 24),
        )
        .fold<int>(0, (sum, other) => sum + other.estimatedMinutes);
    final urgent =
        task.isUrgent(now) ||
        task.estimatedMinutes + competingMinutes >=
            task.dueAt.difference(now).inMinutes;
    final quadrant = switch ((urgent, task.isImportant)) {
      (true, true) => TaskQuadrant.urgentImportant,
      (false, true) => TaskQuadrant.planned,
      (true, false) => TaskQuadrant.quickWin,
      (false, false) => TaskQuadrant.later,
    };
    if (task.status != TaskStatus.active &&
        task.status != TaskStatus.overdueReview) {
      return RiskAssessment(
        score: 0,
        level: '安全',
        reasons: const [],
        quadrant: quadrant,
        urgent: urgent,
        nextRecomputeAt: null,
      );
    }

    final minutesLeft = task.dueAt.difference(now).inMinutes;
    final time = switch (minutesLeft) {
      <= 0 => 45,
      <= 60 => 42,
      <= 180 => 36,
      <= 720 => 29,
      <= 1440 => 22,
      <= 4320 => 13,
      _ => 5,
    };
    final importance = task.isImportant ? 20 : 0;
    final workload =
        (task.estimatedMinutes / (minutesLeft <= 0 ? 1 : minutesLeft) * 30)
            .clamp(0, 15)
            .round();
    final nearby = allTasks.where((other) {
      if (other.id == task.id || other.status != TaskStatus.active) {
        return false;
      }
      return other.dueAt.difference(task.dueAt).abs() <=
          const Duration(hours: 24);
    }).length;
    final density = (nearby * 2).clamp(0, 10);
    final history = (missedRate.clamp(0, 1) * 10).round();
    final score = (time + importance + workload + density + history).clamp(
      0,
      100,
    );
    final level = switch (score) {
      < 25 => '安全',
      < 50 => '注意',
      < 75 => '危险',
      _ => '极高',
    };
    final nextMinute = DateTime.fromMillisecondsSinceEpoch(
      (now.millisecondsSinceEpoch ~/ 60000 + 1) * 60000,
    );
    final boundaries = <DateTime>[
      nextMinute,
      task.dueAt.subtract(Duration(minutes: task.estimatedMinutes + 60)),
      for (final minutes in [4320, 1440, 720, 180, 60, 0])
        task.dueAt.subtract(Duration(minutes: minutes)),
    ]..removeWhere((value) => !value.isAfter(now));
    boundaries.sort();
    return RiskAssessment(
      score: score,
      level: level,
      quadrant: quadrant,
      urgent: urgent,
      nextRecomputeAt: boundaries.firstOrNull,
      reasons: [
        RiskReason('TIME_PRESSURE', time, '距离截止约 $minutesLeft 分钟'),
        RiskReason(
          'IMPORTANCE',
          importance,
          task.isImportant ? '标记为重要' : '普通任务',
        ),
        RiskReason('WORKLOAD', workload, '预计耗时 ${task.estimatedMinutes} 分钟'),
        RiskReason('DDL_DENSITY', density, '前后 24 小时还有 $nearby 个进行中任务'),
        RiskReason(
          'CATEGORY_HISTORY',
          history,
          '同类任务历史错过率 ${(missedRate * 100).round()}%',
        ),
      ],
    );
  }
}
