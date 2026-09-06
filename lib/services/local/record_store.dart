import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// A saved patient record — one annotated chart belonging to one patient.
///
/// Replaces the old file-per-template drafts in [DraftStore], where the storage
/// key was the template path. That meant a second patient charted on the same
/// form silently overwrote the first.
class PatientRecord {
  final int id;

  /// Card/control number issued by the app. This is the record's identity —
  /// charts are not named after patients, matching the locked control-number
  /// field on the forms themselves.
  final String? patientCode;

  /// Folder this record lives in, e.g. 'Pediatric'. Matches the card titles in
  /// `create_case_view.dart`.
  final String category;

  /// Human label of the source form, e.g. 'ART Pedia (Check List)'.
  final String formTitle;

  final String templatePath;
  final List<String> companionPaths;

  /// Serialized strokes + text labels, in the same shape the annotator has
  /// always written.
  final Map<String, dynamic> annotations;

  final DateTime createdAt;
  final DateTime updatedAt;

  PatientRecord({
    required this.id,
    required this.patientCode,
    required this.category,
    required this.formTitle,
    required this.templatePath,
    required this.companionPaths,
    required this.annotations,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PatientRecord.fromMap(Map<String, dynamic> m) => PatientRecord(
        id: m['id'] as int,
        patientCode: m['patient_code'] as String?,
        category: m['category'] as String,
        formTitle: m['form_title'] as String,
        templatePath: m['template_path'] as String,
        companionPaths: ((jsonDecode(m['companion_paths'] as String? ?? '[]')
                as List?) ??
                const [])
            .map((e) => e as String)
            .toList(),
        annotations:
            (jsonDecode(m['annotations'] as String? ?? '{}') as Map?)
                    ?.cast<String, dynamic>() ??
                <String, dynamic>{},
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int),
      );

  /// Label shown on cards — the assigned control number.
  String get displayLabel {
    final code = patientCode?.trim() ?? '';
    return code.isEmpty ? 'Unassigned record' : code;
  }
}

/// SQLite-backed store for saved patient records, grouped into per-department
/// folders so retrieval does not mean scrolling a flat list of files.
class RecordStore {
  RecordStore._();
  static final RecordStore instance = RecordStore._();

  Database? _db;

  /// Folder labels, in the order they appear in the records view. Kept in sync
  /// with the case cards in `create_case_view.dart`.
  static const List<String> categories = [
    'Pediatric',
    'Complete Dentures',
    'Endodontics',
    'Exodontia',
    'Fixed Partial Denture',
    'Removable Partial Denture',
    'Restorative',
    'Periodontics',
  ];

  /// Maps an asset template path to its folder, used when a caller does not
  /// pass a category explicitly and when importing legacy drafts.
  static String categoryForTemplate(String templatePath) {
    const byFolder = {
      'PEDIA CHART': 'Pediatric',
      'CD CHART': 'Complete Dentures',
      'ENDO CHART': 'Endodontics',
      'EXO CHART': 'Exodontia',
      'FPD CHART': 'Fixed Partial Denture',
      'RPD CHART': 'Removable Partial Denture',
      'RESTO CHART': 'Restorative',
      'PERIO CHART': 'Periodontics',
    };
    for (final entry in byFolder.entries) {
      if (templatePath.contains(entry.key)) return entry.value;
    }
    return 'Other';
  }

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final docsDir = await getApplicationDocumentsDirectory();
    final path = p.join(docsDir.path, 'records.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            patient_name TEXT NOT NULL,
            patient_code TEXT,
            category TEXT NOT NULL,
            form_title TEXT NOT NULL,
            template_path TEXT NOT NULL,
            companion_paths TEXT NOT NULL,
            annotations TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_records_category ON records (category)',
        );
        await db.execute(
          'CREATE INDEX idx_records_patient ON records (patient_name)',
        );
        await db.execute(
          'CREATE INDEX idx_records_code ON records (patient_code)',
        );
      },
    );
    await _importLegacyDrafts(_db!);
    return _db!;
  }

  // --- Reads -----------------------------------------------------------------

  /// Record count per folder, so the folder grid can show how full each is.
  Future<Map<String, int>> categoryCounts() async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT category, COUNT(*) AS c FROM records GROUP BY category',
    );
    return {
      for (final r in rows) r['category'] as String: r['c'] as int,
    };
  }

  Future<List<PatientRecord>> listByCategory(String category) async {
    final db = await _database;
    final rows = await db.query(
      'records',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'updated_at DESC',
    );
    return rows.map(PatientRecord.fromMap).toList();
  }

  Future<List<PatientRecord>> recent({int limit = 5}) async {
    final db = await _database;
    final rows = await db.query(
      'records',
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return rows.map(PatientRecord.fromMap).toList();
  }

  /// Case-insensitive partial match on the patient code. An empty [query]
  /// returns nothing so the caller can fall back to the folder view.
  Future<List<PatientRecord>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final db = await _database;
    final rows = await db.query(
      'records',
      where: 'LOWER(IFNULL(patient_code, "")) LIKE ?',
      whereArgs: ['%${q.toLowerCase()}%'],
      orderBy: 'updated_at DESC',
    );
    return rows.map(PatientRecord.fromMap).toList();
  }

  /// Short prefix per department, used to build patient codes.
  static const Map<String, String> _codePrefixes = {
    'Pediatric': 'PED',
    'Complete Dentures': 'CD',
    'Endodontics': 'ENDO',
    'Exodontia': 'EXO',
    'Fixed Partial Denture': 'FPD',
    'Removable Partial Denture': 'RPD',
    'Restorative': 'RESTO',
    'Periodontics': 'PERIO',
  };

  /// Assigns the next patient card/control number for [category], e.g.
  /// PED-2026-003. The chart's own control-number field is a locked region the
  /// student cannot write in (see `pdf_locked_regions.dart`) because the code is
  /// issued here rather than typed by hand.
  Future<String> nextPatientCode(String category) async =>
      _nextPatientCode(await _database, category);

  Future<String> _nextPatientCode(Database db, String category) async {
    final prefix = _codePrefixes[category] ?? 'GEN';
    final year = DateTime.now().year;
    final stem = '$prefix-$year-';
    final rows = await db.query(
      'records',
      columns: ['patient_code'],
      where: 'patient_code LIKE ?',
      whereArgs: ['$stem%'],
    );
    var highest = 0;
    for (final r in rows) {
      final code = r['patient_code'] as String?;
      if (code == null) continue;
      final seq = int.tryParse(code.substring(stem.length));
      if (seq != null && seq > highest) highest = seq;
    }
    return '$stem${(highest + 1).toString().padLeft(3, '0')}';
  }

  Future<PatientRecord?> byId(int id) async {
    final db = await _database;
    final rows = await db.query('records', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return PatientRecord.fromMap(rows.first);
  }

  // --- Writes ----------------------------------------------------------------

  /// Inserts a new record when [id] is null, otherwise updates that record in
  /// place. Returns the row id either way.
  Future<int> save({
    int? id,
    String? patientCode,
    required String category,
    required String formTitle,
    required String templatePath,
    required List<String> companionPaths,
    required Map<String, dynamic> annotations,
  }) async {
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final code = patientCode?.trim();

    final values = {
      // patient_name is a vestigial NOT NULL column from when records were
      // named. Records are identified by code now; the column is kept so
      // existing databases keep accepting inserts.
      'patient_name': '',
      'patient_code': (code == null || code.isEmpty) ? null : code,
      'category': category,
      'form_title': formTitle,
      'template_path': templatePath,
      'companion_paths': jsonEncode(companionPaths),
      'annotations': jsonEncode(annotations),
      'updated_at': now,
    };

    if (id == null) {
      return db.insert('records', {...values, 'created_at': now});
    }
    await db.update('records', values, where: 'id = ?', whereArgs: [id]);
    return id;
  }

  Future<void> delete(int id) async {
    final db = await _database;
    await db.delete('records', where: 'id = ?', whereArgs: [id]);
  }

  // --- Legacy import ---------------------------------------------------------

  /// One-time import of the old `pdf_drafts/*.json` files so work saved before
  /// this change is not stranded. Each import is assigned a control number the
  /// same way a new record is.
  ///
  /// Each source file is deleted only after its row is written, so an interrupted
  /// import re-runs safely on the next launch.
  Future<void> _importLegacyDrafts(Database db) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docsDir.path, 'pdf_drafts'));
      if (!dir.existsSync()) return;

      for (final entry in dir.listSync()) {
        if (entry is! File || !entry.path.endsWith('.json')) continue;
        try {
          final json =
              jsonDecode(await entry.readAsString()) as Map<String, dynamic>;
          final title = json['title'] as String?;
          final templatePath = json['editablePdfPath'] as String?;
          if (title == null || templatePath == null) {
            // Pre-metadata draft — nothing to reopen it with.
            await entry.delete();
            continue;
          }

          final savedAt = DateTime.tryParse(json['savedAt'] as String? ?? '')
                  ?.millisecondsSinceEpoch ??
              DateTime.now().millisecondsSinceEpoch;

          final category = categoryForTemplate(templatePath);
          await db.insert('records', {
            'patient_name': '',
            'patient_code': await _nextPatientCode(db, category),
            'category': category,
            'form_title': title,
            'template_path': templatePath,
            'companion_paths':
                jsonEncode((json['companionPdfPaths'] as List?) ?? const []),
            'annotations': jsonEncode({
              'strokes': json['strokes'] ?? <String, dynamic>{},
              'labels': json['labels'] ?? <String, dynamic>{},
            }),
            'created_at': savedAt,
            'updated_at': savedAt,
          });
          await entry.delete();
        } catch (_) {
          // Skip corrupt draft, keep importing the rest.
        }
      }
    } catch (_) {
      // Import is best-effort; never block opening the store.
    }
  }
}
