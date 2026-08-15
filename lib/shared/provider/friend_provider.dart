import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';
import 'database_provider.dart';
import 'group_provider.dart';

part 'friend_provider.freezed.dart';

const _uuid = Uuid();

// ── Raw streams ──────────────────────────────────────────────────────────────

/// Saved friends, newest first.
final friendsProvider = StreamProvider<List<Friend>>((ref) {
  return ref.watch(appDatabaseProvider).watchFriends();
});

final allMembersProvider = StreamProvider<List<Member>>((ref) {
  return ref.watch(appDatabaseProvider).watchAllMembers();
});

final allSharesProvider = StreamProvider<List<ExpenseShare>>((ref) {
  return ref.watch(appDatabaseProvider).watchAllShares();
});

final allSettlementsProvider = StreamProvider<List<Settlement>>((ref) {
  return ref.watch(appDatabaseProvider).watchAllSettlements();
});

final trashedFriendsProvider = StreamProvider<List<Friend>>((ref) {
  return ref.watch(appDatabaseProvider).watchTrashedFriends();
});

/// memberId → net balance across ALL gatherings, after settlements
/// (positive = owed to them, negative = they owe).
final globalNetProvider = Provider<Map<String, int>>((ref) {
  // Exclude soft-deleted (trashed) groups: deleting a group leaves its expenses
  // and settlements individually un-deleted, so without this filter a trashed
  // gathering's debts keep dragging on friend credit scores until purge.
  final groups = ref.watch(groupsProvider).asData?.value ?? const [];
  final liveGroupIds = {
    for (final g in groups)
      if (g.deletedAt == null) g.id,
  };
  final expenses = (ref.watch(allExpensesProvider).asData?.value ?? const [])
      .where((e) => liveGroupIds.contains(e.groupId))
      .toList();
  final shares = ref.watch(allSharesProvider).asData?.value ?? const [];
  final settlements =
      (ref.watch(allSettlementsProvider).asData?.value ?? const [])
          .where((s) => liveGroupIds.contains(s.groupId))
          .toList();

  // `expenses` is now live-group + live-expense only; drop orphan shares.
  final liveExpenseIds = expenses.map((e) => e.id).toSet();
  final net = <String, int>{};
  for (final e in expenses) {
    net[e.payerMemberId] = (net[e.payerMemberId] ?? 0) + e.amount;
  }
  for (final s in shares) {
    if (!liveExpenseIds.contains(s.expenseId)) continue;
    net[s.memberId] = (net[s.memberId] ?? 0) - s.amount;
  }
  for (final s in settlements) {
    net[s.fromMemberId] = (net[s.fromMemberId] ?? 0) + s.amount;
    net[s.toMemberId] = (net[s.toMemberId] ?? 0) - s.amount;
  }
  return net;
});

/// A friend's comic credit score, derived from their behaviour across every
/// gathering they've been linked into.
@freezed
abstract class CreditScore with _$CreditScore {
  const CreditScore._();

  const factory CreditScore({
    /// 0–100. Higher = a more trustworthy bro.
    required int score,

    /// How much they currently owe, unsettled, across all gatherings.
    required int outstanding,

    /// How many times they've paid someone back.
    required int repaidCount,

    /// Number of gatherings they've joined.
    required int gatherings,
  }) = _CreditScore;

  /// CSV verdict key — 粗哥's ruling.
  String get verdictKey => switch (score) {
    >= 85 => 'credit_elite',
    >= 60 => 'credit_good',
    >= 35 => 'credit_watch',
    _ => 'credit_hopeless',
  };
}

/// Per-friend credit score. Owing money drags it down; paying people back and
/// staying clear lifts it.
final friendCreditProvider = Provider.family<CreditScore, String>((
  ref,
  friendId,
) {
  final members = ref.watch(allMembersProvider).asData?.value ?? const [];
  final settlements =
      ref.watch(allSettlementsProvider).asData?.value ?? const [];
  final net = ref.watch(globalNetProvider);

  final mine = members.where((m) => m.friendId == friendId).toList();
  final myMemberIds = mine.map((m) => m.id).toSet();

  var outstanding = 0;
  final groups = <String>{};
  for (final m in mine) {
    final n = net[m.id] ?? 0;
    if (n < 0) outstanding += -n;
    groups.add(m.groupId);
  }
  final repaid = settlements
      .where((s) => myMemberIds.contains(s.fromMemberId))
      .length;

  final penalty = (outstanding ~/ 50).clamp(0, 60);
  final bonus = (repaid * 5).clamp(0, 20);
  final score = (100 - penalty + bonus).clamp(0, 100);

  return CreditScore(
    score: score,
    outstanding: outstanding,
    repaidCount: repaid,
    gatherings: groups.length,
  );
});

// ── Mutual-debt netting (direct debts only) ──────────────────────────────────

/// One repayment that would clear a single direct debt between me and a friend.
@freezed
abstract class DirectSettleAction with _$DirectSettleAction {
  const factory DirectSettleAction({
    required String groupId,
    required String fromMemberId,
    required String toMemberId,
    required int amount,
  }) = _DirectSettleAction;
}

/// Ids of the live, active direct-debt groups (the synthetic 2-person groups the
/// debt composer mints). Netting is scoped to these — multi-person gatherings
/// aren't purely between you and one friend.
Set<String> _directDebtGroupIds(List<Group> groups, List<Member> members) {
  // Only direct groups I'm actually a member of — a debt the composer recorded
  // between two *other* friends (no "me") must never surface as my debt.
  final myGroupIds = {
    for (final m in members)
      if (m.isMe) m.groupId,
  };
  return {
    for (final g in groups)
      if (g.isDirect &&
          !g.isArchived &&
          g.deletedAt == null &&
          myGroupIds.contains(g.id))
        g.id,
  };
}

/// Signed net across a friend's DIRECT debts, after settlements.
/// `< 0` → the friend owes you; `> 0` → you owe the friend; `0` → all square.
int friendDirectNet({
  required List<Group> groups,
  required List<Member> members,
  required Map<String, int> net,
  required String friendId,
}) {
  final direct = _directDebtGroupIds(groups, members);
  var sum = 0;
  for (final m in members) {
    if (m.friendId == friendId && direct.contains(m.groupId)) {
      sum += net[m.id] ?? 0;
    }
  }
  return sum;
}

/// The repayments that would zero out every direct debt with [friendId] — one
/// per direct group with a non-zero me↔friend balance. Feeds the 一鍵結清 button.
List<DirectSettleAction> friendDirectSettleActions({
  required List<Group> groups,
  required List<Member> members,
  required Map<String, int> net,
  required String friendId,
}) {
  final direct = _directDebtGroupIds(groups, members);
  // Pair up "me" and the friend within each direct group.
  final byGroup = <String, ({Member? me, Member? friend})>{};
  for (final m in members) {
    if (!direct.contains(m.groupId)) continue;
    final cur = byGroup[m.groupId] ?? (me: null, friend: null);
    if (m.isMe) {
      byGroup[m.groupId] = (me: m, friend: cur.friend);
    } else if (m.friendId == friendId) {
      byGroup[m.groupId] = (me: cur.me, friend: m);
    }
  }
  final out = <DirectSettleAction>[];
  for (final entry in byGroup.entries) {
    final me = entry.value.me;
    final friend = entry.value.friend;
    if (me == null || friend == null) continue;
    final fn = net[friend.id] ?? 0; // < 0 → friend owes me
    if (fn == 0) continue;
    out.add(
      fn < 0
          ? DirectSettleAction(
              groupId: entry.key,
              fromMemberId: friend.id,
              toMemberId: me.id,
              amount: -fn,
            )
          : DirectSettleAction(
              groupId: entry.key,
              fromMemberId: me.id,
              toMemberId: friend.id,
              amount: fn,
            ),
    );
  }
  return out;
}

/// Signed net with a friend across direct debts (see [friendDirectNet]).
final friendDirectNetProvider = Provider.family<int, String>((ref, friendId) {
  return friendDirectNet(
    groups: ref.watch(groupsProvider).asData?.value ?? const [],
    members: ref.watch(allMembersProvider).asData?.value ?? const [],
    net: ref.watch(globalNetProvider),
    friendId: friendId,
  );
});

/// The settle-up repayments that clear all direct debts with a friend.
final friendSettleActionsProvider =
    Provider.family<List<DirectSettleAction>, String>((ref, friendId) {
      return friendDirectSettleActions(
        groups: ref.watch(groupsProvider).asData?.value ?? const [],
        members: ref.watch(allMembersProvider).asData?.value ?? const [],
        net: ref.watch(globalNetProvider),
        friendId: friendId,
      );
    });

// ── Writes ───────────────────────────────────────────────────────────────────

final friendServiceProvider = Provider<FriendService>((ref) {
  return FriendService(ref.watch(appDatabaseProvider));
});

class FriendService {
  FriendService(this._db);

  final AppDatabase _db;

  /// Save a bro from a resolved account — the only way to gain one now that
  /// they must be real users. Idempotent on [userId]: adding the same person
  /// twice refreshes their cached profile instead of stacking duplicate rows,
  /// which matters because search and scan reach the same person by different
  /// routes.
  ///
  /// Returns the local friend id.
  Future<String> addBro({
    required String userId,
    required String name,
    String? handle,
    String? avatarUrl,
  }) async {
    final existing = await _db.findFriendByUserId(userId);
    if (existing != null) {
      await _db.updateFriendProfile(
        existing.id,
        name: name,
        handle: handle,
        avatarUrl: avatarUrl,
      );
      return existing.id;
    }

    final id = _uuid.v4();
    await _db.insertFriend(
      FriendsCompanion.insert(
        id: id,
        name: name,
        createdAt: DateTime.now(),
        userId: Value(userId),
        handle: Value(handle),
        avatarUrl: Value(avatarUrl),
      ),
    );
    return id;
  }

  /// Bring the local bro list in line with the server's accepted friendships:
  /// add or refresh the ones that are there, trash the ones that are not.
  ///
  /// The prune is what makes a removal on the other side actually disappear
  /// here — without it the list only ever grows. Pass the full accepted set,
  /// never a partial one.
  Future<void> syncAccepted(
    Iterable<({String userId, String name, String? handle, String? avatarUrl})>
    accepted,
  ) async {
    for (final bro in accepted) {
      await addBro(
        userId: bro.userId,
        name: bro.name,
        handle: bro.handle,
        avatarUrl: bro.avatarUrl,
      );
    }
    await _db.pruneUnlinkedFriends({for (final bro in accepted) bro.userId});
  }

  Future<void> deleteFriend(String id) => _db.deleteFriend(id);

  Future<void> restoreFriend(String id) => _db.restoreFriend(id);
  Future<void> purgeFriend(String id) => _db.purgeFriend(id);
}
