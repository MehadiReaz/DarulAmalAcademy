import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import 'reset_password_screen.dart';

/// Screen for verifying OTP code during Password Reset.
class ResetPasswordOtpScreen extends StatefulWidget {
  final String emailOrPhone;

  const ResetPasswordOtpScreen({
    super.key,
    required this.emailOrPhone,
  });

  @override
  State<ResetPasswordOtpScreen> createState() => _ResetPasswordOtpScreenState();
}

class _ResetPasswordOtpScreenState extends State<ResetPasswordOtpScreen> {
  final _otpController = TextEditingController();
  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();

    if (auth.devOtp != null) {
      _otpController.text = auth.devOtp!;
    }

    _startCooldown(auth.resendCooldown, silent: true);
  }

  void _startCooldown(int seconds, {bool silent = false}) {
    _timer?.cancel();
    if (seconds <= 0) return;

    if (silent) {
      _secondsLeft = seconds;
    } else {
      setState(() => _secondsLeft = seconds);
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _verifyAndProceed() {
    final code = _otpController.text.trim();
    if (code.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the verification code you received'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResetPasswordScreen(
          emailOrPhone: widget.emailOrPhone,
          otpCode: code,
        ),
      ),
    );
  }

  Future<void> _resend() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.forgotPassword(widget.emailOrPhone);
    if (!mounted) return;

    if (ok) {
      if (auth.devOtp != null) _otpController.text = auth.devOtp!;
      _startCooldown(auth.resendCooldown);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new reset code has been sent')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Could not resend reset code'),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Verify Reset Code',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.cream,
                ),
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Enter the verification code sent to\n',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    TextSpan(
                      text: widget.emailOrPhone,
                      style: const TextStyle(
                        color: AppColors.cream,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 8,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 10,
                  color: AppColors.gold,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '••••',
                ),
                onSubmitted: (_) => _verifyAndProceed(),
              ),
              const SizedBox(height: 22),
              AppButton(
                label: 'Verify & Continue',
                loading: auth.busy,
                onPressed: _verifyAndProceed,
              ),
              const SizedBox(height: 18),
              Center(
                child: _secondsLeft > 0
                    ? Text(
                        'Resend available in ${_secondsLeft}s',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12.5,
                        ),
                      )
                    : TextButton(
                        onPressed: auth.busy ? null : _resend,
                        child: const Text(
                          'Resend code',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
