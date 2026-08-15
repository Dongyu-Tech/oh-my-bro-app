import 'package:flutter_test/flutter_test.dart';
import 'package:heymybro/shared/split/settlement.dart';

void main() {
  group('splitEqually', () {
    test('distributes the remainder so slices sum exactly', () {
      expect(splitEqually(1000, 3), [334, 333, 333]);
      expect(splitEqually(1000, 3).fold(0, (a, b) => a + b), 1000);
    });

    test('divides evenly when there is no remainder', () {
      expect(splitEqually(900, 3), [300, 300, 300]);
    });

    test('handles a single member', () {
      expect(splitEqually(250, 1), [250]);
    });

    test('returns empty for non-positive member counts', () {
      expect(splitEqually(100, 0), isEmpty);
    });
  });

  group('netBalances', () {
    test('nets paid minus owed, keeping every member', () {
      final net = netBalances(
        memberIds: ['a', 'b', 'c'],
        paidByMember: {'a': 300},
        owedByMember: {'a': 100, 'b': 100, 'c': 100},
      );
      expect(net, {'a': 200, 'b': -100, 'c': -100});
    });
  });

  group('settleUp', () {
    test('one payer, others repay their share', () {
      final transfers = settleUp({'a': 200, 'b': -100, 'c': -100});
      expect(transfers.length, 2);
      expect(transfers.every((t) => t.to == 'a'), isTrue);
      expect(transfers.map((t) => t.amount).fold(0, (x, y) => x + y), 200);
    });

    test('nobody owes -> no transfers', () {
      expect(settleUp({'a': 0, 'b': 0}), isEmpty);
    });

    test('matches biggest debtor to biggest creditor first', () {
      // a is owed 300, b owes 200, c owes 100.
      final transfers = settleUp({'a': 300, 'b': -200, 'c': -100});
      expect(transfers, const [
        Transfer(from: 'b', to: 'a', amount: 200),
        Transfer(from: 'c', to: 'a', amount: 100),
      ]);
    });

    test('total transferred equals total debt', () {
      final net = {'a': 500, 'b': -150, 'c': -350};
      final moved = settleUp(net).map((t) => t.amount).fold(0, (x, y) => x + y);
      expect(moved, 500);
    });
  });
}
