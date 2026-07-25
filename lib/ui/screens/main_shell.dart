import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/notice_provider.dart';
import '../../providers/shell_provider.dart';
import 'classes/classes_tab.dart';
import 'home/home_tab.dart';
import 'notices/notice_tab.dart';
import 'profile/profile_tab.dart';
import 'quran/quran_tab.dart';

/// Persistent bottom-nav shell. IndexedStack keeps each tab's scroll
/// position and loaded data alive when switching.
///
/// 5 tabs matching the prototype: Home, Classes, Qur'an, Notice, Profile.
/// Support and Homework are reached from Home and Profile.
///
/// The selected index lives in [ShellProvider] rather than local state so
/// that screens nested inside a tab (the Home quick-action grid, for
/// example) can switch tabs directly.
class MainShell extends StatelessWidget {
  const MainShell({super.key});

  static const _tabs = [
    HomeTab(),
    ClassesTab(),
    QuranTab(),
    NoticeTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final index = context.select<ShellProvider, int>((p) => p.index);
    final unread = context.select<NoticeProvider, int>((p) => p.unreadCount);

    return Scaffold(
      body: IndexedStack(index: index, children: _tabs),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: Colors.white,
              indicatorColor: AppColors.goldLight.withValues(alpha: 0.28),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.goldDeep : const Color(0xFF9AA8A5),
                );
              }),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return IconThemeData(
                  size: 22,
                  color: selected ? AppColors.goldDeep : const Color(0xFF9AA8A5),
                );
              }),
            ),
            child: NavigationBar(
              height: 66,
              selectedIndex: index,
              onDestinationSelected: (i) =>
                  context.read<ShellProvider>().goTo(i),
              labelBehavior:
                  NavigationDestinationLabelBehavior.onlyShowSelected,
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  selectedIcon: Icon(Icons.calendar_month_rounded),
                  label: 'Classes',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book_rounded),
                  label: "Qur'an",
                ),
                NavigationDestination(
                  // Unread state is tracked locally — the backend always
                  // reports `is_read: false`. See ReadStateStorage.
                  icon: Badge(
                    isLabelVisible: unread > 0,
                    label: Text('$unread'),
                    backgroundColor: AppColors.danger,
                    child: const Icon(Icons.campaign_outlined),
                  ),
                  selectedIcon: const Icon(Icons.campaign_rounded),
                  label: 'Notice',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
