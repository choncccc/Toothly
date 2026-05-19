import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  Future<bool> login({required String email, required String password}) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      return response.user != null;
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  //Register
  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String userType,
    required String clinicLevel,
    File? avatar,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'first_name': firstName, 'last_name': lastName},
      );

      if (response.user == null) {
        throw Exception("Registration failed. Try again.");
      }

      final userId = response.user!.id;

      String? avatarUrl;
      if (avatar != null) {
        avatarUrl = await _uploadAvatar(userId: userId, file: avatar);
      }

      final profileData = {
        'id': userId,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'user_type': userType,
        'created_at': DateTime.now().toIso8601String(),
      };
      if (clinicLevel.trim().isNotEmpty) {
        // Stored in existing `year` column — conceptually it's the clinic level.
        profileData['year'] = clinicLevel;
      }
      if (avatarUrl != null) {
        profileData['avatar_url'] = avatarUrl;
      }

      await _supabase.from('profiles').insert(profileData);

      await _supabase.auth.signOut();
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception("Failed to save profile: $e");
    }
  }

  /// Uploads to `avatars/<userId>/profile.jpg` and returns a public URL with
  /// a cache-busting query so the dashboard image refreshes after a change.
  Future<String> _uploadAvatar({
    required String userId,
    required File file,
  }) async {
    final path = '$userId/profile.jpg';
    await _supabase.storage.from('avatars').upload(
          path,
          file,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );
    final url = _supabase.storage.from('avatars').getPublicUrl(path);
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Replaces the current user's avatar and writes the new URL to `profiles`.
  Future<String> updateAvatar({required File file}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Not signed in.');
    }
    final url = await _uploadAvatar(userId: user.id, file: file);
    await _supabase
        .from('profiles')
        .update({'avatar_url': url})
        .eq('id', user.id);
    return url;
  }

  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? clinicLevel,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Not signed in.');
    }
    final payload = <String, dynamic>{};
    if (firstName != null) payload['first_name'] = firstName;
    if (lastName != null) payload['last_name'] = lastName;
    if (clinicLevel != null) payload['year'] = clinicLevel;
    if (payload.isEmpty) return;
    await _supabase.from('profiles').update(payload).eq('id', user.id);
  }

  /// Sends a password reset email. Supabase delivers a link the user opens
  /// in a browser to set a new password (configured by Site URL in the
  /// Supabase project settings).
  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email.trim());
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to send reset email: $e');
    }
  }
}
