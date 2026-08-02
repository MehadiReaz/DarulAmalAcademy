import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import 'reset_password_otp_screen.dart';

/// Screen where user enters phone/email to initiate password reset.
class ForgotPasswordScreen extends StatefulWidget {
  final String? initialPhone;

  const ForgotPasswordScreen({
    super.key,
    this.initialPhone,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialPhone != null && widget.initialPhone!.isNotEmpty) {
      _inputController.text = widget.initialPhone!;
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    final input = _inputController.text.trim();

    final ok = await auth.forgotPassword(input);

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResetPasswordOtpScreen(emailOrPhone: input),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Could not start password reset'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.cream),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                const Text(
                  'Forgot Password',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.cream,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Enter your mobile number or email address below. We will send you an OTP verification code to reset your password.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.muted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 32),

                TextFormField(
                  controller: _inputController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: AppColors.cream),
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number or Email',
                    hintText: 'Enter phone or email',
                    prefixIcon: Icon(Icons.phone_iphone_rounded, color: AppColors.muted),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Enter your mobile number or email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                AppButton(
                  label: 'Send Reset Code',
                  loading: auth.busy,
                  onPressed: _sendCode,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
