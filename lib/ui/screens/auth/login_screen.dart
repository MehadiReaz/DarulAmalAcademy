import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import 'forgot_password_screen.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  /// The backend supports both `/auth/send-otp` + `/auth/verify-otp` and
  /// `/auth/login-with-password`. OTP stays the default; password is the
  /// escape hatch when SMS does not arrive.
  bool _usePassword = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    final phone = _phoneController.text.trim();

    if (_usePassword) {
      final ok = await auth.loginWithPassword(
        phone: phone,
        password: _passwordController.text,
      );
      if (!mounted) return;
      // On success the root gate swaps to the shell on its own, so there
      // is nothing to navigate to here.
      if (!ok) _showError(auth.error ?? 'Could not sign you in');
      return;
    }

    final ok = await auth.sendOtp(phone);
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const OtpScreen()),
      );
    } else {
      _showError(auth.error ?? 'Could not send OTP');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  void _forgotPassword() {
    final phone = _phoneController.text.trim();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(initialPhone: phone),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/darulamal-1.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Assalamu Alaikum',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _usePassword
                        ? 'Sign in with your mobile number and password'
                        : 'Sign in with your mobile number to continue',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 30),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                      LengthLimitingTextInputFormatter(20),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Mobile Number',
                      hintText: '1XXX XXXXXX',
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(left: 16, right: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '+91',
                              style: TextStyle(
                                color: AppColors.cream,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            SizedBox(width: 10),
                            SizedBox(
                              height: 20,
                              child: VerticalDivider(
                                color: AppColors.line,
                                width: 1,
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      prefixIconConstraints: BoxConstraints(
                        minWidth: 0,
                        minHeight: 0,
                      ),
                    ),
                    validator: (value) {
                      final v = value?.trim() ?? '';
                      if (v.isEmpty) return 'Enter your mobile number';
                      if (v.length < 7) return 'That number looks too short';
                      return null;
                    },
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (_usePassword) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (!_usePassword) return null;
                        final v = value ?? '';
                        if (v.isEmpty) return 'Enter your password';
                        if (v.length < 6) return 'That password looks too short';
                        return null;
                      },
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: auth.busy ? null : _forgotPassword,
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  AppButton(
                    label: _usePassword ? 'Sign In' : 'Send OTP',
                    loading: auth.busy,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: auth.busy
                        ? null
                        : () {
                            context.read<AuthProvider>().clearError();
                            setState(() => _usePassword = !_usePassword);
                          },
                    child: Text(
                      _usePassword
                          ? 'Sign in with an OTP instead'
                          : 'Sign in with a password instead',
                      style: const TextStyle(
                        color: AppColors.goldLight,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Only registered students can log in.\nContact your madrasah if you need access.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.muted, fontSize: 12, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
