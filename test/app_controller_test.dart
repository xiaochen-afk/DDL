import 'package:ddl_survival/src/data/in_memory_task_repository.dart';
import 'package:ddl_survival/src/data/installation_store.dart';
import 'package:ddl_survival/src/domain/task.dart';
import 'package:ddl_survival/src/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('task lifecycle updates controller projections', () async {
    final controller = AppController(
      InMemoryTaskRepository(),
      InMemoryInstallationStore(),
    );
    await controller.load();
    final initialCount = controller.activeTasks.length;

    final created = await controller.addTask(
      TaskDraft(
        title: '控制器测试任务',
        dueAt: DateTime.now().add(const Duration(days: 2)),
        category: TaskCategory.work,
        isImportant: true,
        estimatedMinutes: 60,
      ),
    );

    expect(controller.activeTasks.length, initialCount + 1);
    await controller.completeTask(created.id);
    expect(
      controller.completedTasks.any((task) => task.id == created.id),
      isTrue,
    );
  });

  test('survival days start at one and increase by calendar day', () async {
    final today = DateTime.now();
    final controller = AppController(
      InMemoryTaskRepository(),
      InMemoryInstallationStore(
        firstLaunchDate: DateTime(
          today.year,
          today.month,
          today.day,
        ).subtract(const Duration(days: 2)),
      ),
    );

    await controller.load();

    expect(controller.survivalDays, 3);
    expect(controller.tasks, isEmpty);
    expect(controller.pressureScore, 0);
    expect(controller.defeatedCount, 0);
  });
}
