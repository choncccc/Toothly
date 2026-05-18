import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/clinical_checklist.dart';
import 'remote/clinical_cases_service.dart';

/// A locally-queued file upload that hasn't reached Supabase Storage yet.
class PendingUpload {
  final int id;
  final String level;
  final String itemKey;
  final String localPath;
  final String displayName;
  final DateTime queuedAt;

  PendingUpload({
    required this.id,
    required this.level,
    required this.itemKey,
    required this.localPath,
    required this.displayName,
    required this.queuedAt,
  });
}

class ClinicalSyncService {
  ClinicalSyncService._();
  static final ClinicalSyncService instance = ClinicalSyncService._();

  final _remote = ClinicalCasesService.instance;
  Database? _db;
  StreamSubscription? _connSub;
  bool _syncing = false;
  final _syncedController = StreamController<void>.broadcast();

  /// Emits whenever a sync pass completes with at least one push.
  Stream<void> get onSynced => _syncedController.stream;

  // ---------------------------------------------------------------------------
  // DB bootstrap
  // ---------------------------------------------------------------------------
  Future<Database> get _database async {
    if (_db != null) return _db!;
    final docsDir = await getApplicationDocumentsDirectory();
    final path = p.join(docsDir.path, 'pending_clinical.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE pending_checks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            level TEXT NOT NULL,
            item_key TEXT NOT NULL,
            checked INTEGER NOT NULL,
            queued_at INTEGER NOT NULL,
            UNIQUE(level, item_key) ON CONFLICT REPLACE
          )
        ''');
        await db.execute('''
          CREATE TABLE pending_uploads (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            level TEXT NOT NULL,
            item_key TEXT NOT NULL,
            local_path TEXT NOT NULL,
            display_name TEXT NOT NULL,
            queued_at INTEGER NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------
  void start() {
    _connSub ??= Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) syncPending();
    });
  }

  Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  bool get _signedIn => Supabase.instance.client.auth.currentUser != null;

  // ---------------------------------------------------------------------------
  // Check-state queue
  // ---------------------------------------------------------------------------

  /// Tries to push a checkbox change immediately; falls back to the queue.
  /// Returns true if pushed, false if queued.
  Future<bool> submitCheck({
    required String level,
    required String itemKey,
    required bool checked,
  }) async {
    if (await _isOnline() && _signedIn) {
      try {
        await _remote.setChecked(
          level: level,
          itemKey: itemKey,
          checked: checked,
        );
        return true;
      } catch (_) {
        await _enqueueCheck(level, itemKey, checked);
        return false;
      }
    }
    await _enqueueCheck(level, itemKey, checked);
    return false;
  }

  Future<void> _enqueueCheck(String level, String itemKey, bool checked) async {
    final db = await _database;
    await db.insert(
      'pending_checks',
      {
        'level': level,
        'item_key': itemKey,
        'checked': checked ? 1 : 0,
        'queued_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---------------------------------------------------------------------------
  // Upload queue
  // ---------------------------------------------------------------------------

  /// Copies the picked file to app docs dir, then tries to upload it.
  /// On failure or offline, it stays queued and surfaces in [listPending].
  /// Returns true if uploaded immediately, false if queued.
  Future<bool> submitUpload({
    required String level,
    required String itemKey,
    required File sourceFile,
    required String displayName,
  }) async {
    final localPath = await _copyToCache(sourceFile, displayName);
    final db = await _database;
    final id = await db.insert('pending_uploads', {
      'level': level,
      'item_key': itemKey,
      'local_path': localPath,
      'display_name': displayName,
      'queued_at': DateTime.now().millisecondsSinceEpoch,
    });

    if (await _isOnline() && _signedIn) {
      try {
        await _remote.uploadFile(
          level: level,
          itemKey: itemKey,
          file: File(localPath),
          displayName: displayName,
        );
        await _removePendingUpload(id, localPath);
        return true;
      } catch (_) {
        // Stay queued.
      }
    }
    return false;
  }

  Future<String> _copyToCache(File sourceFile, String displayName) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docsDir.path, 'pending_uploads'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final safe = displayName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final dest = p.join(dir.path, '${ts}_$safe');
    await sourceFile.copy(dest);
    return dest;
  }

  Future<void> _removePendingUpload(int id, String localPath) async {
    final db = await _database;
    await db.delete('pending_uploads', where: 'id = ?', whereArgs: [id]);
    try {
      final f = File(localPath);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<List<PendingUpload>> listPendingUploads({
    required String level,
    required String itemKey,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'pending_uploads',
      where: 'level = ? AND item_key = ?',
      whereArgs: [level, itemKey],
      orderBy: 'queued_at DESC',
    );
    return rows
        .map((r) => PendingUpload(
              id: r['id'] as int,
              level: r['level'] as String,
              itemKey: r['item_key'] as String,
              localPath: r['local_path'] as String,
              displayName: r['display_name'] as String,
              queuedAt:
                  DateTime.fromMillisecondsSinceEpoch(r['queued_at'] as int),
            ))
        .toList();
  }

  Future<void> deletePendingUpload(int id) async {
    final db = await _database;
    final rows = await db.query(
      'pending_uploads',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    await _removePendingUpload(id, rows.first['local_path'] as String);
  }

  // ---------------------------------------------------------------------------
  // Sync
  // ---------------------------------------------------------------------------
  Future<int> syncPending() async {
    if (_syncing) return 0;
    if (!await _isOnline() || !_signedIn) return 0;
    _syncing = true;
    int pushed = 0;
    try {
      final db = await _database;

      // 1. Push checks
      final checks = await db.query('pending_checks', orderBy: 'id ASC');
      for (final row in checks) {
        try {
          await _remote.setChecked(
            level: row['level'] as String,
            itemKey: row['item_key'] as String,
            checked: (row['checked'] as int) == 1,
          );
          await db.delete(
            'pending_checks',
            where: 'id = ?',
            whereArgs: [row['id']],
          );
          pushed++;
        } catch (_) {
          break;
        }
      }

      // 2. Push uploads
      final uploads = await db.query('pending_uploads', orderBy: 'id ASC');
      for (final row in uploads) {
        final id = row['id'] as int;
        final localPath = row['local_path'] as String;
        final file = File(localPath);
        if (!await file.exists()) {
          // File got cleaned up underneath us — drop the queue entry.
          await db.delete('pending_uploads',
              where: 'id = ?', whereArgs: [id]);
          continue;
        }
        try {
          await _remote.uploadFile(
            level: row['level'] as String,
            itemKey: row['item_key'] as String,
            file: file,
            displayName: row['display_name'] as String,
          );
          await _removePendingUpload(id, localPath);
          pushed++;
        } catch (_) {
          break;
        }
      }

      // 3. Promotion: after a successful sync of checks, see if any level
      //    is now complete and bump profiles.year.
      if (pushed > 0) {
        await _maybePromote();
      }
    } finally {
      _syncing = false;
    }
    if (pushed > 0) _syncedController.add(null);
    return pushed;
  }

  Future<void> _maybePromote() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    String? currentLevel;
    try {
      final row = await client
          .from('profiles')
          .select('year')
          .eq('id', uid)
          .maybeSingle();
      currentLevel = row?['year'] as String?;
    } catch (_) {
      return;
    }
    if (currentLevel == null || currentLevel.isEmpty) return;
    final levels = ClinicalChecklist.levels;
    final idx = levels.indexOf(currentLevel);
    if (idx < 0 || idx >= levels.length - 1) return;

    final items = ClinicalChecklist.itemsFor(currentLevel);
    if (items.isEmpty) return;
    final Map<String, bool> checked;
    try {
      checked = await _remote.fetchCheckedItems(currentLevel);
    } catch (_) {
      return;
    }
    final allDone = items.every((it) => checked[it.key] ?? false);
    if (!allDone) return;
    try {
      await _remote.setClinicLevel(levels[idx + 1]);
    } catch (_) {}
  }

  Future<int> pendingTotal() async {
    final db = await _database;
    final c = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM pending_checks')) ??
        0;
    final u = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM pending_uploads')) ??
        0;
    return c + u;
  }
}
