import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/shared/pages/debt_proposal_card.dart';
import 'package:heymybro/shared/provider/debt_provider.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';

DebtProposal _proposal({
  String status = 'pending',
  String? awaitingId = 'me',
  int? amount = 500,
  String debtorId = 'me',
  String? rejectReason,
}) => DebtProposal(
  id: 'p1',
  kind: 'debt',
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

  testWidgets('it leads with who it is with', (tester) async {
    await pump(tester, _proposal());

    expect(find.text('阿華'), findsOneWidget);
    // The item is the headline now; the person is the corner.
    expect(find.text('晚餐'), findsOneWidget);
  });

  testWidgets('the head starts on the same edge as the title', (tester) async {
    await pump(tester, _proposal());

    // Geometry, not presence: right-aligned it still renders, it just reads as
    // a stray label floating off the card's own left edge.
    expect(
      tester.getTopLeft(find.byType(BrutalAvatar)).dx,
      tester.getTopLeft(find.text('晚餐')).dx,
    );
  });

  testWidgets('the chip beside the name carries the direction', (tester) async {
    await pump(tester, _proposal(debtorId: 'me'));
    expect(find.text('group_you_owe'), findsOneWidget);

    await pump(tester, _proposal(debtorId: 'them'));
    expect(find.text('circle_card_owes_you'), findsOneWidget);
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
