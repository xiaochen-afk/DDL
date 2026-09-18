import 'package:sqflite/sqflite.dart';

const int databaseVersion = 1;
const int riskConfigVersion = 1;

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

  batch.execute('''
    CREATE TABLE tasks (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL CHECK (length(title) BETWEEN 1 AND 60),
      category_id TEXT NOT NULL,
      important INTEGER NOT NULL CHECK (important IN (0, 1)),
      due_at INTEGER NOT NULL,
      estimated_minutes INTEGER NOT NULL CHECK (estimated_minutes > 0),
      notes TEXT NOT NULL DEFAULT '' CHECK (length(notes) <= 300),
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
  ''');
  batch.execute('CREATE INDEX tasks_status_due_at ON tasks(status, due_at)');
  batch.execute(
    'CREATE INDEX tasks_archived_updated_at '
    'ON tasks(archived_at, updated_at)',
  );

  batch.execute('''
    CREATE TABLE task_events (
      id TEXT PRIMARY KEY,
      task_id TEXT NOT NULL,
      event_type TEXT NOT NULL,
      occurred_at INTEGER NOT NULL,
      metadata_json TEXT,
      FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
    )
  ''');
  batch.execute(
    'CREATE INDEX task_events_task_occurred_at '
    'ON task_events(task_id, occurred_at)',
  );

  batch.execute('''
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
  ''');
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

  batch.insert('app_meta', {
    'key': 'schema_version',
    'value': databaseVersion.toString(),
  });
  batch.insert('app_meta', {
    'key': 'risk_config_version',
    'value': riskConfigVersion.toString(),
  });

  await batch.commit(noResult: true);
}

Future<void> migrateDatabase(
  Database db,
  int oldVersion,
  int newVersion,
) async {
  if (oldVersion >= newVersion) return;

  // Version 1 is the first production schema. Future migrations are appended
  // here as ordered, forward-only steps.
  if (oldVersion < 1 && newVersion >= 1) {
    await createSchemaV1(db);
  }
}
