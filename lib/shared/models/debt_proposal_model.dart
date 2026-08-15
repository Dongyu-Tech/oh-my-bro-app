// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'debt_proposal_model.freezed.dart';
part 'debt_proposal_model.g.dart';

/// One row of `my_debt_proposals`: a debt still being negotiated, or the
/// terminal record of one that was confirmed, rejected, withdrawn or voided.
///
/// The `other_*` fields are the counterparty's profile, joined server-side so
/// a card can render a name and a face without a second round trip.
@freezed
abstract class DebtProposalModel with _$DebtProposalModel {
  const DebtProposalModel._();

  const factory DebtProposalModel({
    required String id,

    /// `debt` or `repayment`.
    @Default('debt') String kind,

    /// The debt this repayment clears; null on a debt.
    @JsonKey(name: 'repays_id') String? repaysId,

    /// What is still owed after every agreed repayment. Server-computed, and
    /// only ever present on a confirmed debt.
    int? outstanding,
    @JsonKey(name: 'proposer_id') required String proposerId,
    @JsonKey(name: 'counterparty_id') required String counterpartyId,

    /// Whoever owes the money — always one of the two parties.
    @JsonKey(name: 'debtor_id') required String debtorId,
    required String title,

    /// Null means the proposer left it blank for the other side to fill in.
    int? amount,

    /// The previous figure, set when the other side counters.
    @JsonKey(name: 'original_amount') int? originalAmount,
    required String status,

    /// Whose turn it is; null on every terminal status.
    @JsonKey(name: 'awaiting_id') String? awaitingId,
    @Default(0) int round,
    @JsonKey(name: 'reject_reason') String? rejectReason,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
    @JsonKey(name: 'resolved_at') DateTime? resolvedAt,
    @JsonKey(name: 'other_id') String? otherId,
    @JsonKey(name: 'other_handle') String? otherHandle,
    @JsonKey(name: 'other_display_name') String? otherDisplayName,
    @JsonKey(name: 'other_avatar_url') String? otherAvatarUrl,
  }) = _DebtProposalModel;

  factory DebtProposalModel.fromJson(Map<String, dynamic> json) =>
      _$DebtProposalModelFromJson(json);

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isRepayment => kind == 'repayment';

  /// A debt that is agreed and not yet fully paid off — the only thing a
  /// repayment can be proposed against.
  bool get isRepayable => !isRepayment && isConfirmed && (outstanding ?? 0) > 0;

  /// Terminal and worth telling the user about — as opposed to confirmed,
  /// which announces itself by appearing in the ledger.
  bool get isDeadEnd =>
      status == 'rejected' || status == 'cancelled' || status == 'void';

  /// What to call them before their profile is cached locally.
  String get bestOtherName => (otherDisplayName?.trim().isNotEmpty ?? false)
      ? otherDisplayName!.trim()
      : (otherHandle ?? '?');

  bool isMyTurn(String myUserId) => isPending && awaitingId == myUserId;

  bool iOwe(String myUserId) => debtorId == myUserId;
}
