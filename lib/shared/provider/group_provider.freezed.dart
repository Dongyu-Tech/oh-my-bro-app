// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'group_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GroupSummary {

/// Total spent across all expenses.
 int get total;/// memberId → net balance (>0 owed to them, <0 they owe).
 Map<String, int> get net;/// Minimal repayment plan.
 List<Transfer> get transfers;/// The signed-in member's net balance.
 int get myNet;/// What "I" actually consumed here: the sum of my expense shares (independent
/// of who paid or settlements). This is my real out-of-pocket cost once the
/// gathering is settled — the amount offered to 個人記帳 on 結清.
 int get myShare;
/// Create a copy of GroupSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GroupSummaryCopyWith<GroupSummary> get copyWith => _$GroupSummaryCopyWithImpl<GroupSummary>(this as GroupSummary, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GroupSummary&&(identical(other.total, total) || other.total == total)&&const DeepCollectionEquality().equals(other.net, net)&&const DeepCollectionEquality().equals(other.transfers, transfers)&&(identical(other.myNet, myNet) || other.myNet == myNet)&&(identical(other.myShare, myShare) || other.myShare == myShare));
}


@override
int get hashCode => Object.hash(runtimeType,total,const DeepCollectionEquality().hash(net),const DeepCollectionEquality().hash(transfers),myNet,myShare);

@override
String toString() {
  return 'GroupSummary(total: $total, net: $net, transfers: $transfers, myNet: $myNet, myShare: $myShare)';
}


}

/// @nodoc
abstract mixin class $GroupSummaryCopyWith<$Res>  {
  factory $GroupSummaryCopyWith(GroupSummary value, $Res Function(GroupSummary) _then) = _$GroupSummaryCopyWithImpl;
@useResult
$Res call({
 int total, Map<String, int> net, List<Transfer> transfers, int myNet, int myShare
});




}
/// @nodoc
class _$GroupSummaryCopyWithImpl<$Res>
    implements $GroupSummaryCopyWith<$Res> {
  _$GroupSummaryCopyWithImpl(this._self, this._then);

  final GroupSummary _self;
  final $Res Function(GroupSummary) _then;

/// Create a copy of GroupSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? total = null,Object? net = null,Object? transfers = null,Object? myNet = null,Object? myShare = null,}) {
  return _then(_self.copyWith(
total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,net: null == net ? _self.net : net // ignore: cast_nullable_to_non_nullable
as Map<String, int>,transfers: null == transfers ? _self.transfers : transfers // ignore: cast_nullable_to_non_nullable
as List<Transfer>,myNet: null == myNet ? _self.myNet : myNet // ignore: cast_nullable_to_non_nullable
as int,myShare: null == myShare ? _self.myShare : myShare // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [GroupSummary].
extension GroupSummaryPatterns on GroupSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GroupSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GroupSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GroupSummary value)  $default,){
final _that = this;
switch (_that) {
case _GroupSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GroupSummary value)?  $default,){
final _that = this;
switch (_that) {
case _GroupSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int total,  Map<String, int> net,  List<Transfer> transfers,  int myNet,  int myShare)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GroupSummary() when $default != null:
return $default(_that.total,_that.net,_that.transfers,_that.myNet,_that.myShare);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int total,  Map<String, int> net,  List<Transfer> transfers,  int myNet,  int myShare)  $default,) {final _that = this;
switch (_that) {
case _GroupSummary():
return $default(_that.total,_that.net,_that.transfers,_that.myNet,_that.myShare);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int total,  Map<String, int> net,  List<Transfer> transfers,  int myNet,  int myShare)?  $default,) {final _that = this;
switch (_that) {
case _GroupSummary() when $default != null:
return $default(_that.total,_that.net,_that.transfers,_that.myNet,_that.myShare);case _:
  return null;

}
}

}

/// @nodoc


class _GroupSummary implements GroupSummary {
  const _GroupSummary({required this.total, required final  Map<String, int> net, required final  List<Transfer> transfers, required this.myNet, required this.myShare}): _net = net,_transfers = transfers;
  

/// Total spent across all expenses.
@override final  int total;
/// memberId → net balance (>0 owed to them, <0 they owe).
 final  Map<String, int> _net;
/// memberId → net balance (>0 owed to them, <0 they owe).
@override Map<String, int> get net {
  if (_net is EqualUnmodifiableMapView) return _net;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_net);
}

/// Minimal repayment plan.
 final  List<Transfer> _transfers;
/// Minimal repayment plan.
@override List<Transfer> get transfers {
  if (_transfers is EqualUnmodifiableListView) return _transfers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_transfers);
}

/// The signed-in member's net balance.
@override final  int myNet;
/// What "I" actually consumed here: the sum of my expense shares (independent
/// of who paid or settlements). This is my real out-of-pocket cost once the
/// gathering is settled — the amount offered to 個人記帳 on 結清.
@override final  int myShare;

/// Create a copy of GroupSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GroupSummaryCopyWith<_GroupSummary> get copyWith => __$GroupSummaryCopyWithImpl<_GroupSummary>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GroupSummary&&(identical(other.total, total) || other.total == total)&&const DeepCollectionEquality().equals(other._net, _net)&&const DeepCollectionEquality().equals(other._transfers, _transfers)&&(identical(other.myNet, myNet) || other.myNet == myNet)&&(identical(other.myShare, myShare) || other.myShare == myShare));
}


@override
int get hashCode => Object.hash(runtimeType,total,const DeepCollectionEquality().hash(_net),const DeepCollectionEquality().hash(_transfers),myNet,myShare);

@override
String toString() {
  return 'GroupSummary(total: $total, net: $net, transfers: $transfers, myNet: $myNet, myShare: $myShare)';
}


}

/// @nodoc
abstract mixin class _$GroupSummaryCopyWith<$Res> implements $GroupSummaryCopyWith<$Res> {
  factory _$GroupSummaryCopyWith(_GroupSummary value, $Res Function(_GroupSummary) _then) = __$GroupSummaryCopyWithImpl;
@override @useResult
$Res call({
 int total, Map<String, int> net, List<Transfer> transfers, int myNet, int myShare
});




}
/// @nodoc
class __$GroupSummaryCopyWithImpl<$Res>
    implements _$GroupSummaryCopyWith<$Res> {
  __$GroupSummaryCopyWithImpl(this._self, this._then);

  final _GroupSummary _self;
  final $Res Function(_GroupSummary) _then;

/// Create a copy of GroupSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? total = null,Object? net = null,Object? transfers = null,Object? myNet = null,Object? myShare = null,}) {
  return _then(_GroupSummary(
total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,net: null == net ? _self._net : net // ignore: cast_nullable_to_non_nullable
as Map<String, int>,transfers: null == transfers ? _self._transfers : transfers // ignore: cast_nullable_to_non_nullable
as List<Transfer>,myNet: null == myNet ? _self.myNet : myNet // ignore: cast_nullable_to_non_nullable
as int,myShare: null == myShare ? _self.myShare : myShare // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$DebtRecord {

 String get groupId; String get groupName; String get otherName;/// Their picture, via the member's linked [Friend]. Null for a member who
/// was never linked to one, or who simply has no photo.
 String? get otherAvatarUrl;/// true = they owe me, false = I owe them.
 bool get owedToMe;/// The underlying settle-up transfer (for the 結清 action).
 Transfer get transfer;
/// Create a copy of DebtRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DebtRecordCopyWith<DebtRecord> get copyWith => _$DebtRecordCopyWithImpl<DebtRecord>(this as DebtRecord, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DebtRecord&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.groupName, groupName) || other.groupName == groupName)&&(identical(other.otherName, otherName) || other.otherName == otherName)&&(identical(other.otherAvatarUrl, otherAvatarUrl) || other.otherAvatarUrl == otherAvatarUrl)&&(identical(other.owedToMe, owedToMe) || other.owedToMe == owedToMe)&&(identical(other.transfer, transfer) || other.transfer == transfer));
}


@override
int get hashCode => Object.hash(runtimeType,groupId,groupName,otherName,otherAvatarUrl,owedToMe,transfer);

@override
String toString() {
  return 'DebtRecord(groupId: $groupId, groupName: $groupName, otherName: $otherName, otherAvatarUrl: $otherAvatarUrl, owedToMe: $owedToMe, transfer: $transfer)';
}


}

/// @nodoc
abstract mixin class $DebtRecordCopyWith<$Res>  {
  factory $DebtRecordCopyWith(DebtRecord value, $Res Function(DebtRecord) _then) = _$DebtRecordCopyWithImpl;
@useResult
$Res call({
 String groupId, String groupName, String otherName, String? otherAvatarUrl, bool owedToMe, Transfer transfer
});


$TransferCopyWith<$Res> get transfer;

}
/// @nodoc
class _$DebtRecordCopyWithImpl<$Res>
    implements $DebtRecordCopyWith<$Res> {
  _$DebtRecordCopyWithImpl(this._self, this._then);

  final DebtRecord _self;
  final $Res Function(DebtRecord) _then;

/// Create a copy of DebtRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? groupId = null,Object? groupName = null,Object? otherName = null,Object? otherAvatarUrl = freezed,Object? owedToMe = null,Object? transfer = null,}) {
  return _then(_self.copyWith(
groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,groupName: null == groupName ? _self.groupName : groupName // ignore: cast_nullable_to_non_nullable
as String,otherName: null == otherName ? _self.otherName : otherName // ignore: cast_nullable_to_non_nullable
as String,otherAvatarUrl: freezed == otherAvatarUrl ? _self.otherAvatarUrl : otherAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,owedToMe: null == owedToMe ? _self.owedToMe : owedToMe // ignore: cast_nullable_to_non_nullable
as bool,transfer: null == transfer ? _self.transfer : transfer // ignore: cast_nullable_to_non_nullable
as Transfer,
  ));
}
/// Create a copy of DebtRecord
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TransferCopyWith<$Res> get transfer {
  
  return $TransferCopyWith<$Res>(_self.transfer, (value) {
    return _then(_self.copyWith(transfer: value));
  });
}
}


/// Adds pattern-matching-related methods to [DebtRecord].
extension DebtRecordPatterns on DebtRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DebtRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DebtRecord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DebtRecord value)  $default,){
final _that = this;
switch (_that) {
case _DebtRecord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DebtRecord value)?  $default,){
final _that = this;
switch (_that) {
case _DebtRecord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String groupId,  String groupName,  String otherName,  String? otherAvatarUrl,  bool owedToMe,  Transfer transfer)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DebtRecord() when $default != null:
return $default(_that.groupId,_that.groupName,_that.otherName,_that.otherAvatarUrl,_that.owedToMe,_that.transfer);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String groupId,  String groupName,  String otherName,  String? otherAvatarUrl,  bool owedToMe,  Transfer transfer)  $default,) {final _that = this;
switch (_that) {
case _DebtRecord():
return $default(_that.groupId,_that.groupName,_that.otherName,_that.otherAvatarUrl,_that.owedToMe,_that.transfer);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String groupId,  String groupName,  String otherName,  String? otherAvatarUrl,  bool owedToMe,  Transfer transfer)?  $default,) {final _that = this;
switch (_that) {
case _DebtRecord() when $default != null:
return $default(_that.groupId,_that.groupName,_that.otherName,_that.otherAvatarUrl,_that.owedToMe,_that.transfer);case _:
  return null;

}
}

}

/// @nodoc


class _DebtRecord extends DebtRecord {
  const _DebtRecord({required this.groupId, required this.groupName, required this.otherName, this.otherAvatarUrl, required this.owedToMe, required this.transfer}): super._();
  

@override final  String groupId;
@override final  String groupName;
@override final  String otherName;
/// Their picture, via the member's linked [Friend]. Null for a member who
/// was never linked to one, or who simply has no photo.
@override final  String? otherAvatarUrl;
/// true = they owe me, false = I owe them.
@override final  bool owedToMe;
/// The underlying settle-up transfer (for the 結清 action).
@override final  Transfer transfer;

/// Create a copy of DebtRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DebtRecordCopyWith<_DebtRecord> get copyWith => __$DebtRecordCopyWithImpl<_DebtRecord>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DebtRecord&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.groupName, groupName) || other.groupName == groupName)&&(identical(other.otherName, otherName) || other.otherName == otherName)&&(identical(other.otherAvatarUrl, otherAvatarUrl) || other.otherAvatarUrl == otherAvatarUrl)&&(identical(other.owedToMe, owedToMe) || other.owedToMe == owedToMe)&&(identical(other.transfer, transfer) || other.transfer == transfer));
}


@override
int get hashCode => Object.hash(runtimeType,groupId,groupName,otherName,otherAvatarUrl,owedToMe,transfer);

@override
String toString() {
  return 'DebtRecord(groupId: $groupId, groupName: $groupName, otherName: $otherName, otherAvatarUrl: $otherAvatarUrl, owedToMe: $owedToMe, transfer: $transfer)';
}


}

/// @nodoc
abstract mixin class _$DebtRecordCopyWith<$Res> implements $DebtRecordCopyWith<$Res> {
  factory _$DebtRecordCopyWith(_DebtRecord value, $Res Function(_DebtRecord) _then) = __$DebtRecordCopyWithImpl;
@override @useResult
$Res call({
 String groupId, String groupName, String otherName, String? otherAvatarUrl, bool owedToMe, Transfer transfer
});


@override $TransferCopyWith<$Res> get transfer;

}
/// @nodoc
class __$DebtRecordCopyWithImpl<$Res>
    implements _$DebtRecordCopyWith<$Res> {
  __$DebtRecordCopyWithImpl(this._self, this._then);

  final _DebtRecord _self;
  final $Res Function(_DebtRecord) _then;

/// Create a copy of DebtRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? groupId = null,Object? groupName = null,Object? otherName = null,Object? otherAvatarUrl = freezed,Object? owedToMe = null,Object? transfer = null,}) {
  return _then(_DebtRecord(
groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,groupName: null == groupName ? _self.groupName : groupName // ignore: cast_nullable_to_non_nullable
as String,otherName: null == otherName ? _self.otherName : otherName // ignore: cast_nullable_to_non_nullable
as String,otherAvatarUrl: freezed == otherAvatarUrl ? _self.otherAvatarUrl : otherAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,owedToMe: null == owedToMe ? _self.owedToMe : owedToMe // ignore: cast_nullable_to_non_nullable
as bool,transfer: null == transfer ? _self.transfer : transfer // ignore: cast_nullable_to_non_nullable
as Transfer,
  ));
}

/// Create a copy of DebtRecord
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TransferCopyWith<$Res> get transfer {
  
  return $TransferCopyWith<$Res>(_self.transfer, (value) {
    return _then(_self.copyWith(transfer: value));
  });
}
}

// dart format on
