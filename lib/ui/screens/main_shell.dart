import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/chat_provider.dart';
import '../../providers/shell_provider.dart';
import 'chat/chat_list_screen.dart';
import 'home/home_tab.dart';
import 'profile/profile_tab.dart';
import 'quran/quran_tab.dart';

/// Persistent bottom-nav shell. IndexedStack keeps each tab's scroll
/// position and loaded data alive when switching.
///
/// 5 tabs: Home, Classes, Qur'an, Group Chat, Profile.
/// Support, Homework, and Notices are reached from Home and Profile.
///
/// The selected index lives in [ShellProvider] rather than local state so
/// that screens nested inside a tab (the Home quick-action grid, for
/// example) can switch tabs directly.
class MainShell extends StatelessWidget {
  const MainShell({super.key});

  static const _tabs = [HomeTab(), QuranTab(), ChatListScreen(), ProfileTab()];

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
    final unread = context.select<ChatProvider, int>((p) => p.totalUnread);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) =>
          _handlePopInvoked(context, didPop),
      child: Scaffold(
        body: IndexedStack(index: index, children: _tabs),
        bottomNavigationBar: _CaretNavBar(
          index: index,
          unread: unread,
          onTap: (i) => context.read<ShellProvider>().goTo(i),
        ),
      ),
    );
  }
}

/// Floating icon-only nav bar with a caret that slides to the active tab.
///
/// This replaces Material 3's [NavigationBar]. The stock widget centres its
/// destinations vertically and only supports a pill-shaped indicator behind
/// the icon, so there's no supported way to pin a caret to the top edge —
/// hence the hand-rolled Row.
///
/// Note that [NavigationBar] also grew its own height by
/// `MediaQuery.viewPaddingOf(context).bottom` for free. That's gone now, so
/// the [SafeArea] below is doing that job instead — without it the bar
/// collides with the home indicator on gesture-nav devices.
class _CaretNavBar extends StatelessWidget {
  const _CaretNavBar({
    required this.index,
    required this.unread,
    required this.onTap,
  });

  final int index;
  final int unread;
  final ValueChanged<int> onTap;

  /// The mockup keeps the active icon in its outline weight and only
  /// re-tints it, so there are no filled `selectedIcon` variants here.
  static const _icons = [
    Icons.home_outlined,
    Icons.menu_book_outlined,
    Icons.forum_outlined,
    Icons.person_outline_rounded,
  ];

  /// Labels are no longer painted — the mockup is icon-only — but they're
  /// still read out by TalkBack/VoiceOver via [Semantics].
  static const _labels = ['Home', "Qur'an", 'Group Chat', 'Profile'];

  static const _chatIndex = 3;

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
                              child: Center(
                                child: i == _chatIndex
                                    ? Badge(
                                        isLabelVisible: unread > 0,
                                        label: Text('$unread'),
                                        backgroundColor: AppColors.danger,
                                        child: icon,
                                      )
                                    : icon,
                              ),
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

/// Downward-pointing triangle pinned to the top edge of the bar.
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
