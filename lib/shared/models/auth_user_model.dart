// Auth user payload — provider-agnostic. Populated by whichever AuthService
// implementation you wire in (Google Sign-In, OAuth, anonymous, etc).

import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_user_model.freezed.dart';
part 'auth_user_model.g.dart';

@freezed
abstract class AuthUserModel with _$AuthUserModel {
  const factory AuthUserModel({
    required String id,
    String? email,
    String? displayName,
    String? photoUrl,
  }) = _AuthUserModel;

  factory AuthUserModel.fromJson(Map<String, dynamic> json) =>
      _$AuthUserModelFromJson(json);
}
