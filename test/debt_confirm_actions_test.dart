import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/core/error/result.dart';
import 'package:heymybro/shared/pages/debt_confirm_page.dart';
import 'package:heymybro/shared/provider/debt_provider.dart';
import 'package:heymybro/shared/repositories/debt_repository.dart';

DebtProposal _proposal({String? awaitingId = 'me', int? amount = 500}) =>
    DebtProposal(
      id: 'p1',
      proposerId: 'them',
      counterpartyId: 'me',
      debtorId: 'me',
      title: '晚餐',
      amount: amount,
      status: 'pending',
      awaitingId: awaitingId,
      round: 0,
      otherName: '阿華',
      createdAt: DateTime(2026, 8, 15),
      updatedAt: DateTime(2026, 8, 15),
    );

/// Holds what the page sees, so an action can change the proposal underneath
/// it exactly as a real answer does.
class _ProposalsNotifier extends Notifier<List<DebtProposal>> {
  @override
  List<DebtProposal> build() => [_proposal()];

  void set(List<DebtProposal> rows) => state = rows;
}

final _proposals = NotifierProvider<_ProposalsNotifier, List<DebtProposal>>(
  _ProposalsNotifier.new,
);

/// Set to reproduce a server refusal — which is exactly what the two-round cap
/// used to do to a second amount change.
///
/// Module level, not a field: nothing watches debtServiceProvider in these
/// tests, so it is disposed between reads and each action gets a freshly built
/// service. A flag on the instance would be set on one and read on another.
bool _refuseCounter = false;

/// Answers succeed, and — like the real thing — hand the turn to the other
/// side. That second part is the whole point: it rebuilds the action row away
/// mid-await, which is what used to swallow the close.
class _FakeDebtService extends DebtService {
  // ignore: use_super_parameters
  _FakeDebtService(Ref ref) : _ref = ref, super(ref);

  final Ref _ref;

  @override
  void start() {}

  /// The real one writes to Drift and awaits it. That await is what lets the
  /// rebuild land *inside* the action, unmounting the caller — without it the
  /// test would pass against the very bug it exists to catch.
  @override
  Future<void> refresh() async => Future<void>.delayed(Duration.zero);

  @override
  Future<Result<DebtOutcome>> counter(String id, int amount) async {
    if (_refuseCounter) {
      await refresh();
      return const Result.ok(DebtOutcome.unknown);
    }
    _ref.read(_proposals.notifier).set([
      _proposal(awaitingId: 'them', amount: amount),
    ]);
    await refresh();
    return const Result.ok(DebtOutcome.ok);
  }

  @override
  Future<Result<DebtOutcome>> accept(String id) async {
    _ref.read(_proposals.notifier).set(const []);
    await refresh();
    return const Result.ok(DebtOutcome.ok);
  }
}

void main() {
  setUp(() => _refuseCounter = false);

  Future<void> openPage(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myUserIdProvider.overrideWithValue('me'),
          debtServiceProvider.overrideWith(_FakeDebtService.new),
          debtProposalsProvider.overrideWith(
            (ref) => Stream.value(ref.watch(_proposals)),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DebtConfirmPage(proposalId: 'p1'),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(DebtConfirmPage), findsOneWidget);
  }

  // Note on what these do and do not prove: they pin the *behaviour* — a
  // successful answer closes the page — which is what broke when countering a
  // second time started failing on the server. They do not distinguish
  // capturing the Navigator before the await from guarding on context.mounted
  // after it; widget-test timing lets the latter pass too.
  testWidgets('changing the amount closes the page', (tester) async {
    await openPage(tester);

    await tester.tap(find.text('debt_action_counter'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '400');
    await tester.tap(find.text('debt_send'));
    await tester.pumpAndSettle();

    expect(
      find.byType(DebtConfirmPage),
      findsNothing,
      reason: 'the ball is in their court now; there is nothing left to answer',
    );
  });

  testWidgets('backing out of the amount sheet leaves the page open', (
    tester,
  ) async {
    await openPage(tester);

    await tester.tap(find.text('debt_action_counter'));
    await tester.pumpAndSettle();

    // Dismiss the sheet without sending.
    await tester.tapAt(const Offset(210, 60));
    await tester.pumpAndSettle();

    expect(find.byType(DebtConfirmPage), findsOneWidget);
    expect(find.text('debt_action_counter'), findsOneWidget);
  });

  testWidgets('a refused change leaves the page open to try again', (
    tester,
  ) async {
    // This is what the two-round cap produced: the answer bounced, so the page
    // stayed put and the debt could not be corrected. Removing the cap is the
    // real fix; this pins that a refusal still leaves somewhere to retry from
    // rather than stranding the user on a dead screen.
    await openPage(tester);
    _refuseCounter = true;

    await tester.tap(find.text('debt_action_counter'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '400');
    await tester.tap(find.text('debt_send'));
    await tester.pumpAndSettle();

    expect(find.byType(DebtConfirmPage), findsOneWidget);
    expect(find.text('debt_action_counter'), findsOneWidget);
  });

  testWidgets('agreeing closes the page too', (tester) async {
    await openPage(tester);

    await tester.tap(find.textContaining('debt_accept_'));
    await tester.pumpAndSettle();

    expect(find.byType(DebtConfirmPage), findsNothing);
  });
}
