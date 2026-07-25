import 'package:flutter/foundation.dart';

import '../core/network/api_exception.dart';

/// Tracks the lifecycle of a single async section of a screen.
enum LoadState { idle, loading, ready, error }

/// Shared plumbing so each provider doesn't re-implement
/// loading / error / notify bookkeeping.
abstract class BaseProvider extends ChangeNotifier {
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Guards against "setState after dispose" when a request finishes
  /// after the user has already left the screen.
  void safeNotify() {
    if (!_disposed) notifyListeners();
  }

  /// Runs [action], converting any ApiException into a message string.
  /// Returns null on failure.
  Future<T?> guard<T>(
    Future<T> Function() action, {
    required void Function(LoadState state, String? error) onState,
  }) async {
    onState(LoadState.loading, null);
    safeNotify();

    try {
      final result = await action();
      onState(LoadState.ready, null);
      safeNotify();
      return result;
    } on ApiException catch (e) {
      onState(LoadState.error, e.message);
      safeNotify();
      return null;
    } catch (e) {
      onState(LoadState.error, 'Unexpected error: $e');
      safeNotify();
      return null;
    }
  }
}
