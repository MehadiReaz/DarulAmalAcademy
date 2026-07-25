import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';

/// NOTE: the backend accepts name, phone, address, date_of_birth, gender and
/// blood_group — but `formatUserData()` does NOT return those fields, so we
/// cannot pre-fill them. Left blank fields are simply not sent.
/// See README "Backend notes" for the suggested fix.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _dobController = TextEditingController();
  String? _gender;

  static const _genders = ['male', 'female'];

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameController = TextEditingController(text: user?.name ?? '');
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
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 12),
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
              decoration: const InputDecoration(labelText: 'Full Name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone',
                hintText: 'Leave blank to keep unchanged',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Address',
                hintText: 'Leave blank to keep unchanged',
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
            const Text(
              'Gender',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
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
