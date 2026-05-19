import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class CaseDraft {
  final String title;
  final String editablePdfPath;
  final List<String> companionPdfPaths;
  final DateTime savedAt;
  final String filePath;

  CaseDraft({
    required this.title,
    required this.editablePdfPath,
    required this.companionPdfPaths,
    required this.savedAt,
    required this.filePath,
  });
}

class DraftStore {
  DraftStore._();

  static String draftKey(String editablePath) =>
      editablePath.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  static Future<Directory> _draftsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final d = Directory('${dir.path}/pdf_drafts');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  static Future<File> fileFor(String editablePath) async {
    final d = await _draftsDir();
    return File('${d.path}/${draftKey(editablePath)}.json');
  }

  static Future<List<CaseDraft>> list() async {
    final d = await _draftsDir();
    if (!d.existsSync()) return const [];
    final out = <CaseDraft>[];
    for (final e in d.listSync()) {
      if (e is! File || !e.path.endsWith('.json')) continue;
      try {
        final json =
            jsonDecode(await e.readAsString()) as Map<String, dynamic>;
        final title = json['title'] as String?;
        final editablePath = json['editablePdfPath'] as String?;
        // Old-format drafts (pre-metadata) are skipped — there is no way to
        // reopen them without knowing their source PDF.
        if (title == null || editablePath == null) continue;
        out.add(CaseDraft(
          title: title,
          editablePdfPath: editablePath,
          companionPdfPaths: ((json['companionPdfPaths'] as List?) ?? const [])
              .map((e) => e as String)
              .toList(),
          savedAt:
              DateTime.tryParse(json['savedAt'] as String? ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0),
          filePath: e.path,
        ));
      } catch (_) {
        // Skip corrupt files.
      }
    }
    out.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return out;
  }

  static Future<void> delete(String filePath) async {
    try {
      final f = File(filePath);
      if (f.existsSync()) await f.delete();
    } catch (_) {}
  }
}
