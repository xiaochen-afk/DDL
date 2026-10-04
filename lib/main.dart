import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'src/app.dart';
import 'src/data/database/app_database.dart';
import 'src/data/flutter_notification_port.dart';
import 'src/data/in_memory_task_repository.dart';
import 'src/data/local_settings_repository.dart';
import 'src/data/reminder_repository.dart';
import 'src/data/sqlite_task_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    runApp(DdlSurvivalApp(repository: InMemoryTaskRepository()));
    return;
  }
  final database = AppDatabase();
  FlutterNotificationPort? notificationPort;
  try {
    final initialized = FlutterNotificationPort();
    await initialized.initialize();
    notificationPort = initialized;
  } catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'DDL local notifications',
        context: ErrorDescription('while initializing platform notifications'),
      ),
    );
  }
  runApp(
    DdlSurvivalApp(
      repository: SqliteTaskRepository(database),
      preferenceRepository: SqlitePreferenceRepository(database),
      profileRepository: SqliteProfileRepository(database),
      reminderRepository: SqliteReminderRepository(database),
      notificationPort: notificationPort,
      onDispose: () async {
        await notificationPort?.dispose();
        await database.close();
      },
    ),
  );
}
