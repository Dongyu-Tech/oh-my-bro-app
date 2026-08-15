import 'package:collection/collection.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';
import '../../core/error/error_logger.dart';
import '../split/settlement.dart';
import 'database_provider.dart';
import 'friend_provider.dart';

part 'group_provider.freezed.dart';

const _uuid = Uuid();

/// Deterministic 6-digit "room code" for a group, used by the invite/join flow.
/// (Local demo — a real cross-device join would mint & store this server-side.)
String roomCodeFor(String groupId) =>
    (groupId.hashCode.abs() % 900000 + 100000).toString();

// ── Reads ─────────────────────────────────────────────────────────────────

/// All groups (active + archived), newest first. UI splits them. Includes the
/// synthetic direct-debt groups — use [gatheringsProvider] for the "攤" lists.
final groupsProvider = StreamProvider<List<Group>>((ref) {
  return ref.watch(appDatabaseProvider).watchGroups();
});

/// Real gatherings for the "攤" lists — every group EXCEPT the synthetic
/// 2-person groups a confirmed debt is projected into (see `DebtProjection`).
/// Those direct debts still flow into [myDebtsProvider]/帳本 and 信用分; they're
/// just hidden from the 揪團 dashboard so they don't clutter it. Newest first
/// (inherits [groupsProvider]'s order).
final gatheringsProvider = Provider<List<Group>>((ref) {
  final groups = ref.watch(groupsProvider).asData?.value ?? const [];
  return groups.where((g) => !g.isDirect).toList();
});

/// Every expense across all groups.
final allExpensesProvider = StreamProvider<List<Expense>>((ref) {
  return ref.watch(appDatabaseProvider).watchAllExpenses();
});

/// Personal (just-me) entries, newest first.
final personalEntriesProvider = StreamProvider<List<PersonalEntry>>((ref) {
  return ref.watch(appDatabaseProvider).watchPersonalEntries();
});

// Recycle-bin streams.
final trashedGroupsProvider = StreamProvider<List<Group>>((ref) {
  return ref.watch(appDatabaseProvider).watchTrashedGroups();
});
final trashedExpensesProvider = StreamProvider<List<Expense>>((ref) {
  return ref.watch(appDatabaseProvider).watchTrashedExpenses();
});
final trashedPersonalEntriesProvider = StreamProvider<List<PersonalEntry>>((
  ref,
) {
  return ref.watch(appDatabaseProvider).watchTrashedPersonalEntries();
});

/// Total *personal* spend this calendar month — just-me entries only. Split /
/// gathering spend (including direct debts, and money others owe you) is
/// money-between-people that lives in 帳本, so it must NOT be counted as your
/// own spending here — otherwise the 個人 balance contradicts its own list.
final monthSpendProvider = Provider<int>((ref) {
  final now = DateTime.now();
  bool thisMonth(DateTime d) => d.year == now.year && d.month == now.month;

  final personal = ref.watch(personalEntriesProvider).asData?.value ?? const [];
  return personal
      .where((e) => thisMonth(e.createdAt))
      .fold(0, (sum, e) => sum + e.amount);
});

/// Number of distinct calendar days you've logged a personal entry (all-time).
/// Drives the 帳戶統計 "記帳天數" stat on the account page.
final daysLoggedProvider = Provider<int>((ref) {
  final personal = ref.watch(personalEntriesProvider).asData?.value ?? const [];
  final days = <int>{
    for (final e in personal)
      e.createdAt.year * 10000 + e.createdAt.month * 100 + e.createdAt.day,
  };
  return days.length;
});

final groupMembersProvider = StreamProvider.family<List<Member>, String>((
  ref,
  groupId,
) {
  return ref.watch(appDatabaseProvider).watchMembers(groupId);
});

final groupExpensesProvider = StreamProvider.family<List<Expense>, String>((
  ref,
  groupId,
) {
  return ref.watch(appDatabaseProvider).watchExpenses(groupId);
});

final groupSharesProvider = StreamProvider.family<List<ExpenseShare>, String>((
  ref,
  groupId,
) {
  return ref.watch(appDatabaseProvider).watchSharesForGroup(groupId);
});

final groupSettlementsProvider =
    StreamProvider.family<List<Settlement>, String>((ref, groupId) {
      return ref.watch(appDatabaseProvider).watchSettlementsForGroup(groupId);
    });

/// Derived per-group snapshot the detail screen binds to: total spend, each
/// member's net balance (AFTER settlements), the remaining repayment plan, and
/// "my" net. Loading until the underlying streams have data.
final groupSummaryProvider = Provider.family<AsyncValue<GroupSummary>, String>((
  ref,
  groupId,
) {
  final members = ref.watch(groupMembersProvider(groupId)).asData?.value;
  final expenses = ref.watch(groupExpensesProvider(groupId)).asData?.value;
  final shares = ref.watch(groupSharesProvider(groupId)).asData?.value;
  final settlements = ref
      .watch(groupSettlementsProvider(groupId))
      .asData
      ?.value;
  if (members == null ||
      expenses == null ||
      shares == null ||
      settlements == null) {
    return const AsyncValue.loading();
  }

  // `expenses` is already live-only; drop shares belonging to trashed expenses.
  final liveExpenseIds = expenses.map((e) => e.id).toSet();
  final paid = <String, int>{};
  for (final e in expenses) {
    paid[e.payerMemberId] = (paid[e.payerMemberId] ?? 0) + e.amount;
  }
  final owed = <String, int>{};
  for (final s in shares) {
    if (!liveExpenseIds.contains(s.expenseId)) continue;
    owed[s.memberId] = (owed[s.memberId] ?? 0) + s.amount;
  }
  final net = netBalances(
    memberIds: members.map((m) => m.id),
    paidByMember: paid,
    owedByMember: owed,
  );
  // A repayment (from → to) shifts the debtor's net up and the creditor's down.
  for (final s in settlements) {
    net[s.fromMemberId] = (net[s.fromMemberId] ?? 0) + s.amount;
    net[s.toMemberId] = (net[s.toMemberId] ?? 0) - s.amount;
  }
  final me = members.where((m) => m.isMe).firstOrNull;
  return AsyncValue.data(
    GroupSummary(
      total: expenses.fold(0, (sum, e) => sum + e.amount),
      net: net,
      transfers: settleUp(net),
      myNet: me == null ? 0 : (net[me.id] ?? 0),
      myShare: me == null ? 0 : (owed[me.id] ?? 0),
    ),
  );
});

/// The amount of my own share to log into 個人記帳 after settling [transfer] for
/// [settledAmount] — but only when that repayment fully clears my net in the
/// group (so I book my consumption exactly once, on 結清). Returns `null` when
/// nothing should be logged: a partial repayment, a transfer I'm not part of, a
/// net that isn't cleared, or a share of 0 (I only fronted, consumed nothing).
///
/// [myNet] is my net *before* the settlement; the post-settlement net is
/// predicted from it so the result doesn't depend on stream propagation.
int? shareToBookAfterSettle({
  required int myNet,
  required int myShare,
  required int alreadyBooked,
  required String? myMemberId,
  required Transfer transfer,
  required int settledAmount,
}) {
  if (myMemberId == null) return null;
  if (settledAmount != transfer.amount) return null; // partial → not cleared
  final int postNet;
  if (transfer.to == myMemberId) {
    postNet = myNet - settledAmount; // I received; my credit shrinks
  } else if (transfer.from == myMemberId) {
    postNet = myNet + settledAmount; // I paid; my debt shrinks
  } else {
    return null; // this repayment isn't between me and someone
  }
  if (postNet != 0) return null;
  // Book only the share I haven't booked from earlier settlements in this group;
  // otherwise settling the same circle twice re-books my whole share each time.
  final unbooked = myShare - alreadyBooked;
  return unbooked > 0 ? unbooked : null;
}

/// Sum of personal-entry amounts already booked from [groupId]'s settlements —
/// so a re-settle books only the still-unbooked remainder of my share (guards
/// against double-booking when a circle is settled to zero more than once).
int alreadyBookedShare({
  required String groupId,
  required List<Settlement> settlements,
  required List<PersonalEntry> personalEntries,
}) {
  final ids = {
    for (final s in settlements)
      if (s.groupId == groupId) s.id,
  };
  if (ids.isEmpty) return 0;
  return personalEntries
      .where(
        (e) =>
            e.sourceSettlementId != null && ids.contains(e.sourceSettlementId),
      )
      .fold(0, (sum, e) => sum + e.amount);
}

/// My total consumption in one group — the sum of my expense shares over its
/// live expenses (independent of who paid or of settlements). Computed from the
/// app-wide member/expense/share lists so it stays correct even when that
/// group's [groupSummaryProvider] was never watched (e.g. on the friend-detail
/// page, where 一鍵結清 runs).
int myShareOfGroup({
  required String groupId,
  required List<Member> members,
  required List<Expense> expenses,
  required List<ExpenseShare> shares,
}) {
  final myId = members
      .where((m) => m.isMe && m.groupId == groupId)
      .map((m) => m.id)
      .firstOrNull;
  if (myId == null) return 0;
  final liveExpenseIds = expenses
      .where((e) => e.groupId == groupId && e.deletedAt == null)
      .map((e) => e.id)
      .toSet();
  return shares
      .where((s) => s.memberId == myId && liveExpenseIds.contains(s.expenseId))
      .fold(0, (sum, s) => sum + s.amount);
}

/// Immutable snapshot of a group's money state.
@freezed
abstract class GroupSummary with _$GroupSummary {
  const factory GroupSummary({
    /// Total spent across all expenses.
    required int total,

    /// memberId → net balance (>0 owed to them, <0 they owe).
    required Map<String, int> net,

    /// Minimal repayment plan.
    required List<Transfer> transfers,

    /// The signed-in member's net balance.
    required int myNet,

    /// What "I" actually consumed here: the sum of my expense shares (independent
    /// of who paid or settlements). This is my real out-of-pocket cost once the
    /// gathering is settled — the amount offered to 個人記帳 on 結清.
    required int myShare,
  }) = _GroupSummary;
}

/// One outstanding debt between me and another person, in one gathering.
@freezed
abstract class DebtRecord with _$DebtRecord {
  const DebtRecord._();

  const factory DebtRecord({
    required String groupId,
    required String groupName,
    required String otherName,

    /// Their picture, via the member's linked [Friend]. Null for a member who
    /// was never linked to one, or who simply has no photo.
    String? otherAvatarUrl,

    /// true = they owe me, false = I owe them.
    required bool owedToMe,

    /// The underlying settle-up transfer (for the 結清 action).
    required Transfer transfer,
  }) = _DebtRecord;

  int get amount => transfer.amount;
}

/// Every outstanding debt that involves me, across active gatherings — the
/// "債務紀錄" list. Derived from each group's settle-up plan.
final myDebtsProvider = Provider<List<DebtRecord>>((ref) {
  final groups = (ref.watch(groupsProvider).asData?.value ?? const []).where(
    (g) => !g.isArchived,
  );
  final avatarByFriendId = {
    for (final f
        in ref.watch(friendsProvider).asData?.value ?? const <Friend>[])
      f.id: f.avatarUrl,
  };
  final out = <DebtRecord>[];
  final trace = <String>[];
  for (final g in groups) {
    final summary = ref.watch(groupSummaryProvider(g.id)).asData?.value;
    final members = ref.watch(groupMembersProvider(g.id)).asData?.value;
    if (summary == null || members == null) {
      trace.add(
        '${g.name}: NOT READY '
        '(summary=${summary != null} members=${members != null})',
      );
      continue;
    }
    final me = members.where((m) => m.isMe).map((m) => m.id).firstOrNull;
    if (me == null) {
      trace.add('${g.name}: NO "me" MEMBER (of ${members.length})');
      continue;
    }
    trace.add(
      '${g.name}: members=${members.length} '
      'exp=${ref.watch(groupExpensesProvider(g.id)).asData?.value.length} '
      'shares=${ref.watch(groupSharesProvider(g.id)).asData?.value.length} '
      'settle=${ref.watch(groupSettlementsProvider(g.id)).asData?.value.length} '
      'transfers=${summary.transfers.length} '
      'net=${summary.net.values.toList()}',
    );
    final nameOf = {for (final m in members) m.id: m.name};
    // Members carry a friendId, and the picture lives on the friend.
    final avatarOf = {
      for (final m in members)
        m.id: m.friendId == null ? null : avatarByFriendId[m.friendId],
    };
    for (final t in summary.transfers) {
      if (t.from == me) {
        out.add(
          DebtRecord(
            groupId: g.id,
            groupName: g.name,
            otherName: nameOf[t.to] ?? '?',
            otherAvatarUrl: avatarOf[t.to],
            owedToMe: false,
            transfer: t,
          ),
        );
      } else if (t.to == me) {
        out.add(
          DebtRecord(
            groupId: g.id,
            groupName: g.name,
            otherName: nameOf[t.from] ?? '?',
            otherAvatarUrl: avatarOf[t.from],
            owedToMe: true,
            transfer: t,
          ),
        );
      }
    }
  }
  logAppTrace('ledger', 'groups=${groups.length} debts=${out.length}');
  for (final line in trace) {
    logAppTrace('ledger', '  $line');
  }
  return out;
});

// ── Writes ──────────────────────────────────────────────────────────────────

final groupServiceProvider = Provider<GroupService>((ref) {
  return GroupService(ref.watch(appDatabaseProvider));
});

/// Thin write API over [AppDatabase], generating ids and timestamps. Kept
/// separate from the widgets so screens never touch Drift companions directly.
class GroupService {
  GroupService(this._db);

  final AppDatabase _db;

  /// Create a group with "me" plus the given members. Each member is a name
  /// with an optional [friendId] linking it to a saved friend (so their history
  /// accrues). Returns the new group id.
  Future<String> createGroup({
    required String name,
    required int colorValue,
    required List<({String name, String? friendId})> members,
    String myName = '我',
  }) async {
    final groupId = _uuid.v4();
    final now = DateTime.now();
    await _db.insertGroup(
      GroupsCompanion.insert(
        id: groupId,
        name: name,
        colorValue: colorValue,
        createdAt: now,
      ),
    );
    await _db.insertMember(
      MembersCompanion.insert(
        id: _uuid.v4(),
        groupId: groupId,
        name: myName,
        isMe: const Value(true),
        createdAt: now,
      ),
    );
    for (final member in members) {
      await _db.insertMember(
        MembersCompanion.insert(
          id: _uuid.v4(),
          groupId: groupId,
          name: member.name,
          friendId: Value(member.friendId),
          createdAt: DateTime.now(),
        ),
      );
    }
    return groupId;
  }

  Future<void> addMember(String groupId, String name, {String? friendId}) {
    return _db.insertMember(
      MembersCompanion.insert(
        id: _uuid.v4(),
        groupId: groupId,
        name: name,
        friendId: Value(friendId),
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Record a direct debt "[debtor] 欠 [creditor] $amount ([title])" with zero
  /// splitting: it becomes a 2-person gathering where the creditor "paid" and
  /// the debtor owes the whole amount, so it flows into 帳本/結清/信用分.
  ///
  /// **Unused, and must stay that way.** A debt is now a proposal the other
  /// side has to confirm (`DebtService.propose` → `DebtProjection`), and this
  /// writes one straight into the ledger with nobody's agreement. Wiring it
  /// back into a screen would silently reintroduce debts the other person
  /// never accepted.
  ///
  /// It survives only because removing it belongs with the wider cleanup of
  /// the `isDirect` synthetic-group trick, not with the feature that
  /// obsoleted it.
  @Deprecated('Use DebtService.propose — a debt needs the other side to agree')
  Future<void> addDirectDebt({
    required ({String name, String? friendId, bool isMe}) debtor,
    required ({String name, String? friendId, bool isMe}) creditor,
    required String title,
    required int amount,
  }) async {
    final groupId = _uuid.v4();
    final now = DateTime.now();
    await _db.insertGroup(
      GroupsCompanion.insert(
        id: groupId,
        name: title,
        colorValue: 0xFF6E5BD0, // purple — direct-debt marker colour
        createdAt: now,
        isDirect: const Value(true), // hidden from the "攤" lists; feeds 帳本 only
      ),
    );
    final debtorId = _uuid.v4();
    final creditorId = _uuid.v4();
    await _db.insertMember(
      MembersCompanion.insert(
        id: debtorId,
        groupId: groupId,
        name: debtor.name,
        isMe: Value(debtor.isMe),
        friendId: Value(debtor.friendId),
        createdAt: now,
      ),
    );
    await _db.insertMember(
      MembersCompanion.insert(
        id: creditorId,
        groupId: groupId,
        name: creditor.name,
        isMe: Value(creditor.isMe),
        friendId: Value(creditor.friendId),
        createdAt: now,
      ),
    );
    await addExpense(
      groupId: groupId,
      title: title,
      amount: amount,
      payerId: creditorId,
      shares: {debtorId: amount, creditorId: 0},
    );
  }

  /// Record a repayment: [fromMemberId] paid [toMemberId] [amount].
  /// Records the repayment and returns the new settlement's id, so a caller can
  /// link a 結清-booked personal entry back to it.
  Future<String> settle({
    required String groupId,
    required String fromMemberId,
    required String toMemberId,
    required int amount,
  }) async {
    final id = _uuid.v4();
    await _db.insertSettlement(
      SettlementsCompanion.insert(
        id: id,
        groupId: groupId,
        fromMemberId: fromMemberId,
        toMemberId: toMemberId,
        amount: amount,
        createdAt: DateTime.now(),
      ),
    );
    return id;
  }

  /// Record an expense. [shares] maps memberId → owed amount and must sum to
  /// [amount] (the caller builds it via [splitEqually] or custom entry).
  Future<void> addExpense({
    required String groupId,
    required String title,
    required int amount,
    required String payerId,
    required Map<String, int> shares,
  }) {
    final expenseId = _uuid.v4();
    return _db.insertExpenseWithShares(
      ExpensesCompanion.insert(
        id: expenseId,
        groupId: groupId,
        title: title,
        amount: amount,
        payerMemberId: payerId,
        createdAt: DateTime.now(),
      ),
      [
        for (final entry in shares.entries)
          ExpenseSharesCompanion.insert(
            id: _uuid.v4(),
            expenseId: expenseId,
            memberId: entry.key,
            amount: entry.value,
          ),
      ],
    );
  }

  Future<void> deleteExpense(String expenseId) => _db.deleteExpense(expenseId);

  /// Replace an existing expense's fields + split (edit).
  Future<void> updateExpense({
    required String expenseId,
    required String title,
    required int amount,
    required String payerId,
    required Map<String, int> shares,
  }) {
    return _db.updateExpenseWithShares(
      expenseId,
      title: title,
      amount: amount,
      payerMemberId: payerId,
      shares: [
        for (final entry in shares.entries)
          ExpenseSharesCompanion.insert(
            id: _uuid.v4(),
            expenseId: expenseId,
            memberId: entry.key,
            amount: entry.value,
          ),
      ],
    );
  }

  Future<void> deleteSettlement(String settlementId) =>
      _db.deleteSettlement(settlementId);

  Future<void> updateGroupInfo(String groupId, String name, int colorValue) =>
      _db.updateGroupInfo(groupId, name, colorValue);

  /// Log a personal (just-me) spend from the home quick-add.
  Future<void> addPersonalEntry({
    required String title,
    required int amount,
    String? sourceSettlementId,
  }) {
    return _db.insertPersonalEntry(
      PersonalEntriesCompanion.insert(
        id: _uuid.v4(),
        title: title,
        amount: amount,
        sourceSettlementId: Value(sourceSettlementId),
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> updatePersonalEntry(String id, String title, int amount) =>
      _db.updatePersonalEntry(id, title, amount);

  Future<void> deletePersonalEntry(String id) => _db.deletePersonalEntry(id);

  // Recycle bin: restore (un-trash) / purge (permanent).
  Future<void> restoreGroup(String id) => _db.restoreGroup(id);
  Future<void> purgeGroup(String id) => _db.purgeGroup(id);
  Future<void> restoreExpense(String id) => _db.restoreExpense(id);
  Future<void> purgeExpense(String id) => _db.purgeExpense(id);
  Future<void> restorePersonalEntry(String id) => _db.restorePersonalEntry(id);
  Future<void> purgePersonalEntry(String id) => _db.purgePersonalEntry(id);

  Future<void> setArchived(String groupId, bool archived) =>
      _db.setArchived(groupId, archived);

  Future<void> deleteGroup(String groupId) => _db.deleteGroup(groupId);
}
