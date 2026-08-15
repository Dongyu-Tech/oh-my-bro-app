// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'debt_proposal_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DebtProposalModel {

 String get id;/// `debt` or `repayment`.
 String get kind;/// The debt this repayment clears; null on a debt.
@JsonKey(name: 'repays_id') String? get repaysId;/// What is still owed after every agreed repayment. Server-computed, and
/// only ever present on a confirmed debt.
 int? get outstanding;@JsonKey(name: 'proposer_id') String get proposerId;@JsonKey(name: 'counterparty_id') String get counterpartyId;/// Whoever owes the money — always one of the two parties.
@JsonKey(name: 'debtor_id') String get debtorId; String get title;/// Null means the proposer left it blank for the other side to fill in.
 int? get amount;/// The previous figure, set when the other side counters.
@JsonKey(name: 'original_amount') int? get originalAmount; String get status;/// Whose turn it is; null on every terminal status.
@JsonKey(name: 'awaiting_id') String? get awaitingId; int get round;@JsonKey(name: 'reject_reason') String? get rejectReason;@JsonKey(name: 'created_at') DateTime get createdAt;@JsonKey(name: 'updated_at') DateTime get updatedAt;@JsonKey(name: 'resolved_at') DateTime? get resolvedAt;@JsonKey(name: 'other_id') String? get otherId;@JsonKey(name: 'other_handle') String? get otherHandle;@JsonKey(name: 'other_display_name') String? get otherDisplayName;@JsonKey(name: 'other_avatar_url') String? get otherAvatarUrl;
/// Create a copy of DebtProposalModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DebtProposalModelCopyWith<DebtProposalModel> get copyWith => _$DebtProposalModelCopyWithImpl<DebtProposalModel>(this as DebtProposalModel, _$identity);

  /// Serializes this DebtProposalModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DebtProposalModel&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.repaysId, repaysId) || other.repaysId == repaysId)&&(identical(other.outstanding, outstanding) || other.outstanding == outstanding)&&(identical(other.proposerId, proposerId) || other.proposerId == proposerId)&&(identical(other.counterpartyId, counterpartyId) || other.counterpartyId == counterpartyId)&&(identical(other.debtorId, debtorId) || other.debtorId == debtorId)&&(identical(other.title, title) || other.title == title)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.originalAmount, originalAmount) || other.originalAmount == originalAmount)&&(identical(other.status, status) || other.status == status)&&(identical(other.awaitingId, awaitingId) || other.awaitingId == awaitingId)&&(identical(other.round, round) || other.round == round)&&(identical(other.rejectReason, rejectReason) || other.rejectReason == rejectReason)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.resolvedAt, resolvedAt) || other.resolvedAt == resolvedAt)&&(identical(other.otherId, otherId) || other.otherId == otherId)&&(identical(other.otherHandle, otherHandle) || other.otherHandle == otherHandle)&&(identical(other.otherDisplayName, otherDisplayName) || other.otherDisplayName == otherDisplayName)&&(identical(other.otherAvatarUrl, otherAvatarUrl) || other.otherAvatarUrl == otherAvatarUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,kind,repaysId,outstanding,proposerId,counterpartyId,debtorId,title,amount,originalAmount,status,awaitingId,round,rejectReason,createdAt,updatedAt,resolvedAt,otherId,otherHandle,otherDisplayName,otherAvatarUrl]);

@override
String toString() {
  return 'DebtProposalModel(id: $id, kind: $kind, repaysId: $repaysId, outstanding: $outstanding, proposerId: $proposerId, counterpartyId: $counterpartyId, debtorId: $debtorId, title: $title, amount: $amount, originalAmount: $originalAmount, status: $status, awaitingId: $awaitingId, round: $round, rejectReason: $rejectReason, createdAt: $createdAt, updatedAt: $updatedAt, resolvedAt: $resolvedAt, otherId: $otherId, otherHandle: $otherHandle, otherDisplayName: $otherDisplayName, otherAvatarUrl: $otherAvatarUrl)';
}


}

/// @nodoc
abstract mixin class $DebtProposalModelCopyWith<$Res>  {
  factory $DebtProposalModelCopyWith(DebtProposalModel value, $Res Function(DebtProposalModel) _then) = _$DebtProposalModelCopyWithImpl;
@useResult
$Res call({
 String id, String kind,@JsonKey(name: 'repays_id') String? repaysId, int? outstanding,@JsonKey(name: 'proposer_id') String proposerId,@JsonKey(name: 'counterparty_id') String counterpartyId,@JsonKey(name: 'debtor_id') String debtorId, String title, int? amount,@JsonKey(name: 'original_amount') int? originalAmount, String status,@JsonKey(name: 'awaiting_id') String? awaitingId, int round,@JsonKey(name: 'reject_reason') String? rejectReason,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'updated_at') DateTime updatedAt,@JsonKey(name: 'resolved_at') DateTime? resolvedAt,@JsonKey(name: 'other_id') String? otherId,@JsonKey(name: 'other_handle') String? otherHandle,@JsonKey(name: 'other_display_name') String? otherDisplayName,@JsonKey(name: 'other_avatar_url') String? otherAvatarUrl
});




}
/// @nodoc
class _$DebtProposalModelCopyWithImpl<$Res>
    implements $DebtProposalModelCopyWith<$Res> {
  _$DebtProposalModelCopyWithImpl(this._self, this._then);

  final DebtProposalModel _self;
  final $Res Function(DebtProposalModel) _then;

/// Create a copy of DebtProposalModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? kind = null,Object? repaysId = freezed,Object? outstanding = freezed,Object? proposerId = null,Object? counterpartyId = null,Object? debtorId = null,Object? title = null,Object? amount = freezed,Object? originalAmount = freezed,Object? status = null,Object? awaitingId = freezed,Object? round = null,Object? rejectReason = freezed,Object? createdAt = null,Object? updatedAt = null,Object? resolvedAt = freezed,Object? otherId = freezed,Object? otherHandle = freezed,Object? otherDisplayName = freezed,Object? otherAvatarUrl = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,repaysId: freezed == repaysId ? _self.repaysId : repaysId // ignore: cast_nullable_to_non_nullable
as String?,outstanding: freezed == outstanding ? _self.outstanding : outstanding // ignore: cast_nullable_to_non_nullable
as int?,proposerId: null == proposerId ? _self.proposerId : proposerId // ignore: cast_nullable_to_non_nullable
as String,counterpartyId: null == counterpartyId ? _self.counterpartyId : counterpartyId // ignore: cast_nullable_to_non_nullable
as String,debtorId: null == debtorId ? _self.debtorId : debtorId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,amount: freezed == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int?,originalAmount: freezed == originalAmount ? _self.originalAmount : originalAmount // ignore: cast_nullable_to_non_nullable
as int?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,awaitingId: freezed == awaitingId ? _self.awaitingId : awaitingId // ignore: cast_nullable_to_non_nullable
as String?,round: null == round ? _self.round : round // ignore: cast_nullable_to_non_nullable
as int,rejectReason: freezed == rejectReason ? _self.rejectReason : rejectReason // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,resolvedAt: freezed == resolvedAt ? _self.resolvedAt : resolvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,otherId: freezed == otherId ? _self.otherId : otherId // ignore: cast_nullable_to_non_nullable
as String?,otherHandle: freezed == otherHandle ? _self.otherHandle : otherHandle // ignore: cast_nullable_to_non_nullable
as String?,otherDisplayName: freezed == otherDisplayName ? _self.otherDisplayName : otherDisplayName // ignore: cast_nullable_to_non_nullable
as String?,otherAvatarUrl: freezed == otherAvatarUrl ? _self.otherAvatarUrl : otherAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [DebtProposalModel].
extension DebtProposalModelPatterns on DebtProposalModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DebtProposalModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DebtProposalModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DebtProposalModel value)  $default,){
final _that = this;
switch (_that) {
case _DebtProposalModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DebtProposalModel value)?  $default,){
final _that = this;
switch (_that) {
case _DebtProposalModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String kind, @JsonKey(name: 'repays_id')  String? repaysId,  int? outstanding, @JsonKey(name: 'proposer_id')  String proposerId, @JsonKey(name: 'counterparty_id')  String counterpartyId, @JsonKey(name: 'debtor_id')  String debtorId,  String title,  int? amount, @JsonKey(name: 'original_amount')  int? originalAmount,  String status, @JsonKey(name: 'awaiting_id')  String? awaitingId,  int round, @JsonKey(name: 'reject_reason')  String? rejectReason, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'updated_at')  DateTime updatedAt, @JsonKey(name: 'resolved_at')  DateTime? resolvedAt, @JsonKey(name: 'other_id')  String? otherId, @JsonKey(name: 'other_handle')  String? otherHandle, @JsonKey(name: 'other_display_name')  String? otherDisplayName, @JsonKey(name: 'other_avatar_url')  String? otherAvatarUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DebtProposalModel() when $default != null:
return $default(_that.id,_that.kind,_that.repaysId,_that.outstanding,_that.proposerId,_that.counterpartyId,_that.debtorId,_that.title,_that.amount,_that.originalAmount,_that.status,_that.awaitingId,_that.round,_that.rejectReason,_that.createdAt,_that.updatedAt,_that.resolvedAt,_that.otherId,_that.otherHandle,_that.otherDisplayName,_that.otherAvatarUrl);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String kind, @JsonKey(name: 'repays_id')  String? repaysId,  int? outstanding, @JsonKey(name: 'proposer_id')  String proposerId, @JsonKey(name: 'counterparty_id')  String counterpartyId, @JsonKey(name: 'debtor_id')  String debtorId,  String title,  int? amount, @JsonKey(name: 'original_amount')  int? originalAmount,  String status, @JsonKey(name: 'awaiting_id')  String? awaitingId,  int round, @JsonKey(name: 'reject_reason')  String? rejectReason, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'updated_at')  DateTime updatedAt, @JsonKey(name: 'resolved_at')  DateTime? resolvedAt, @JsonKey(name: 'other_id')  String? otherId, @JsonKey(name: 'other_handle')  String? otherHandle, @JsonKey(name: 'other_display_name')  String? otherDisplayName, @JsonKey(name: 'other_avatar_url')  String? otherAvatarUrl)  $default,) {final _that = this;
switch (_that) {
case _DebtProposalModel():
return $default(_that.id,_that.kind,_that.repaysId,_that.outstanding,_that.proposerId,_that.counterpartyId,_that.debtorId,_that.title,_that.amount,_that.originalAmount,_that.status,_that.awaitingId,_that.round,_that.rejectReason,_that.createdAt,_that.updatedAt,_that.resolvedAt,_that.otherId,_that.otherHandle,_that.otherDisplayName,_that.otherAvatarUrl);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String kind, @JsonKey(name: 'repays_id')  String? repaysId,  int? outstanding, @JsonKey(name: 'proposer_id')  String proposerId, @JsonKey(name: 'counterparty_id')  String counterpartyId, @JsonKey(name: 'debtor_id')  String debtorId,  String title,  int? amount, @JsonKey(name: 'original_amount')  int? originalAmount,  String status, @JsonKey(name: 'awaiting_id')  String? awaitingId,  int round, @JsonKey(name: 'reject_reason')  String? rejectReason, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'updated_at')  DateTime updatedAt, @JsonKey(name: 'resolved_at')  DateTime? resolvedAt, @JsonKey(name: 'other_id')  String? otherId, @JsonKey(name: 'other_handle')  String? otherHandle, @JsonKey(name: 'other_display_name')  String? otherDisplayName, @JsonKey(name: 'other_avatar_url')  String? otherAvatarUrl)?  $default,) {final _that = this;
switch (_that) {
case _DebtProposalModel() when $default != null:
return $default(_that.id,_that.kind,_that.repaysId,_that.outstanding,_that.proposerId,_that.counterpartyId,_that.debtorId,_that.title,_that.amount,_that.originalAmount,_that.status,_that.awaitingId,_that.round,_that.rejectReason,_that.createdAt,_that.updatedAt,_that.resolvedAt,_that.otherId,_that.otherHandle,_that.otherDisplayName,_that.otherAvatarUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DebtProposalModel extends DebtProposalModel {
  const _DebtProposalModel({required this.id, this.kind = 'debt', @JsonKey(name: 'repays_id') this.repaysId, this.outstanding, @JsonKey(name: 'proposer_id') required this.proposerId, @JsonKey(name: 'counterparty_id') required this.counterpartyId, @JsonKey(name: 'debtor_id') required this.debtorId, required this.title, this.amount, @JsonKey(name: 'original_amount') this.originalAmount, required this.status, @JsonKey(name: 'awaiting_id') this.awaitingId, this.round = 0, @JsonKey(name: 'reject_reason') this.rejectReason, @JsonKey(name: 'created_at') required this.createdAt, @JsonKey(name: 'updated_at') required this.updatedAt, @JsonKey(name: 'resolved_at') this.resolvedAt, @JsonKey(name: 'other_id') this.otherId, @JsonKey(name: 'other_handle') this.otherHandle, @JsonKey(name: 'other_display_name') this.otherDisplayName, @JsonKey(name: 'other_avatar_url') this.otherAvatarUrl}): super._();
  factory _DebtProposalModel.fromJson(Map<String, dynamic> json) => _$DebtProposalModelFromJson(json);

@override final  String id;
/// `debt` or `repayment`.
@override@JsonKey() final  String kind;
/// The debt this repayment clears; null on a debt.
@override@JsonKey(name: 'repays_id') final  String? repaysId;
/// What is still owed after every agreed repayment. Server-computed, and
/// only ever present on a confirmed debt.
@override final  int? outstanding;
@override@JsonKey(name: 'proposer_id') final  String proposerId;
@override@JsonKey(name: 'counterparty_id') final  String counterpartyId;
/// Whoever owes the money — always one of the two parties.
@override@JsonKey(name: 'debtor_id') final  String debtorId;
@override final  String title;
/// Null means the proposer left it blank for the other side to fill in.
@override final  int? amount;
/// The previous figure, set when the other side counters.
@override@JsonKey(name: 'original_amount') final  int? originalAmount;
@override final  String status;
/// Whose turn it is; null on every terminal status.
@override@JsonKey(name: 'awaiting_id') final  String? awaitingId;
@override@JsonKey() final  int round;
@override@JsonKey(name: 'reject_reason') final  String? rejectReason;
@override@JsonKey(name: 'created_at') final  DateTime createdAt;
@override@JsonKey(name: 'updated_at') final  DateTime updatedAt;
@override@JsonKey(name: 'resolved_at') final  DateTime? resolvedAt;
@override@JsonKey(name: 'other_id') final  String? otherId;
@override@JsonKey(name: 'other_handle') final  String? otherHandle;
@override@JsonKey(name: 'other_display_name') final  String? otherDisplayName;
@override@JsonKey(name: 'other_avatar_url') final  String? otherAvatarUrl;

/// Create a copy of DebtProposalModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DebtProposalModelCopyWith<_DebtProposalModel> get copyWith => __$DebtProposalModelCopyWithImpl<_DebtProposalModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DebtProposalModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DebtProposalModel&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.repaysId, repaysId) || other.repaysId == repaysId)&&(identical(other.outstanding, outstanding) || other.outstanding == outstanding)&&(identical(other.proposerId, proposerId) || other.proposerId == proposerId)&&(identical(other.counterpartyId, counterpartyId) || other.counterpartyId == counterpartyId)&&(identical(other.debtorId, debtorId) || other.debtorId == debtorId)&&(identical(other.title, title) || other.title == title)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.originalAmount, originalAmount) || other.originalAmount == originalAmount)&&(identical(other.status, status) || other.status == status)&&(identical(other.awaitingId, awaitingId) || other.awaitingId == awaitingId)&&(identical(other.round, round) || other.round == round)&&(identical(other.rejectReason, rejectReason) || other.rejectReason == rejectReason)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.resolvedAt, resolvedAt) || other.resolvedAt == resolvedAt)&&(identical(other.otherId, otherId) || other.otherId == otherId)&&(identical(other.otherHandle, otherHandle) || other.otherHandle == otherHandle)&&(identical(other.otherDisplayName, otherDisplayName) || other.otherDisplayName == otherDisplayName)&&(identical(other.otherAvatarUrl, otherAvatarUrl) || other.otherAvatarUrl == otherAvatarUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,kind,repaysId,outstanding,proposerId,counterpartyId,debtorId,title,amount,originalAmount,status,awaitingId,round,rejectReason,createdAt,updatedAt,resolvedAt,otherId,otherHandle,otherDisplayName,otherAvatarUrl]);

@override
String toString() {
  return 'DebtProposalModel(id: $id, kind: $kind, repaysId: $repaysId, outstanding: $outstanding, proposerId: $proposerId, counterpartyId: $counterpartyId, debtorId: $debtorId, title: $title, amount: $amount, originalAmount: $originalAmount, status: $status, awaitingId: $awaitingId, round: $round, rejectReason: $rejectReason, createdAt: $createdAt, updatedAt: $updatedAt, resolvedAt: $resolvedAt, otherId: $otherId, otherHandle: $otherHandle, otherDisplayName: $otherDisplayName, otherAvatarUrl: $otherAvatarUrl)';
}


}

/// @nodoc
abstract mixin class _$DebtProposalModelCopyWith<$Res> implements $DebtProposalModelCopyWith<$Res> {
  factory _$DebtProposalModelCopyWith(_DebtProposalModel value, $Res Function(_DebtProposalModel) _then) = __$DebtProposalModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String kind,@JsonKey(name: 'repays_id') String? repaysId, int? outstanding,@JsonKey(name: 'proposer_id') String proposerId,@JsonKey(name: 'counterparty_id') String counterpartyId,@JsonKey(name: 'debtor_id') String debtorId, String title, int? amount,@JsonKey(name: 'original_amount') int? originalAmount, String status,@JsonKey(name: 'awaiting_id') String? awaitingId, int round,@JsonKey(name: 'reject_reason') String? rejectReason,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'updated_at') DateTime updatedAt,@JsonKey(name: 'resolved_at') DateTime? resolvedAt,@JsonKey(name: 'other_id') String? otherId,@JsonKey(name: 'other_handle') String? otherHandle,@JsonKey(name: 'other_display_name') String? otherDisplayName,@JsonKey(name: 'other_avatar_url') String? otherAvatarUrl
});




}
/// @nodoc
class __$DebtProposalModelCopyWithImpl<$Res>
    implements _$DebtProposalModelCopyWith<$Res> {
  __$DebtProposalModelCopyWithImpl(this._self, this._then);

  final _DebtProposalModel _self;
  final $Res Function(_DebtProposalModel) _then;

/// Create a copy of DebtProposalModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? kind = null,Object? repaysId = freezed,Object? outstanding = freezed,Object? proposerId = null,Object? counterpartyId = null,Object? debtorId = null,Object? title = null,Object? amount = freezed,Object? originalAmount = freezed,Object? status = null,Object? awaitingId = freezed,Object? round = null,Object? rejectReason = freezed,Object? createdAt = null,Object? updatedAt = null,Object? resolvedAt = freezed,Object? otherId = freezed,Object? otherHandle = freezed,Object? otherDisplayName = freezed,Object? otherAvatarUrl = freezed,}) {
  return _then(_DebtProposalModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,repaysId: freezed == repaysId ? _self.repaysId : repaysId // ignore: cast_nullable_to_non_nullable
as String?,outstanding: freezed == outstanding ? _self.outstanding : outstanding // ignore: cast_nullable_to_non_nullable
as int?,proposerId: null == proposerId ? _self.proposerId : proposerId // ignore: cast_nullable_to_non_nullable
as String,counterpartyId: null == counterpartyId ? _self.counterpartyId : counterpartyId // ignore: cast_nullable_to_non_nullable
as String,debtorId: null == debtorId ? _self.debtorId : debtorId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,amount: freezed == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int?,originalAmount: freezed == originalAmount ? _self.originalAmount : originalAmount // ignore: cast_nullable_to_non_nullable
as int?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,awaitingId: freezed == awaitingId ? _self.awaitingId : awaitingId // ignore: cast_nullable_to_non_nullable
as String?,round: null == round ? _self.round : round // ignore: cast_nullable_to_non_nullable
as int,rejectReason: freezed == rejectReason ? _self.rejectReason : rejectReason // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,resolvedAt: freezed == resolvedAt ? _self.resolvedAt : resolvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,otherId: freezed == otherId ? _self.otherId : otherId // ignore: cast_nullable_to_non_nullable
as String?,otherHandle: freezed == otherHandle ? _self.otherHandle : otherHandle // ignore: cast_nullable_to_non_nullable
as String?,otherDisplayName: freezed == otherDisplayName ? _self.otherDisplayName : otherDisplayName // ignore: cast_nullable_to_non_nullable
as String?,otherAvatarUrl: freezed == otherAvatarUrl ? _self.otherAvatarUrl : otherAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
