// The app's own record of a person — mirrors `public.users` on Supabase.
//
// Distinct from [AuthUserModel], which is whatever the auth provider knows
// about the *signed-in* user (id, email, Google name/picture). This one is the
// app-level profile and exists for OTHER people too, not just you.

// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user_model.freezed.dart';
part 'app_user_model.g.dart';

/// Mirrors the `gender` check constraint on `public.users`. Anything the server
/// grows later that this build doesn't know decodes as null rather than
/// throwing — an old client must not choke on a newer row.
@JsonEnum(valueField: 'wire')
enum Gender {
  male('male'),
  female('female'),
  other('other'),
  preferNotToSay('prefer_not_to_say');

  const Gender(this.wire);
  final String wire;
}

@freezed
abstract class AppUserModel with _$AppUserModel {
  const AppUserModel._();

  const factory AppUserModel({
    required String id,

    /// The unique search key. Null until the user picks one — the router
    /// pins them to the handle-setup step while it is.
    String? handle,

    @JsonKey(name: 'display_name') String? displayName,

    /// Avatar the user uploaded themselves. Wins over [providerAvatarUrl].
    @JsonKey(name: 'avatar_url') String? avatarUrl,

    /// Mirror of the Google picture, refreshed server-side on each sign-in.
    @JsonKey(name: 'provider_avatar_url') String? providerAvatarUrl,

    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
    Gender? gender,

    /// A birthday, not an age — an age would be wrong again every year.
    DateTime? birthday,
    String? bio,
  }) = _AppUserModel;

  factory AppUserModel.fromJson(Map<String, dynamic> json) =>
      _$AppUserModelFromJson(json);

  /// The same precedence `public.effective_avatar_url()` applies server-side,
  /// repeated here for rows fetched as plain columns.
  String? get effectiveAvatarUrl => avatarUrl ?? providerAvatarUrl;

  /// What to show as this person's name, best available first.
  String get bestName {
    final display = displayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final h = handle?.trim();
    if (h != null && h.isNotEmpty) return h;
    return '';
  }

  /// Whole years since [birthday], or null if unset. Derived rather than
  /// stored so it can never go stale.
  int? get age {
    final b = birthday;
    if (b == null) return null;
    final now = DateTime.now();
    var years = now.year - b.year;
    if (now.month < b.month || (now.month == b.month && now.day < b.day)) {
      years--;
    }
    return years < 0 ? null : years;
  }
}
