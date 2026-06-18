import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:heymybro/shared/models/auth_user_model.dart';
import 'package:heymybro/shared/pages/app_shell.dart';
import 'package:heymybro/shared/pages/friend_ledger_page.dart';
import 'package:heymybro/shared/pages/onboarding_page.dart';
import 'package:heymybro/shared/provider/auth_provider.dart';
import 'package:heymybro/shared/widgets/app_keyboard_focus_guard.dart';

/// App router, exposed as a provider so its redirect guard can read live auth
/// state. A single [GoRouter] is kept (not rebuilt on every auth change) and
/// re-evaluates [GoRouter.redirect] via [refreshListenable].
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authServiceProvider);

  final refresh = _AuthRefreshNotifier(auth.userChanges);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/onboarding',
    refreshListenable: refresh,
    // Dismiss any focused text input whenever the navigation stack changes.
    observers: [appKeyboardFocusRouteObserver],
    // Auth gate: signed-out users are pinned to /onboarding; signed-in users
    // are kept out of it. Session restore on cold start lands here too.
    redirect: (context, state) {
      final signedIn = auth.currentUser != null;
      final atOnboarding = state.matchedLocation == '/onboarding';
      if (!signedIn && !atOnboarding) return '/onboarding';
      if (signedIn && atOnboarding) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const AppShell()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingPage()),

      // Pass typed payloads via state.extra rather than encoding into the URL.
      GoRoute(
        path: '/circle/ledger',
        builder: (_, state) =>
            FriendLedgerPage(args: state.extra as FriendLedgerArgs),
      ),
    ],
  );
});

/// Bridges [AuthService.userChanges] to a [Listenable] so GoRouter re-runs its
/// redirect whenever the signed-in user changes (sign-in, sign-out, restore).
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Stream<AuthUserModel?> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthUserModel?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
