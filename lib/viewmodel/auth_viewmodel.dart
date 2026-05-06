import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthViewModel extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> logout(BuildContext context) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _supabase.auth.signOut();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Logout failed: $e")));
    }

    _isLoading = false;
    notifyListeners();
  }
}
