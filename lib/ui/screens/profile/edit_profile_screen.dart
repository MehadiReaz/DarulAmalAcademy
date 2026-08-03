import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';

/// Edit the fields `POST /auth/student/profile` accepts: name, email,
/// phone, address, date_of_birth, gender, blood_group, and photo.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _dobController;
  String? _gender;
  String? _bloodGroup;
  String? _selectedPhotoPath;

  static const _genders = ['male', 'female'];
  static const _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
  ];

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;

    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _addressController = TextEditingController(text: user?.address ?? '');
    _dobController = TextEditingController(text: user?.dateOfBirth ?? '');

    final gender = user?.gender?.toLowerCase();
    if (gender != null && _genders.contains(gender)) _gender = gender;

    final blood = user?.bloodGroup?.toUpperCase().replaceAll(' ', '');
    if (blood != null && _bloodGroups.contains(blood)) _bloodGroup = blood;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.single.path;
        if (path != null && path.isNotEmpty) {
          setState(() => _selectedPhotoPath = path);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not pick image: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    DateTime initial = DateTime(now.year - 12);
    final existing = DateTime.tryParse(_dobController.text.trim());
    if (existing != null && existing.isBefore(now)) initial = existing;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: now,
    );
    if (picked != null) {
      final m = picked.month.toString().padLeft(2, '0');
      final d = picked.day.toString().padLeft(2, '0');
      _dobController.text = '${picked.year}-$m-$d';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    final ok = await auth.updateProfile(
      name: _nameController.text,
      email: _emailController.text,
      phone: _phoneController.text,
      address: _addressController.text,
      dateOfBirth: _dobController.text,
      gender: _gender,
      bloodGroup: _bloodGroup,
      photoPath: _selectedPhotoPath,
    );

    if (!mounted) return;

    if (ok) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Could not update profile'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: AppColors.gold.withAlpha(38),
                    backgroundImage: _selectedPhotoPath != null
                        ? FileImage(File(_selectedPhotoPath!))
                        : (user?.profilePhotoUrl != null &&
                                user!.profilePhotoUrl!.isNotEmpty
                            ? NetworkImage(user.profilePhotoUrl!)
                                as ImageProvider
                            : null),
                    child: (_selectedPhotoPath == null &&
                            (user?.profilePhotoUrl == null ||
                                user!.profilePhotoUrl!.isEmpty))
                        ? const Icon(Icons.person_rounded,
                            size: 48, color: AppColors.gold)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: _pickPhoto,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 16,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full Name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email Address'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Address',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dobController,
              readOnly: true,
              onTap: _pickDate,
              decoration: const InputDecoration(
                labelText: 'Date of Birth',
                hintText: 'YYYY-MM-DD',
                suffixIcon: Icon(Icons.calendar_today_rounded,
                    size: 18, color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 18),
            const _FieldLabel('Gender'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 9,
              children: _genders.map((g) {
                final selected = _gender == g;
                return ChoiceChip(
                  label: Text(g[0].toUpperCase() + g.substring(1)),
                  selected: selected,
                  onSelected: (_) => setState(() => _gender = g),
                  backgroundColor: AppColors.surface,
                  selectedColor: AppColors.gold,
                  side: const BorderSide(color: AppColors.line),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color:
                        selected ? const Color(0xFF231600) : AppColors.muted,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            const _FieldLabel('Blood Group'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _bloodGroups.map((b) {
                final selected = _bloodGroup == b;
                return ChoiceChip(
                  label: Text(b),
                  selected: selected,
                  // Tapping the selected chip clears it, so a student can
                  // undo a mis-tap without leaving the screen.
                  onSelected: (_) =>
                      setState(() => _bloodGroup = selected ? null : b),
                  backgroundColor: AppColors.surface,
                  selectedColor: AppColors.gold,
                  side: const BorderSide(color: AppColors.line),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color:
                        selected ? const Color(0xFF231600) : AppColors.muted,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            AppButton(
              label: 'Save Changes',
              loading: auth.busy,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
