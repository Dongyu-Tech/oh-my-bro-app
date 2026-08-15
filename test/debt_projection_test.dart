import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/shared/debt/debt_projection.dart';

const _p1 = 'a1b2c3d4-0000-4000-8000-000000000001';
const _p2 = 'a1b2c3d4-0000-4000-8000-000000000002';

DebtProjection _projection({
  String proposalId = _p1,
  int amount = 500,
  bool iAmCreditor = true,
}) => DebtProjection.build(
  proposalId: proposalId,
  title: '晚餐',
  amount: amount,
  creditorUserId: iAmCreditor ? 'user-me' : 'user-them',
  debtorUserId: iAmCreditor ? 'user-them' : 'user-me',
  creditorName: iAmCreditor ? 'me' : '阿華',
  debtorName: iAmCreditor ? '阿華' : 'me',
  iAmCreditor: iAmCreditor,
  friendId: 'friend-1',
  confirmedAt: DateTime(2026, 8, 15),
);

void main() {
  group('derived ids', () {
    test('the same proposal always derives the same ids', () {
      final a = _projection();
      final b = _projection();

      expect(a.group.id.value, b.group.id.value);
      expect(a.expense.id.value, b.expense.id.value);
      expect(a.creditor.id.value, b.creditor.id.value);
      expect(a.debtor.id.value, b.debtor.id.value);
      expect(
        a.shares.map((s) => s.id.value).toList(),
        b.shares.map((s) => s.id.value).toList(),
      );
    });

    test('different proposals derive different ids', () {
      expect(
        _projection().group.id.value,
        isNot(_projection(proposalId: _p2).group.id.value),
      );
    });

    test('the two people in one proposal get different ids', () {
      final p = _projection();
      expect(p.creditor.id.value, isNot(p.debtor.id.value));
      expect(p.shares.first.id.value, isNot(p.shares.last.id.value));
    });

    test('both devices derive identical ids despite disagreeing on "me"', () {
      // Same proposal seen from the other phone: only isMe flips.
      final mine = _projection();
      final theirs = DebtProjection.build(
        proposalId: _p1,
        title: '晚餐',
        amount: 500,
        creditorUserId: 'user-me',
        debtorUserId: 'user-them',
        creditorName: '阿東',
        debtorName: 'me',
        iAmCreditor: false,
        friendId: 'friend-9',
        confirmedAt: DateTime(2026, 8, 15),
      );

      expect(mine.group.id.value, theirs.group.id.value);
      expect(mine.expense.id.value, theirs.expense.id.value);
      expect(mine.creditor.id.value, theirs.creditor.id.value);
      expect(mine.debtor.id.value, theirs.debtor.id.value);
      expect(mine.creditor.isMe.value, isNot(theirs.creditor.isMe.value));
    });
  });

  group('applying a projection', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forExecutor(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('lands as a hidden 2-person direct-debt group', () async {
      await db.applyDebtProjection(_projection());

      final groups = await db.watchGroups().first;
      expect(groups.single.isDirect, isTrue);
      expect(groups.single.name, '晚餐');

      final members = await db.watchMembers(groups.single.id).first;
      expect(members.length, 2);
      expect(members.where((m) => m.isMe).length, 1);

      final expenses = await db.watchExpenses(groups.single.id).first;
      expect(expenses.single.amount, 500);

      final shares = await db.watchSharesForGroup(groups.single.id).first;
      expect(shares.map((s) => s.amount).toList()..sort(), [0, 500]);
    });

    test('applying the same projection repeatedly changes nothing', () async {
      // Realtime push, catch-up fetch, the next cold start, a reinstall
      // re-fetching everything — the same confirmation arrives many times.
      await db.applyDebtProjection(_projection());
      await db.applyDebtProjection(_projection());
      await db.applyDebtProjection(_projection());

      expect((await db.watchGroups().first).length, 1);
      expect((await db.watchAllExpenses().first).length, 1);
      expect((await db.watchAllShares().first).length, 2);
      expect((await db.watchAllMembers().first).length, 2);
    });

    test('the debtor owes it all, the creditor owes nothing', () async {
      await db.applyDebtProjection(_projection());

      final members = await db.watchAllMembers().first;
      final shares = await db.watchAllShares().first;
      final debtor = members.firstWhere((m) => m.name == '阿華');
      final creditor = members.firstWhere((m) => m.isMe);

      expect(shares.firstWhere((s) => s.memberId == debtor.id).amount, 500);
      expect(shares.firstWhere((s) => s.memberId == creditor.id).amount, 0);
      expect(
        (await db.watchAllExpenses().first).single.payerMemberId,
        creditor.id,
      );
    });

    test('the friend link goes on the other person, never on me', () async {
      await db.applyDebtProjection(_projection());
      final members = await db.watchAllMembers().first;

      expect(members.firstWhere((m) => m.isMe).friendId, isNull);
      expect(members.firstWhere((m) => !m.isMe).friendId, 'friend-1');
    });

    test('a replay cannot inflate the balance', () async {
      // The bug this whole design exists to prevent: three arrivals of one
      // confirmation reading as 阿華 owing 1500.
      await db.applyDebtProjection(_projection());
      await db.applyDebtProjection(_projection());
      await db.applyDebtProjection(_projection());

      final shares = await db.watchAllShares().first;
      expect(shares.fold<int>(0, (sum, s) => sum + s.amount), 500);
    });
  });

  group('feeding the ledger', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forExecutor(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('nets out as "they owe me" through the normal maths', () async {
      await db.applyDebtProjection(_projection());

      final groups = await db.watchGroups().first;
      final members = await db.watchAllMembers().first;
      final expenses = await db.watchAllExpenses().first;
      final shares = await db.watchAllShares().first;

      // Same computation globalNetProvider runs.
      final net = <String, int>{};
      for (final e in expenses) {
        net[e.payerMemberId] = (net[e.payerMemberId] ?? 0) + e.amount;
      }
      for (final s in shares) {
        net[s.memberId] = (net[s.memberId] ?? 0) - s.amount;
      }

      final me = members.firstWhere((m) => m.isMe);
      final them = members.firstWhere((m) => !m.isMe);
      expect(groups.single.isDirect, isTrue);
      expect(net[me.id], 500, reason: 'positive = owed to me');
      expect(net[them.id], -500, reason: 'negative = they owe');
    });
  });
}
