import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/core/routing/router.dart';
import 'package:heymybro/shared/pages/debt_confirm_page.dart';
import 'package:heymybro/shared/provider/database_provider.dart';
import 'package:heymybro/shared/provider/debt_provider.dart';
import 'package:heymybro/shared/provider/friend_provider.dart';
import 'package:heymybro/shared/repositories/debt_repository.dart';
import 'package:heymybro/shared/widgets/back_button.dart';
import 'package:heymybro/shared/widgets/debt_popup_host.dart';

/// Drives what the host sees as "next to open", so a proposal can arrive
/// mid-test — the only way to exercise "don't interrupt typing".
class _NextNotifier extends Notifier<DebtProposal?> {
  @override
  DebtProposal? build() => null;

  void queue(DebtProposal? proposal) => state = proposal;
}

final _testNext = NotifierProvider<_NextNotifier, DebtProposal?>(
  _NextNotifier.new,
);

/// Drives the "they agreed" announcements the same way.
class _ConfirmationsNotifier extends Notifier<List<DebtProposal>> {
  @override
  List<DebtProposal> build() => const [];

  void queue(List<DebtProposal> rows) => state = rows;
}

final _confirmations =
    NotifierProvider<_ConfirmationsNotifier, List<DebtProposal>>(
      _ConfirmationsNotifier.new,
    );

/// Records what the host asked the service to do, and never starts a real
/// subscription.
class _SpyDebtService extends DebtService {
  // Not `super.ref`: DebtService keeps its Ref private to its own library, so
  // the spy needs its own copy to reach the test's provider.
  // ignore: use_super_parameters
  _SpyDebtService(Ref ref) : _ref = ref, super(ref);

  final Ref _ref;
  final popped = <String>[];
  final confirmAlertsSeen = <String>[];
  int refreshes = 0;

  @override
  void start() {}

  @override
  Future<void> refresh() async => refreshes++;

  @override
  Future<void> markConfirmAlertSeen(String id) async {
    confirmAlertsSeen.add(id);
    _ref.read(_confirmations.notifier).queue(const []);
  }

  @override
  Future<void> markPopped(String id) async {
    popped.add(id);
    // The real one writes poppedAt, which is what drops the proposal out of
    // the queue. Without modelling that, the host would immediately reopen it.
    _ref.read(_testNext.notifier).queue(null);
  }
}

/// A debt the other side has just agreed to, not yet announced here.
DebtProposal _confirmed({String id = 'c1'}) => DebtProposal(
  id: id,
  proposerId: 'me',
  counterpartyId: 'them',
  debtorId: 'them',
  title: '晚餐',
  amount: 500,
  status: 'confirmed',
  round: 0,
  otherName: '阿華',
  createdAt: DateTime(2026, 8, 15),
  updatedAt: DateTime(2026, 8, 15),
  resolvedAt: DateTime(2026, 8, 15),
);

DebtProposal _proposal({String id = 'p1'}) => DebtProposal(
  id: id,
  proposerId: 'them',
  counterpartyId: 'me',
  debtorId: 'me',
  title: '晚餐',
  amount: 500,
  status: 'pending',
  awaitingId: 'me',
  round: 0,
  otherName: '阿華',
  createdAt: DateTime(2026, 8, 15),
  updatedAt: DateTime(2026, 8, 15),
);

void main() {
  late AppDatabase db;
  late _SpyDebtService spy;

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    bool withTextField = false,
  }) async {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Mirrors app.dart: the host wraps the router's output, which is exactly
    // why it has to push through GoRouter rather than Navigator.of.
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: withTextField
                ? const TextField(key: Key('field'))
                // Keyed so a test can prove the page did not shift.
                : const SizedBox.expand(key: Key('page-marker')),
          ),
        ),
        GoRoute(
          path: '/debt/:id',
          builder: (_, state) =>
              DebtConfirmPage(proposalId: state.pathParameters['id']!),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          myUserIdProvider.overrideWithValue('me'),
          routerProvider.overrideWithValue(router),
          debtRepositoryProvider.overrideWithValue(
            const UnavailableDebtRepository(),
          ),
          debtServiceProvider.overrideWith((ref) => spy = _SpyDebtService(ref)),
          // Both Drift-backed streams become plain ones. Drift schedules a
          // zero-duration cleanup timer when a query stream is cancelled, and
          // the framework tears the tree down with its own final runApp and
          // then immediately asserts no timer is pending — so a live Drift
          // stream inside a ProviderScope fails that check however the test is
          // written.
          debtProposalsProvider.overrideWith(
            (ref) => Stream.value([_proposal()]),
          ),
          friendsProvider.overrideWith((ref) => Stream.value(const <Friend>[])),
          nextPopupProvider.overrideWith((ref) => ref.watch(_testNext)),
          unseenConfirmationsProvider.overrideWith(
            (ref) => ref.watch(_confirmations),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) =>
              DebtPopupHost(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
  }

  final page = find.byType(DebtConfirmPage);

  testWidgets('a proposal waiting on me opens the confirm page', (
    tester,
  ) async {
    final container = await pump(tester);
    expect(page, findsNothing);

    container.read(_testNext.notifier).queue(_proposal());
    await tester.pumpAndSettle();

    expect(page, findsOneWidget);
    // The three answers, on the page rather than in a sheet. The confirmation
    // spells out who and how much rather than just saying "accept".
    expect(find.textContaining('debt_accept_'), findsOneWidget);
    expect(find.text('debt_action_counter'), findsOneWidget);
    expect(find.text('debt_action_reject'), findsOneWidget);
  });

  testWidgets('nothing opens when nothing is waiting', (tester) async {
    await pump(tester);
    expect(page, findsNothing);
  });

  testWidgets('it does not steal the keyboard mid-sentence', (tester) async {
    final container = await pump(tester, withTextField: true);

    await tester.tap(find.byKey(const Key('field')));
    await tester.pumpAndSettle();

    // The proposal arrives while they are already typing something else.
    container.read(_testNext.notifier).queue(_proposal());
    await tester.pumpAndSettle();

    expect(
      page,
      findsNothing,
      reason: 'taking the keyboard away mid-sentence is the thing to prevent',
    );
  });

  testWidgets('it opens once the field is let go', (tester) async {
    final container = await pump(tester, withTextField: true);

    await tester.tap(find.byKey(const Key('field')));
    await tester.pumpAndSettle();
    container.read(_testNext.notifier).queue(_proposal());
    await tester.pumpAndSettle();
    expect(page, findsNothing);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    expect(page, findsOneWidget, reason: 'deferred, not dropped');
  });

  testWidgets('backing out records that it has been shown', (tester) async {
    final container = await pump(tester);
    container.read(_testNext.notifier).queue(_proposal());
    await tester.pumpAndSettle();
    expect(page, findsOneWidget);

    await tester.tap(find.byType(BrutalBackButton));
    await tester.pumpAndSettle();

    expect(page, findsNothing);
    expect(
      spy.popped,
      ['p1'],
      reason: 'otherwise it reopens itself on every launch until answered',
    );
  });

  testWidgets('the agreed alert floats over the app instead of moving it', (
    tester,
  ) async {
    final container = await pump(tester);
    final before = tester.getTopLeft(find.byKey(const Key('page-marker')));

    container.read(_confirmations.notifier).queue([_confirmed()]);
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.circleCheck), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('page-marker'))),
      before,
      reason: 'a banner that pushes the page down moves it under the reader',
    );
  });

  testWidgets('dismissing the alert marks it announced', (tester) async {
    final container = await pump(tester);
    container.read(_confirmations.notifier).queue([_confirmed()]);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pumpAndSettle();

    expect(spy.confirmAlertsSeen, ['c1']);
  });

  testWidgets('coming back from the background refetches', (tester) async {
    await pump(tester);
    final before = spy.refreshes;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(
      spy.refreshes,
      greaterThan(before),
      reason: 'what puts the newest debt on screen when the app is reopened',
    );
  });
}
