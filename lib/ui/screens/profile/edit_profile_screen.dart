import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';

/// Edit the fields `PUT /auth/student/profile` accepts: name, phone,
/// address, date_of_birth, gender and blood_group.
///
/// These are now pre-filled. `GET /auth/student/profile` has always
/// returned them — the app's `StudentUser` model just wasn't reading the
/// nested payload, so every field came back null and the form opened
/// blank with a "leave blank to keep unchanged" hint.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _dobController;
  String? _gender;
  String? _bloodGroup;

  static const _genders = ['male', 'female'];
  static const _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
  ];

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;

    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _addressController = TextEditingController(text: user?.address ?? '');
    _dobController = TextEditingController(text: user?.dateOfBirth ?? '');

    // Only adopt the server value if it is one this form can represent —
    // otherwise the chip row would show nothing selected and silently
    // overwrite a valid value on save.
    final gender = user?.gender?.toLowerCase();
    if (gender != null && _genders.contains(gender)) _gender = gender;

    final blood = user?.bloodGroup?.toUpperCase().replaceAll(' ', '');
    if (blood != null && _bloodGroups.contains(blood)) _bloodGroup = blood;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    // Open on the student's existing date of birth when there is one.
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
      phone: _phoneController.text,
      address: _addressController.text,
      dateOfBirth: _dobController.text,
      gender: _gender,
      bloodGroup: _bloodGroup,
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

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full Name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
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
