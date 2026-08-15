// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friendship_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FriendshipModel _$FriendshipModelFromJson(Map<String, dynamic> json) =>
    _FriendshipModel(
      otherId: json['other_id'] as String,
      handle: json['handle'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      status: $enumDecode(
        _$FriendshipStatusEnumMap,
        json['status'],
        unknownValue: FriendshipStatus.pending,
      ),
      requestedBy: json['requested_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$FriendshipModelToJson(_FriendshipModel instance) =>
    <String, dynamic>{
      'other_id': instance.otherId,
      'handle': instance.handle,
      'display_name': instance.displayName,
      'avatar_url': instance.avatarUrl,
      'status': _$FriendshipStatusEnumMap[instance.status]!,
      'requested_by': instance.requestedBy,
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$FriendshipStatusEnumMap = {
  FriendshipStatus.pending: 'pending',
  FriendshipStatus.accepted: 'accepted',
};

_FriendToken _$FriendTokenFromJson(Map<String, dynamic> json) => _FriendToken(
  token: json['token'] as String,
  expiresAt: DateTime.parse(json['expires_at'] as String),
);

Map<String, dynamic> _$FriendTokenToJson(_FriendToken instance) =>
    <String, dynamic>{
      'token': instance.token,
      'expires_at': instance.expiresAt.toIso8601String(),
    };
