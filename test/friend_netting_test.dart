import 'package:flutter_test/flutter_test.dart';
import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/shared/provider/friend_provider.dart';

Group _group(String id, {bool isDirect = true, bool isArchived = false}) =>
    Group(
      id: id,
      name: id,
      colorValue: 0,
      isArchived: isArchived,
      isDirect: isDirect,
      createdAt: DateTime(2026, 1, 1),
    );

Member _member(
  String id,
  String groupId, {
  bool isMe = false,
  String? friendId,
}) => Member(
  id: id,
  groupId: groupId,
  name: id,
  isMe: isMe,
  friendId: friendId,
  createdAt: DateTime(2026, 1, 1),
);

const _friendId = 'friend-1';

void main() {
  // Two direct debts with the same friend that partly offset:
  //   g1: friend owes me 150  (net: friend -150, me +150)
  //   g2: I owe friend 100    (net: friend +100, me -100)
  final groups = [_group('g1'), _group('g2')];
  final members = [
    _member('m1', 'g1', isMe: true),
    _member('f1', 'g1', friendId: _friendId),
    _member('m2', 'g2', isMe: true),
    _member('f2', 'g2', friendId: _friendId),
  ];
  final net = {'m1': 150, 'f1': -150, 'm2': -100, 'f2': 100};

  group('friendDirectNet', () {
    test('nets offsetting debts across direct groups', () {
      // -150 (friend owes me) + 100 (I owe friend) = -50 → friend owes you 50.
      final result = friendDirectNet(
        groups: groups,
        members: members,
        net: net,
        friendId: _friendId,
      );
      expect(result, -50);
    });

    test('ignores non-direct (gathering) groups', () {
      final withGathering = [...groups, _group('g3', isDirect: false)];
      final ms = [
        ...members,
        _member('m3', 'g3', isMe: true),
        _member('f3', 'g3', friendId: _friendId),
      ];
      final n = {...net, 'm3': 999, 'f3': -999};
      final result = friendDirectNet(
        groups: withGathering,
        members: ms,
        net: n,
        friendId: _friendId,
      );
      expect(
        result,
        -50,
        reason: 'the gathering group must not affect the net',
      );
    });
  });

  group('friendDirectSettleActions', () {
    test('emits one repayment per non-zero direct debt, correct direction', () {
      final actions = friendDirectSettleActions(
        groups: groups,
        members: members,
        net: net,
        friendId: _friendId,
      );
      expect(actions.length, 2);

      final g1 = actions.firstWhere((a) => a.groupId == 'g1');
      // friend owes me → friend pays me.
      expect(g1.fromMemberId, 'f1');
      expect(g1.toMemberId, 'm1');
      expect(g1.amount, 150);

      final g2 = actions.firstWhere((a) => a.groupId == 'g2');
      // I owe friend → I pay friend.
      expect(g2.fromMemberId, 'm2');
      expect(g2.toMemberId, 'f2');
      expect(g2.amount, 100);
    });

    test('skips already-settled (zero-net) direct debts', () {
      final settled = {'m1': 0, 'f1': 0, 'm2': -100, 'f2': 100};
      final actions = friendDirectSettleActions(
        groups: groups,
        members: members,
        net: settled,
        friendId: _friendId,
      );
      expect(actions.map((a) => a.groupId), ['g2']);
    });
  });
}
