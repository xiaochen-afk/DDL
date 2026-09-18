import 'dart:async';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../../core/app_failure.dart';
import 'schema.dart';

class AppDatabase {
  AppDatabase({DatabaseFactory? factory, String? databasePath})
    : _factory = factory ?? databaseFactory,
      _databasePath = databasePath;

  static const fileName = 'ddl_survival.db';

  final DatabaseFactory _factory;
  final String? _databasePath;
  Database? _database;
  Future<Database>? _opening;

  Future<Database> get database {
    final current = _database;
    if (current != null && current.isOpen) return Future.value(current);
    return open();
  }

  Future<Database> open() {
    final pending = _opening;
    if (pending != null) return pending;

    final operation = _openInternal();
    _opening = operation;
    return operation.whenComplete(() {
      if (identical(_opening, operation)) _opening = null;
    });
  }

  Future<Database> _openInternal() async {
    try {
      final resolvedPath =
          _databasePath ?? path.join(await getDatabasesPath(), fileName);
      final opened = await _factory.openDatabase(
        resolvedPath,
        options: OpenDatabaseOptions(
          version: databaseVersion,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
          onCreate: (db, version) async {
            try {
              await createSchemaV1(db);
            } catch (error) {
              throw AppFailure(
                code: 'MIGRATION_FAILED',
                message: 'Unable to create the local database schema.',
                cause: error,
              );
            }
          },
          onUpgrade: (db, oldVersion, newVersion) async {
            try {
              await migrateDatabase(db, oldVersion, newVersion);
            } catch (error) {
              throw AppFailure(
                code: 'MIGRATION_FAILED',
                message: 'Unable to upgrade the local database schema.',
                cause: error,
              );
            }
          },
          onDowngrade: (db, oldVersion, newVersion) {
            throw const AppFailure(
              code: 'MIGRATION_FAILED',
              message: 'Database downgrade is not supported.',
            );
          },
        ),
      );
      _database = opened;
      return opened;
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw AppFailure(
        code: _isStorageFull(error) ? 'STORAGE_FULL' : 'DATABASE_UNAVAILABLE',
        message: 'Unable to open the local database.',
        cause: error,
      );
    }
  }

  Future<void> close() async {
    final current = _database;
    _database = null;
    if (current != null && current.isOpen) await current.close();
  }

  static bool _isStorageFull(Object error) {
    final value = error.toString().toLowerCase();
    return value.contains('database or disk is full') ||
        value.contains('sqlite_full');
  }
}
