import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'package:heymybro/shared/debt/debt_projection.dart';

part 'database.g.dart';

// ── Split-the-bill schema ────────────────────────────────────────────────────
// A "團" (Group) is the one concept behind both a one-off gathering and a
// long-lived circle: a one-off is simply a group you archive after settling.
// Members belong to a group (a member can be a plain name — no account
// required, which keeps in-person invites frictionless). Each Expense is paid
// by one member and split into ExpenseShares (one row per member's owed slice),
// so both equal and custom splits are just different sets of share rows.

/// A gathering / circle. `isArchived` distinguishes a settled one-off (archived)
/// from an ongoing group (active).
class Groups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// ARGB int of the card's cover colour (see BrutalColors palette choices).
  IntColumn get colorValue => integer()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  /// A synthetic 2-person group a confirmed debt is projected into (see
  /// [DebtProjection]) to record "A 欠 B $x". It still feeds 帳本 (債務紀錄)
  /// and 信用分, but is hidden from the "攤" (gathering) lists so direct debts
  /// don't clutter the 揪團 dashboard.
  BoolColumn get isDirect => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  /// Non-null once moved to the recycle bin (soft delete).
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A person in a group. `isMe` marks the single member that represents the
/// signed-in user, used to compute "my" net balance.
class Members extends Table {
  TextColumn get id => text()();
  TextColumn get groupId =>
      text().references(Groups, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  BoolColumn get isMe => boolean().withDefault(const Constant(false))();

  /// Links this member to a saved [Friends] row, or null for a one-off name.
  /// Lets a friend's history/credit score accrue across gatherings.
  TextColumn get friendId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One spend within a group. `amount` is whole TWD (no minor units). One member
/// [payerMemberId] fronted the money; who owes what is in [ExpenseShares].
class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get groupId =>
      text().references(Groups, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  IntColumn get amount => integer()();
  TextColumn get payerMemberId =>
      text().references(Members, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get createdAt => dateTime()();

  /// Non-null once moved to the recycle bin (soft delete).
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A single member's owed slice of one expense. The shares of an expense sum to
/// the expense amount (equal split distributes any rounding remainder).
class ExpenseShares extends Table {
  TextColumn get id => text()();
  TextColumn get expenseId =>
      text().references(Expenses, #id, onDelete: KeyAction.cascade)();
  TextColumn get memberId =>
      text().references(Members, #id, onDelete: KeyAction.cascade)();
  IntColumn get amount => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A personal (just-me) spend — no split, no group. Fed by the home quick-add,
/// or auto-created by 結清 when you log your share of a settled gathering.
class PersonalEntries extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  IntColumn get amount => integer()();

  /// When 結清 booked this entry (your share of a settled gathering), the id of
  /// the settlement it came from — so undoing that repayment removes this entry
  /// too, and re-settling can't double-book. Null for manual quick-add entries.
  TextColumn get sourceSettlementId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  /// Non-null once moved to the recycle bin (soft delete).
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A saved friend (local contact). Gathering members can link to one so their
/// repayment history — and comic credit score — accrues across gatherings.
class Friends extends Table {
  TextColumn get id => text()();

  /// What *I* call them. Seeded from their profile, then mine to change.
  TextColumn get name => text()();

  /// Their `public.users` id. Null only on rows added before bros had to be
  /// real accounts — those keep working but can never show a picture.
  TextColumn get userId => text().nullable()();

  /// Their handle at the time they were added, so the row can be re-resolved
  /// against the server later.
  TextColumn get handle => text().nullable()();

  /// Cached avatar URL. Kept locally on purpose: the list has to render before
  /// (and without) a network round trip, and `users` RLS only lets us re-read
  /// their row once the friendship also exists server-side.
  TextColumn get avatarUrl => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  /// Non-null once moved to the recycle bin (soft delete).
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A recorded repayment inside a gathering: [fromMemberId] paid [toMemberId]
/// [amount]. Clears debt — factored into net balances and the settle-up plan,
/// and it's the "did they pay back" signal behind credit scores.
class Settlements extends Table {
  TextColumn get id => text()();
  TextColumn get groupId =>
      text().references(Groups, #id, onDelete: KeyAction.cascade)();
  TextColumn get fromMemberId =>
      text().references(Members, #id, onDelete: KeyAction.cascade)();
  TextColumn get toMemberId =>
      text().references(Members, #id, onDelete: KeyAction.cascade)();
  IntColumn get amount => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A debt still being negotiated. Mirrors `public.debt_proposals`, plus two
/// columns only this device knows about.
///
/// This table holds the negotiation, never the arithmetic. Once [status] is
/// `confirmed` the proposal is projected into the ordinary
/// [Groups]/[Expenses]/[ExpenseShares] shape — the only thing `globalNetProvider`
/// can read — so a pending proposal stays out of every balance and every
/// credit score without a line of code to exclude it.
class DebtProposals extends Table {
  TextColumn get id => text()();

  /// `debt` or `repayment`. A repayment needs the same agreement a debt does,
  /// so it rides the same table and the same flow; it differs only in what a
  /// confirmed one becomes locally, which answers it allows, and what the
  /// screen shows.
  TextColumn get kind => text().withDefault(const Constant('debt'))();

  /// The debt this repayment clears. Null on a debt.
  TextColumn get repaysId => text().nullable()();

  /// What is still owed on this debt after every agreed repayment. Server-
  /// computed, and only ever set on a confirmed debt.
  IntColumn get outstanding => integer().nullable()();

  TextColumn get proposerId => text()();
  TextColumn get counterpartyId => text()();

  /// Whoever owes the money — always one of the two parties.
  TextColumn get debtorId => text()();
  TextColumn get title => text()();

  /// Null means "left blank on purpose, the other side fills it in".
  IntColumn get amount => integer().nullable()();

  /// The previous figure, kept when the other side counters so the card can
  /// show "was $500".
  IntColumn get originalAmount => integer().nullable()();
  TextColumn get status => text()();

  /// Whose turn it is; null on every terminal status.
  TextColumn get awaitingId => text().nullable()();
  IntColumn get round => integer().withDefault(const Constant(0))();
  TextColumn get rejectReason => text().nullable()();

  /// The other party's cached name/picture, for the same reason as
  /// [Friends.avatarUrl]: the list has to render before a network round trip.
  TextColumn get otherName => text().nullable()();
  TextColumn get otherAvatarUrl => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();

  /// Device-local: the popup has already been shown for this one. Without it,
  /// every app launch re-pops the same proposal.
  DateTimeColumn get poppedAt => dateTime().nullable()();

  /// Device-local: the user has acknowledged a dead end (rejected / withdrawn /
  /// voided) and the card can stop taking up space.
  DateTimeColumn get dismissedAt => dateTime().nullable()();

  /// Device-local: "they agreed" has already been announced on this device.
  ///
  /// Set the moment *this* device does the accepting, so the person who
  /// pressed the button is never told what they just did — leaving the banner
  /// for the other side, whichever side that turned out to be after the
  /// haggling.
  DateTimeColumn get confirmAlertAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Groups,
    Members,
    Expenses,
    ExpenseShares,
    PersonalEntries,
    Friends,
    Settlements,
    DebtProposals,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'heymybro'));

  /// Seam for tests: drives the same schema and migrations against a supplied
  /// executor (an in-memory database) instead of the on-device file, which
  /// needs path_provider and so cannot open under `flutter test`.
  AppDatabase.forExecutor(super.executor);

  @override
  int get schemaVersion => 11;

  // v1 table-less → v2 split schema → v3 PersonalEntries → v4 Friends +
  // Settlements + Members.friendId → v5 soft-delete (deletedAt) columns →
  // v6 Groups.isDirect (direct-debt marker) → v7 PersonalEntries
  // .sourceSettlementId (links a 結清-booked entry to its settlement) →
  // v8 Friends.userId/handle/avatarUrl (a bro is a real account now) →
  // v9 DebtProposals (a logged debt is a proposal until both sides agree) →
  // v10 DebtProposals.confirmAlertAt (announce "they agreed" once, to the
  // side that did not press accept) → v11 DebtProposals.kind/repaysId/
  // outstanding (a repayment needs agreeing to as well). Bump
  // BackupService.supportedSchemaVersions alongside any future change here.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // No v1 tables existed; create the whole current schema.
        await m.createAll();
      } else {
        if (from < 3) await m.createTable(personalEntries);
        if (from < 4) {
          await m.createTable(friends);
          await m.createTable(settlements);
          await m.addColumn(members, members.friendId);
        }
        if (from < 5) {
          await m.addColumn(groups, groups.deletedAt);
          await m.addColumn(expenses, expenses.deletedAt);
          await m.addColumn(personalEntries, personalEntries.deletedAt);
          await m.addColumn(friends, friends.deletedAt);
        }
        if (from < 6) await m.addColumn(groups, groups.isDirect);
        if (from < 7) {
          await m.addColumn(
            personalEntries,
            personalEntries.sourceSettlementId,
          );
        }
        if (from < 8) {
          // Nullable on purpose: friends added before this are plain names
          // with no account behind them. They stay usable and simply never
          // get a picture.
          await m.addColumn(friends, friends.userId);
          await m.addColumn(friends, friends.handle);
          await m.addColumn(friends, friends.avatarUrl);
        }
        if (from < 9) await m.createTable(debtProposals);
        if (from < 10 && from >= 9) {
          // Only when the table already existed; a from<9 upgrade just
          // created it with this column present.
          await m.addColumn(debtProposals, debtProposals.confirmAlertAt);
        }
        if (from < 11 && from >= 9) {
          await m.addColumn(debtProposals, debtProposals.kind);
          await m.addColumn(debtProposals, debtProposals.repaysId);
          await m.addColumn(debtProposals, debtProposals.outstanding);
        }
      }
    },
    beforeOpen: (details) async {
      // Enforce ON DELETE CASCADE (off by default in SQLite).
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  // ── Reads (watch = live streams the UI binds to) ──────────────────────────

  /// Live groups (not trashed), newest first. Active/archived split downstream.
  Stream<List<Group>> watchGroups() =>
      (select(groups)
            ..where((g) => g.deletedAt.isNull())
            ..orderBy([(g) => OrderingTerm.desc(g.createdAt)]))
          .watch();

  Future<Group?> getGroup(String groupId) =>
      (select(groups)..where((g) => g.id.equals(groupId))).getSingleOrNull();

  Stream<List<Member>> watchMembers(String groupId) =>
      (select(members)
            ..where((m) => m.groupId.equals(groupId))
            ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
          .watch();

  Future<List<Member>> getMembers(String groupId) =>
      (select(members)..where((m) => m.groupId.equals(groupId))).get();

  Stream<List<Expense>> watchExpenses(String groupId) =>
      (select(expenses)
            ..where((e) => e.groupId.equals(groupId) & e.deletedAt.isNull())
            ..orderBy([(e) => OrderingTerm.desc(e.createdAt)]))
          .watch();

  /// Every live expense across all groups (for the home month-total).
  Stream<List<Expense>> watchAllExpenses() =>
      (select(expenses)..where((e) => e.deletedAt.isNull())).watch();

  /// Live personal (just-me) entries, newest first.
  Stream<List<PersonalEntry>> watchPersonalEntries() =>
      (select(personalEntries)
            ..where((e) => e.deletedAt.isNull())
            ..orderBy([(e) => OrderingTerm.desc(e.createdAt)]))
          .watch();

  Future<void> insertPersonalEntry(PersonalEntriesCompanion entry) =>
      into(personalEntries).insert(entry);

  /// All share rows for every expense in a group, for balance computation.
  Stream<List<ExpenseShare>> watchSharesForGroup(String groupId) {
    final query = select(expenseShares).join([
      innerJoin(expenses, expenses.id.equalsExp(expenseShares.expenseId)),
    ])..where(expenses.groupId.equals(groupId));
    return query.watch().map(
      (rows) => rows.map((r) => r.readTable(expenseShares)).toList(),
    );
  }

  /// Live saved friends, newest first.
  Stream<List<Friend>> watchFriends() =>
      (select(friends)
            ..where((f) => f.deletedAt.isNull())
            ..orderBy([(f) => OrderingTerm.desc(f.createdAt)]))
          .watch();

  // ── Debt proposals (the negotiation, not the ledger) ──────────────────────

  /// Every proposal this device knows about, newest activity first. Terminal
  /// ones are included — the UI decides what to hide, via `dismissedAt`.
  Stream<List<DebtProposal>> watchDebtProposals() => (select(
    debtProposals,
  )..orderBy([(d) => OrderingTerm.desc(d.updatedAt)])).watch();

  /// Replace the local mirror with exactly what the server returned.
  ///
  /// Upsert alone is not enough. It can only ever add and update, so anything
  /// deleted server-side stays on the device forever — a debt that no longer
  /// exists, still listed, opening onto "this one is no longer here". The
  /// server is the authority on which proposals exist, so rows it did not
  /// return are removed.
  ///
  /// Only ever call this with a list that actually came back from a successful
  /// fetch: an empty list from a failed one would wipe the mirror.
  ///
  /// Callers must leave `poppedAt`/`dismissedAt`/`confirmAlertAt` absent in the
  /// companions: they are this device's business and the server knows nothing
  /// about them, so including them would re-arm popups and banners the user has
  /// already dealt with on every single sync.
  Future<void> syncDebtProposals(List<DebtProposalsCompanion> rows) {
    return transaction(() async {
      if (rows.isEmpty) {
        // `NOT IN ()` is a syntax error, so "keep nothing" needs no clause.
        await delete(debtProposals).go();
        return;
      }
      final keep = [for (final r in rows) r.id.value];
      await (delete(debtProposals)..where((d) => d.id.isNotIn(keep))).go();
      await batch((b) => b.insertAllOnConflictUpdate(debtProposals, rows));
    });
  }

  Future<void> markDebtPopped(String id) =>
      (update(debtProposals)..where((d) => d.id.equals(id))).write(
        DebtProposalsCompanion(poppedAt: Value(DateTime.now())),
      );

  /// Delete every direct-debt group that no live proposal accounts for.
  ///
  /// The projection writes these rows and, until this existed, nothing ever
  /// removed them — so a proposal deleted server-side left its debt behind on
  /// the device permanently, with nothing backing it. Same lesson as the
  /// mirror one layer up: a sync that can only add cannot express a deletion.
  ///
  /// Members, expenses, shares and settlements all cascade off the group, so
  /// removing it takes the whole debt with it.
  ///
  /// Only ever call this after a SUCCESSFUL fetch. An empty set legitimately
  /// means "the server has no debts", and passing one after a failed fetch
  /// would clear the ledger.
  ///
  /// Note this cannot distinguish an orphan from a direct debt recorded by the
  /// old local-only composer — both are `isDirect` groups with ids no proposal
  /// derives. Those predate debts needing agreement and are swept too.
  Future<void> purgeOrphanDirectDebts(Set<String> liveGroupIds) {
    return (delete(groups)..where((g) {
          // `NOT IN ()` is a syntax error, so an empty set means "every direct
          // debt is an orphan" and needs no exclusion clause at all.
          return liveGroupIds.isEmpty
              ? g.isDirect.equals(true)
              : g.isDirect.equals(true) & g.id.isNotIn(liveGroupIds.toList());
        }))
        .go();
  }

  Future<void> markDebtConfirmAlertSeen(String id) =>
      (update(debtProposals)..where((d) => d.id.equals(id))).write(
        DebtProposalsCompanion(confirmAlertAt: Value(DateTime.now())),
      );

  Future<void> markDebtDismissed(String id) =>
      (update(debtProposals)..where((d) => d.id.equals(id))).write(
        DebtProposalsCompanion(dismissedAt: Value(DateTime.now())),
      );

  // ── Recycle bin (trashed rows) ─────────────────────────────────────────────
  Stream<List<Group>> watchTrashedGroups() =>
      (select(groups)
            ..where((g) => g.deletedAt.isNotNull())
            ..orderBy([(g) => OrderingTerm.desc(g.deletedAt)]))
          .watch();

  Stream<List<Expense>> watchTrashedExpenses() =>
      (select(expenses)..where((e) => e.deletedAt.isNotNull())).watch();

  Stream<List<PersonalEntry>> watchTrashedPersonalEntries() =>
      (select(personalEntries)..where((e) => e.deletedAt.isNotNull())).watch();

  Stream<List<Friend>> watchTrashedFriends() =>
      (select(friends)..where((f) => f.deletedAt.isNotNull())).watch();

  Stream<List<Settlement>> watchSettlementsForGroup(String groupId) =>
      (select(settlements)..where((s) => s.groupId.equals(groupId))).watch();

  /// Every settlement + every member across all groups — the raw material for
  /// per-friend credit scores.
  Stream<List<Settlement>> watchAllSettlements() => select(settlements).watch();

  Stream<List<Member>> watchAllMembers() => select(members).watch();

  Stream<List<ExpenseShare>> watchAllShares() => select(expenseShares).watch();

  // ── Writes ────────────────────────────────────────────────────────────────

  Future<void> insertFriend(FriendsCompanion friend) =>
      into(friends).insert(friend);

  /// The friend row already pointing at [userId], if any — so adding the same
  /// bro twice updates them instead of stacking duplicates.
  ///
  /// Trashed rows count. If the server says you are bros, a local row sitting
  /// in the bin is stale state to be corrected, not a reason to create a second
  /// row for the same person.
  Future<Friend?> findFriendByUserId(String userId) =>
      (select(friends)
            ..where((f) => f.userId.equals(userId))
            ..limit(1))
          .getSingleOrNull();

  /// Trash every account-backed friend whose id is NOT in [liveUserIds] —
  /// the other side removed us, or a request was withdrawn.
  ///
  /// Scoped to rows that have a `userId`, so friends added before bros were
  /// accounts are never swept up by a server list that could not know about
  /// them. Only ever call this with a list that actually came back from the
  /// server: an empty list from a failed fetch would clear everyone.
  Future<void> pruneUnlinkedFriends(Set<String> liveUserIds) {
    return (update(friends)..where((f) {
          final linked = f.userId.isNotNull() & f.deletedAt.isNull();
          // `NOT IN ()` is a syntax error, so an empty set means "prune every
          // linked friend" and needs no exclusion clause at all.
          return liveUserIds.isEmpty
              ? linked
              : linked & f.userId.isNotIn(liveUserIds.toList());
        }))
        .write(FriendsCompanion(deletedAt: Value(DateTime.now())));
  }

  /// Refresh the cached profile bits of a friend after a lookup, and un-trash
  /// them: this only runs for someone the server currently lists as a bro, and
  /// the server is the authority on that.
  Future<void> updateFriendProfile(
    String friendId, {
    required String? handle,
    required String? avatarUrl,
  }) => (update(friends)..where((f) => f.id.equals(friendId))).write(
    FriendsCompanion(
      handle: Value(handle),
      avatarUrl: Value(avatarUrl),
      deletedAt: const Value(null),
    ),
  );

  Future<void> renameFriend(String friendId, String name) =>
      (update(friends)..where((f) => f.id.equals(friendId))).write(
        FriendsCompanion(name: Value(name)),
      );

  Future<void> deleteFriend(String friendId) =>
      (update(friends)..where((f) => f.id.equals(friendId))).write(
        FriendsCompanion(deletedAt: Value(DateTime.now())),
      );

  Future<void> insertSettlement(SettlementsCompanion settlement) =>
      into(settlements).insert(settlement);

  /// Undo a repayment. Also removes any personal entry that 結清 auto-booked
  /// from it, so undoing a settlement retracts the spend it logged (and a later
  /// re-settle books it exactly once, never twice).
  Future<void> deleteSettlement(String settlementId) => transaction(() async {
    await (delete(
      personalEntries,
    )..where((e) => e.sourceSettlementId.equals(settlementId))).go();
    await (delete(settlements)..where((s) => s.id.equals(settlementId))).go();
  });

  Future<void> updateGroupInfo(String groupId, String name, int colorValue) =>
      (update(groups)..where((g) => g.id.equals(groupId))).write(
        GroupsCompanion(name: Value(name), colorValue: Value(colorValue)),
      );

  Future<void> updatePersonalEntry(String id, String title, int amount) =>
      (update(personalEntries)..where((e) => e.id.equals(id))).write(
        PersonalEntriesCompanion(title: Value(title), amount: Value(amount)),
      );

  Future<void> deletePersonalEntry(String id) =>
      (update(personalEntries)..where((e) => e.id.equals(id))).write(
        PersonalEntriesCompanion(deletedAt: Value(DateTime.now())),
      );

  /// Replace an expense's fields and its shares in one transaction (edit).
  Future<void> updateExpenseWithShares(
    String expenseId, {
    required String title,
    required int amount,
    required String payerMemberId,
    required List<ExpenseSharesCompanion> shares,
  }) {
    return transaction(() async {
      await (update(expenses)..where((e) => e.id.equals(expenseId))).write(
        ExpensesCompanion(
          title: Value(title),
          amount: Value(amount),
          payerMemberId: Value(payerMemberId),
        ),
      );
      await (delete(
        expenseShares,
      )..where((s) => s.expenseId.equals(expenseId))).go();
      await batch((b) => b.insertAll(expenseShares, shares));
    });
  }

  Future<void> insertGroup(GroupsCompanion group) => into(groups).insert(group);

  Future<void> insertMember(MembersCompanion member) =>
      into(members).insert(member);

  Future<void> setArchived(String groupId, bool archived) =>
      (update(groups)..where((g) => g.id.equals(groupId))).write(
        GroupsCompanion(isArchived: Value(archived)),
      );

  Future<void> deleteGroup(String groupId) =>
      (update(groups)..where((g) => g.id.equals(groupId))).write(
        GroupsCompanion(deletedAt: Value(DateTime.now())),
      );

  /// Insert an expense together with its member shares in one transaction.
  Future<void> insertExpenseWithShares(
    ExpensesCompanion expense,
    List<ExpenseSharesCompanion> shares,
  ) {
    return transaction(() async {
      await into(expenses).insert(expense);
      await batch((b) => b.insertAll(expenseShares, shares));
    });
  }

  /// Land a confirmed debt proposal in the ledger.
  ///
  /// Idempotent by construction: every id comes from the proposal id (see
  /// [DebtProjection]) and every insert ignores conflicts, so applying the
  /// same projection any number of times leaves exactly one debt.
  ///
  /// Deliberately insertOrIgnore rather than insertOnConflictUpdate: a
  /// confirmed proposal is immutable, and "ignore" is what makes a replay free
  /// instead of a rewrite that could clobber a later local edit.
  Future<void> applyDebtProjection(DebtProjection projection) {
    return transaction(() async {
      await into(
        groups,
      ).insert(projection.group, mode: InsertMode.insertOrIgnore);
      for (final member in [projection.creditor, projection.debtor]) {
        await into(members).insert(member, mode: InsertMode.insertOrIgnore);
      }
      await into(
        expenses,
      ).insert(projection.expense, mode: InsertMode.insertOrIgnore);
      await batch(
        (b) => b.insertAll(
          expenseShares,
          projection.shares,
          mode: InsertMode.insertOrIgnore,
        ),
      );

      // Un-trash. insertOrIgnore skips a row that already exists, so without
      // this a debt the user once tidied out of 帳本 could never come back —
      // their device hiding it forever while the other still showed it, with
      // no amount of syncing able to reconcile the two.
      //
      // The server says this debt exists and both sides agreed to it, and the
      // server is the authority on that. A local deletedAt is stale state to
      // correct, not a decision to honour — the same reasoning that lets a
      // friend sync un-trash a bro the server still lists.
      await (update(groups)
            ..where((g) => g.id.equals(projection.group.id.value)))
          .write(const GroupsCompanion(deletedAt: Value(null)));
      await (update(expenses)
            ..where((e) => e.id.equals(projection.expense.id.value)))
          .write(const ExpensesCompanion(deletedAt: Value(null)));
    });
  }

  /// Land a confirmed repayment. Idempotent for the same reason the debt
  /// projection is: the id comes from the repayment's own proposal, so a
  /// replay writes nothing.
  Future<void> applyRepaymentSettlement(SettlementsCompanion settlement) =>
      into(settlements).insert(settlement, mode: InsertMode.insertOrIgnore);

  Future<void> deleteExpense(String expenseId) =>
      (update(expenses)..where((e) => e.id.equals(expenseId))).write(
        ExpensesCompanion(deletedAt: Value(DateTime.now())),
      );

  // ── Recycle bin: restore (un-trash) and purge (permanent) ──────────────────
  Future<void> restoreGroup(String id) =>
      (update(groups)..where((g) => g.id.equals(id))).write(
        const GroupsCompanion(deletedAt: Value(null)),
      );
  Future<void> purgeGroup(String id) =>
      (delete(groups)..where((g) => g.id.equals(id))).go();

  Future<void> restoreExpense(String id) =>
      (update(expenses)..where((e) => e.id.equals(id))).write(
        const ExpensesCompanion(deletedAt: Value(null)),
      );
  Future<void> purgeExpense(String id) =>
      (delete(expenses)..where((e) => e.id.equals(id))).go();

  Future<void> restorePersonalEntry(String id) =>
      (update(personalEntries)..where((e) => e.id.equals(id))).write(
        const PersonalEntriesCompanion(deletedAt: Value(null)),
      );
  Future<void> purgePersonalEntry(String id) =>
      (delete(personalEntries)..where((e) => e.id.equals(id))).go();

  Future<void> restoreFriend(String id) =>
      (update(friends)..where((f) => f.id.equals(id))).write(
        const FriendsCompanion(deletedAt: Value(null)),
      );
  Future<void> purgeFriend(String id) =>
      (delete(friends)..where((f) => f.id.equals(id))).go();
}
