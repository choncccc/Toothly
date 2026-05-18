import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum SyncStatus { ok, offline, notSignedIn, error, busy }

class SyncReport {
  final int pushed;
  final int remaining;
  final SyncStatus status;
  final String? error;
  const SyncReport({
    required this.pushed,
    required this.remaining,
    required this.status,
    this.error,
  });
}

class PendingCase {
  final int? id;
  final String userId;
  final String date;
  final String title;
  final String notes;
  final String time;
  final String caseType;

  PendingCase({
    this.id,
    required this.userId,
    required this.date,
    required this.title,
    required this.notes,
    required this.time,
    required this.caseType,
  });

  Map<String, dynamic> toRow() => {
        'user_id': userId,
        'date': date,
        'title': title,
        'notes': notes,
        'time': time,
        'case_type': caseType,
      };

  Map<String, dynamic> toDbMap() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'date': date,
        'title': title,
        'notes': notes,
        'time': time,
        'case_type': caseType,
      };

  factory PendingCase.fromDb(Map<String, dynamic> m) => PendingCase(
        id: m['id'] as int?,
        userId: m['user_id'] as String,
        date: m['date'] as String,
        title: m['title'] as String,
        notes: (m['notes'] as String?) ?? '',
        time: (m['time'] as String?) ?? '',
        caseType: (m['case_type'] as String?) ?? '',
      );
}

class CaseSyncService {
  CaseSyncService._();
  static final CaseSyncService instance = CaseSyncService._();

  Database? _db;
  StreamSubscription? _connSub;
  bool _syncing = false;
  final _syncedController = StreamController<int>.broadcast();

  /// Emits the number of pending cases successfully pushed after each
  /// `syncPending` run that managed to push at least one item.
  Stream<int> get onSynced => _syncedController.stream;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final docsDir = await getApplicationDocumentsDirectory();
    final path = join(docsDir.path, 'pending_cases.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE pending_cases (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            date TEXT NOT NULL,
            title TEXT NOT NULL,
            notes TEXT,
            time TEXT,
            case_type TEXT
          )
        ''');
      },
    );
    return _db!;
  }

  void start() {
    _connSub ??= Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) {
        syncPending();
      }
    });
  }

  Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Try to push to Supabase. If offline or the push fails, queue locally.
  /// Returns true if synced immediately, false if queued for later.
  Future<bool> submitCompletedCase(PendingCase entry) async {
    if (await _isOnline()) {
      try {
        await _pushOne(entry);
        return true;
      } catch (_) {
        await _enqueue(entry);
        return false;
      }
    }
    await _enqueue(entry);
    return false;
  }

  Future<void> _enqueue(PendingCase entry) async {
    final db = await _database;
    await db.insert('pending_cases', entry.toDbMap());
  }

  Future<int> pendingCount() async {
    final db = await _database;
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM pending_cases');
    return Sqflite.firstIntValue(r) ?? 0;
  }

  /// Pushes any queued cases to Supabase.
  /// Returns a [SyncReport] describing what happened so the UI can surface it.
  Future<SyncReport> syncPending() async {
    if (_syncing) {
      return const SyncReport(pushed: 0, remaining: 0, status: SyncStatus.busy);
    }
    _syncing = true;
    int pushed = 0;
    String? error;
    SyncStatus status = SyncStatus.ok;
    try {
      if (!await _isOnline()) {
        final remaining = await pendingCount();
        return SyncReport(
          pushed: 0,
          remaining: remaining,
          status: SyncStatus.offline,
        );
      }
      if (Supabase.instance.client.auth.currentUser == null) {
        final remaining = await pendingCount();
        return SyncReport(
          pushed: 0,
          remaining: remaining,
          status: SyncStatus.notSignedIn,
        );
      }
      final db = await _database;
      final rows = await db.query('pending_cases', orderBy: 'id ASC');
      for (final row in rows) {
        final entry = PendingCase.fromDb(row);
        try {
          await _pushOne(entry);
          await db.delete(
            'pending_cases',
            where: 'id = ?',
            whereArgs: [entry.id],
          );
          pushed++;
        } catch (e) {
          error = e.toString();
          status = SyncStatus.error;
          break;
        }
      }
    } catch (e) {
      error = e.toString();
      status = SyncStatus.error;
    } finally {
      _syncing = false;
    }
    if (pushed > 0) {
      _syncedController.add(pushed);
    }
    final remaining = await pendingCount();
    return SyncReport(
      pushed: pushed,
      remaining: remaining,
      status: status,
      error: error,
    );
  }

  Future<void> _pushOne(PendingCase entry) async {
    final client = Supabase.instance.client;
    await client.from('appointments').insert(entry.toRow());
    await _bumpCasesCompleted(client, entry.userId);
  }

  Future<void> _bumpCasesCompleted(SupabaseClient client, String userId) async {
    try {
      await client.rpc(
        'increment_cases_completed',
        params: {'user_id': userId},
      );
      return;
    } catch (_) {
      // RPC missing or failed — fall through.
    }
    try {
      final row = await client
          .from('profiles')
          .select('cases_completed')
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return;
      final current = (row['cases_completed'] as int?) ?? 0;
      await client
          .from('profiles')
          .update({'cases_completed': current + 1})
          .eq('id', userId);
    } catch (_) {
      // Non-fatal; the appointment row is the source of truth.
    }
  }
}
