import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/history_entry.dart';

class HistoryService {
  static const _maxEntries = 50;
  Database? _db;

  Future<void> init() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'history.db');

    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            file_path TEXT NOT NULL UNIQUE,
            file_name TEXT NOT NULL,
            last_progress_secs INTEGER DEFAULT 0,
            last_played_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<List<HistoryEntry>> getAll() async {
    final rows = await _db!.query(
      'history',
      orderBy: 'last_played_at DESC',
    );
    return rows.map((r) => HistoryEntry.fromMap(r)).toList();
  }

  Future<void> upsert(HistoryEntry entry) async {
    await _db!.insert(
      'history',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Trim to max entries
    final rows = await _db!.rawQuery('SELECT COUNT(*) FROM history');
    final count = rows.first.values.first as int?;
    if (count != null && count > _maxEntries) {
      await _db!.rawDelete('''
        DELETE FROM history WHERE id NOT IN (
          SELECT id FROM history ORDER BY last_played_at DESC LIMIT ?
        )
      ''', [_maxEntries]);
    }
  }

  Future<void> updateProgress(String filePath, int secs) async {
    await _db!.update(
      'history',
      {
        'last_progress_secs': secs,
        'last_played_at': DateTime.now().toIso8601String(),
      },
      where: 'file_path = ?',
      whereArgs: [filePath],
    );
  }

  Future<void> delete(int id) async {
    await _db!.delete('history', where: 'id = ?', whereArgs: [id]);
  }
}
