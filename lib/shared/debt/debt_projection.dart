import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:heymybro/core/database/database.dart';

/// Fixed namespace behind every id derived from a debt proposal.
///
/// Never change this. Re-deriving would orphan every debt already projected
/// under the old namespace and then project a second copy of each — which is
/// precisely the failure this whole mechanism exists to prevent.
const _debtNamespace = '6f1c2e40-0c2a-4c1e-9a1b-2d3f4a5b6c7d';

const _uuid = Uuid();

String debtGroupId(String proposalId) =>
    _uuid.v5(_debtNamespace, 'group:$proposalId');

String debtExpenseId(String proposalId) =>
    _uuid.v5(_debtNamespace, 'expense:$proposalId');

String debtMemberId(String proposalId, String userId) =>
    _uuid.v5(_debtNamespace, 'member:$proposalId:$userId');

String debtShareId(String proposalId, String memberId) =>
    _uuid.v5(_debtNamespace, 'share:$proposalId:$memberId');

/// The local rows a confirmed proposal becomes: the same
/// group + members + expense + shares shape `GroupService.addDirectDebt`
/// already produced, so 帳本 / 信用分 / 結清 need no changes to understand it.
///
/// Every id is derived from the proposal id rather than generated randomly,
/// and that is the entire point. A confirmation reaches a device more than
/// once — the realtime push, the catch-up fetch, the next cold start, a
/// reinstall re-fetching everything — and random ids would turn each arrival
/// into another copy of the same debt, so the ledger would climb 500 → 1000 →
/// 1500 on its own. Derived ids make re-applying a projection a no-op instead
/// of something callers have to remember to guard against.
class DebtProjection {
  const DebtProjection({
    required this.group,
    required this.creditor,
    required this.debtor,
    required this.expense,
    required this.shares,
  });

  final GroupsCompanion group;
  final MembersCompanion creditor;
  final MembersCompanion debtor;
  final ExpensesCompanion expense;
  final List<ExpenseSharesCompanion> shares;

  /// [iAmCreditor] is the only thing that differs between the two devices: the
  /// ids and the money are identical on both phones, but "which row is me"
  /// naturally is not — the same split the server schema already models by
  /// turning Drift's per-device `isMe` into a `user_id`.
  ///
  /// [friendId] links the *other* person to my local Friends row so their
  /// repayment history and credit score accrue. Null if they somehow aren't in
  /// my friend book yet; the debt still lands, it just doesn't feed their score
  /// until the next friend sync.
  static DebtProjection build({
    required String proposalId,
    required String title,
    required int amount,
    required String creditorUserId,
    required String debtorUserId,
    required String creditorName,
    required String debtorName,
    required bool iAmCreditor,
    required String? friendId,
    required DateTime confirmedAt,
  }) {
    final groupId = debtGroupId(proposalId);
    final creditorId = debtMemberId(proposalId, creditorUserId);
    final debtorId = debtMemberId(proposalId, debtorUserId);
    final expenseId = debtExpenseId(proposalId);

    return DebtProjection(
      group: GroupsCompanion.insert(
        id: groupId,
        name: title,
        colorValue: 0xFF6E5BD0, // purple — the direct-debt marker colour
        createdAt: confirmedAt,
        // Hidden from the 揪團 lists; feeds 帳本 only.
        isDirect: const Value(true),
      ),
      creditor: MembersCompanion.insert(
        id: creditorId,
        groupId: groupId,
        name: creditorName,
        isMe: Value(iAmCreditor),
        friendId: Value(iAmCreditor ? null : friendId),
        createdAt: confirmedAt,
      ),
      debtor: MembersCompanion.insert(
        id: debtorId,
        groupId: groupId,
        name: debtorName,
        isMe: Value(!iAmCreditor),
        friendId: Value(iAmCreditor ? friendId : null),
        createdAt: confirmedAt,
      ),
      expense: ExpensesCompanion.insert(
        id: expenseId,
        groupId: groupId,
        title: title,
        amount: amount,
        // The creditor "paid" and the debtor's share is the whole amount —
        // that is what makes the ordinary netting read this as "debtor owes
        // creditor" with no special-casing.
        payerMemberId: creditorId,
        createdAt: confirmedAt,
      ),
      shares: [
        ExpenseSharesCompanion.insert(
          id: debtShareId(proposalId, debtorId),
          expenseId: expenseId,
          memberId: debtorId,
          amount: amount,
        ),
        ExpenseSharesCompanion.insert(
          id: debtShareId(proposalId, creditorId),
          expenseId: expenseId,
          memberId: creditorId,
          amount: 0,
        ),
      ],
    );
  }
}
