import 'dart:async';

import '../../shared/models/auth_user_model.dart';
import '../error/result.dart';

/// Provider-agnostic auth surface. Wire a real implementation
/// (Google Sign-In, OAuth, Supabase, Firebase, anonymous, etc) by extending
/// [AuthService] and overriding [authServiceProvider] in main.dart.
abstract class AuthService {
  /// Emits the current user (null when signed out). Listenable by providers.
  Stream<AuthUserModel?> get userChanges;

  /// Synchronously read the current user.
  AuthUserModel? get currentUser;

  Future<Result<AuthUserModel>> signIn();
  Future<Result<void>> signOut();
}

/// Default no-op implementation. Always signed out, [signIn] returns an
/// UnimplementedError. Replace via ProviderScope override when wiring a real
/// provider. Lets the app boot and compile without committing to a backend.
class NoopAuthService implements AuthService {
  final _controller = StreamController<AuthUserModel?>.broadcast();

  @override
  AuthUserModel? get currentUser => null;

  @override
  Stream<AuthUserModel?> get userChanges => _controller.stream;

  @override
  Future<Result<AuthUserModel>> signIn() async => Result.error(
        AuthNotWiredException('AuthService.signIn not wired yet'),
      );

  @override
  Future<Result<void>> signOut() async {
    _controller.add(null);
    return const Result.ok(null);
  }
}

class AuthNotWiredException implements Exception {
  AuthNotWiredException(this.message);
  final String message;

  @override
  String toString() => 'AuthNotWiredException: $message';
}

/// Sign-in was aborted by the user (dismissed the Google sheet). Benign — call
/// sites should treat this as a no-op and NOT surface an error message.
class AuthCancelledException implements Exception {
  const AuthCancelledException();

  @override
  String toString() => 'AuthCancelledException';
}

/// Any other sign-in / sign-out failure, carrying a human-readable [message].
class AuthFailedException implements Exception {
  const AuthFailedException(this.message);
  final String message;

  @override
  String toString() => 'AuthFailedException: $message';
}
