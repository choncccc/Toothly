import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// A file attached to a clinical checklist item, stored locally.
class ClinicalFile {
  final int id;
  final String level;
  final String itemKey;
  final String filePath;
  final String displayName;
  final DateTime uploadedAt;

  ClinicalFile({
    required this.id,
    required this.level,
    required this.itemKey,
    required this.filePath,
    required this.displayName,
    required this.uploadedAt,
  });

  factory ClinicalFile.fromMap(Map<String, dynamic> m) => ClinicalFile(
        id: m['id'] as int,
        level: m['level'] as String,
        itemKey: m['item_key'] as String,
        filePath: m['file_path'] as String,
        displayName: m['display_name'] as String,
        uploadedAt:
            DateTime.fromMillisecondsSinceEpoch(m['uploaded_at'] as int),
      );
}

/// Offline replacement for the old Supabase-backed `ClinicalCasesService` +
/// `ClinicalSyncService`. Checklist check-state lives in SQLite; attached
/// files are copied into the app documents directory and tracked in a table.
class ClinicalStore {
  ClinicalStore._();
  static final ClinicalStore instance = ClinicalStore._();

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final docsDir = await getApplicationDocumentsDirectory();
    final path = p.join(docsDir.path, 'clinical.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE checks (
            level TEXT NOT NULL,
            item_key TEXT NOT NULL,
            checked INTEGER NOT NULL,
            PRIMARY KEY (level, item_key)
          )
        ''');
        await db.execute('''
          CREATE TABLE uploads (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            level TEXT NOT NULL,
            item_key TEXT NOT NULL,
            file_path TEXT NOT NULL,
            display_name TEXT NOT NULL,
            uploaded_at INTEGER NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  // --- Check state -----------------------------------------------------------

  Future<Map<String, bool>> fetchCheckedItems(String level) async {
    final db = await _database;
    final rows = await db.query(
      'checks',
      columns: ['item_key', 'checked'],
      where: 'level = ?',
      whereArgs: [level],
    );
    final map = <String, bool>{};
    for (final r in rows) {
      map[r['item_key'] as String] = (r['checked'] as int) == 1;
    }
    return map;
  }

  Future<void> setChecked({
    required String level,
    required String itemKey,
    required bool checked,
  }) async {
    final db = await _database;
    await db.insert(
      'checks',
      {
        'level': level,
        'item_key': itemKey,
        'checked': checked ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- File attachments ------------------------------------------------------

  Future<List<ClinicalFile>> listUploads({
    required String level,
    required String itemKey,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'uploads',
      where: 'level = ? AND item_key = ?',
      whereArgs: [level, itemKey],
      orderBy: 'uploaded_at DESC',
    );
    return rows.map(ClinicalFile.fromMap).toList();
  }

  /// Copies [sourceFile] into the app documents directory and records it.
  Future<ClinicalFile> addUpload({
    required String level,
    required String itemKey,
    required File sourceFile,
    required String displayName,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docsDir.path, 'clinical_uploads'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final safe = displayName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final dest = p.join(dir.path, '${ts}_$safe');
    await sourceFile.copy(dest);

    final db = await _database;
    final id = await db.insert('uploads', {
      'level': level,
      'item_key': itemKey,
      'file_path': dest,
      'display_name': displayName,
      'uploaded_at': ts,
    });

    return ClinicalFile(
      id: id,
      level: level,
      itemKey: itemKey,
      filePath: dest,
      displayName: displayName,
      uploadedAt: DateTime.fromMillisecondsSinceEpoch(ts),
    );
  }

  Future<void> deleteUpload(ClinicalFile file) async {
    final db = await _database;
    await db.delete('uploads', where: 'id = ?', whereArgs: [file.id]);
    try {
      final f = File(file.filePath);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
