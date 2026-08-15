import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/shared/provider/database_provider.dart';
import 'package:heymybro/shared/provider/debt_provider.dart';
import 'package:heymybro/shared/provider/friend_provider.dart';
import 'package:heymybro/shared/repositories/debt_repository.dart';
import 'package:heymybro/shared/widgets/debt_popup_host.dart';

/// Drives what the host sees as "next to pop", so a proposal can arrive
/// mid-test — which is the only way to exercise "don't interrupt typing".
class _NextNotifier extends Notifier<DebtProposal?> {
  @override
  DebtProposal? build() => null;

  void queue(DebtProposal? proposal) => state = proposal;
}

final _testNext = NotifierProvider<_NextNotifier, DebtProposal?>(
  _NextNotifier.new,
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
  int refreshes = 0;

  @override
  void start() {}

  @override
  Future<void> refresh() async => refreshes++;

  @override
  Future<void> markPopped(String id) async {
    popped.add(id);
    // The real one writes poppedAt, which is what drops the proposal out of
    // the queue. Without modelling that the host would just re-present it on
    // the next frame.
    _ref.read(_testNext.notifier).queue(null);
  }
}

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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          myUserIdProvider.overrideWithValue('me'),
          debtRepositoryProvider.overrideWithValue(
            const UnavailableDebtRepository(),
          ),
          debtServiceProvider.overrideWith((ref) => spy = _SpyDebtService(ref)),
          // Both Drift-backed streams become plain ones. Drift schedules a
          // zero-duration cleanup timer when a query stream is cancelled, and
          // the framework tears the tree down with its own final runApp and
          // then immediately asserts that no timer is pending — so any live
          // Drift stream inside a ProviderScope fails that check regardless of
          // how the test is written.
          debtProposalsProvider.overrideWith(
            (ref) => Stream.value(const <DebtProposal>[]),
          ),
          friendsProvider.overrideWith((ref) => Stream.value(const <Friend>[])),
          nextPopupProvider.overrideWith((ref) => ref.watch(_testNext)),
        ],
        child: MaterialApp(
          home: DebtPopupHost(
            child: Scaffold(
              body: withTextField
                  ? const TextField(key: Key('field'))
                  : const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
  }

  final popup = find.textContaining('debt_popup_title');

  testWidgets('a proposal waiting on me pops up', (tester) async {
    final container = await pump(tester);
    expect(popup, findsNothing);

    container.read(_testNext.notifier).queue(_proposal());
    await tester.pumpAndSettle();

    expect(popup, findsOneWidget);
    expect(find.text('debt_action_accept'), findsOneWidget);
    expect(find.text('debt_popup_later'), findsOneWidget);
  });

  testWidgets('nothing pops up when nothing is waiting', (tester) async {
    await pump(tester);
    expect(popup, findsNothing);
  });

  testWidgets('it does not steal the keyboard mid-sentence', (tester) async {
    final container = await pump(tester, withTextField: true);

    await tester.tap(find.byKey(const Key('field')));
    await tester.pumpAndSettle();

    // The proposal arrives while they are already typing something else.
    container.read(_testNext.notifier).queue(_proposal());
    await tester.pumpAndSettle();

    expect(
      popup,
      findsNothing,
      reason: 'taking the keyboard away mid-sentence is the thing to prevent',
    );
  });

  testWidgets('it pops once the field is let go', (tester) async {
    final container = await pump(tester, withTextField: true);

    await tester.tap(find.byKey(const Key('field')));
    await tester.pumpAndSettle();
    container.read(_testNext.notifier).queue(_proposal());
    await tester.pumpAndSettle();
    expect(popup, findsNothing);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    expect(popup, findsOneWidget, reason: 'deferred, not dropped');
  });

  testWidgets('dismissing it records that it has been shown', (tester) async {
    final container = await pump(tester);
    container.read(_testNext.notifier).queue(_proposal());
    await tester.pumpAndSettle();
    expect(popup, findsOneWidget);

    await tester.tap(find.text('debt_popup_later'));
    await tester.pumpAndSettle();

    expect(popup, findsNothing);
    expect(spy.popped, [
      'p1',
    ], reason: 'otherwise it re-pops on every launch until answered');
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
      reason: 'the layer that turns a dropped socket into late, not never',
    );
  });
}
