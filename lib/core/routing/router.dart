import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:heymybro/shared/models/auth_user_model.dart';
import 'package:heymybro/shared/pages/app_shell.dart';
import 'package:heymybro/shared/pages/debt_confirm_page.dart';
import 'package:heymybro/shared/pages/friend_ledger_page.dart';
import 'package:heymybro/shared/pages/friend_detail_page.dart';
import 'package:heymybro/shared/pages/gatherings_list_page.dart';
import 'package:heymybro/shared/pages/group_detail_page.dart';
import 'package:heymybro/shared/pages/handle_setup_page.dart';
import 'package:heymybro/shared/pages/join_room_page.dart';
import 'package:heymybro/shared/pages/new_group_page.dart';
import 'package:heymybro/shared/pages/onboarding_page.dart';
import 'package:heymybro/shared/pages/profile_edit_page.dart';
import 'package:heymybro/shared/pages/record_page.dart';
import 'package:heymybro/shared/pages/room_page.dart';
import 'package:heymybro/shared/pages/scan_page.dart';
import 'package:heymybro/shared/provider/auth_provider.dart';
import 'package:heymybro/shared/provider/user_provider.dart';
import 'package:heymybro/shared/widgets/app_keyboard_focus_guard.dart';

/// App router, exposed as a provider so its redirect guard can read live auth
/// state. A single [GoRouter] is kept (not rebuilt on every auth change) and
/// re-evaluates [GoRouter.redirect] via [refreshListenable].
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authServiceProvider);

  final refresh = _AuthRefreshNotifier(auth.userChanges);
  ref.onDispose(refresh.dispose);

  // The handle gate is driven by an async profile fetch, so the redirect can't
  // read it from `auth` alone. Nudging the same listenable makes GoRouter
  // re-run redirect once the profile lands, without rebuilding the router.
  ref.listen(needsHandleProvider, (_, __) => refresh.bump());

  return GoRouter(
    initialLocation: '/onboarding',
    refreshListenable: refresh,
    // Dismiss any focused text input whenever the navigation stack changes.
    observers: [appKeyboardFocusRouteObserver],
    // Two gates, in order. Auth: signed-out users are pinned to /onboarding,
    // signed-in users are kept out of it (cold-start session restore lands here
    // too). Handle: a signed-in user without one is pinned to /handle, because
    // nobody can find them until they pick it.
    redirect: (context, state) {
      final signedIn = auth.currentUser != null;
      final at = state.matchedLocation;

      if (!signedIn) return at == '/onboarding' ? null : '/onboarding';
      if (at == '/onboarding') return '/';

      // `ref.read`, not `watch`: this closure must not re-create the router.
      // needsHandleProvider stays false while the profile is loading and when
      // there is no backend, so neither state can trap anyone here.
      final needsHandle = ref.read(needsHandleProvider);
      if (needsHandle && at != '/handle') return '/handle';
      if (!needsHandle && at == '/handle') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const AppShell()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingPage()),
      // One-time gate: pick the handle other people search you by.
      GoRoute(path: '/handle', builder: (_, __) => const HandleSetupPage()),
      GoRoute(
        path: '/profile/edit',
        builder: (_, __) => const ProfileEditPage(),
      ),

      // Split-the-bill circles. `/group/new` is listed before `/group/:id` so
      // the literal path wins over the param.
      GoRoute(path: '/group/new', builder: (_, __) => const NewGroupPage()),
      // Invite-first room screen (big code + QR) for a gathering.
      GoRoute(
        path: '/group/:id/room',
        builder: (_, state) => RoomPage(groupId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/group/:id',
        builder: (_, state) =>
            GroupDetailPage(groupId: state.pathParameters['id']!),
      ),
      // Join a gathering by typing its room code.
      GoRoute(path: '/join', builder: (_, __) => const JoinRoomPage()),
      // Camera QR scanner; pops a ScannedFriend to whoever pushed it.
      GoRoute(path: '/scan', builder: (_, __) => const ScanPage()),
      // Unified record form (personal / into a circle), pushed from home.
      GoRoute(path: '/record', builder: (_, __) => const RecordPage()),
      // A debt awaiting an answer, opened automatically by DebtPopupHost the
      // moment one arrives and tappable from 帳本's 待確認 block.
      GoRoute(
        path: '/debt/:id',
        builder: (_, state) =>
            DebtConfirmPage(proposalId: state.pathParameters['id']!),
      ),

      // All gatherings (active + archived), pushed from the home "view all".
      GoRoute(
        path: '/gatherings',
        builder: (_, __) => const GatheringsListPage(),
      ),
      // A friend's comic credit report.
      GoRoute(
        path: '/friend/:id',
        builder: (_, state) =>
            FriendDetailPage(friendId: state.pathParameters['id']!),
      ),

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

  /// Re-run the redirect for a reason other than an auth change — currently the
  /// profile arriving, which is what decides the handle gate.
  void bump() => notifyListeners();

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
