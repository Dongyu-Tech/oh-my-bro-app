import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/shared/pages/debt_confirm_page.dart';
import 'package:heymybro/shared/provider/debt_provider.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';

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
    Size size = const Size(420, 900),
  }) async {
    await tester.binding.setSurfaceSize(size);
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

    expect(find.text('-\$500'), findsOneWidget);
    expect(find.text('晚餐'), findsOneWidget);
    // The claim is the caption; the claimant is named under it in corner
    // brackets, so the sentence never repeats the name.
    expect(find.text('debt_claim_you_owe'), findsOneWidget);
    expect(find.text('「阿華」'), findsOneWidget);
  });

  testWidgets('direction follows who the debtor is', (tester) async {
    await pump(tester, known: [_proposal(debtorId: 'them')]);
    expect(find.text('debt_claim_owes_you'), findsOneWidget);
    expect(find.text('debt_claim_you_owe'), findsNothing);
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

    expect(find.text('-\$400'), findsOneWidget);
    expect(find.textContaining('debt_was_amount'), findsOneWidget);
  });

  testWidgets('what I owe is a signed red number', (tester) async {
    await pump(tester, known: [_proposal(debtorId: 'me')]);

    final amount = tester.widget<Text>(find.text('-\$500'));
    expect(
      amount.style?.color,
      BrutalColors.secondary,
      reason: 'red carries a liability (DESIGN.md)',
    );
  });

  testWidgets('what I am owed is an unsigned green number', (tester) async {
    await pump(tester, known: [_proposal(debtorId: 'them')]);

    final amount = tester.widget<Text>(find.text('\$500'));
    expect(amount.style?.color, BrutalColors.incomeGreen);
    expect(
      find.text('-\$500'),
      findsNothing,
      reason:
          'the minus is what survives greyscale, so it must mean expense '
          'and only expense',
    );
  });

  testWidgets('it survives a small screen and a long item name', (
    tester,
  ) async {
    // A 52px amount, an overlapping sticker and three buttons on an iPhone SE
    // is where this layout would break first. A RenderFlex overflow throws in
    // debug, so reaching the assertions at all is the assertion.
    await pump(
      tester,
      size: const Size(320, 568),
      known: [
        _proposal(
          amount: 1234567,
          originalAmount: 7654321,
        ).copyWith(title: '上禮拜五那頓超級無敵長的燒肉店聚餐加宵夜'),
      ],
    );

    expect(find.byType(DebtConfirmPage), findsOneWidget);
    expect(find.text('debt_action_accept'), findsOneWidget);
  });

  testWidgets('a proposal this device does not have says so', (tester) async {
    // Reached by opening a link for something already withdrawn, or before
    // the sync has caught up.
    await pump(tester, known: const [], openId: 'missing');

    expect(find.text('debt_confirm_gone'), findsOneWidget);
    expect(find.text('debt_action_accept'), findsNothing);
  });
}
