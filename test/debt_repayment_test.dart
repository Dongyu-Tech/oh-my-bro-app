import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/core/error/result.dart';
import 'package:heymybro/shared/debt/debt_projection.dart';
import 'package:heymybro/shared/models/debt_proposal_model.dart';
import 'package:heymybro/shared/pages/debt_confirm_page.dart';
import 'package:heymybro/shared/provider/database_provider.dart';
import 'package:heymybro/shared/provider/debt_provider.dart';
import 'package:heymybro/shared/repositories/debt_repository.dart';

const _debtId = 'debt-1';

/// Both sides agreed 阿華 (them) owes me 500.
DebtProposalModel _debt({int? outstanding = 500}) => DebtProposalModel(
  id: _debtId,
  proposerId: 'me',
  counterpartyId: 'them',
  debtorId: 'them',
  title: '晚餐',
  amount: 500,
  outstanding: outstanding,
  status: 'confirmed',
  createdAt: DateTime(2026, 8, 15),
  updatedAt: DateTime(2026, 8, 15),
  resolvedAt: DateTime(2026, 8, 15),
  otherId: 'them',
  otherDisplayName: '阿華',
);

/// They claim to have paid some of it back.
DebtProposalModel _repayment({
  String id = 'repay-1',
  int amount = 300,
  String status = 'confirmed',
  String? awaitingId,
  int? outstanding = 500,
}) => DebtProposalModel(
  id: id,
  kind: 'repayment',
  repaysId: _debtId,
  proposerId: 'them',
  counterpartyId: 'me',
  // The payer is the debtor of the debt being cleared.
  debtorId: 'them',
  title: '晚餐',
  amount: amount,
  outstanding: outstanding,
  status: status,
  awaitingId: awaitingId,
  createdAt: DateTime(2026, 8, 16),
  updatedAt: DateTime(2026, 8, 16),
  resolvedAt: status == 'pending' ? null : DateTime(2026, 8, 16),
  otherId: 'them',
  otherDisplayName: '阿華',
);

class _FakeRepo implements DebtRepository {
  _FakeRepo(this.rows);
  List<DebtProposalModel> rows;

  @override
  Future<Result<List<DebtProposalModel>>> list({DateTime? since}) async =>
      Result.ok(rows);

  @override
  Future<Result<DebtOutcome>> propose({
    required String id,
    required String counterpartyId,
    required String debtorId,
    required String title,
    int? amount,
  }) async => const Result.ok(DebtOutcome.ok);

  @override
  Future<Result<DebtOutcome>> respond({
    required String id,
    required DebtReply reply,
    int? amount,
    String? reason,
  }) async => const Result.ok(DebtOutcome.ok);

  @override
  Future<Result<DebtOutcome>> proposeRepayment({
    required String id,
    required String repaysId,
    required int amount,
  }) async => const Result.ok(DebtOutcome.ok);

  @override
  Future<Result<DebtOutcome>> cancel(String id) async =>
      const Result.ok(DebtOutcome.ok);
}

void main() {
  group('projection', () {
    late AppDatabase db;
    late ProviderContainer container;

    void setUpWith(List<DebtProposalModel> rows) {
      db = AppDatabase.forExecutor(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          debtRepositoryProvider.overrideWithValue(_FakeRepo(rows)),
          myUserIdProvider.overrideWithValue('me'),
        ],
      );
      addTearDown(db.close);
      addTearDown(container.dispose);
      container.listen(debtProposalsProvider, (_, __) {});
    }

    test('an agreed repayment becomes a settlement in the debt', () async {
      setUpWith([_debt(), _repayment()]);
      await container.read(debtServiceProvider).refresh();

      final settlements = await db.watchAllSettlements().first;
      expect(settlements.length, 1);
      expect(settlements.single.amount, 300);
      expect(settlements.single.groupId, debtGroupId(_debtId));
      expect(
        settlements.single.fromMemberId,
        debtMemberId(_debtId, 'them'),
        reason: 'money leaves the debtor',
      );
      expect(settlements.single.toMemberId, debtMemberId(_debtId, 'me'));
    });

    test('it cuts the balance through the ordinary netting', () async {
      setUpWith([_debt(), _repayment()]);
      await container.read(debtServiceProvider).refresh();

      // The same sum globalNetProvider runs.
      final expenses = await db.watchAllExpenses().first;
      final shares = await db.watchAllShares().first;
      final settlements = await db.watchAllSettlements().first;
      final net = <String, int>{};
      for (final e in expenses) {
        net[e.payerMemberId] = (net[e.payerMemberId] ?? 0) + e.amount;
      }
      for (final s in shares) {
        net[s.memberId] = (net[s.memberId] ?? 0) - s.amount;
      }
      for (final s in settlements) {
        net[s.fromMemberId] = (net[s.fromMemberId] ?? 0) + s.amount;
        net[s.toMemberId] = (net[s.toMemberId] ?? 0) - s.amount;
      }

      expect(
        net[debtMemberId(_debtId, 'them')],
        -200,
        reason: '500 owed, 300 repaid',
      );
    });

    test('replaying it does not clear the debt twice', () async {
      setUpWith([_debt(), _repayment()]);
      final service = container.read(debtServiceProvider);

      // Realtime push, catch-up fetch, next cold start.
      await service.refresh();
      await service.refresh();
      await service.refresh();

      final settlements = await db.watchAllSettlements().first;
      expect(settlements.length, 1);
      expect(
        settlements.fold<int>(0, (s, e) => s + e.amount),
        300,
        reason: 'a replay must not forgive more than was paid',
      );
    });

    test('a pending repayment clears nothing yet', () async {
      setUpWith([_debt(), _repayment(status: 'pending', awaitingId: 'me')]);
      await container.read(debtServiceProvider).refresh();

      expect(await db.watchAllSettlements().first, isEmpty);
    });

    test('the debt it repays is findable by its projected group', () async {
      setUpWith([_debt()]);
      await container.read(debtServiceProvider).refresh();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final byGroup = container.read(debtProposalByGroupProvider);
      expect(byGroup[debtGroupId(_debtId)]?.id, _debtId);
      expect(
        byGroup.length,
        1,
        reason: 'only confirmed debts can be repaid, never repayments',
      );
    });
  });

  group('the repayment screen', () {
    Future<void> pump(WidgetTester tester, List<DebtProposal> known) async {
      await tester.binding.setSurfaceSize(const Size(420, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myUserIdProvider.overrideWithValue('me'),
            debtProposalsProvider.overrideWith((ref) => Stream.value(known)),
          ],
          child: const MaterialApp(
            home: DebtConfirmPage(proposalId: 'repay-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    DebtProposal row({int amount = 300, int? outstanding = 500}) =>
        DebtProposal(
          id: 'repay-1',
          kind: 'repayment',
          repaysId: _debtId,
          proposerId: 'them',
          counterpartyId: 'me',
          debtorId: 'them',
          title: '晚餐',
          amount: amount,
          outstanding: outstanding,
          status: 'pending',
          awaitingId: 'me',
          round: 0,
          otherName: '阿華',
          createdAt: DateTime(2026, 8, 16),
          updatedAt: DateTime(2026, 8, 16),
        );

    testWidgets('says what the repayment leaves behind', (tester) async {
      await pump(tester, [row()]);

      // The whole point of the extra line: "they paid 300" is not enough to
      // agree to without knowing whether that ends it.
      expect(find.text('\$300'), findsOneWidget);
      expect(find.textContaining('debt_repay_leaves'), findsOneWidget);
      expect(find.text('debt_repay_clears'), findsNothing);
    });

    testWidgets('says so when it clears the debt outright', (tester) async {
      await pump(tester, [row(amount: 500)]);

      expect(find.text('debt_repay_clears'), findsOneWidget);
      expect(find.textContaining('debt_repay_leaves'), findsNothing);
    });

    testWidgets('offers no haggling — only yes or no', (tester) async {
      await pump(tester, [row()]);

      expect(find.textContaining('debt_repay_accept'), findsOneWidget);
      expect(find.text('debt_action_reject'), findsOneWidget);
      expect(
        find.text('debt_action_counter'),
        findsNothing,
        reason: 'either the money arrived or it did not',
      );
    });
  });
}
