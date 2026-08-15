// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'debt_proposal_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DebtProposalModel _$DebtProposalModelFromJson(Map<String, dynamic> json) =>
    _DebtProposalModel(
      id: json['id'] as String,
      kind: json['kind'] as String? ?? 'debt',
      repaysId: json['repays_id'] as String?,
      outstanding: (json['outstanding'] as num?)?.toInt(),
      proposerId: json['proposer_id'] as String,
      counterpartyId: json['counterparty_id'] as String,
      debtorId: json['debtor_id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num?)?.toInt(),
      originalAmount: (json['original_amount'] as num?)?.toInt(),
      status: json['status'] as String,
      awaitingId: json['awaiting_id'] as String?,
      round: (json['round'] as num?)?.toInt() ?? 0,
      rejectReason: json['reject_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      resolvedAt: json['resolved_at'] == null
          ? null
          : DateTime.parse(json['resolved_at'] as String),
      otherId: json['other_id'] as String?,
      otherHandle: json['other_handle'] as String?,
      otherDisplayName: json['other_display_name'] as String?,
      otherAvatarUrl: json['other_avatar_url'] as String?,
    );

Map<String, dynamic> _$DebtProposalModelToJson(_DebtProposalModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'kind': instance.kind,
      'repays_id': instance.repaysId,
      'outstanding': instance.outstanding,
      'proposer_id': instance.proposerId,
      'counterparty_id': instance.counterpartyId,
      'debtor_id': instance.debtorId,
      'title': instance.title,
      'amount': instance.amount,
      'original_amount': instance.originalAmount,
      'status': instance.status,
      'awaiting_id': instance.awaitingId,
      'round': instance.round,
      'reject_reason': instance.rejectReason,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'resolved_at': instance.resolvedAt?.toIso8601String(),
      'other_id': instance.otherId,
      'other_handle': instance.otherHandle,
      'other_display_name': instance.otherDisplayName,
      'other_avatar_url': instance.otherAvatarUrl,
    };
