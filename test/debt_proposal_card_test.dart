import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/shared/pages/debt_proposal_card.dart';
import 'package:heymybro/shared/provider/debt_provider.dart';

DebtProposal _proposal({
  String status = 'pending',
  String? awaitingId = 'me',
  int? amount = 500,
  String debtorId = 'me',
  String? rejectReason,
}) => DebtProposal(
  id: 'p1',
  proposerId: 'them',
  counterpartyId: 'me',
  debtorId: debtorId,
  title: '晚餐',
  amount: amount,
  status: status,
  awaitingId: awaitingId,
  round: 0,
  rejectReason: rejectReason,
  otherName: '阿華',
  createdAt: DateTime(2026, 8, 15),
  updatedAt: DateTime(2026, 8, 15),
);

void main() {
  Future<void> pump(WidgetTester tester, DebtProposal proposal) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [myUserIdProvider.overrideWithValue('me')],
        child: MaterialApp(
          home: Scaffold(body: DebtProposalCard(proposal: proposal)),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('waiting on me offers somewhere to go', (tester) async {
    await pump(tester, _proposal());

    expect(find.text('debt_action_goto'), findsOneWidget);
    expect(find.text('debt_status_waiting'), findsNothing);
  });

  testWidgets('waiting on them only says so', (tester) async {
    await pump(tester, _proposal(awaitingId: 'them'));

    expect(find.text('debt_status_waiting'), findsOneWidget);
    expect(
      find.text('debt_action_goto'),
      findsNothing,
      reason: 'there is nothing for me to do on this one',
    );
  });

  testWidgets('it carries the badge that marks it unagreed', (tester) async {
    await pump(tester, _proposal());
    expect(find.text('debt_pending_title'), findsOneWidget);
  });

  testWidgets('direction follows who the debtor is', (tester) async {
    await pump(tester, _proposal(debtorId: 'me'));
    expect(find.textContaining('tx_you_owe'), findsOneWidget);

    await pump(tester, _proposal(debtorId: 'them'));
    expect(find.textContaining('tx_owes_you'), findsOneWidget);
  });

  testWidgets('a blank amount says so rather than showing zero', (
    tester,
  ) async {
    await pump(tester, _proposal(amount: null));

    expect(find.text('debt_amount_blank'), findsOneWidget);
    expect(find.textContaining('\$0'), findsNothing);
  });

  testWidgets('a rejection shows its reason and can be acknowledged', (
    tester,
  ) async {
    await pump(
      tester,
      _proposal(status: 'rejected', awaitingId: null, rejectReason: '那頓我付的'),
    );

    expect(find.text('debt_state_rejected_bare'), findsOneWidget);
    expect(find.textContaining('debt_state_rejected'), findsWidgets);
    expect(find.text('debt_action_goto'), findsNothing);
  });

  testWidgets('a voided proposal explains itself', (tester) async {
    await pump(tester, _proposal(status: 'void', awaitingId: null));

    expect(find.text('debt_state_void'), findsOneWidget);
    expect(find.byIcon(LucideIcons.hourglass), findsNothing);
  });
}
