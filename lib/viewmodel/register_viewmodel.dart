import '../repositories/auth_repository.dart';

class RegisterViewModel {
  final AuthRepository _authRepository;

  String? errorMessage;
  bool isLoading = false;

  RegisterViewModel(this._authRepository);

  Future<bool> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String year,
  }) async {
    final fName = firstName.trim();
    final lName = lastName.trim();
    final mail = email.trim();
    final pass = password.trim();

    if ([fName, lName, mail, pass].any((e) => e.isEmpty)) {
      errorMessage = "Please fill all fields";
      return false;
    }

    if (pass.length < 6) {
      errorMessage = "Password must be at least 6 characters";
      return false;
    }

    final studentRegex = RegExp(r'^\d{6}.*@pcc\.edu\.ph$');
    final teacherRegex = RegExp(r'^[a-zA-Z].*@pcc\.edu\.ph$');

    String userType = "";

    if (studentRegex.hasMatch(mail)) {
      userType = "student";
    } else if (teacherRegex.hasMatch(mail)) {
      userType = "teacher";
    } else {
      errorMessage = "Email must be a valid PCC student or teacher email";
      return false;
    }

    try {
      isLoading = true;
      await _authRepository.register(
        firstName: fName,
        lastName: lName,
        email: mail,
        password: pass,
        userType: userType,
        year: year,
      );
      isLoading = false;
      return true;
    } catch (e) {
      isLoading = false;
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    }
  }
}
