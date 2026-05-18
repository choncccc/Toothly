import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/auth_repository.dart';
import '../viewmodel/login_viewmodel.dart';

// Palette ---------------------------------------------------------------------
const _bgColor = Color(0xFFF8F9FF);
const _primary = Color(0xFF5D4B8A);
const _purpleDeep = Color(0xFF8F6BFF);
const _gold = Color(0xFFf7e4b0);
const _border = Color(0xFFE6E1F5);

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  late final LoginViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = LoginViewModel(AuthRepository(Supabase.instance.client));
  }

  @override
  void dispose() {
    _emailCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_loading) return;
    setState(() => _loading = true);
    final ok = await _vm.login(_emailCtl.text, _passCtl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      Fluttertoast.showToast(
        msg: 'Welcome back',
        backgroundColor: _purpleDeep,
        textColor: Colors.white,
        gravity: ToastGravity.BOTTOM,
      );
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Fluttertoast.showToast(
        msg: _vm.errorMessage ?? 'Login failed',
        backgroundColor: Colors.red.shade700,
        textColor: Colors.white,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _BrandHeader(
                title: 'Welcome back',
                subtitle: 'Sign in to continue',
              ),
              const SizedBox(height: 28),
              const _FieldLabel('Email'),
              _RoundedField(
                controller: _emailCtl,
                hint: 'you@pcc.edu.ph',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              const _FieldLabel('Password'),
              _RoundedField(
                controller: _passCtl,
                hint: 'Enter your password',
                icon: Icons.lock_outline_rounded,
                obscureText: _obscure,
                suffix: IconButton(
                  splashRadius: 18,
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: _primary,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                onSubmitted: (_) => _handleLogin(),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/forgot-password'),
                  style: TextButton.styleFrom(foregroundColor: _primary),
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _PrimaryButton(
                label: 'Sign in',
                loading: _loading,
                onPressed: _handleLogin,
              ),
              const SizedBox(height: 24),
              _RegisterFooter(
                onTap: () => Navigator.pushNamed(context, '/register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Reusable building blocks (shared across auth screens)
// =============================================================================

class _BrandHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _BrandHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 110,
          height: 110,
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
            child: Image.asset(
              'assets/img/logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _primary,
            fontFamily: 'Derrick',
            fontSize: 26,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 13,
            fontFamily: 'Roboto',
          ),
        ),
      ],
    );
  }
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
  final Widget? suffix;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onSubmitted;

  const _RoundedField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.suffix,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      cursorColor: _primary,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: obscureText ? 1 : maxLines,
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
        suffixIcon: suffix,
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
    required this.loading,
    required this.onPressed,
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
                  fontFamily: 'Derrick',
                  fontSize: 16,
                  letterSpacing: 0.6,
                ),
              ),
      ),
    );
  }
}

class _RegisterFooter extends StatelessWidget {
  final VoidCallback onTap;
  const _RegisterFooter({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Don\'t have an account?  ',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 14,
            fontFamily: 'Roboto',
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: const Text(
            'Register',
            style: TextStyle(
              color: _primary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

// Shared header for register / forgot-password — exported via re-import.
class AuthBrandHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const AuthBrandHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) =>
      _BrandHeader(title: title, subtitle: subtitle);
}

class AuthFieldLabel extends StatelessWidget {
  final String text;
  const AuthFieldLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => _FieldLabel(text);
}

class AuthRoundedField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onSubmitted;

  const AuthRoundedField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.suffix,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) => _RoundedField(
        controller: controller,
        hint: hint,
        icon: icon,
        suffix: suffix,
        obscureText: obscureText,
        keyboardType: keyboardType,
        maxLines: maxLines,
        onSubmitted: onSubmitted,
      );
}

class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) =>
      _PrimaryButton(label: label, loading: loading, onPressed: onPressed);
}
