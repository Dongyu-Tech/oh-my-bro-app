import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/result.dart';
import '../models/debt_proposal_model.dart';
import 'user_repository.dart' show BackendNotWiredException;

/// What a debt RPC decided. Mirrors the strings the functions return; an
/// unrecognised one becomes [unknown] rather than throwing, so a newer server
/// cannot break an older build.
enum DebtOutcome {
  ok,

  /// Somebody got there first, or this was a double tap or a retry after a
  /// dropped connection. The end state the user asked for already holds.
  stale,

  /// Not your turn.
  notYours,
  notFound,

  /// They are not, or are no longer, a friend.
  notFriends,

  /// Tried to accept a proposal whose amount was left blank — the amount has
  /// to be countered in first.
  noAmount,

  /// The amount, title or direction was rejected by the server's validation.
  badInput,

  /// Already countered once; only accept or reject remain.
  roundExhausted,

  /// That's you.
  self,

  unknown;

  static DebtOutcome parse(String? wire) => switch (wire) {
    'ok' => ok,
    'stale' => stale,
    'not_yours' => notYours,
    'not_found' => notFound,
    'not_friends' => notFriends,
    'no_amount' => noAmount,
    'bad_amount' || 'bad_title' || 'bad_debtor' || 'bad_action' => badInput,
    'round_exhausted' => roundExhausted,
    'self' => self,
    _ => unknown,
  };

  /// `stale` counts as done. The user asked for an end state that already
  /// holds, so showing them a red error would just frighten them over a
  /// success.
  bool get isSuccess => this == ok || this == stale;
}

/// How to answer a proposal that is waiting on me.
enum DebtReply { accept, reject, counter }

/// The debt-proposal surface. Every write is a SECURITY DEFINER RPC — the
/// client has read-only access to `public.debt_proposals`, so it can never
/// mark its own proposal confirmed.
abstract class DebtRepository {
  /// Proposals touching me, newest activity first. [since] limits the result
  /// to rows changed after it (the catch-up fetch); null fetches everything.
  Future<Result<List<DebtProposalModel>>> list({DateTime? since});

  /// Propose a debt. [id] is client-generated, so a retry after a dropped
  /// connection is idempotent rather than a second proposal.
  Future<Result<DebtOutcome>> propose({
    required String id,
    required String counterpartyId,
    required String debtorId,
    required String title,
    int? amount,
  });

  /// Answer one waiting on me. [amount] is required for [DebtReply.counter]
  /// and ignored otherwise; [reason] only means anything for
  /// [DebtReply.reject].
  Future<Result<DebtOutcome>> respond({
    required String id,
    required DebtReply reply,
    int? amount,
    String? reason,
  });

  /// Withdraw my own proposal before the other side answers.
  Future<Result<DebtOutcome>> cancel(String id);
}

/// Default: everything fails cleanly, so a build with no Supabase config still
/// boots and 記一筆欠款 degrades instead of crashing.
class UnavailableDebtRepository implements DebtRepository {
  const UnavailableDebtRepository();

  @override
  Future<Result<List<DebtProposalModel>>> list({DateTime? since}) async =>
      const Result.error(BackendNotWiredException());

  @override
  Future<Result<DebtOutcome>> propose({
    required String id,
    required String counterpartyId,
    required String debtorId,
    required String title,
    int? amount,
  }) async => const Result.error(BackendNotWiredException());

  @override
  Future<Result<DebtOutcome>> respond({
    required String id,
    required DebtReply reply,
    int? amount,
    String? reason,
  }) async => const Result.error(BackendNotWiredException());

  @override
  Future<Result<DebtOutcome>> cancel(String id) async =>
      const Result.error(BackendNotWiredException());
}

class SupabaseDebtRepository implements DebtRepository {
  SupabaseDebtRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<Result<List<DebtProposalModel>>> list({DateTime? since}) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'my_debt_proposals',
        params: {'p_since': since?.toUtc().toIso8601String()},
      );
      return Result.ok([
        for (final row in rows)
          DebtProposalModel.fromJson(row as Map<String, dynamic>),
      ]);
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  @override
  Future<Result<DebtOutcome>> propose({
    required String id,
    required String counterpartyId,
    required String debtorId,
    required String title,
    int? amount,
  }) async {
    try {
      final wire = await _client.rpc<String?>(
        'propose_debt',
        params: {
          'p_id': id,
          'p_counterparty': counterpartyId,
          'p_debtor': debtorId,
          'p_title': title,
          'p_amount': amount,
        },
      );
      return Result.ok(DebtOutcome.parse(wire));
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  @override
  Future<Result<DebtOutcome>> respond({
    required String id,
    required DebtReply reply,
    int? amount,
    String? reason,
  }) async {
    try {
      final wire = await _client.rpc<String?>(
        'respond_debt',
        params: {
          'p_id': id,
          'p_action': switch (reply) {
            DebtReply.accept => 'accept',
            DebtReply.reject => 'reject',
            DebtReply.counter => 'counter',
          },
          'p_amount': amount,
          'p_reason': reason,
        },
      );
      return Result.ok(DebtOutcome.parse(wire));
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  @override
  Future<Result<DebtOutcome>> cancel(String id) async {
    try {
      final wire = await _client.rpc<String?>(
        'cancel_debt',
        params: {'p_id': id},
      );
      return Result.ok(DebtOutcome.parse(wire));
    } on Exception catch (e) {
      return Result.error(e);
    }
  }
}
