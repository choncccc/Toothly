import 'dart:io';
import 'dart:typed_data';

import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClinicalUpload {
  final String id;
  final String userId;
  final String level;
  final String itemKey;
  final String filePath;
  final String fileName;
  final String? mimeType;
  final DateTime uploadedAt;

  ClinicalUpload({
    required this.id,
    required this.userId,
    required this.level,
    required this.itemKey,
    required this.filePath,
    required this.fileName,
    required this.mimeType,
    required this.uploadedAt,
  });

  factory ClinicalUpload.fromMap(Map<String, dynamic> m) => ClinicalUpload(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        level: m['level'] as String,
        itemKey: m['item_key'] as String,
        filePath: m['file_path'] as String,
        fileName: m['file_name'] as String,
        mimeType: m['mime_type'] as String?,
        uploadedAt: DateTime.parse(m['uploaded_at'] as String),
      );
}

class ClinicalCasesService {
  ClinicalCasesService._();
  static final ClinicalCasesService instance = ClinicalCasesService._();

  static const String bucket = 'clinical-cases';

  SupabaseClient get _client => Supabase.instance.client;

  String? get _userId => _client.auth.currentUser?.id;

  /// Updates the user's clinic level in `profiles.year`.
  Future<void> setClinicLevel(String level) async {
    final uid = _userId;
    if (uid == null) throw StateError('Not signed in');
    await _client.from('profiles').update({'year': level}).eq('id', uid);
  }

  Future<Map<String, bool>> fetchCheckedItems(String level) async {
    final uid = _userId;
    if (uid == null) return {};
    final rows = await _client
        .from('clinical_case_items')
        .select('item_key, checked')
        .eq('user_id', uid)
        .eq('level', level);
    final map = <String, bool>{};
    for (final r in (rows as List)) {
      map[r['item_key'] as String] = (r['checked'] as bool?) ?? false;
    }
    return map;
  }

  Future<void> setChecked({
    required String level,
    required String itemKey,
    required bool checked,
  }) async {
    final uid = _userId;
    if (uid == null) throw StateError('Not signed in');
    await _client.from('clinical_case_items').upsert({
      'user_id': uid,
      'level': level,
      'item_key': itemKey,
      'checked': checked,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,level,item_key');
  }

  Future<List<ClinicalUpload>> listUploads({
    required String level,
    required String itemKey,
  }) async {
    final uid = _userId;
    if (uid == null) return [];
    final rows = await _client
        .from('clinical_case_uploads')
        .select()
        .eq('user_id', uid)
        .eq('level', level)
        .eq('item_key', itemKey)
        .order('uploaded_at', ascending: false);
    return (rows as List)
        .map((e) => ClinicalUpload.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<ClinicalUpload> uploadFile({
    required String level,
    required String itemKey,
    required File file,
    required String displayName,
  }) async {
    final uid = _userId;
    if (uid == null) throw StateError('Not signed in');

    final bytes = await file.readAsBytes();
    return uploadBytes(
      level: level,
      itemKey: itemKey,
      bytes: bytes,
      displayName: displayName,
    );
  }

  Future<ClinicalUpload> uploadBytes({
    required String level,
    required String itemKey,
    required Uint8List bytes,
    required String displayName,
  }) async {
    final uid = _userId;
    if (uid == null) throw StateError('Not signed in');

    final mimeType = lookupMimeType(displayName) ?? 'application/octet-stream';
    final ts = DateTime.now().millisecondsSinceEpoch;
    final safeName = displayName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final levelSegment = level.replaceAll(' ', '_');
    final storagePath = '$uid/$levelSegment/$itemKey/${ts}_$safeName';

    await _client.storage.from(bucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );

    final row = await _client
        .from('clinical_case_uploads')
        .insert({
          'user_id': uid,
          'level': level,
          'item_key': itemKey,
          'file_path': storagePath,
          'file_name': displayName,
          'mime_type': mimeType,
          'uploaded_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();

    return ClinicalUpload.fromMap(row);
  }

  Future<String> createSignedUrl(String filePath,
      {int expiresInSeconds = 300}) async {
    return await _client.storage
        .from(bucket)
        .createSignedUrl(filePath, expiresInSeconds);
  }

  Future<void> deleteUpload(ClinicalUpload upload) async {
    await _client.storage.from(bucket).remove([upload.filePath]);
    await _client
        .from('clinical_case_uploads')
        .delete()
        .eq('id', upload.id);
  }
}
