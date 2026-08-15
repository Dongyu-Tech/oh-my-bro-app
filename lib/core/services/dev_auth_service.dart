import 'dart:async';

import '../../shared/models/auth_user_model.dart';
import '../error/result.dart';
import 'auth_service.dart';

/// Development-only auth bypass. [signIn] always succeeds with a fake "bro"
/// user, so the app is reachable without any Supabase / Google config — used
/// for local UI work when no real backend credentials are present.
///
/// Wired in only under [kDebugMode] from main.dart's auth resolver; release
/// builds keep [NoopAuthService]. Starts signed-out so the onboarding hero +
/// login sheet still show; tapping "Sign in with Google" drops you into the app.
class DevAuthService implements AuthService {
  final _controller = StreamController<AuthUserModel?>.broadcast();
  AuthUserModel? _user;

  static const _fakeUser = AuthUserModel(
    id: 'dev-bro',
    email: 'bro@example.com',
    displayName: '欸粗哥',
  );

  @override
  AuthUserModel? get currentUser => _user;

  @override
  Stream<AuthUserModel?> get userChanges => _controller.stream;

  @override
  Future<Result<AuthUserModel>> signIn() async {
    _user = _fakeUser;
    _controller.add(_user);
    return const Result.ok(_fakeUser);
  }

  @override
  Future<Result<void>> signOut() async {
    _user = null;
    _controller.add(null);
    return const Result.ok(null);
  }
}
