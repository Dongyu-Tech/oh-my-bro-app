import 'package:flutter/material.dart';

/// App-level focus guard.
///
/// Centralises the rule "a focused text input should be dismissed when
/// navigation changes, when the software keyboard is hidden, or when the user
/// taps away" instead of wrapping every page in its own `GestureDetector`.
///
/// Pieces that work together:
/// * [appKeyboardFocusRouteObserver] — register it on the router so route
///   pushes/pops/removes/replaces drop the primary focus.
/// * [AppKeyboardFocusGuard] — wrap the app child (via `MaterialApp.router`'s
///   `builder`) so that dismissing the keyboard drops focus, and a tap on any
///   non-interactive area drops focus (handy on iOS, which has no system "hide
///   keyboard" key).
/// * Call [dismissPrimaryFocus] directly from any in-app transition the route
///   observer can't see — e.g. swiping between tabs in a `PageView`.

/// Shared route observer that unfocuses whenever the navigation stack changes.
/// Register it once in the app router.
final appKeyboardFocusRouteObserver = AppKeyboardFocusRouteObserver();

/// Drops the current primary focus if anything is focused, hiding the keyboard.
void dismissPrimaryFocus() {
  final primaryFocus = FocusManager.instance.primaryFocus;
  if (primaryFocus == null || !primaryFocus.hasFocus) {
    return;
  }

  primaryFocus.unfocus();
}

/// [NavigatorObserver] that dismisses focus on every navigation change.
class AppKeyboardFocusRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    dismissPrimaryFocus();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    dismissPrimaryFocus();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    dismissPrimaryFocus();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    dismissPrimaryFocus();
  }
}

/// Wraps the app child and dismisses the primary focus once the software
/// keyboard finishes hiding (e.g. system back gesture or the keyboard's
/// "done" button), so a stale focus ring is never left behind.
class AppKeyboardFocusGuard extends StatefulWidget {
  const AppKeyboardFocusGuard({required this.child, super.key});

  final Widget child;

  @override
  State<AppKeyboardFocusGuard> createState() => _AppKeyboardFocusGuardState();
}

class _AppKeyboardFocusGuardState extends State<AppKeyboardFocusGuard>
    with WidgetsBindingObserver {
  bool _isKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final bottomInset = _currentBottomViewInset();
    if (bottomInset == null) {
      return;
    }

    final wasKeyboardVisible = _isKeyboardVisible;
    _isKeyboardVisible = bottomInset > 0;
    // Only act on the keyboard transitioning from visible -> hidden.
    if (!wasKeyboardVisible || _isKeyboardVisible) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && (_currentBottomViewInset() ?? 0) == 0) {
        dismissPrimaryFocus();
      }
    });
  }

  double? _currentBottomViewInset() {
    final view = View.maybeOf(context);
    if (view == null) {
      return null;
    }

    return view.viewInsets.bottom / view.devicePixelRatio;
  }

  @override
  Widget build(BuildContext context) {
    // A tap on any area not claimed by a child (button, field, …) drops focus.
    // Translucent so children still receive their own gestures and scrolling is
    // unaffected. On iOS — which has no system "hide keyboard" key — this is the
    // main way to dismiss, alongside the route/metrics/page-change hooks.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: dismissPrimaryFocus,
      child: widget.child,
    );
  }
}
