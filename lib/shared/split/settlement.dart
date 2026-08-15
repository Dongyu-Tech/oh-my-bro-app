// Pure split-the-bill math — no Flutter / Drift imports (freezed_annotation is
// plain Dart), so it's trivially unit-testable. All amounts are whole TWD
// (integers).

import 'package:freezed_annotation/freezed_annotation.dart';

part 'settlement.freezed.dart';

/// One suggested repayment: [from] pays [to] the given [amount].
@freezed
abstract class Transfer with _$Transfer {
  const factory Transfer({
    /// Member id of the debtor (pays).
    required String from,

    /// Member id of the creditor (receives).
    required String to,
    required int amount,
  }) = _Transfer;
}

/// Split [amount] equally across [n] members. Distributes the rounding
/// remainder so the slices sum EXACTLY to [amount] — the first `remainder`
/// members each pay 1 extra. Returns an empty list when [n] <= 0.
///
/// e.g. splitEqually(1000, 3) -> [334, 333, 333] (sums to 1000).
List<int> splitEqually(int amount, int n) {
  if (n <= 0) return const [];
  final base = amount ~/ n;
  final remainder = amount - base * n; // 0..n-1, sign follows amount
  return [for (var i = 0; i < n; i++) base + (i < remainder ? 1 : 0)];
}

/// Net balance per member id: positive = others owe them (they fronted more
/// than their share), negative = they owe. Members with no activity map to 0.
///
/// [memberIds] anchors the result set so every member appears (even at 0).
Map<String, int> netBalances({
  required Iterable<String> memberIds,
  required Map<String, int> paidByMember,
  required Map<String, int> owedByMember,
}) {
  return {
    for (final id in memberIds)
      id: (paidByMember[id] ?? 0) - (owedByMember[id] ?? 0),
  };
}

/// Greedy minimal-transfer settlement: repeatedly match the biggest debtor to
/// the biggest creditor. Produces at most (members - 1) transfers. Ignores
/// members whose net is 0. The input net map need not sum to exactly 0 (it does
/// when shares sum to expense totals); any tiny residue is left unsettled.
List<Transfer> settleUp(Map<String, int> net) {
  final creditors = <MapEntry<String, int>>[]; // net > 0 (to receive)
  final debtors =
      <MapEntry<String, int>>[]; // net < 0 (to pay), stored positive
  net.forEach((id, value) {
    if (value > 0) creditors.add(MapEntry(id, value));
    if (value < 0) debtors.add(MapEntry(id, -value));
  });
  // Largest first so we clear big balances in few hops. Tie-break on id for a
  // deterministic, testable order.
  int byAmountDescThenId(MapEntry<String, int> a, MapEntry<String, int> b) {
    final c = b.value.compareTo(a.value);
    return c != 0 ? c : a.key.compareTo(b.key);
  }

  creditors.sort(byAmountDescThenId);
  debtors.sort(byAmountDescThenId);

  final transfers = <Transfer>[];
  var ci = 0;
  var di = 0;
  var credit = creditors.isEmpty ? 0 : creditors.first.value;
  var debt = debtors.isEmpty ? 0 : debtors.first.value;

  while (ci < creditors.length && di < debtors.length) {
    final pay = credit < debt ? credit : debt;
    if (pay > 0) {
      transfers.add(
        Transfer(from: debtors[di].key, to: creditors[ci].key, amount: pay),
      );
    }
    credit -= pay;
    debt -= pay;
    if (credit == 0) {
      ci++;
      if (ci < creditors.length) credit = creditors[ci].value;
    }
    if (debt == 0) {
      di++;
      if (di < debtors.length) debt = debtors[di].value;
    }
  }
  return transfers;
}
