import 'package:flutter_test/flutter_test.dart';
import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/shared/provider/group_provider.dart';
import 'package:heymybro/shared/split/settlement.dart';

Member _m(String id, String groupId, {bool isMe = false}) => Member(
  id: id,
  groupId: groupId,
  name: id,
  isMe: isMe,
  createdAt: DateTime(2026, 1, 1),
);

Expense _e(String id, String groupId, {DateTime? deletedAt}) => Expense(
  id: id,
  groupId: groupId,
  title: id,
  amount: 0,
  payerMemberId: 'payer',
  createdAt: DateTime(2026, 1, 1),
  deletedAt: deletedAt,
);

ExpenseShare _s(String expenseId, String memberId, int amount) => ExpenseShare(
  id: '$expenseId-$memberId',
  expenseId: expenseId,
  memberId: memberId,
  amount: amount,
);

Settlement _st(String id, String groupId) => Settlement(
  id: id,
  groupId: groupId,
  fromMemberId: 'me',
  toMemberId: 'bob',
  amount: 0,
  createdAt: DateTime(2026, 1, 1),
);

PersonalEntry _pe(String id, int amount, {String? source}) => PersonalEntry(
  id: id,
  title: id,
  amount: amount,
  sourceSettlementId: source,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  group('shareToBookAfterSettle', () {
    test('books my share when a full repayment clears my credit', () {
      // I'm owed $250 (I paid, split evenly); friend pays me back in full.
      final r = shareToBookAfterSettle(
        myNet: 250,
        myShare: 250,
        alreadyBooked: 0,
        myMemberId: 'me',
        transfer: const Transfer(from: 'friend', to: 'me', amount: 250),
        settledAmount: 250,
      );
      expect(r, 250);
    });

    test('books my share when a full repayment clears my debt', () {
      // I owe $130 (friend paid); I pay it back in full.
      final r = shareToBookAfterSettle(
        myNet: -130,
        myShare: 130,
        alreadyBooked: 0,
        myMemberId: 'me',
        transfer: const Transfer(from: 'me', to: 'friend', amount: 130),
        settledAmount: 130,
      );
      expect(r, 130);
    });

    test('books nothing when my share is 0 (I only fronted the money)', () {
      // Direct debt: friend owes me the whole $150; I consumed nothing.
      final r = shareToBookAfterSettle(
        myNet: 150,
        myShare: 0,
        alreadyBooked: 0,
        myMemberId: 'me',
        transfer: const Transfer(from: 'friend', to: 'me', amount: 150),
        settledAmount: 150,
      );
      expect(r, isNull);
    });

    test('books nothing on a partial repayment', () {
      final r = shareToBookAfterSettle(
        myNet: 250,
        myShare: 250,
        alreadyBooked: 0,
        myMemberId: 'me',
        transfer: const Transfer(from: 'friend', to: 'me', amount: 250),
        settledAmount: 100,
      );
      expect(r, isNull);
    });

    test('books nothing while I am still owed by others (net not cleared)', () {
      // 3-way: two people owe me $200 each; only one repays now.
      final r = shareToBookAfterSettle(
        myNet: 400,
        myShare: 200,
        alreadyBooked: 0,
        myMemberId: 'me',
        transfer: const Transfer(from: 'a', to: 'me', amount: 200),
        settledAmount: 200,
      );
      expect(r, isNull);
    });

    test('books nothing for a repayment I am not part of', () {
      final r = shareToBookAfterSettle(
        myNet: 0,
        myShare: 200,
        alreadyBooked: 0,
        myMemberId: 'me',
        transfer: const Transfer(from: 'a', to: 'b', amount: 100),
        settledAmount: 100,
      );
      expect(r, isNull);
    });

    test('books nothing when there is no "me" member', () {
      final r = shareToBookAfterSettle(
        myNet: 250,
        myShare: 250,
        alreadyBooked: 0,
        myMemberId: null,
        transfer: const Transfer(from: 'friend', to: 'me', amount: 250),
        settledAmount: 250,
      );
      expect(r, isNull);
    });

    test('books only the unbooked remainder on a second settle-to-zero', () {
      // Circle re-settled: cumulative share 200, but 100 was already booked by
      // an earlier settlement → only the new $100 should be booked (bug #2).
      final r = shareToBookAfterSettle(
        myNet: -100,
        myShare: 200,
        alreadyBooked: 100,
        myMemberId: 'me',
        transfer: const Transfer(from: 'me', to: 'bob', amount: 100),
        settledAmount: 100,
      );
      expect(r, 100);
    });

    test('books nothing when my whole share is already booked', () {
      final r = shareToBookAfterSettle(
        myNet: -100,
        myShare: 100,
        alreadyBooked: 100,
        myMemberId: 'me',
        transfer: const Transfer(from: 'me', to: 'bob', amount: 100),
        settledAmount: 100,
      );
      expect(r, isNull);
    });
  });

  group('myShareOfGroup', () {
    final members = [_m('me', 'g1', isMe: true), _m('bob', 'g1')];

    test('sums my shares over the group\'s live expenses', () {
      final expenses = [_e('e1', 'g1'), _e('e2', 'g1')];
      final shares = [
        _s('e1', 'me', 50),
        _s('e1', 'bob', 50),
        _s('e2', 'me', 30),
      ];
      expect(
        myShareOfGroup(
          groupId: 'g1',
          members: members,
          expenses: expenses,
          shares: shares,
        ),
        80,
      );
    });

    test('ignores shares of soft-deleted expenses', () {
      final expenses = [
        _e('e1', 'g1'),
        _e('e2', 'g1', deletedAt: DateTime(2026, 2, 1)),
      ];
      final shares = [_s('e1', 'me', 50), _s('e2', 'me', 30)];
      expect(
        myShareOfGroup(
          groupId: 'g1',
          members: members,
          expenses: expenses,
          shares: shares,
        ),
        50,
      );
    });

    test('ignores expenses from other groups', () {
      final expenses = [_e('e1', 'g1'), _e('e3', 'g2')];
      final shares = [_s('e1', 'me', 50), _s('e3', 'me', 999)];
      expect(
        myShareOfGroup(
          groupId: 'g1',
          members: members,
          expenses: expenses,
          shares: shares,
        ),
        50,
      );
    });

    test('returns 0 when the group has no "me" member', () {
      expect(
        myShareOfGroup(
          groupId: 'g1',
          members: [_m('bob', 'g1')],
          expenses: [_e('e1', 'g1')],
          shares: [_s('e1', 'bob', 50)],
        ),
        0,
      );
    });
  });

  group('alreadyBookedShare', () {
    test('sums entries sourced from this group\'s settlements only', () {
      final settlements = [_st('s1', 'g1'), _st('s2', 'g1'), _st('s3', 'g2')];
      final entries = [
        _pe('p1', 40, source: 's1'), // g1
        _pe('p2', 60, source: 's2'), // g1
        _pe('p3', 99, source: 's3'), // g2 — a different group
        _pe('p4', 12), // manual entry, no settlement source
      ];
      expect(
        alreadyBookedShare(
          groupId: 'g1',
          settlements: settlements,
          personalEntries: entries,
        ),
        100,
      );
    });

    test('is 0 when nothing has been booked for the group yet', () {
      expect(
        alreadyBookedShare(
          groupId: 'g1',
          settlements: [_st('s1', 'g1')],
          personalEntries: [_pe('p1', 40)],
        ),
        0,
      );
    });
  });
}
