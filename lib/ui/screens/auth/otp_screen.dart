import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();

    // Convenience while the backend SMS driver is in dev mode.
    if (auth.devOtp != null) _otpController.text = auth.devOtp!;

    _startCooldown(auth.resendCooldown, silent: true);
  }

  void _startCooldown(int seconds, {bool silent = false}) {
    _timer?.cancel();
    if (seconds <= 0) return;

    // `silent` avoids calling setState() during initState().
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

  Future<void> _verify() async {
    final code = _otpController.text.trim();
    if (code.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the code you received')),
      );
      return;
    }
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyOtp(code);

    if (!mounted) return;

    if (ok) {
      // The root widget listens to AuthProvider and swaps to the shell,
      // so we just clear the auth stack.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Verification failed'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _resend() async {
    final auth = context.read<AuthProvider>();
    final phone = auth.pendingPhone;
    if (phone == null) return;

    final ok = await auth.sendOtp(phone);
    if (!mounted) return;

    if (ok) {
      if (auth.devOtp != null) _otpController.text = auth.devOtp!;
      _startCooldown(auth.resendCooldown);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new code has been sent')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Could not resend'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Verify OTP',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Enter the code sent to\n',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    TextSpan(
                      text: auth.pendingPhone ?? '',
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
                onSubmitted: (_) => _verify(),
              ),
              const SizedBox(height: 22),
              AppButton(
                label: 'Verify & Continue',
                loading: auth.busy,
                onPressed: _verify,
              ),
              const SizedBox(height: 18),
              Center(
                child: _secondsLeft > 0
                    ? Text(
                        'Resend available in ${_secondsLeft}s',
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12.5),
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
