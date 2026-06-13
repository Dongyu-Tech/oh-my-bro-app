// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_settings_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AppSettingsModel {

 ThemeMode get themeMode; AppLanguage get language;@ColorIntConverter() Color get themeColor;
/// Create a copy of AppSettingsModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppSettingsModelCopyWith<AppSettingsModel> get copyWith => _$AppSettingsModelCopyWithImpl<AppSettingsModel>(this as AppSettingsModel, _$identity);

  /// Serializes this AppSettingsModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppSettingsModel&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.language, language) || other.language == language)&&(identical(other.themeColor, themeColor) || other.themeColor == themeColor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,themeMode,language,themeColor);

@override
String toString() {
  return 'AppSettingsModel(themeMode: $themeMode, language: $language, themeColor: $themeColor)';
}


}

/// @nodoc
abstract mixin class $AppSettingsModelCopyWith<$Res>  {
  factory $AppSettingsModelCopyWith(AppSettingsModel value, $Res Function(AppSettingsModel) _then) = _$AppSettingsModelCopyWithImpl;
@useResult
$Res call({
 ThemeMode themeMode, AppLanguage language,@ColorIntConverter() Color themeColor
});




}
/// @nodoc
class _$AppSettingsModelCopyWithImpl<$Res>
    implements $AppSettingsModelCopyWith<$Res> {
  _$AppSettingsModelCopyWithImpl(this._self, this._then);

  final AppSettingsModel _self;
  final $Res Function(AppSettingsModel) _then;

/// Create a copy of AppSettingsModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? themeMode = null,Object? language = null,Object? themeColor = null,}) {
  return _then(_self.copyWith(
themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as ThemeMode,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as AppLanguage,themeColor: null == themeColor ? _self.themeColor : themeColor // ignore: cast_nullable_to_non_nullable
as Color,
  ));
}

}


/// Adds pattern-matching-related methods to [AppSettingsModel].
extension AppSettingsModelPatterns on AppSettingsModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppSettingsModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppSettingsModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppSettingsModel value)  $default,){
final _that = this;
switch (_that) {
case _AppSettingsModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppSettingsModel value)?  $default,){
final _that = this;
switch (_that) {
case _AppSettingsModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ThemeMode themeMode,  AppLanguage language, @ColorIntConverter()  Color themeColor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppSettingsModel() when $default != null:
return $default(_that.themeMode,_that.language,_that.themeColor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ThemeMode themeMode,  AppLanguage language, @ColorIntConverter()  Color themeColor)  $default,) {final _that = this;
switch (_that) {
case _AppSettingsModel():
return $default(_that.themeMode,_that.language,_that.themeColor);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ThemeMode themeMode,  AppLanguage language, @ColorIntConverter()  Color themeColor)?  $default,) {final _that = this;
switch (_that) {
case _AppSettingsModel() when $default != null:
return $default(_that.themeMode,_that.language,_that.themeColor);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppSettingsModel implements AppSettingsModel {
  const _AppSettingsModel({this.themeMode = ThemeMode.system, this.language = AppLanguage.english, @ColorIntConverter() this.themeColor = Colors.deepPurple});
  factory _AppSettingsModel.fromJson(Map<String, dynamic> json) => _$AppSettingsModelFromJson(json);

@override@JsonKey() final  ThemeMode themeMode;
@override@JsonKey() final  AppLanguage language;
@override@JsonKey()@ColorIntConverter() final  Color themeColor;

/// Create a copy of AppSettingsModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppSettingsModelCopyWith<_AppSettingsModel> get copyWith => __$AppSettingsModelCopyWithImpl<_AppSettingsModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppSettingsModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppSettingsModel&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.language, language) || other.language == language)&&(identical(other.themeColor, themeColor) || other.themeColor == themeColor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,themeMode,language,themeColor);

@override
String toString() {
  return 'AppSettingsModel(themeMode: $themeMode, language: $language, themeColor: $themeColor)';
}


}

/// @nodoc
abstract mixin class _$AppSettingsModelCopyWith<$Res> implements $AppSettingsModelCopyWith<$Res> {
  factory _$AppSettingsModelCopyWith(_AppSettingsModel value, $Res Function(_AppSettingsModel) _then) = __$AppSettingsModelCopyWithImpl;
@override @useResult
$Res call({
 ThemeMode themeMode, AppLanguage language,@ColorIntConverter() Color themeColor
});




}
/// @nodoc
class __$AppSettingsModelCopyWithImpl<$Res>
    implements _$AppSettingsModelCopyWith<$Res> {
  __$AppSettingsModelCopyWithImpl(this._self, this._then);

  final _AppSettingsModel _self;
  final $Res Function(_AppSettingsModel) _then;

/// Create a copy of AppSettingsModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? themeMode = null,Object? language = null,Object? themeColor = null,}) {
  return _then(_AppSettingsModel(
themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as ThemeMode,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as AppLanguage,themeColor: null == themeColor ? _self.themeColor : themeColor // ignore: cast_nullable_to_non_nullable
as Color,
  ));
}


}

// dart format on
