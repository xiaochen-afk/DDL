import 'package:ddl_survival/src/domain/risk_engine.dart';
import 'package:ddl_survival/src/domain/task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 3, 8);

  TaskItem task(
    String id,
    DateTime dueAt, {
    TaskStatus status = TaskStatus.active,
  }) => TaskItem(
    id: id,
    title: id,
    dueAt: dueAt,
    category: TaskCategory.study,
    isImportant: true,
    estimatedMinutes: 60,
    status: status,
    createdAt: now,
  );

  test('risk breakdown sums to score and includes density and history', () {
    final target = task('a', now.add(const Duration(hours: 2)));
    final neighbor = task('b', now.add(const Duration(hours: 3)));
    final result = RiskEngine.assess(target, now, [
      target,
      neighbor,
    ], missedRate: 0.5);
    expect(
      result.score,
      result.reasons.fold<int>(0, (sum, reason) => sum + reason.points),
    );
    expect(result.reasons.map((reason) => reason.code), [
      'TIME_PRESSURE',
      'IMPORTANCE',
      'WORKLOAD',
      'DDL_DENSITY',
      'CATEGORY_HISTORY',
    ]);
    expect(result.reasons[3].points, 2);
    expect(result.reasons[4].points, 5);
    expect(result.nextRecomputeAt, isNotNull);
    expect(result.score, inInclusiveRange(0, 100));
  });

  test('settled task contributes no current risk', () {
    final completed = task('done', now, status: TaskStatus.completed);
    expect(RiskEngine.assess(completed, now, [completed]).score, 0);
  });

  test('competing work can make a planned task urgent', () {
    final target = TaskItem(
      id: 'target',
      title: 'target',
      dueAt: now.add(const Duration(hours: 4)),
      category: TaskCategory.work,
      isImportant: true,
      estimatedMinutes: 30,
      status: TaskStatus.active,
      createdAt: now,
    );
    final neighbor = TaskItem(
      id: 'neighbor',
      title: 'neighbor',
      dueAt: now.add(const Duration(hours: 3)),
      category: TaskCategory.work,
      isImportant: false,
      estimatedMinutes: 240,
      status: TaskStatus.active,
      createdAt: now,
    );
    expect(target.quadrantAt(now), TaskQuadrant.planned);
    expect(
      RiskEngine.assess(target, now, [target, neighbor]).quadrant,
      TaskQuadrant.urgentImportant,
    );
  });
}
