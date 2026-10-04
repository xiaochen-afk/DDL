import 'package:sqflite/sqflite.dart';

const int databaseVersion = 2;
const int riskConfigVersion = 2;

String _tasksTableSql(String tableName, int titleLimit, int notesLimit) =>
    '''
    CREATE TABLE $tableName (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL CHECK (length(title) BETWEEN 1 AND $titleLimit),
      category_id TEXT NOT NULL,
      important INTEGER NOT NULL CHECK (important IN (0, 1)),
      due_at INTEGER NOT NULL,
      estimated_minutes INTEGER NOT NULL CHECK (estimated_minutes > 0),
      notes TEXT NOT NULL DEFAULT '' CHECK (length(notes) <= $notesLimit),
      status TEXT NOT NULL CHECK (
        status IN (
          'PENDING',
          'COMPLETED',
          'OVERDUE_REVIEW',
          'COMPLETED_LATE',
          'MISSED',
          'ARCHIVED'
        )
      ),
      completed_at INTEGER,
      archived_at INTEGER,
      risk_score_snapshot INTEGER,
      risk_config_version INTEGER NOT NULL,
      version INTEGER NOT NULL DEFAULT 1 CHECK (version > 0),
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      FOREIGN KEY (category_id) REFERENCES categories(id)
    )
  ''';

const String _taskEventsTableSql = '''
    CREATE TABLE task_events (
      id TEXT PRIMARY KEY,
      task_id TEXT NOT NULL,
      event_type TEXT NOT NULL,
      occurred_at INTEGER NOT NULL,
      metadata_json TEXT,
      FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
    )
  ''';

const String _remindersTableSql = '''
    CREATE TABLE reminders (
      id TEXT PRIMARY KEY,
      platform_notification_id TEXT,
      task_id TEXT NOT NULL,
      scheduled_at INTEGER NOT NULL,
      channel TEXT NOT NULL CHECK (channel IN ('critical', 'normal')),
      status TEXT NOT NULL CHECK (
        status IN (
          'PENDING',
          'SCHEDULED',
          'SCHEDULE_FAILED',
          'CANCELLED',
          'FIRED'
        )
      ),
      last_error_code TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
    )
  ''';

Future<void> createSchemaV1(Database db) async {
  final batch = db.batch();

  batch.execute('''
    CREATE TABLE categories (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      icon TEXT NOT NULL,
      color_token TEXT NOT NULL,
      is_system INTEGER NOT NULL CHECK (is_system IN (0, 1)),
      sort_order INTEGER NOT NULL,
      created_at INTEGER NOT NULL
    )
  ''');
  batch.execute(
    'CREATE UNIQUE INDEX categories_name_unique ON categories(name)',
  );

  batch.execute(_tasksTableSql('tasks', 60, 300));
  batch.execute('CREATE INDEX tasks_status_due_at ON tasks(status, due_at)');
  batch.execute(
    'CREATE INDEX tasks_archived_updated_at '
    'ON tasks(archived_at, updated_at)',
  );

  batch.execute(_taskEventsTableSql);
  batch.execute(
    'CREATE INDEX task_events_task_occurred_at '
    'ON task_events(task_id, occurred_at)',
  );

  batch.execute(_remindersTableSql);
  batch.execute(
    'CREATE INDEX reminders_task_scheduled_at '
    'ON reminders(task_id, scheduled_at)',
  );

  batch.execute('''
    CREATE TABLE preferences (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      copy_tone TEXT NOT NULL CHECK (
        copy_tone IN ('off', 'gentle', 'standard')
      ),
      notifications_enabled INTEGER NOT NULL CHECK (
        notifications_enabled IN (0, 1)
      ),
      quiet_hours_start TEXT,
      quiet_hours_end TEXT,
      default_reminder_offsets_json TEXT NOT NULL,
      urgent_threshold_minutes INTEGER NOT NULL,
      buffer_minutes INTEGER NOT NULL,
      timezone TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');

  batch.execute('''
    CREATE TABLE profile (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      nickname TEXT NOT NULL,
      motto TEXT NOT NULL,
      avatar_uri TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');

  batch.execute('''
    CREATE TABLE app_meta (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''');

  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  const categories = [
    ('study', '学习', 'school', 'category.study', 0),
    ('work', '工作', 'work', 'category.work', 1),
    ('life', '生活', 'home', 'category.life', 2),
    ('fun', '娱乐', 'sports_esports', 'category.fun', 3),
  ];
  for (final category in categories) {
    batch.insert('categories', {
      'id': category.$1,
      'name': category.$2,
      'icon': category.$3,
      'color_token': category.$4,
      'is_system': 1,
      'sort_order': category.$5,
      'created_at': now,
    });
  }

  batch.insert('app_meta', {'key': 'schema_version', 'value': '1'});
  batch.insert('app_meta', {
    'key': 'risk_config_version',
    'value': riskConfigVersion.toString(),
  });

  await batch.commit(noResult: true);
}

Future<void> createSchemaV2(Database db) async {
  await createSchemaV1(db);
  await _migrateV1ToV2(db);
}

Future<void> migrateDatabase(
  Database db,
  int oldVersion,
  int newVersion,
) async {
  if (oldVersion >= newVersion) return;

  if (oldVersion < 1 && newVersion >= 1) {
    await createSchemaV1(db);
  }
  if (oldVersion < 2 && newVersion >= 2) {
    await _migrateV1ToV2(db);
  }
}

Future<void> _migrateV1ToV2(Database db) async {
  // Drop child tables before replacing tasks so ON DELETE CASCADE cannot erase
  // their rows. sqflite runs onCreate/onUpgrade in a single transaction.
  await db.execute(
    'CREATE TEMP TABLE migration_task_events AS SELECT * FROM task_events',
  );
  await db.execute(
    'CREATE TEMP TABLE migration_reminders AS SELECT * FROM reminders',
  );
  await db.execute('DROP TABLE task_events');
  await db.execute('DROP TABLE reminders');

  await db.execute(_tasksTableSql('tasks_v2', 80, 1000));
  await db.execute('INSERT INTO tasks_v2 SELECT * FROM tasks');
  await db.execute('DROP TABLE tasks');
  await db.execute('ALTER TABLE tasks_v2 RENAME TO tasks');
  await db.execute('CREATE INDEX tasks_status_due_at ON tasks(status, due_at)');
  await db.execute(
    'CREATE INDEX tasks_archived_updated_at ON tasks(archived_at, updated_at)',
  );

  await db.execute(_taskEventsTableSql);
  await db.execute(
    'INSERT INTO task_events SELECT * FROM migration_task_events',
  );
  await db.execute(
    'CREATE INDEX task_events_task_occurred_at '
    'ON task_events(task_id, occurred_at)',
  );
  await db.execute(_remindersTableSql);
  await db.execute('INSERT INTO reminders SELECT * FROM migration_reminders');
  await db.execute(
    'CREATE INDEX reminders_task_scheduled_at '
    'ON reminders(task_id, scheduled_at)',
  );

  final violations = await db.rawQuery('PRAGMA foreign_key_check');
  if (violations.isNotEmpty) {
    throw StateError('Foreign key violation during schema v2 migration.');
  }
  await db.execute('DROP TABLE migration_task_events');
  await db.execute('DROP TABLE migration_reminders');
  await db.update(
    'app_meta',
    {'value': '2'},
    where: 'key = ?',
    whereArgs: ['schema_version'],
  );
}
