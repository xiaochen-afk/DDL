import 'package:ddl_survival/src/app.dart';
import 'package:ddl_survival/src/data/in_memory_task_repository.dart';
import 'package:ddl_survival/src/data/installation_store.dart';
import 'package:ddl_survival/src/domain/task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('can navigate and create a task', (tester) async {
    await tester.pumpWidget(
      DdlSurvivalApp(
        repository: InMemoryTaskRepository(),
        installationStore: InMemoryInstallationStore(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('生存第 1 天'), findsOneWidget);
    expect(find.text('今天没有警报'), findsOneWidget);
    expect(find.text('最近的雷区'), findsOneWidget);

    await tester.tap(find.text('待办'));
    await tester.pumpAndSettle();
    expect(find.text('四象限作战图'), findsOneWidget);

    await tester.tap(find.widgetWithText(FloatingActionButton, '新任务'));
    await tester.pumpAndSettle();
    expect(find.text('签下生死状'), findsWidgets);

    await tester.enterText(find.byType(TextFormField).first, '测试新的 DDL');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    final submit = find.byKey(const Key('create_task_submit'));
    expect(submit, findsOneWidget);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.textContaining('已记录：测试新的 DDL'), findsOneWidget);
  });

  testWidgets('can resolve an overdue task', (tester) async {
    final repository = InMemoryTaskRepository();
    final overdue = await repository.createTask(
      TaskDraft(
        title: '测试逾期任务',
        dueAt: DateTime.now().subtract(const Duration(hours: 1)),
        category: TaskCategory.study,
        isImportant: true,
        estimatedMinutes: 30,
      ),
    );
    await repository.transitionTask(overdue.id, TaskStatus.overdueReview);

    await tester.pumpWidget(
      DdlSurvivalApp(
        repository: repository,
        installationStore: InMemoryInstallationStore(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('忏悔录'));
    await tester.pumpAndSettle();
    expect(find.text('测试逾期任务'), findsOneWidget);

    await tester.tap(find.text('做完了，只是忘记打勾'));
    await tester.pumpAndSettle();
    expect(find.text('案底清空'), findsOneWidget);
  });
}
