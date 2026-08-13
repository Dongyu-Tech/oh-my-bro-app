import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/result.dart';
import '../models/app_user_model.dart';
import '../repositories/user_repository.dart';
import 'auth_provider.dart';

/// Defaults to the unavailable seam. `main.dart` overrides it with
/// [SupabaseUserRepository] once Supabase has been initialized — same shape as
/// [authServiceProvider].
final userRepositoryProvider = Provider<UserRepository>(
  (ref) => const UnavailableUserRepository(),
);

/// The signed-in user's `public.users` row, refetched whenever the auth user
/// changes. Null means "nobody signed in" **or** "this build has no backend" —
/// both are states where there is simply no profile to show, not errors.
final myProfileProvider = FutureProvider<AppUserModel?>((ref) async {
  final auth =
      ref.watch(currentUserProvider).asData?.value ??
      ref.watch(authServiceProvider).currentUser;
  if (auth == null) return null;

  return switch (await ref.watch(userRepositoryProvider).fetchMe()) {
    Ok(value: final profile) => profile,
    // A config-less dev build is the normal case here, not a failure worth
    // showing the user an error screen over.
    Error(error: BackendNotWiredException()) => null,
    Error(error: final e) => throw e,
  };
}, retry: _profileRetry);

/// Riverpod 3 retries a throwing provider on its own, and its default is far
/// too patient for this one: 10 attempts with exponential backoff (200ms →
/// 6.4s) parks the UI on a spinner for roughly half a minute and re-hits the
/// backend eleven times before the error is ever shown. It also only skips
/// `Error`/`ProviderException`, and everything thrown here is an `Exception`.
///
/// So: never retry a failure that cannot fix itself, and give a transient one
/// two quick attempts rather than ten slow ones.
Duration? _profileRetry(int retryCount, Object error) {
  if (error is UserRowMissingException) return null;
  if (retryCount >= 2) return null;
  return Duration(milliseconds: 300 * (retryCount + 1));
}

/// True once we know the user has a profile but has not picked a handle yet.
///
/// Deliberately false while the profile is still loading and false when there
/// is no profile at all — a gate that fires on "don't know yet" would bounce
/// people to the handle screen on every cold start.
final needsHandleProvider = Provider<bool>((ref) {
  final profile = ref.watch(myProfileProvider).asData?.value;
  if (profile == null) return false;
  return (profile.handle ?? '').trim().isEmpty;
});
