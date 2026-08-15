import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';
import '../../core/error/result.dart';
import '../debt/debt_projection.dart';
import '../models/debt_proposal_model.dart';
import '../repositories/debt_repository.dart';
import '../repositories/user_repository.dart' show BackendNotWiredException;
import 'auth_provider.dart';
import 'database_provider.dart';
import 'friend_provider.dart';

/// Never rendered. Every screen shows the signed-in user as `'group_me'.tr()`
/// via `m.isMe ? … : m.name`, so the stored name on my own member row is dead
/// weight — but the column is non-null, and putting a translated string in the
/// database would freeze today's language into the row forever.
const _myMemberNamePlaceholder = 'me';

/// Defaults to the unavailable seam; `main.dart` swaps in the Supabase-backed
/// one once Supabase has been initialized.
final debtRepositoryProvider = Provider<DebtRepository>(
  (ref) => const UnavailableDebtRepository(),
);

/// Every proposal this device knows about, straight off Drift so the list
/// renders offline and before any network round trip.
final debtProposalsProvider = StreamProvider<List<DebtProposal>>((ref) {
  return ref.watch(appDatabaseProvider).watchDebtProposals();
});

/// The signed-in user's id, or null. Every "is this mine / is it my turn"
/// question needs it.
final myUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authServiceProvider).currentUser?.id;
});

/// Waiting on me to answer.
final pendingForMeProvider = Provider<List<DebtProposal>>((ref) {
  final me = ref.watch(myUserIdProvider);
  if (me == null) return const [];
  final all = ref.watch(debtProposalsProvider).asData?.value ?? const [];
  return all.where((d) => d.status == 'pending' && d.awaitingId == me).toList();
});

/// Sent by me, waiting on them.
final pendingForThemProvider = Provider<List<DebtProposal>>((ref) {
  final me = ref.watch(myUserIdProvider);
  if (me == null) return const [];
  final all = ref.watch(debtProposalsProvider).asData?.value ?? const [];
  return all.where((d) => d.status == 'pending' && d.awaitingId != me).toList();
});

/// Rejected, withdrawn or voided, and not yet acknowledged.
final unseenDeadEndsProvider = Provider<List<DebtProposal>>((ref) {
  final all = ref.watch(debtProposalsProvider).asData?.value ?? const [];
  return all
      .where(
        (d) =>
            (d.status == 'rejected' ||
                d.status == 'cancelled' ||
                d.status == 'void') &&
            d.dismissedAt == null,
      )
      .toList();
});

/// Confirmed, and this device has not yet said so.
///
/// Only ever non-empty for the side that did NOT press accept — accepting
/// marks its own row seen straight away, because telling somebody what they
/// just did is noise. Which side that is flips with the haggling: whoever
/// answers last is the one who agreed, and the other one gets told.
final unseenConfirmationsProvider = Provider<List<DebtProposal>>((ref) {
  final all = ref.watch(debtProposalsProvider).asData?.value ?? const [];
  return all
      .where((d) => d.status == 'confirmed' && d.confirmAlertAt == null)
      .toList();
});

/// The one proposal to pop up next: waiting on me, and never popped before.
/// One at a time on purpose — three popups in a row is not a notification.
final nextPopupProvider = Provider<DebtProposal?>((ref) {
  for (final d in ref.watch(pendingForMeProvider)) {
    if (d.poppedAt == null) return d;
  }
  return null;
});

/// Owns the write path: RPC → mirror into Drift → project if confirmed.
final debtServiceProvider = Provider<DebtService>((ref) {
  // Keep the friend list warm without rebuilding this provider when it
  // changes: projection needs it to link the other person to their local
  // Friend row, which is what makes their credit score accrue.
  ref.listen(friendsProvider, (_, __) {});

  final service = DebtService(ref);
  ref.onDispose(service.dispose);
  service.start();
  return service;
});

class DebtService {
  DebtService(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();
  sb.RealtimeChannel? _channel;

  AppDatabase get _db => _ref.read(appDatabaseProvider);
  DebtRepository get _repo => _ref.read(debtRepositoryProvider);

  /// Subscribe to live changes and do one catch-up fetch.
  ///
  /// Two layers, each covering what the other cannot: realtime is what makes
  /// the popup appear the moment the other person taps, and the fetch is what
  /// turns a dropped connection into "late" rather than "never". With only the
  /// push, a lost socket means a debt the user never learns about.
  void start() {
    unawaited(refresh());

    if (_repo is UnavailableDebtRepository) return;
    try {
      _channel = sb.Supabase.instance.client
          .channel('debt_proposals')
          .onPostgresChanges(
            event: sb.PostgresChangeEvent.all,
            schema: 'public',
            table: 'debt_proposals',
            // The payload says something moved but carries none of the joined
            // profile columns, so re-running the catch-up fetch keeps one code
            // path instead of two. It is a single indexed query.
            callback: (_) => unawaited(refresh()),
          )
          .subscribe();
    } on Object {
      // No Supabase in this build (tests, missing config). The catch-up fetch
      // already degraded cleanly; live updates simply don't happen.
      _channel = null;
    }
  }

  void dispose() {
    final channel = _channel;
    if (channel == null) return;
    try {
      unawaited(sb.Supabase.instance.client.removeChannel(channel));
    } on Object {
      // Nothing to unsubscribe from if Supabase was never up.
    }
  }

  /// Pull anything newer than what we hold and mirror it locally.
  Future<void> refresh() async {
    final since = await _db.latestDebtProposalUpdatedAt();
    switch (await _repo.list(since: since)) {
      case Ok(value: final rows):
        await _absorb(rows);
      case Error(error: BackendNotWiredException()):
        return; // config-less build: nothing to sync, not a failure
      case Error():
        return; // transient; the next resume or push tries again
    }
  }

  /// Write server rows into Drift and land any that are confirmed.
  Future<void> _absorb(List<DebtProposalModel> rows) async {
    if (rows.isEmpty) return;

    await _db.upsertDebtProposals([
      for (final r in rows)
        DebtProposalsCompanion.insert(
          id: r.id,
          proposerId: r.proposerId,
          counterpartyId: r.counterpartyId,
          debtorId: r.debtorId,
          title: r.title,
          amount: Value(r.amount),
          originalAmount: Value(r.originalAmount),
          status: r.status,
          awaitingId: Value(r.awaitingId),
          round: Value(r.round),
          rejectReason: Value(r.rejectReason),
          otherName: Value(r.bestOtherName),
          otherAvatarUrl: Value(r.otherAvatarUrl),
          createdAt: r.createdAt,
          updatedAt: r.updatedAt,
          resolvedAt: Value(r.resolvedAt),
          // poppedAt / dismissedAt deliberately absent — they belong to this
          // device, and including them would re-arm popups the user already
          // dealt with on every single sync.
        ),
    ]);

    for (final r in rows) {
      if (r.isConfirmed) await _project(r);
    }
  }

  /// Land a confirmed proposal in the ledger. Safe to call repeatedly — see
  /// [DebtProjection].
  Future<void> _project(DebtProposalModel r) async {
    final me = _ref.read(myUserIdProvider);
    final amount = r.amount;
    // A confirmed proposal always has an amount (the server enforces it), and
    // there is no "me" to project against when signed out.
    if (me == null || amount == null) return;

    final otherId = r.proposerId == me ? r.counterpartyId : r.proposerId;
    final friends =
        _ref.read(friendsProvider).asData?.value ?? const <Friend>[];
    Friend? friend;
    for (final f in friends) {
      if (f.userId == otherId) friend = f;
    }

    final otherName = friend?.name ?? r.bestOtherName;
    final iAmDebtor = r.debtorId == me;

    await _db.applyDebtProjection(
      DebtProjection.build(
        proposalId: r.id,
        title: r.title,
        amount: amount,
        creditorUserId: iAmDebtor ? otherId : me,
        debtorUserId: iAmDebtor ? me : otherId,
        creditorName: iAmDebtor ? otherName : _myMemberNamePlaceholder,
        debtorName: iAmDebtor ? _myMemberNamePlaceholder : otherName,
        iAmCreditor: !iAmDebtor,
        friendId: friend?.id,
        confirmedAt: r.resolvedAt ?? r.updatedAt,
      ),
    );
  }

  /// Propose a debt. The caller maps the outcome to a message.
  Future<Result<DebtOutcome>> propose({
    required String counterpartyUserId,
    required String debtorUserId,
    required String title,
    int? amount,
  }) async {
    final result = await _repo.propose(
      id: _uuid.v4(),
      counterpartyId: counterpartyUserId,
      debtorId: debtorUserId,
      title: title,
      amount: amount,
    );
    if (result case Ok(value: final outcome) when outcome.isSuccess) {
      await refresh();
    }
    return result;
  }

  /// Accepting does not go through [_respond], because the order matters here.
  ///
  /// The refresh is what brings the row back as `confirmed`, and "confirmed and
  /// not yet announced" is exactly what raises the banner. Marking afterwards
  /// is a race the banner wins — so this device's copy is marked *first*, and
  /// only then does the row land. I am the one who agreed; being told so is
  /// noise. The other side's copy still has it unset and will announce it.
  Future<Result<DebtOutcome>> accept(String id) async {
    final result = await _repo.respond(id: id, reply: DebtReply.accept);
    if (result case Ok(value: final outcome) when outcome.isSuccess) {
      await _db.markDebtConfirmAlertSeen(id);
      await refresh();
    }
    return result;
  }

  Future<Result<DebtOutcome>> reject(String id, String reason) =>
      _respond(id, DebtReply.reject, reason: reason);

  Future<Result<DebtOutcome>> counter(String id, int amount) =>
      _respond(id, DebtReply.counter, amount: amount);

  Future<Result<DebtOutcome>> cancel(String id) async {
    final result = await _repo.cancel(id);
    if (result case Ok(value: final outcome) when outcome.isSuccess) {
      await refresh();
    }
    return result;
  }

  Future<Result<DebtOutcome>> _respond(
    String id,
    DebtReply reply, {
    int? amount,
    String? reason,
  }) async {
    final result = await _repo.respond(
      id: id,
      reply: reply,
      amount: amount,
      reason: reason,
    );
    // Refresh immediately instead of waiting for realtime to echo our own
    // write back, or accepting would leave a visible gap before the debt shows
    // up in the ledger. Projection is idempotent, so the echo costs nothing.
    if (result case Ok(value: final outcome) when outcome.isSuccess) {
      await refresh();
    }
    return result;
  }

  Future<void> markPopped(String id) => _db.markDebtPopped(id);

  Future<void> markDismissed(String id) => _db.markDebtDismissed(id);

  Future<void> markConfirmAlertSeen(String id) =>
      _db.markDebtConfirmAlertSeen(id);
}
