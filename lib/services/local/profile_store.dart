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
  // Per-user case counter: the full key is '<prefix><userCode>' so each user's
  // numbering is independent (user 01 -> 101.., user 03 -> 301.. from scratch).
  static const _kCaseSeqPrefix = 'case_seq_';

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

  // --- Case numbering --------------------------------------------------------

  String get _caseSeqKey => '$_kCaseSeqPrefix$userCode';

  /// Number of cases the current user has started so far.
  int get _caseSeq => _p.getInt(_caseSeqKey) ?? 0;

  /// Builds the case number for the user's [seq]-th case, e.g. user `01` ->
  /// 101, 102…; user `02` -> 201, 202… (`userCode * 100 + seq`).
  int caseNumberForSeq(int seq) => (int.tryParse(userCode) ?? 0) * 100 + seq;

  /// Every case number already created for the current user, oldest first.
  /// Used to let a patient that needs more than one form reuse the same number.
  List<int> get existingCaseNumbers => [
    for (var s = 1; s <= _caseSeq; s++) caseNumberForSeq(s),
  ];

  /// Reserves and returns the next case number for the current user, persisting
  /// the per-user counter so each new case gets a unique value across sessions.
  Future<int> allocateCaseNumber() async {
    final seq = _caseSeq + 1;
    await _p.setInt(_caseSeqKey, seq);
    return caseNumberForSeq(seq);
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
