import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../data/clinical_checklist.dart';
import '../services/local/profile_store.dart';

// Palette ---------------------------------------------------------------------
const _bgColor = Color(0xFFF8F9FF);
const _primary = Color(0xFF5D4B8A);
const _purpleDeep = Color(0xFF8F6BFF);
const _gold = Color(0xFFf7e4b0);
const _border = Color(0xFFE6E1F5);

/// First-launch flow. Collects the practitioner's name (screen 1) and clinic
/// level (screen 2), persists them locally, then enters the app. Shown only
/// while [ProfileStore.onboardingComplete] is false.
class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final _pageCtl = PageController();
  final _firstCtl = TextEditingController();
  final _lastCtl = TextEditingController();

  int _page = 0;
  String _clinicLevel = ClinicalChecklist.levels.first;
  bool _saving = false;

  @override
  void dispose() {
    _pageCtl.dispose();
    _firstCtl.dispose();
    _lastCtl.dispose();
    super.dispose();
  }

  void _toClinicLevel() {
    if (_firstCtl.text.trim().isEmpty || _lastCtl.text.trim().isEmpty) {
      Fluttertoast.showToast(
        msg: 'Please enter your first and last name',
        backgroundColor: Colors.red.shade700,
        textColor: Colors.white,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }
    FocusScope.of(context).unfocus();
    _pageCtl.animateToPage(
      1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    await ProfileStore.instance.completeOnboarding(
      firstName: _firstCtl.text,
      lastName: _lastCtl.text,
      clinicLevel: _clinicLevel,
    );
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            _StepDots(current: _page),
            Expanded(
              child: PageView(
                controller: _pageCtl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _NamePage(
                    firstCtl: _firstCtl,
                    lastCtl: _lastCtl,
                    onNext: _toClinicLevel,
                  ),
                  _ClinicLevelPage(
                    selected: _clinicLevel,
                    onSelect: (v) => setState(() => _clinicLevel = v),
                    onBack: () => _pageCtl.animateToPage(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    ),
                    onFinish: _finish,
                    saving: _saving,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Screen 1 — Name
// =============================================================================
class _NamePage extends StatelessWidget {
  final TextEditingController firstCtl;
  final TextEditingController lastCtl;
  final VoidCallback onNext;

  const _NamePage({
    required this.firstCtl,
    required this.lastCtl,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Logo(),
          const SizedBox(height: 24),
          const _Title('Welcome to Toothly'),
          const SizedBox(height: 6),
          const _Subtitle("Let's set up your profile. What's your name?"),
          const SizedBox(height: 28),
          const _FieldLabel('First name'),
          _RoundedField(
            controller: firstCtl,
            hint: 'Juan',
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          const _FieldLabel('Last name'),
          _RoundedField(
            controller: lastCtl,
            hint: 'Dela Cruz',
            icon: Icons.badge_outlined,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onNext(),
          ),
          const SizedBox(height: 28),
          _PrimaryButton(label: 'Continue', onPressed: onNext),
        ],
      ),
    );
  }
}

// =============================================================================
// Screen 2 — Clinic level
// =============================================================================
class _ClinicLevelPage extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onBack;
  final VoidCallback onFinish;
  final bool saving;

  const _ClinicLevelPage({
    required this.selected,
    required this.onSelect,
    required this.onBack,
    required this.onFinish,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Logo(),
          const SizedBox(height: 24),
          const _Title('Your clinic level'),
          const SizedBox(height: 6),
          const _Subtitle('Pick the clinic level you are currently in.'),
          const SizedBox(height: 28),
          for (final level in ClinicalChecklist.levels) ...[
            _LevelTile(
              level: level,
              selected: level == selected,
              onTap: () => onSelect(level),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 16),
          _PrimaryButton(
            label: 'Get started',
            loading: saving,
            onPressed: onFinish,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: saving ? null : onBack,
            style: TextButton.styleFrom(foregroundColor: _primary),
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final String level;
  final bool selected;
  final VoidCallback onTap;

  const _LevelTile({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: selected ? _purpleDeep : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _gold : _border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? Colors.white : _primary,
            ),
            const SizedBox(width: 14),
            Text(
              level,
              style: TextStyle(
                color: selected ? Colors.white : _primary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Shared building blocks
// =============================================================================
class _StepDots extends StatelessWidget {
  final int current;
  const _StepDots({required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? _purpleDeep : _border,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: _gold, width: 3),
          boxShadow: [
            BoxShadow(
              color: _purpleDeep.withValues(alpha: 0.15),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: ClipOval(
          child: Image.asset('assets/img/logo.png', fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _primary,
          fontFamily: 'Roboto',
          fontSize: 24,
          letterSpacing: 0.6,
        ),
      );
}

class _Subtitle extends StatelessWidget {
  final String text;
  const _Subtitle(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 13,
          fontFamily: 'Roboto',
        ),
      );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 6, bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            color: _primary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class _RoundedField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  const _RoundedField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      cursorColor: _primary,
      textInputAction: textInputAction,
      textCapitalization: TextCapitalization.words,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: _primary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(icon, color: _primary, size: 20),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 44, minHeight: 44),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _purpleDeep, width: 1.6),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _purpleDeep.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _purpleDeep,
          disabledBackgroundColor: _purpleDeep.withValues(alpha: 0.6),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _gold, width: 1.5),
          ),
        ),
        child: loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Roboto',
                  fontSize: 16,
                  letterSpacing: 0.6,
                ),
              ),
      ),
    );
  }
}
