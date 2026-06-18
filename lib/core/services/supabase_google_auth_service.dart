import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/models/auth_user_model.dart';
import '../error/result.dart';
import 'auth_service.dart';

/// Real [AuthService] backed by Supabase Auth + native Google Sign-In.
///
/// Sign-in uses the supabase-recommended native flow: `google_sign_in` obtains a
/// Google ID token on-device (a native account picker, no browser), which is
/// exchanged for a Supabase session via [GoTrueClient.signInWithIdToken].
/// Supabase persists and restores the session, so [userChanges] reflects
/// cold-start restores as well as live sign-in/out.
class SupabaseGoogleAuthService implements AuthService {
  SupabaseGoogleAuthService({
    required String webClientId,
    required String iosClientId,
    GoTrueClient? auth,
    GoogleSignIn? googleSignIn,
  }) : _webClientId = webClientId,
       _iosClientId = iosClientId,
       _auth = auth ?? Supabase.instance.client.auth,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  /// Web (server) client ID — the audience Supabase verifies the ID token
  /// against. Must match the client ID registered under Supabase's Google
  /// provider.
  final String _webClientId;

  /// iOS client ID — required for the native iOS sign-in sheet.
  final String _iosClientId;

  final GoTrueClient _auth;
  final GoogleSignIn _googleSignIn;

  /// google_sign_in 7.x requires a one-time [GoogleSignIn.initialize] before
  /// any other call; cache it so we run it at most once.
  Future<void>? _googleInit;

  Future<void> _ensureGoogleInitialized() {
    return _googleInit ??= _googleSignIn.initialize(
      clientId: _iosClientId,
      serverClientId: _webClientId,
    );
  }

  @override
  AuthUserModel? get currentUser => _mapUser(_auth.currentUser);

  @override
  Stream<AuthUserModel?> get userChanges =>
      _auth.onAuthStateChange.map((state) => _mapUser(state.session?.user));

  @override
  Future<Result<AuthUserModel>> signIn() async {
    try {
      await _ensureGoogleInitialized();

      // Throws GoogleSignInException (code == canceled) if the user backs out.
      final account = await _googleSignIn.authenticate();

      final idToken = account.authentication.idToken;
      if (idToken == null) {
        return const Result.error(
          AuthFailedException('Google did not return an ID token'),
        );
      }

      // Access token is optional for Supabase identity sign-in; fetch it
      // best-effort so a provider token is available if already authorized.
      final authorization = await account.authorizationClient
          .authorizationForScopes(const <String>['email']);

      final response = await _auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: authorization?.accessToken,
      );

      final user = _mapUser(response.user);
      if (user == null) {
        return const Result.error(
          AuthFailedException('Supabase returned no user'),
        );
      }
      return Result.ok(user);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return const Result.error(AuthCancelledException());
      }
      return Result.error(
        AuthFailedException('Google sign-in failed (${e.code}): ${e.description}'),
      );
    } on AuthException catch (e) {
      return Result.error(AuthFailedException(e.message));
    } catch (e) {
      return Result.error(AuthFailedException(e.toString()));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      // Clear the Google account selection first, then the Supabase session.
      await _googleSignIn.signOut();
      await _auth.signOut();
      return const Result.ok(null);
    } on AuthException catch (e) {
      return Result.error(AuthFailedException(e.message));
    } catch (e) {
      return Result.error(AuthFailedException(e.toString()));
    }
  }

  /// Maps a Supabase [User] to the provider-agnostic [AuthUserModel].
  ///
  /// `user_metadata` is populated by Google (full_name / avatar_url). It is only
  /// used here for display — never for authorization (it is user-editable).
  AuthUserModel? _mapUser(User? user) {
    if (user == null) return null;
    final meta = user.userMetadata ?? const <String, dynamic>{};
    return AuthUserModel(
      id: user.id,
      email: user.email,
      displayName: (meta['full_name'] ?? meta['name']) as String?,
      photoUrl: (meta['avatar_url'] ?? meta['picture']) as String?,
    );
  }
}
