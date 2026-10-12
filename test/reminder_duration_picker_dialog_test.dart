import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ddl_survival/src/screens/reminder_duration_picker_dialog.dart';

void main() {
  testWidgets('default reminder uses hour and minute wheels', (tester) async {
    List<int>? savedOffsets;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                savedOffsets = await showDialog<List<int>>(
                  context: context,
                  builder: (_) => const ReminderDurationPickerDialog(
                    initialOffsets: <int>[1440],
                  ),
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('小时'), findsOneWidget);
    expect(find.text('分钟'), findsOneWidget);
    expect(find.byType(ListWheelScrollView), findsNWidgets(2));

    final wheels = tester.widgetList<ListWheelScrollView>(
      find.byType(ListWheelScrollView),
    );
    final minuteController =
        wheels.elementAt(1).controller! as FixedExtentScrollController;
    minuteController.jumpToItem(1);
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(savedOffsets, <int>[1441]);
  });

  testWidgets('zero duration cannot be saved', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReminderDurationPickerDialog(initialOffsets: <int>[0]),
      ),
    );

    expect(find.text('至少提前 1 分钟'), findsOneWidget);
    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '保存'),
    );
    expect(saveButton.onPressed, isNull);
  });
}
