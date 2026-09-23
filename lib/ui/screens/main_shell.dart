import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/shell_provider.dart';
import 'courses/my_courses_screen.dart';
import 'home/home_tab.dart';
import 'profile/profile_tab.dart';
import 'quran/quran_tab.dart';

/// Persistent bottom-nav shell with 4 tabs:
/// Home, Courses, Qur'an, Profile.
class MainShell extends StatelessWidget {
  const MainShell({super.key});

  static const _tabs = [
    HomeTab(),
    MyCoursesScreen(),
    QuranTab(),
    ProfileTab(),
  ];

  Future<void> _handlePopInvoked(BuildContext context, bool didPop) async {
    if (didPop) return;

    final shell = context.read<ShellProvider>();
    if (shell.index != ShellTab.home) {
      shell.goTo(ShellTab.home);
      return;
    }

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Exit App?'),
        content: const Text(
          'Are you sure you want to exit the application?',
          style: TextStyle(color: AppColors.muted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Exit',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = context.select<ShellProvider, int>((p) => p.index);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) =>
          _handlePopInvoked(context, didPop),
      child: Scaffold(
        body: IndexedStack(index: index, children: _tabs),
        bottomNavigationBar: _CaretNavBar(
          index: index,
          onTap: (i) => context.read<ShellProvider>().goTo(i),
        ),
      ),
    );
  }
}

class _CaretNavBar extends StatelessWidget {
  const _CaretNavBar({
    required this.index,
    required this.onTap,
  });

  final int index;
  final ValueChanged<int> onTap;

  static const _icons = [
    Icons.home_outlined,
    Icons.school_outlined,
    Icons.menu_book_outlined,
    Icons.person_outline_rounded,
  ];

  static const _labels = ['Home', 'Courses', "Qur'an", 'Profile'];

  static const _barHeight = 64.0;
  static const _caretWidth = 12.0;
  static const _caretHeight = 6.0;
  static const _radius = 28.0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: SizedBox(
            height: _barHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final slot = constraints.maxWidth / _icons.length;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      top: 0,
                      left: slot * index + (slot - _caretWidth) / 2,
                      child: const CustomPaint(
                        size: Size(_caretWidth, _caretHeight),
                        painter: _CaretPainter(AppColors.navAccent),
                      ),
                    ),
                    Row(
                      children: List.generate(_icons.length, (i) {
                        final selected = i == index;
                        final icon = Icon(
                          _icons[i],
                          size: 24,
                          color: selected
                              ? AppColors.navAccent
                              : AppColors.navInactive,
                        );
                        return Expanded(
                          child: Semantics(
                            label: _labels[i],
                            button: true,
                            selected: selected,
                            child: InkResponse(
                              onTap: () => onTap(i),
                              radius: _barHeight / 2,
                              child: Center(child: icon),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CaretPainter extends CustomPainter {
  const _CaretPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CaretPainter oldDelegate) => oldDelegate.color != color;
}
