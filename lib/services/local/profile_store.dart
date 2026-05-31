import 'package:shared_preferences/shared_preferences.dart';

/// Local, offline profile storage backed by [SharedPreferences].
///
/// Replaces the old Supabase `profiles` table. Holds everything the app shows
/// about the practitioner: their name, current clinic level, completed-case
/// count, an optional locally-stored avatar, and whether onboarding is done.
class ProfileStore {
  ProfileStore._();
  static final ProfileStore instance = ProfileStore._();

  static const _kOnboarded = 'onboarding_complete';
  static const _kFirstName = 'first_name';
  static const _kLastName = 'last_name';
  static const _kClinicLevel = 'clinic_level';
  static const _kCasesCompleted = 'cases_completed';
  static const _kAvatarPath = 'avatar_path';

  SharedPreferences? _prefs;
  SharedPreferences get _p {
    final p = _prefs;
    if (p == null) {
      throw StateError('ProfileStore.init() must be called before use.');
    }
    return p;
  }

  /// Must be awaited once at startup (in `main`) before any getter is read.
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // --- Reads -----------------------------------------------------------------
  bool get onboardingComplete => _p.getBool(_kOnboarded) ?? false;
  String get firstName => _p.getString(_kFirstName) ?? '';
  String get lastName => _p.getString(_kLastName) ?? '';
  String get clinicLevel => _p.getString(_kClinicLevel) ?? '';
  int get casesCompleted => _p.getInt(_kCasesCompleted) ?? 0;
  String? get avatarPath => _p.getString(_kAvatarPath);

  // --- Writes ----------------------------------------------------------------

  /// Persists the onboarding answers and marks the flow complete.
  Future<void> completeOnboarding({
    required String firstName,
    required String lastName,
    required String clinicLevel,
  }) async {
    await _p.setString(_kFirstName, firstName.trim());
    await _p.setString(_kLastName, lastName.trim());
    await _p.setString(_kClinicLevel, clinicLevel);
    await _p.setBool(_kOnboarded, true);
  }

  Future<void> setName({
    required String firstName,
    required String lastName,
  }) async {
    await _p.setString(_kFirstName, firstName.trim());
    await _p.setString(_kLastName, lastName.trim());
  }

  Future<void> setClinicLevel(String level) async {
    await _p.setString(_kClinicLevel, level);
  }

  Future<void> setAvatarPath(String path) async {
    await _p.setString(_kAvatarPath, path);
  }

  Future<void> incrementCasesCompleted() async {
    await _p.setInt(_kCasesCompleted, casesCompleted + 1);
  }
}
