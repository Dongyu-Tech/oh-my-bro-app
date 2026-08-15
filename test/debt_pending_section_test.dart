import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/shared/pages/debt_pending_section.dart';
import 'package:heymybro/shared/provider/database_provider.dart';
import 'package:heymybro/shared/provider/debt_provider.dart';

/// Without EasyLocalization initialised, `.tr()` returns the key unchanged —
/// which is exactly what these assertions look for. It keeps them about
/// structure rather than about the current wording of the Chinese copy.
DebtProposal _proposal({
  String id = 'p1',
  String status = 'pending',
  String? awaitingId = 'me',
  int? amount = 500,
  int? originalAmount,
  String debtorId = 'them',
  String? rejectReason,
}) => DebtProposal(
  id: id,
  proposerId: 'me',
  counterpartyId: 'them',
  debtorId: debtorId,
  title: '晚餐',
  amount: amount,
  originalAmount: originalAmount,
  status: status,
  awaitingId: awaitingId,
  round: 0,
  rejectReason: rejectReason,
  otherName: '阿華',
  createdAt: DateTime(2026, 8, 15),
  updatedAt: DateTime(2026, 8, 15),
);

void main() {
  late AppDatabase db;

  Future<void> pump(
    WidgetTester tester, {
    List<DebtProposal> mine = const [],
    List<DebtProposal> theirs = const [],
    List<DebtProposal> deadEnds = const [],
  }) async {
    // Overridden so a stray Drift read fails loudly here rather than reaching
    // for path_provider. Nothing in this widget should open a query stream:
    // Drift schedules a cleanup timer on cancel, and a widget test fails on
    // any timer still pending once the tree is disposed.
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          myUserIdProvider.overrideWithValue('me'),
          pendingForMeProvider.overrideWithValue(mine),
          pendingForThemProvider.overrideWithValue(theirs),
          unseenDeadEndsProvider.overrideWithValue(deadEnds),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: DebtPendingSection()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders nothing at all when there is nothing pending', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('debt_pending_title'), findsNothing);
    expect(find.byType(SizedBox), findsWidgets); // the shrink placeholder
  });

  testWidgets('my turn shows all three answers', (tester) async {
    await pump(tester, mine: [_proposal()]);

    expect(find.text('debt_pending_title'), findsOneWidget);
    expect(find.text('debt_action_accept'), findsOneWidget);
    expect(find.text('debt_action_reject'), findsOneWidget);
    expect(find.text('debt_action_counter'), findsOneWidget);
    expect(find.text('debt_action_cancel'), findsNothing);
    expect(find.text('\$500'), findsOneWidget);
  });

  testWidgets('their turn offers withdraw and nothing to answer', (
    tester,
  ) async {
    await pump(tester, theirs: [_proposal(awaitingId: 'them')]);

    expect(find.text('debt_action_cancel'), findsOneWidget);
    expect(find.text('debt_action_accept'), findsNothing);
    expect(find.text('debt_action_reject'), findsNothing);
  });

  testWidgets('a blank amount says so instead of showing zero', (tester) async {
    await pump(tester, mine: [_proposal(amount: null)]);

    expect(find.text('debt_amount_blank'), findsOneWidget);
    expect(find.text('\$0'), findsNothing);
  });

  testWidgets('a countered proposal shows what it used to say', (tester) async {
    await pump(tester, mine: [_proposal(amount: 400, originalAmount: 500)]);

    expect(find.text('\$400'), findsOneWidget);
    expect(find.textContaining('debt_was_amount'), findsOneWidget);
  });

  testWidgets('a rejection surfaces its reason and can be acknowledged', (
    tester,
  ) async {
    await pump(
      tester,
      deadEnds: [
        _proposal(status: 'rejected', awaitingId: null, rejectReason: '那頓我付的'),
      ],
    );

    expect(find.textContaining('debt_state_rejected'), findsOneWidget);
    expect(find.text('debt_action_dismiss'), findsOneWidget);
  });

  testWidgets('a voided proposal explains itself', (tester) async {
    await pump(tester, deadEnds: [_proposal(status: 'void', awaitingId: null)]);

    expect(find.text('debt_state_void'), findsOneWidget);
  });

  testWidgets('direction follows who the debtor is', (tester) async {
    await pump(tester, mine: [_proposal(debtorId: 'me')]);
    expect(find.textContaining('debt_you_owe_them'), findsOneWidget);

    await pump(tester, mine: [_proposal(debtorId: 'them')]);
    expect(find.textContaining('debt_they_owe'), findsOneWidget);
  });
}
