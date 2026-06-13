import 'package:go_router/go_router.dart';

import 'package:heymybro/shared/pages/app_shell.dart';
import 'package:heymybro/shared/pages/friend_ledger_page.dart';
import 'package:heymybro/shared/pages/onboarding_page.dart';
import 'package:heymybro/shared/widgets/app_keyboard_focus_guard.dart';

final router = GoRouter(
  // Boot into the onboarding gate; its non-dismissible login sheet calls
  // `go('/')` once the user signs in.
  initialLocation: '/onboarding',
  // Dismiss any focused text input whenever the navigation stack changes.
  observers: [appKeyboardFocusRouteObserver],
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
