import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heymybro/core/error/result.dart';
import 'package:heymybro/core/services/auth_service.dart';
import 'package:heymybro/shared/models/app_user_model.dart';
import 'package:heymybro/shared/models/auth_user_model.dart';
import 'package:heymybro/shared/provider/auth_provider.dart';
import 'package:heymybro/shared/provider/user_provider.dart';
import 'package:heymybro/shared/repositories/user_repository.dart';

/// Always-signed-in stand-in so myProfileProvider gets past its auth check.
///
/// [userChanges] is a quiet broadcast stream, the same shape NoopAuthService
/// uses. A `Stream.value(...)` here would hand out a fresh stream on every
/// read and emit mid-test, rebuilding myProfileProvider while its fetch was
/// still in flight — the provider would be torn down before it could resolve.
class _SignedInAuth implements AuthService {
  final _controller = StreamController<AuthUserModel?>.broadcast();

  @override
  AuthUserModel? get currentUser => const AuthUserModel(id: 'u1');

  @override
  Stream<AuthUserModel?> get userChanges => _controller.stream;

  @override
  Future<Result<AuthUserModel>> signIn() async =>
      const Result.ok(AuthUserModel(id: 'u1'));

  @override
  Future<Result<void>> signOut() async => const Result.ok(null);
}

class _FakeRepo implements UserRepository {
  _FakeRepo(this._me);
  final Result<AppUserModel> _me;

  @override
  Future<Result<AppUserModel>> fetchMe() async => _me;

  @override
  Future<Result<AppUserModel?>> findByHandle(String handle) async =>
      const Result.ok(null);

  @override
  Future<Result<AppUserModel>> saveMe(AppUserModel user) async =>
      Result.ok(user);
}

/// The handle gate pins a signed-in user to /handle. Anything that makes it
/// fire when it shouldn't traps them on a screen with no way out, so the
/// "don't fire" cases matter more than the "do fire" one.
void main() {
  ProviderContainer containerWith(Result<AppUserModel> me) {
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(_SignedInAuth()),
        userRepositoryProvider.overrideWithValue(_FakeRepo(me)),
      ],
    );
    addTearDown(container.dispose);

    // Keeps the provider alive across awaits. onError swallows the deliberate
    // failure in the error test — without it the thrown exception also escapes
    // to the zone and fails the test on its way past.
    final sub = container.listen(
      myProfileProvider,
      (_, __) {},
      onError: (_, __) {},
    );
    addTearDown(sub.close);

    return container;
  }

  /// Waits for [myProfileProvider] to leave the loading state and returns the
  /// settled AsyncValue.
  ///
  /// Deliberately not `container.read(provider.future)`: in this Riverpod
  /// version a FutureProvider whose body throws never delivers that error
  /// through `.future` — it completes with Riverpod's own "disposed during
  /// loading state" StateError instead. The AsyncValue carries the real one.
  /// Polls rather than listening: on failure Riverpod routes to the
  /// subscription's `onError` instead of its value listener, so a
  /// completer-on-listener never fires and the test just hangs. The container
  /// already holds a live subscription, so reading here is safe.
  Future<AsyncValue<AppUserModel?>> settled(ProviderContainer container) async {
    for (var i = 0; i < 100; i++) {
      final value = container.read(myProfileProvider);
      if (!value.isLoading) return value;
      await Future<void>.delayed(Duration.zero);
    }
    fail('myProfileProvider never left the loading state');
  }

  test('fires when the profile exists but has no handle', () async {
    final container = containerWith(
      const Result.ok(AppUserModel(id: 'u1', handle: null)),
    );
    await container.read(myProfileProvider.future);

    expect(container.read(needsHandleProvider), isTrue);
  });

  test('fires on a handle that is only whitespace', () async {
    final container = containerWith(
      const Result.ok(AppUserModel(id: 'u1', handle: '   ')),
    );
    await container.read(myProfileProvider.future);

    expect(container.read(needsHandleProvider), isTrue);
  });

  test('does not fire once a handle is set', () async {
    final container = containerWith(
      const Result.ok(AppUserModel(id: 'u1', handle: 'alex_1')),
    );
    await container.read(myProfileProvider.future);

    expect(container.read(needsHandleProvider), isFalse);
  });

  test('does not fire while the profile is still loading', () {
    final container = containerWith(
      const Result.ok(AppUserModel(id: 'u1', handle: null)),
    );
    // Deliberately not awaited: a gate that fired on "don't know yet" would
    // bounce every cold start to /handle before the fetch returns.
    expect(container.read(needsHandleProvider), isFalse);
  });

  test('does not fire on a build with no backend', () async {
    // A config-less dev build must stay usable, not get stuck at /handle.
    final container = containerWith(
      const Result.error(BackendNotWiredException()),
    );

    expect(await container.read(myProfileProvider.future), isNull);
    expect(container.read(needsHandleProvider), isFalse);
  });

  test(
    'a real fetch failure surfaces as an error rather than a gate',
    () async {
      final container = containerWith(
        const Result.error(UserRowMissingException()),
      );

      final value = await settled(container);

      expect(value.hasError, isTrue);
      expect(value.error, isA<UserRowMissingException>());
      // Still no gate: an error is not "needs a handle".
      expect(container.read(needsHandleProvider), isFalse);
    },
  );
}
