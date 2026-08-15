// One side's view of a mutual friendship, as `public.my_friendships()` returns
// it: the *other* person's profile plus the state of the relationship.

// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'friendship_model.freezed.dart';
part 'friendship_model.g.dart';

enum FriendshipStatus { pending, accepted }

@freezed
abstract class FriendshipModel with _$FriendshipModel {
  const FriendshipModel._();

  const factory FriendshipModel({
    /// The other person's `public.users` id.
    @JsonKey(name: 'other_id') required String otherId,

    String? handle,
    @JsonKey(name: 'display_name') String? displayName,

    /// Already resolved server-side to uploaded-avatar-then-provider-mirror.
    @JsonKey(name: 'avatar_url') String? avatarUrl,

    @JsonKey(unknownEnumValue: FriendshipStatus.pending)
    required FriendshipStatus status,

    /// Who asked. On a pending row this is the whole question: if it is us we
    /// are waiting, if it is them we owe an answer.
    @JsonKey(name: 'requested_by') required String requestedBy,

    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _FriendshipModel;

  factory FriendshipModel.fromJson(Map<String, dynamic> json) =>
      _$FriendshipModelFromJson(json);

  bool get isAccepted => status == FriendshipStatus.accepted;

  /// A request *they* sent that we have not answered — the only kind that
  /// should ever show accept/reject buttons.
  bool incomingFor(String? myUserId) =>
      status == FriendshipStatus.pending && requestedBy != myUserId;

  /// A request *we* sent, still unanswered.
  bool outgoingFor(String? myUserId) =>
      status == FriendshipStatus.pending && requestedBy == myUserId;

  /// Best available name, same precedence the rest of the app uses.
  String get bestName {
    final display = displayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final h = handle?.trim();
    if (h != null && h.isNotEmpty) return h;
    return '';
  }
}

/// A freshly minted share code and the moment it stops working.
@freezed
abstract class FriendToken with _$FriendToken {
  const factory FriendToken({
    required String token,
    @JsonKey(name: 'expires_at') required DateTime expiresAt,
  }) = _FriendToken;

  factory FriendToken.fromJson(Map<String, dynamic> json) =>
      _$FriendTokenFromJson(json);
}
