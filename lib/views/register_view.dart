import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/auth_repository.dart';
import '../viewmodel/register_viewmodel.dart';
import 'login_view.dart' show AuthBrandHeader, AuthFieldLabel,
    AuthRoundedField, AuthPrimaryButton;

const _bgColor = Color(0xFFF8F9FF);
const _primary = Color(0xFF5D4B8A);
const _purpleDeep = Color(0xFF8F6BFF);
const _border = Color(0xFFE6E1F5);

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  static const List<String> clinicLevels = ['Level I', 'Level II', 'Level III'];

  final _fNameCtl = TextEditingController();
  final _lNameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  String? _selectedLevel;
  bool _obscure = true;
  bool _loading = false;
  File? _avatar;

  late final RegisterViewModel _vm;

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1024,
    );
    if (picked == null) return;
    setState(() => _avatar = File(picked.path));
  }

  @override
  void initState() {
    super.initState();
    _vm = RegisterViewModel(AuthRepository(Supabase.instance.client));
  }

  @override
  void dispose() {
    _fNameCtl.dispose();
    _lNameCtl.dispose();
    _emailCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_loading) return;
    setState(() => _loading = true);
    final ok = await _vm.register(
      firstName: _fNameCtl.text,
      lastName: _lNameCtl.text,
      email: _emailCtl.text,
      password: _passCtl.text,
      clinicLevel: _selectedLevel ?? '',
      avatar: _avatar,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      Fluttertoast.showToast(
        msg: 'Registered successfully',
        backgroundColor: _purpleDeep,
        textColor: Colors.white,
        gravity: ToastGravity.BOTTOM,
      );
      Navigator.pushReplacementNamed(context, '/');
    } else {
      Fluttertoast.showToast(
        msg: _vm.errorMessage ?? 'Registration failed',
        backgroundColor: Colors.red.shade700,
        textColor: Colors.white,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  void _showLevelPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select clinic level',
              style: TextStyle(
                color: _primary,
                fontFamily: 'Roboto',
                fontSize: 18,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            for (final level in clinicLevels)
              ListTile(
                onTap: () {
                  setState(() => _selectedLevel = level);
                  Navigator.pop(context);
                },
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.workspace_premium_rounded,
                      color: _primary, size: 18),
                ),
                title: Text(
                  level.replaceFirst('Level ', 'Clinician '),
                  style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: _selectedLevel == level
                    ? const Icon(Icons.check_circle_rounded, color: _purpleDeep)
                    : null,
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
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
              const AuthBrandHeader(
                title: 'Create account',
                subtitle: 'Sign up to get started with Toothly',
              ),
              const SizedBox(height: 20),
              Center(
                child: _AvatarPicker(
                  file: _avatar,
                  onTap: _pickAvatar,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AuthFieldLabel('First name'),
                        AuthRoundedField(
                          controller: _fNameCtl,
                          hint: 'Juan',
                          icon: Icons.person_outline_rounded,
                          keyboardType: TextInputType.name,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AuthFieldLabel('Last name'),
                        AuthRoundedField(
                          controller: _lNameCtl,
                          hint: 'Dela Cruz',
                          icon: Icons.person_outline_rounded,
                          keyboardType: TextInputType.name,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const AuthFieldLabel('Clinic level'),
              _LevelPickerField(
                value: _selectedLevel,
                onTap: _showLevelPicker,
              ),
              const SizedBox(height: 14),
              const AuthFieldLabel('Email'),
              AuthRoundedField(
                controller: _emailCtl,
                hint: 'you@pcc.edu.ph',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              const AuthFieldLabel('Password'),
              AuthRoundedField(
                controller: _passCtl,
                hint: 'At least 6 characters',
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
              ),
              const SizedBox(height: 24),
              AuthPrimaryButton(
                label: 'Create account',
                loading: _loading,
                onPressed: _handleRegister,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account?  ',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacementNamed(context, '/'),
                    child: const Text(
                      'Sign in',
                      style: TextStyle(
                        color: _primary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  final File? file;
  final VoidCallback onTap;
  const _AvatarPicker({required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: _border, width: 2),
            ),
            child: ClipOval(
              child: file == null
                  ? const Icon(
                      Icons.person_outline_rounded,
                      size: 44,
                      color: _primary,
                    )
                  : Image.file(
                      file!,
                      fit: BoxFit.cover,
                      width: 96,
                      height: 96,
                    ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: _purpleDeep,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelPickerField extends StatelessWidget {
  final String? value;
  final VoidCallback onTap;
  const _LevelPickerField({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final display = value == null
        ? 'Select clinic level'
        : value!.replaceFirst('Level ', 'Clinician ');
    final isPlaceholder = value == null;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              const Icon(Icons.workspace_premium_rounded,
                  color: _primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  display,
                  style: TextStyle(
                    color: isPlaceholder ? Colors.grey.shade500 : _primary,
                    fontWeight:
                        isPlaceholder ? FontWeight.normal : FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, color: _primary),
            ],
          ),
        ),
      ),
    );
  }
}
