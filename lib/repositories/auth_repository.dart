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
    required String year,
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

      await _supabase.auth.refreshSession();

      await _supabase.from('profiles').insert({
        'id': response.user!.id,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'user_type': userType,
        'year_level': year,
        'created_at': DateTime.now().toIso8601String(),
      });
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception("Failed to save profile: $e");
    }
  }
}
