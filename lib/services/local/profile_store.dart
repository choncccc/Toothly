import 'package:shared_preferences/shared_preferences.dart';

/// Local, offline profile storage backed by [SharedPreferences].
///
/// Replaces the old Supabase `profiles` table. Holds everything the app shows
/// about the practitioner: their client-assigned user code, current clinic
/// level, completed-case count, an optional locally-stored avatar, and whether
/// onboarding is done.
class ProfileStore {
  ProfileStore._();
  static final ProfileStore instance = ProfileStore._();

  static const _kOnboarded = 'onboarding_complete';
  static const _kUserCode = 'user_code';
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

  /// The raw 2-digit code the client assigns to each user (e.g. `01`).
  String get userCode => _p.getString(_kUserCode) ?? '';

  /// The label shown across the app, e.g. `User01`. Empty when no code is set.
  String get displayName => userCode.isEmpty ? '' : 'User$userCode';

  String get clinicLevel => _p.getString(_kClinicLevel) ?? '';
  int get casesCompleted => _p.getInt(_kCasesCompleted) ?? 0;
  String? get avatarPath => _p.getString(_kAvatarPath);

  // --- Writes ----------------------------------------------------------------

  /// Persists the onboarding answers and marks the flow complete.
  Future<void> completeOnboarding({
    required String userCode,
    required String clinicLevel,
  }) async {
    await _p.setString(_kUserCode, _normalizeCode(userCode));
    await _p.setString(_kClinicLevel, clinicLevel);
    await _p.setBool(_kOnboarded, true);
  }

  Future<void> setUserCode(String code) async {
    await _p.setString(_kUserCode, _normalizeCode(code));
  }

  /// Keeps only digits and zero-pads to two characters (e.g. `1` -> `01`).
  static String _normalizeCode(String code) {
    final digits = code.replaceAll(RegExp(r'\D'), '');
    return digits.padLeft(2, '0');
  }

  Future<void> setClinicLevel(String level) async {
    await _p.setString(_kClinicLevel, level);
  }

  Future<void> setAvatarPath(String path) async {
    await _p.setString(_kAvatarPath, path);
  }
}
