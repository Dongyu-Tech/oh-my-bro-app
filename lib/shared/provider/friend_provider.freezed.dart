// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'friend_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CreditScore {

/// 0–100. Higher = a more trustworthy bro.
 int get score;/// How much they currently owe, unsettled, across all gatherings.
 int get outstanding;/// How many times they've paid someone back.
 int get repaidCount;/// Number of gatherings they've joined.
 int get gatherings;
/// Create a copy of CreditScore
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CreditScoreCopyWith<CreditScore> get copyWith => _$CreditScoreCopyWithImpl<CreditScore>(this as CreditScore, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CreditScore&&(identical(other.score, score) || other.score == score)&&(identical(other.outstanding, outstanding) || other.outstanding == outstanding)&&(identical(other.repaidCount, repaidCount) || other.repaidCount == repaidCount)&&(identical(other.gatherings, gatherings) || other.gatherings == gatherings));
}


@override
int get hashCode => Object.hash(runtimeType,score,outstanding,repaidCount,gatherings);

@override
String toString() {
  return 'CreditScore(score: $score, outstanding: $outstanding, repaidCount: $repaidCount, gatherings: $gatherings)';
}


}

/// @nodoc
abstract mixin class $CreditScoreCopyWith<$Res>  {
  factory $CreditScoreCopyWith(CreditScore value, $Res Function(CreditScore) _then) = _$CreditScoreCopyWithImpl;
@useResult
$Res call({
 int score, int outstanding, int repaidCount, int gatherings
});




}
/// @nodoc
class _$CreditScoreCopyWithImpl<$Res>
    implements $CreditScoreCopyWith<$Res> {
  _$CreditScoreCopyWithImpl(this._self, this._then);

  final CreditScore _self;
  final $Res Function(CreditScore) _then;

/// Create a copy of CreditScore
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? score = null,Object? outstanding = null,Object? repaidCount = null,Object? gatherings = null,}) {
  return _then(_self.copyWith(
score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,outstanding: null == outstanding ? _self.outstanding : outstanding // ignore: cast_nullable_to_non_nullable
as int,repaidCount: null == repaidCount ? _self.repaidCount : repaidCount // ignore: cast_nullable_to_non_nullable
as int,gatherings: null == gatherings ? _self.gatherings : gatherings // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CreditScore].
extension CreditScorePatterns on CreditScore {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CreditScore value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CreditScore() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CreditScore value)  $default,){
final _that = this;
switch (_that) {
case _CreditScore():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CreditScore value)?  $default,){
final _that = this;
switch (_that) {
case _CreditScore() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int score,  int outstanding,  int repaidCount,  int gatherings)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CreditScore() when $default != null:
return $default(_that.score,_that.outstanding,_that.repaidCount,_that.gatherings);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int score,  int outstanding,  int repaidCount,  int gatherings)  $default,) {final _that = this;
switch (_that) {
case _CreditScore():
return $default(_that.score,_that.outstanding,_that.repaidCount,_that.gatherings);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int score,  int outstanding,  int repaidCount,  int gatherings)?  $default,) {final _that = this;
switch (_that) {
case _CreditScore() when $default != null:
return $default(_that.score,_that.outstanding,_that.repaidCount,_that.gatherings);case _:
  return null;

}
}

}

/// @nodoc


class _CreditScore extends CreditScore {
  const _CreditScore({required this.score, required this.outstanding, required this.repaidCount, required this.gatherings}): super._();
  

/// 0–100. Higher = a more trustworthy bro.
@override final  int score;
/// How much they currently owe, unsettled, across all gatherings.
@override final  int outstanding;
/// How many times they've paid someone back.
@override final  int repaidCount;
/// Number of gatherings they've joined.
@override final  int gatherings;

/// Create a copy of CreditScore
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CreditScoreCopyWith<_CreditScore> get copyWith => __$CreditScoreCopyWithImpl<_CreditScore>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CreditScore&&(identical(other.score, score) || other.score == score)&&(identical(other.outstanding, outstanding) || other.outstanding == outstanding)&&(identical(other.repaidCount, repaidCount) || other.repaidCount == repaidCount)&&(identical(other.gatherings, gatherings) || other.gatherings == gatherings));
}


@override
int get hashCode => Object.hash(runtimeType,score,outstanding,repaidCount,gatherings);

@override
String toString() {
  return 'CreditScore(score: $score, outstanding: $outstanding, repaidCount: $repaidCount, gatherings: $gatherings)';
}


}

/// @nodoc
abstract mixin class _$CreditScoreCopyWith<$Res> implements $CreditScoreCopyWith<$Res> {
  factory _$CreditScoreCopyWith(_CreditScore value, $Res Function(_CreditScore) _then) = __$CreditScoreCopyWithImpl;
@override @useResult
$Res call({
 int score, int outstanding, int repaidCount, int gatherings
});




}
/// @nodoc
class __$CreditScoreCopyWithImpl<$Res>
    implements _$CreditScoreCopyWith<$Res> {
  __$CreditScoreCopyWithImpl(this._self, this._then);

  final _CreditScore _self;
  final $Res Function(_CreditScore) _then;

/// Create a copy of CreditScore
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? score = null,Object? outstanding = null,Object? repaidCount = null,Object? gatherings = null,}) {
  return _then(_CreditScore(
score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,outstanding: null == outstanding ? _self.outstanding : outstanding // ignore: cast_nullable_to_non_nullable
as int,repaidCount: null == repaidCount ? _self.repaidCount : repaidCount // ignore: cast_nullable_to_non_nullable
as int,gatherings: null == gatherings ? _self.gatherings : gatherings // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$DirectSettleAction {

 String get groupId; String get fromMemberId; String get toMemberId; int get amount;
/// Create a copy of DirectSettleAction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DirectSettleActionCopyWith<DirectSettleAction> get copyWith => _$DirectSettleActionCopyWithImpl<DirectSettleAction>(this as DirectSettleAction, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DirectSettleAction&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.fromMemberId, fromMemberId) || other.fromMemberId == fromMemberId)&&(identical(other.toMemberId, toMemberId) || other.toMemberId == toMemberId)&&(identical(other.amount, amount) || other.amount == amount));
}


@override
int get hashCode => Object.hash(runtimeType,groupId,fromMemberId,toMemberId,amount);

@override
String toString() {
  return 'DirectSettleAction(groupId: $groupId, fromMemberId: $fromMemberId, toMemberId: $toMemberId, amount: $amount)';
}


}

/// @nodoc
abstract mixin class $DirectSettleActionCopyWith<$Res>  {
  factory $DirectSettleActionCopyWith(DirectSettleAction value, $Res Function(DirectSettleAction) _then) = _$DirectSettleActionCopyWithImpl;
@useResult
$Res call({
 String groupId, String fromMemberId, String toMemberId, int amount
});




}
/// @nodoc
class _$DirectSettleActionCopyWithImpl<$Res>
    implements $DirectSettleActionCopyWith<$Res> {
  _$DirectSettleActionCopyWithImpl(this._self, this._then);

  final DirectSettleAction _self;
  final $Res Function(DirectSettleAction) _then;

/// Create a copy of DirectSettleAction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? groupId = null,Object? fromMemberId = null,Object? toMemberId = null,Object? amount = null,}) {
  return _then(_self.copyWith(
groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,fromMemberId: null == fromMemberId ? _self.fromMemberId : fromMemberId // ignore: cast_nullable_to_non_nullable
as String,toMemberId: null == toMemberId ? _self.toMemberId : toMemberId // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [DirectSettleAction].
extension DirectSettleActionPatterns on DirectSettleAction {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DirectSettleAction value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DirectSettleAction() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DirectSettleAction value)  $default,){
final _that = this;
switch (_that) {
case _DirectSettleAction():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DirectSettleAction value)?  $default,){
final _that = this;
switch (_that) {
case _DirectSettleAction() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String groupId,  String fromMemberId,  String toMemberId,  int amount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DirectSettleAction() when $default != null:
return $default(_that.groupId,_that.fromMemberId,_that.toMemberId,_that.amount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String groupId,  String fromMemberId,  String toMemberId,  int amount)  $default,) {final _that = this;
switch (_that) {
case _DirectSettleAction():
return $default(_that.groupId,_that.fromMemberId,_that.toMemberId,_that.amount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String groupId,  String fromMemberId,  String toMemberId,  int amount)?  $default,) {final _that = this;
switch (_that) {
case _DirectSettleAction() when $default != null:
return $default(_that.groupId,_that.fromMemberId,_that.toMemberId,_that.amount);case _:
  return null;

}
}

}

/// @nodoc


class _DirectSettleAction implements DirectSettleAction {
  const _DirectSettleAction({required this.groupId, required this.fromMemberId, required this.toMemberId, required this.amount});
  

@override final  String groupId;
@override final  String fromMemberId;
@override final  String toMemberId;
@override final  int amount;

/// Create a copy of DirectSettleAction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DirectSettleActionCopyWith<_DirectSettleAction> get copyWith => __$DirectSettleActionCopyWithImpl<_DirectSettleAction>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DirectSettleAction&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.fromMemberId, fromMemberId) || other.fromMemberId == fromMemberId)&&(identical(other.toMemberId, toMemberId) || other.toMemberId == toMemberId)&&(identical(other.amount, amount) || other.amount == amount));
}


@override
int get hashCode => Object.hash(runtimeType,groupId,fromMemberId,toMemberId,amount);

@override
String toString() {
  return 'DirectSettleAction(groupId: $groupId, fromMemberId: $fromMemberId, toMemberId: $toMemberId, amount: $amount)';
}


}

/// @nodoc
abstract mixin class _$DirectSettleActionCopyWith<$Res> implements $DirectSettleActionCopyWith<$Res> {
  factory _$DirectSettleActionCopyWith(_DirectSettleAction value, $Res Function(_DirectSettleAction) _then) = __$DirectSettleActionCopyWithImpl;
@override @useResult
$Res call({
 String groupId, String fromMemberId, String toMemberId, int amount
});




}
/// @nodoc
class __$DirectSettleActionCopyWithImpl<$Res>
    implements _$DirectSettleActionCopyWith<$Res> {
  __$DirectSettleActionCopyWithImpl(this._self, this._then);

  final _DirectSettleAction _self;
  final $Res Function(_DirectSettleAction) _then;

/// Create a copy of DirectSettleAction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? groupId = null,Object? fromMemberId = null,Object? toMemberId = null,Object? amount = null,}) {
  return _then(_DirectSettleAction(
groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,fromMemberId: null == fromMemberId ? _self.fromMemberId : fromMemberId // ignore: cast_nullable_to_non_nullable
as String,toMemberId: null == toMemberId ? _self.toMemberId : toMemberId // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
