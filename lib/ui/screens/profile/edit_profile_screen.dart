import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_toast.dart';

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
      AppToast.showError(context, 'Could not pick image: $e');
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
      Navigator.of(context).pop();
      AppToast.showSuccess(context, 'Profile updated successfully');
    } else {
      AppToast.showError(context, auth.error ?? 'Could not update profile');
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
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
          children: [
            // Avatar Upload Picker Card
            Center(
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3.5),
                        decoration: BoxDecoration(
                          gradient: AppColors.goldGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.22),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.surface,
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
                              ? const Icon(
                                  Icons.person_rounded,
                                  size: 50,
                                  color: AppColors.gold,
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: InkWell(
                          onTap: _pickPhoto,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.bgDeep,
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 16,
                              color: Color(0xFF231600),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Tap camera icon to change profile photo',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 1: Basic Information
            const _FormSectionHeader(title: 'BASIC INFORMATION'),
            const SizedBox(height: 10),
            _FormContainer(
              children: [
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone_outlined, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Section 2: Address & Date of Birth
            const _FormSectionHeader(title: 'PERSONAL & ADDRESS'),
            const SizedBox(height: 10),
            _FormContainer(
              children: [
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _dobController,
                  readOnly: true,
                  onTap: _pickDate,
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth',
                    hintText: 'YYYY-MM-DD',
                    prefixIcon: Icon(Icons.cake_outlined, size: 20),
                    suffixIcon: Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Section 3: Additional Options
            const _FormSectionHeader(title: 'ADDITIONAL DETAILS'),
            const SizedBox(height: 10),
            _FormContainer(
              children: [
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
                      backgroundColor: AppColors.bgDeep,
                      selectedColor: AppColors.gold,
                      side: const BorderSide(color: AppColors.line),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? const Color(0xFF231600)
                            : AppColors.muted,
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
                      onSelected: (_) => setState(
                        () => _bloodGroup = selected ? null : b,
                      ),
                      backgroundColor: AppColors.bgDeep,
                      selectedColor: AppColors.gold,
                      side: const BorderSide(color: AppColors.line),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? const Color(0xFF231600)
                            : AppColors.muted,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 30),

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

class _FormSectionHeader extends StatelessWidget {
  final String title;
  const _FormSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: AppColors.gold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _FormContainer extends StatelessWidget {
  final List<Widget> children;
  const _FormContainer({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
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

