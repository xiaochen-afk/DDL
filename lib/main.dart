import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'src/app.dart';
import 'src/data/database/app_database.dart';
import 'src/data/in_memory_task_repository.dart';
import 'src/data/sqlite_task_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    runApp(DdlSurvivalApp(repository: InMemoryTaskRepository()));
    return;
  }
  final database = AppDatabase();
  runApp(
    DdlSurvivalApp(
      repository: SqliteTaskRepository(database),
      onDispose: database.close,
    ),
  );
}
