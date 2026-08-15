// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AppUserModel _$AppUserModelFromJson(Map<String, dynamic> json) =>
    _AppUserModel(
      id: json['id'] as String,
      handle: json['handle'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      providerAvatarUrl: json['provider_avatar_url'] as String?,
      gender: $enumDecodeNullable(
        _$GenderEnumMap,
        json['gender'],
        unknownValue: JsonKey.nullForUndefinedEnumValue,
      ),
      birthday: json['birthday'] == null
          ? null
          : DateTime.parse(json['birthday'] as String),
      bio: json['bio'] as String?,
    );

Map<String, dynamic> _$AppUserModelToJson(_AppUserModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'handle': instance.handle,
      'display_name': instance.displayName,
      'avatar_url': instance.avatarUrl,
      'provider_avatar_url': instance.providerAvatarUrl,
      'gender': _$GenderEnumMap[instance.gender],
      'birthday': instance.birthday?.toIso8601String(),
      'bio': instance.bio,
    };

const _$GenderEnumMap = {
  Gender.male: 'male',
  Gender.female: 'female',
  Gender.other: 'other',
  Gender.preferNotToSay: 'prefer_not_to_say',
};
