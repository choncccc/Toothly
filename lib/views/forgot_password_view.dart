import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/auth_repository.dart';
import 'login_view.dart' show AuthBrandHeader, AuthFieldLabel,
    AuthRoundedField, AuthPrimaryButton;

const _bgColor = Color(0xFFF8F9FF);
const _primary = Color(0xFF5D4B8A);
const _purpleDeep = Color(0xFF8F6BFF);
const _border = Color(0xFFE6E1F5);

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _emailCtl = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  late final AuthRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = AuthRepository(Supabase.instance.client);
  }

  @override
  void dispose() {
    _emailCtl.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final email = _emailCtl.text.trim();
    if (email.isEmpty) {
      Fluttertoast.showToast(
        msg: 'Please enter your email',
        backgroundColor: Colors.red.shade700,
        textColor: Colors.white,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      Fluttertoast.showToast(
        msg: 'Enter a valid email address',
        backgroundColor: Colors.red.shade700,
        textColor: Colors.white,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await _repo.sendPasswordReset(email: email);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _sent = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      Fluttertoast.showToast(
        msg: e.toString().replaceFirst('Exception: ', ''),
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
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _primary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthBrandHeader(
                title: 'Reset password',
                subtitle:
                    'Enter your email and we’ll send you a reset link.',
              ),
              const SizedBox(height: 28),
              if (_sent) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _border,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.mark_email_read_rounded,
                            color: _primary, size: 28),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Check your email',
                        style: TextStyle(
                          color: _primary,
                          fontFamily: 'Derrick',
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'We sent a reset link to ${_emailCtl.text.trim()}. '
                        'Open it on this device and follow the steps.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                AuthPrimaryButton(
                  label: 'Back to sign in',
                  loading: false,
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    setState(() => _sent = false);
                  },
                  style: TextButton.styleFrom(foregroundColor: _purpleDeep),
                  child: const Text(
                    'Use a different email',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ] else ...[
                const AuthFieldLabel('Email'),
                AuthRoundedField(
                  controller: _emailCtl,
                  hint: 'you@pcc.edu.ph',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  onSubmitted: (_) => _handleSend(),
                ),
                const SizedBox(height: 20),
                AuthPrimaryButton(
                  label: 'Send reset link',
                  loading: _loading,
                  onPressed: _handleSend,
                ),
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      'Back to sign in',
                      style: TextStyle(
                        color: _primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
