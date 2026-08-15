import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/shared/pages/debt_confirm_page.dart';
import 'package:heymybro/shared/provider/debt_provider.dart';

DebtProposal _proposal({
  String id = 'p1',
  String status = 'pending',
  String? awaitingId = 'me',
  int? amount = 500,
  int? originalAmount,
  String debtorId = 'me',
}) => DebtProposal(
  id: id,
  proposerId: 'them',
  counterpartyId: 'me',
  debtorId: debtorId,
  title: '晚餐',
  amount: amount,
  originalAmount: originalAmount,
  status: status,
  awaitingId: awaitingId,
  round: 0,
  otherName: '阿華',
  createdAt: DateTime(2026, 8, 15),
  updatedAt: DateTime(2026, 8, 15),
);

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required List<DebtProposal> known,
    String openId = 'p1',
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myUserIdProvider.overrideWithValue('me'),
          // A plain stream, not Drift: a live Drift query stream schedules a
          // cleanup timer on cancel that a widget test flags as a leak.
          debtProposalsProvider.overrideWith((ref) => Stream.value(known)),
        ],
        child: MaterialApp(home: DebtConfirmPage(proposalId: openId)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the amount, the item and which way it goes', (
    tester,
  ) async {
    await pump(tester, known: [_proposal()]);

    expect(find.text('\$500'), findsOneWidget);
    expect(find.text('晚餐'), findsOneWidget);
    expect(find.textContaining('debt_you_owe_them'), findsOneWidget);
  });

  testWidgets('direction follows who the debtor is', (tester) async {
    await pump(tester, known: [_proposal(debtorId: 'them')]);
    expect(find.textContaining('debt_they_owe'), findsOneWidget);
  });

  testWidgets('my turn gets all three answers', (tester) async {
    await pump(tester, known: [_proposal()]);

    expect(find.text('debt_action_accept'), findsOneWidget);
    expect(find.text('debt_action_counter'), findsOneWidget);
    expect(find.text('debt_action_reject'), findsOneWidget);
    expect(find.text('debt_action_cancel'), findsNothing);
  });

  testWidgets('waiting on them offers only withdraw', (tester) async {
    await pump(tester, known: [_proposal(awaitingId: 'them')]);

    expect(find.text('debt_action_cancel'), findsOneWidget);
    expect(find.text('debt_action_accept'), findsNothing);
    expect(find.textContaining('debt_waiting_for'), findsOneWidget);
  });

  testWidgets('an already-settled proposal offers nothing to press', (
    tester,
  ) async {
    await pump(
      tester,
      known: [_proposal(status: 'confirmed', awaitingId: null)],
    );

    expect(find.text('debt_action_accept'), findsNothing);
    expect(find.text('debt_action_cancel'), findsNothing);
    expect(find.text('debt_confirm_settled'), findsOneWidget);
  });

  testWidgets('a blank amount says so rather than showing zero', (
    tester,
  ) async {
    await pump(tester, known: [_proposal(amount: null)]);

    expect(find.text('debt_amount_blank'), findsOneWidget);
    expect(find.text('\$0'), findsNothing);
  });

  testWidgets('a countered proposal shows what it used to say', (tester) async {
    await pump(tester, known: [_proposal(amount: 400, originalAmount: 500)]);

    expect(find.text('\$400'), findsOneWidget);
    expect(find.textContaining('debt_was_amount'), findsOneWidget);
  });

  testWidgets('a proposal this device does not have says so', (tester) async {
    // Reached by opening a link for something already withdrawn, or before
    // the sync has caught up.
    await pump(tester, known: const [], openId: 'missing');

    expect(find.text('debt_confirm_gone'), findsOneWidget);
    expect(find.text('debt_action_accept'), findsNothing);
  });
}
