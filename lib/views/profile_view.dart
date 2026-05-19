import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/auth_repository.dart';
import '../viewmodel/auth_viewmodel.dart';
import '../viewmodel/home_viewmodel.dart';

const _bgColor = Color(0xFFF8F9FF);
const _primary = Color(0xFF5D4B8A);
const _purpleLight = Color(0xFFB191FF);
const _purpleDeep = Color(0xFF8F6BFF);
const _gold = Color(0xFFf7e4b0);
const _border = Color(0xFFE6E1F5);

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  late final AuthRepository _repo;
  final _fNameCtl = TextEditingController();
  final _lNameCtl = TextEditingController();
  bool _savingAvatar = false;
  bool _savingProfile = false;

  @override
  void initState() {
    super.initState();
    _repo = AuthRepository(Supabase.instance.client);
    final home = context.read<HomeViewmodel>();
    _fNameCtl.text = home.fName == 'Guest' ? '' : home.fName;
    _lNameCtl.text = home.lName;
  }

  @override
  void dispose() {
    _fNameCtl.dispose();
    _lNameCtl.dispose();
    super.dispose();
  }

  String _initials(String name) {
    final cleaned = name.trim();
    if (cleaned.isEmpty) return 'U';
    final parts = cleaned.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Future<void> _changeAvatar() async {
    if (_savingAvatar) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1024,
    );
    if (picked == null) return;
    setState(() => _savingAvatar = true);
    try {
      await _repo.updateAvatar(file: File(picked.path));
      if (!mounted) return;
      await context.read<HomeViewmodel>().refresh();
      Fluttertoast.showToast(
        msg: 'Profile photo updated',
        backgroundColor: _purpleDeep,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Failed to update photo: $e',
        backgroundColor: Colors.red.shade700,
        textColor: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _savingAvatar = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_savingProfile) return;
    final fName = _fNameCtl.text.trim();
    final lName = _lNameCtl.text.trim();
    if (fName.isEmpty || lName.isEmpty) {
      Fluttertoast.showToast(
        msg: 'Name fields cannot be empty',
        backgroundColor: Colors.red.shade700,
        textColor: Colors.white,
      );
      return;
    }
    setState(() => _savingProfile = true);
    try {
      await _repo.updateProfile(firstName: fName, lastName: lName);
      if (!mounted) return;
      await context.read<HomeViewmodel>().refresh();
      Fluttertoast.showToast(
        msg: 'Profile saved',
        backgroundColor: _purpleDeep,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Save failed: $e',
        backgroundColor: Colors.red.shade700,
        textColor: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeViewmodel>();

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: _primary),
        title: const Text(
          'PROFILE',
          style: TextStyle(
            color: _primary,
            fontFamily: 'Derrick',
            fontSize: 22,
            letterSpacing: 1.4,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _AvatarHeader(
            avatarUrl: home.avatarUrl,
            initials: _initials(home.fName),
            saving: _savingAvatar,
            onTap: _changeAvatar,
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              '${home.user_type} ${home.fName}'.trim(),
              style: const TextStyle(
                color: _primary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
              ),
            ),
          ),
          if (home.email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Center(
              child: Text(
                home.email,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 13,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _InfoTile(
            label: 'Clinic level',
            value: home.clinicLevel.isEmpty
                ? 'Not set'
                : home.clinicLevel.replaceFirst('Level ', 'Clinic '),
            icon: Icons.workspace_premium_outlined,
          ),
          const SizedBox(height: 10),
          _InfoTile(
            label: 'Cases completed',
            value: home.casesCompleted.toString(),
            icon: Icons.assignment_turned_in_outlined,
          ),
          const SizedBox(height: 24),
          const Text(
            'Edit details',
            style: TextStyle(
              color: _primary,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          _LabeledField(label: 'First name', controller: _fNameCtl),
          const SizedBox(height: 10),
          _LabeledField(label: 'Last name', controller: _lNameCtl),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _savingProfile ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: _purpleDeep,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _savingProfile
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save changes',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 28),
          const Divider(color: _border),
          const SizedBox(height: 12),
          Consumer<AuthViewModel>(
            builder: (context, authVM, _) => SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: authVM.isLoading
                    ? null
                    : () async {
                        await authVM.logout(context);
                        if (!context.mounted) return;
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: authVM.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout_rounded),
                label: const Text(
                  'Log out',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarHeader extends StatelessWidget {
  final String? avatarUrl;
  final String initials;
  final bool saving;
  final VoidCallback onTap;

  const _AvatarHeader({
    required this.avatarUrl,
    required this.initials,
    required this.saving,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: saving ? null : onTap,
        child: Stack(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_purpleLight, _purpleDeep],
                ),
                border: Border.all(color: _gold, width: 3),
              ),
              alignment: Alignment.center,
              child: ClipOval(
                child: avatarUrl == null
                    ? Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      )
                    : Image.network(
                        avatarUrl!,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: _purpleDeep,
                  shape: BoxShape.circle,
                ),
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.camera_alt_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(icon, color: _primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontFamily: 'Roboto',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Roboto',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const _LabeledField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 12,
            fontFamily: 'Roboto',
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
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
              borderSide: const BorderSide(color: _purpleDeep, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
