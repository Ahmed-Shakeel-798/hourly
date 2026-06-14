import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/activity_log.dart';

/// Local SQLite store for activity check-ins.
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
    final path = p.join(dir.path, 'mobile_monitor.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ts INTEGER NOT NULL,
            text TEXT NOT NULL,
            source TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_logs_ts ON logs(ts)');
      },
    );
  }

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
}
