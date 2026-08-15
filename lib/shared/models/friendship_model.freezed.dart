// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'friendship_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FriendshipModel {

/// The other person's `public.users` id.
@JsonKey(name: 'other_id') String get otherId; String? get handle;@JsonKey(name: 'display_name') String? get displayName;/// Already resolved server-side to uploaded-avatar-then-provider-mirror.
@JsonKey(name: 'avatar_url') String? get avatarUrl;@JsonKey(unknownEnumValue: FriendshipStatus.pending) FriendshipStatus get status;/// Who asked. On a pending row this is the whole question: if it is us we
/// are waiting, if it is them we owe an answer.
@JsonKey(name: 'requested_by') String get requestedBy;@JsonKey(name: 'created_at') DateTime get createdAt;
/// Create a copy of FriendshipModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FriendshipModelCopyWith<FriendshipModel> get copyWith => _$FriendshipModelCopyWithImpl<FriendshipModel>(this as FriendshipModel, _$identity);

  /// Serializes this FriendshipModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FriendshipModel&&(identical(other.otherId, otherId) || other.otherId == otherId)&&(identical(other.handle, handle) || other.handle == handle)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.status, status) || other.status == status)&&(identical(other.requestedBy, requestedBy) || other.requestedBy == requestedBy)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,otherId,handle,displayName,avatarUrl,status,requestedBy,createdAt);

@override
String toString() {
  return 'FriendshipModel(otherId: $otherId, handle: $handle, displayName: $displayName, avatarUrl: $avatarUrl, status: $status, requestedBy: $requestedBy, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $FriendshipModelCopyWith<$Res>  {
  factory $FriendshipModelCopyWith(FriendshipModel value, $Res Function(FriendshipModel) _then) = _$FriendshipModelCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'other_id') String otherId, String? handle,@JsonKey(name: 'display_name') String? displayName,@JsonKey(name: 'avatar_url') String? avatarUrl,@JsonKey(unknownEnumValue: FriendshipStatus.pending) FriendshipStatus status,@JsonKey(name: 'requested_by') String requestedBy,@JsonKey(name: 'created_at') DateTime createdAt
});




}
/// @nodoc
class _$FriendshipModelCopyWithImpl<$Res>
    implements $FriendshipModelCopyWith<$Res> {
  _$FriendshipModelCopyWithImpl(this._self, this._then);

  final FriendshipModel _self;
  final $Res Function(FriendshipModel) _then;

/// Create a copy of FriendshipModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? otherId = null,Object? handle = freezed,Object? displayName = freezed,Object? avatarUrl = freezed,Object? status = null,Object? requestedBy = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
otherId: null == otherId ? _self.otherId : otherId // ignore: cast_nullable_to_non_nullable
as String,handle: freezed == handle ? _self.handle : handle // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as FriendshipStatus,requestedBy: null == requestedBy ? _self.requestedBy : requestedBy // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [FriendshipModel].
extension FriendshipModelPatterns on FriendshipModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FriendshipModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FriendshipModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FriendshipModel value)  $default,){
final _that = this;
switch (_that) {
case _FriendshipModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FriendshipModel value)?  $default,){
final _that = this;
switch (_that) {
case _FriendshipModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'other_id')  String otherId,  String? handle, @JsonKey(name: 'display_name')  String? displayName, @JsonKey(name: 'avatar_url')  String? avatarUrl, @JsonKey(unknownEnumValue: FriendshipStatus.pending)  FriendshipStatus status, @JsonKey(name: 'requested_by')  String requestedBy, @JsonKey(name: 'created_at')  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FriendshipModel() when $default != null:
return $default(_that.otherId,_that.handle,_that.displayName,_that.avatarUrl,_that.status,_that.requestedBy,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'other_id')  String otherId,  String? handle, @JsonKey(name: 'display_name')  String? displayName, @JsonKey(name: 'avatar_url')  String? avatarUrl, @JsonKey(unknownEnumValue: FriendshipStatus.pending)  FriendshipStatus status, @JsonKey(name: 'requested_by')  String requestedBy, @JsonKey(name: 'created_at')  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _FriendshipModel():
return $default(_that.otherId,_that.handle,_that.displayName,_that.avatarUrl,_that.status,_that.requestedBy,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'other_id')  String otherId,  String? handle, @JsonKey(name: 'display_name')  String? displayName, @JsonKey(name: 'avatar_url')  String? avatarUrl, @JsonKey(unknownEnumValue: FriendshipStatus.pending)  FriendshipStatus status, @JsonKey(name: 'requested_by')  String requestedBy, @JsonKey(name: 'created_at')  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _FriendshipModel() when $default != null:
return $default(_that.otherId,_that.handle,_that.displayName,_that.avatarUrl,_that.status,_that.requestedBy,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FriendshipModel extends FriendshipModel {
  const _FriendshipModel({@JsonKey(name: 'other_id') required this.otherId, this.handle, @JsonKey(name: 'display_name') this.displayName, @JsonKey(name: 'avatar_url') this.avatarUrl, @JsonKey(unknownEnumValue: FriendshipStatus.pending) required this.status, @JsonKey(name: 'requested_by') required this.requestedBy, @JsonKey(name: 'created_at') required this.createdAt}): super._();
  factory _FriendshipModel.fromJson(Map<String, dynamic> json) => _$FriendshipModelFromJson(json);

/// The other person's `public.users` id.
@override@JsonKey(name: 'other_id') final  String otherId;
@override final  String? handle;
@override@JsonKey(name: 'display_name') final  String? displayName;
/// Already resolved server-side to uploaded-avatar-then-provider-mirror.
@override@JsonKey(name: 'avatar_url') final  String? avatarUrl;
@override@JsonKey(unknownEnumValue: FriendshipStatus.pending) final  FriendshipStatus status;
/// Who asked. On a pending row this is the whole question: if it is us we
/// are waiting, if it is them we owe an answer.
@override@JsonKey(name: 'requested_by') final  String requestedBy;
@override@JsonKey(name: 'created_at') final  DateTime createdAt;

/// Create a copy of FriendshipModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FriendshipModelCopyWith<_FriendshipModel> get copyWith => __$FriendshipModelCopyWithImpl<_FriendshipModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FriendshipModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FriendshipModel&&(identical(other.otherId, otherId) || other.otherId == otherId)&&(identical(other.handle, handle) || other.handle == handle)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.status, status) || other.status == status)&&(identical(other.requestedBy, requestedBy) || other.requestedBy == requestedBy)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,otherId,handle,displayName,avatarUrl,status,requestedBy,createdAt);

@override
String toString() {
  return 'FriendshipModel(otherId: $otherId, handle: $handle, displayName: $displayName, avatarUrl: $avatarUrl, status: $status, requestedBy: $requestedBy, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$FriendshipModelCopyWith<$Res> implements $FriendshipModelCopyWith<$Res> {
  factory _$FriendshipModelCopyWith(_FriendshipModel value, $Res Function(_FriendshipModel) _then) = __$FriendshipModelCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'other_id') String otherId, String? handle,@JsonKey(name: 'display_name') String? displayName,@JsonKey(name: 'avatar_url') String? avatarUrl,@JsonKey(unknownEnumValue: FriendshipStatus.pending) FriendshipStatus status,@JsonKey(name: 'requested_by') String requestedBy,@JsonKey(name: 'created_at') DateTime createdAt
});




}
/// @nodoc
class __$FriendshipModelCopyWithImpl<$Res>
    implements _$FriendshipModelCopyWith<$Res> {
  __$FriendshipModelCopyWithImpl(this._self, this._then);

  final _FriendshipModel _self;
  final $Res Function(_FriendshipModel) _then;

/// Create a copy of FriendshipModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? otherId = null,Object? handle = freezed,Object? displayName = freezed,Object? avatarUrl = freezed,Object? status = null,Object? requestedBy = null,Object? createdAt = null,}) {
  return _then(_FriendshipModel(
otherId: null == otherId ? _self.otherId : otherId // ignore: cast_nullable_to_non_nullable
as String,handle: freezed == handle ? _self.handle : handle // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as FriendshipStatus,requestedBy: null == requestedBy ? _self.requestedBy : requestedBy // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$FriendToken {

 String get token;@JsonKey(name: 'expires_at') DateTime get expiresAt;
/// Create a copy of FriendToken
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FriendTokenCopyWith<FriendToken> get copyWith => _$FriendTokenCopyWithImpl<FriendToken>(this as FriendToken, _$identity);

  /// Serializes this FriendToken to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FriendToken&&(identical(other.token, token) || other.token == token)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,token,expiresAt);

@override
String toString() {
  return 'FriendToken(token: $token, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class $FriendTokenCopyWith<$Res>  {
  factory $FriendTokenCopyWith(FriendToken value, $Res Function(FriendToken) _then) = _$FriendTokenCopyWithImpl;
@useResult
$Res call({
 String token,@JsonKey(name: 'expires_at') DateTime expiresAt
});




}
/// @nodoc
class _$FriendTokenCopyWithImpl<$Res>
    implements $FriendTokenCopyWith<$Res> {
  _$FriendTokenCopyWithImpl(this._self, this._then);

  final FriendToken _self;
  final $Res Function(FriendToken) _then;

/// Create a copy of FriendToken
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? token = null,Object? expiresAt = null,}) {
  return _then(_self.copyWith(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [FriendToken].
extension FriendTokenPatterns on FriendToken {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FriendToken value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FriendToken() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FriendToken value)  $default,){
final _that = this;
switch (_that) {
case _FriendToken():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FriendToken value)?  $default,){
final _that = this;
switch (_that) {
case _FriendToken() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String token, @JsonKey(name: 'expires_at')  DateTime expiresAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FriendToken() when $default != null:
return $default(_that.token,_that.expiresAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String token, @JsonKey(name: 'expires_at')  DateTime expiresAt)  $default,) {final _that = this;
switch (_that) {
case _FriendToken():
return $default(_that.token,_that.expiresAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String token, @JsonKey(name: 'expires_at')  DateTime expiresAt)?  $default,) {final _that = this;
switch (_that) {
case _FriendToken() when $default != null:
return $default(_that.token,_that.expiresAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FriendToken implements FriendToken {
  const _FriendToken({required this.token, @JsonKey(name: 'expires_at') required this.expiresAt});
  factory _FriendToken.fromJson(Map<String, dynamic> json) => _$FriendTokenFromJson(json);

@override final  String token;
@override@JsonKey(name: 'expires_at') final  DateTime expiresAt;

/// Create a copy of FriendToken
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FriendTokenCopyWith<_FriendToken> get copyWith => __$FriendTokenCopyWithImpl<_FriendToken>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FriendTokenToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FriendToken&&(identical(other.token, token) || other.token == token)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,token,expiresAt);

@override
String toString() {
  return 'FriendToken(token: $token, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class _$FriendTokenCopyWith<$Res> implements $FriendTokenCopyWith<$Res> {
  factory _$FriendTokenCopyWith(_FriendToken value, $Res Function(_FriendToken) _then) = __$FriendTokenCopyWithImpl;
@override @useResult
$Res call({
 String token,@JsonKey(name: 'expires_at') DateTime expiresAt
});




}
/// @nodoc
class __$FriendTokenCopyWithImpl<$Res>
    implements _$FriendTokenCopyWith<$Res> {
  __$FriendTokenCopyWithImpl(this._self, this._then);

  final _FriendToken _self;
  final $Res Function(_FriendToken) _then;

/// Create a copy of FriendToken
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? token = null,Object? expiresAt = null,}) {
  return _then(_FriendToken(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
