import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Shown while AuthProvider.bootstrap() decides where to send the user.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.menu_book_rounded,
                  size: 38, color: Color(0xFF231600)),
            ),
            const SizedBox(height: 22),
            const Text(
              'Darul Amal Academy',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 26),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
          ],
        ),
      ),
    );
  }
}

