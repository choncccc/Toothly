import 'package:flutter/material.dart';
import '../repositories/auth_repository.dart';

class LoginViewModel {
  final AuthRepository _authRepository;

  String? errorMessage;

  LoginViewModel(this._authRepository);
  Future<bool> login(String email, String password) async {
    email = email.trim();
    password = password.trim();
    if (email.isEmpty || password.isEmpty) {
      errorMessage = "Please fill all fields";
      return false;
    }

    if (password.length < 6) {
      errorMessage = "Password must be at least 6 characters";
      return false;
    }

    try {
      final success = await _authRepository.login(
        email: email,
        password: password,
      );

      if (!success) {
        errorMessage = "Invalid login credentials";
      }

      return success;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    }
  }
}
