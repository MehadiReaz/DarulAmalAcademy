import 'package:flutter/widgets.dart';

/// Window-size breakpoints (Material 3 window size classes).
///
/// Decisions use the *current window width*, not the device type, so a
/// tablet in split-screen gets the phone layout and a phone in landscape
/// gets a wider one.
class Responsive {
  Responsive._();

  /// Below this the app is laid out as on a phone.
  static const double medium = 600;

  /// At or above this there is room for a navigation rail beside content.
  static const double expanded = 840;

  /// Default cap for reading-width content (lists, forms, detail pages).
  static const double contentMaxWidth = 760;

  /// Cap for card grids, which use the extra width for more columns.
  static const double gridMaxWidth = 1200;

  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;

  static bool isCompact(BuildContext context) => width(context) < medium;

  static bool isExpanded(BuildContext context) => width(context) >= expanded;

  /// True for tablets (by the device's shorter side), regardless of the
  /// current orientation or window size.
  static bool isTabletDevice(Size logicalScreenSize) =>
      logicalScreenSize.shortestSide >= medium;

  /// Columns for a grid of items at least [minItemWidth] wide.
  static int columns(
    double availableWidth, {
    required double minItemWidth,
    int min = 1,
    int max = 6,
  }) =>
      (availableWidth / minItemWidth).floor().clamp(min, max);
}

/// Centers [child] and caps its width on wide windows; a no-op on phones.
///
/// Wrap a Scaffold `body` with it so tablet content stays at a readable
/// width while the app bar and background still span the screen.
class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = Responsive.contentMaxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
