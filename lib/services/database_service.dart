import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/activity_log.dart';
import '../models/task.dart';

/// Local SQLite store for activity check-ins and daily tasks.
///
/// Implemented as a singleton so it can also be opened from the background
/// notification isolate (when an inline reply arrives while the app is killed).
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'hourly.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await _createLogs(db);
        await _createTasks(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createTasks(db);
      },
    );
  }

  Future<void> _createLogs(Database db) async {
    await db.execute('''
      CREATE TABLE logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ts INTEGER NOT NULL,
        text TEXT NOT NULL,
        source TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_logs_ts ON logs(ts)');
  }

  Future<void> _createTasks(Database db) async {
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        done INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        done_at INTEGER
      )
    ''');
    await db.execute('CREATE INDEX idx_tasks_created ON tasks(created_at)');
  }

  // --- Check-ins -----------------------------------------------------------

  Future<int> insertLog(ActivityLog log) async {
    final db = await _database;
    return db.insert('logs', log.toMap()..remove('id'));
  }

  Future<List<ActivityLog>> logsForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final db = await _database;
    final rows = await db.query(
      'logs',
      where: 'ts >= ? AND ts < ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'ts DESC',
    );
    return rows.map(ActivityLog.fromMap).toList();
  }

  Future<void> deleteLog(int id) async {
    final db = await _database;
    await db.delete('logs', where: 'id = ?', whereArgs: [id]);
  }

  // --- Tasks ---------------------------------------------------------------

  Future<int> insertTask(Task task) async {
    final db = await _database;
    return db.insert('tasks', task.toMap()..remove('id'));
  }

  Future<List<Task>> tasksForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final db = await _database;
    final rows = await db.query(
      'tasks',
      where: 'created_at >= ? AND created_at < ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'done ASC, created_at ASC',
    );
    return rows.map(Task.fromMap).toList();
  }

  Future<void> updateTask(Task task) async {
    final db = await _database;
    await db.update('tasks', task.toMap(),
        where: 'id = ?', whereArgs: [task.id]);
  }

  Future<void> deleteTask(int id) async {
    final db = await _database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }
}
