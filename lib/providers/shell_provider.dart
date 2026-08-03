import 'package:flutter/foundation.dart';

/// Indexes of the bottom-nav destinations in `MainShell`.
///
/// Named rather than magic numbers so the Home tab's quick actions can
/// jump to a sibling tab without hardcoding an integer that silently
/// breaks the day someone reorders the nav bar.
class ShellTab {
  ShellTab._();

  static const int home = 0;
  static const int quran = 1;
  static const int chat = 2;
  static const int profile = 3;

  static const int count = 4;
}

/// Owns which bottom-nav tab is selected.
///
/// Previously `MainShell` kept this in local state, so the Home tab's
/// "My Class" / "Notice" / "Qur'an" tiles could not actually navigate —
/// they showed a snackbar telling the student to tap the tab themselves.
/// Lifting the index into a provider lets any descendant switch tabs.
class ShellProvider extends ChangeNotifier {
  int _index = ShellTab.home;

  int get index => _index;

  void goTo(int index) {
    if (index < 0 || index >= ShellTab.count) return;
    if (_index == index) return;
    _index = index;
    notifyListeners();
  }

  /// Called on logout so the next session starts on Home.
  void reset() {
    if (_index == ShellTab.home) return;
    _index = ShellTab.home;
    notifyListeners();
  }
}
