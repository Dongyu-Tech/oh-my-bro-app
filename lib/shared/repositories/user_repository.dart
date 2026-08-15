import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/result.dart';
import '../models/app_user_model.dart';

/// Read/write access to `public.users`.
///
/// Follows the same seam shape as `AuthService`: the app compiles and boots
/// against [UnavailableUserRepository], and `main.dart` swaps in
/// [SupabaseUserRepository] once Supabase has actually been initialized. That
/// keeps CI, tests and a config-less dev build working without a backend.
abstract class UserRepository {
  /// The signed-in user's own row. RLS guarantees this is theirs.
  Future<Result<AppUserModel>> fetchMe();

  /// Exact handle lookup — the only way to see someone you have no other
  /// relationship with. Ok(null) means "no such handle", which is a normal
  /// answer, not an error.
  Future<Result<AppUserModel?>> findByHandle(String handle);

  /// Writes the editable subset of [user] — handle, display name, gender,
  /// birthday, bio — onto the signed-in user's row. Avatar columns are not
  /// touched here.
  Future<Result<AppUserModel>> saveMe(AppUserModel user);
}

/// The handle someone typed is already in use. Its own type because the UI has
/// to say something specific about it rather than dumping a Postgres error.
class HandleTakenException implements Exception {
  const HandleTakenException(this.handle);
  final String handle;

  @override
  String toString() => 'HandleTakenException: $handle';
}

/// The handle failed the server's format check (`^[a-zA-Z0-9_]{3,20}$`).
class HandleInvalidException implements Exception {
  const HandleInvalidException(this.handle);
  final String handle;

  @override
  String toString() => 'HandleInvalidException: $handle';
}

/// No backend configured in this build.
class BackendNotWiredException implements Exception {
  const BackendNotWiredException();

  @override
  String toString() => 'BackendNotWiredException';
}

/// Default: every call fails cleanly. Lets the app boot with no Supabase
/// config instead of throwing on the first profile read.
class UnavailableUserRepository implements UserRepository {
  const UnavailableUserRepository();

  @override
  Future<Result<AppUserModel>> fetchMe() async =>
      const Result.error(BackendNotWiredException());

  @override
  Future<Result<AppUserModel?>> findByHandle(String handle) async =>
      const Result.error(BackendNotWiredException());

  @override
  Future<Result<AppUserModel>> saveMe(AppUserModel user) async =>
      const Result.error(BackendNotWiredException());
}

class SupabaseUserRepository implements UserRepository {
  SupabaseUserRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _table = 'users';

  /// Postgres SQLSTATEs we can turn into something a human can act on.
  static const _uniqueViolation = '23505';
  static const _checkViolation = '23514';

  String? get _uid => _client.auth.currentUser?.id;

  @override
  Future<Result<AppUserModel>> fetchMe() async {
    final uid = _uid;
    if (uid == null) return const Result.error(BackendNotWiredException());
    try {
      final row = await _client
          .from(_table)
          .select()
          .eq('id', uid)
          .maybeSingle();
      if (row == null) {
        // The sign-up trigger should have made this row. If it is missing the
        // trigger failed or was never installed — say so plainly rather than
        // silently inventing an empty profile.
        return const Result.error(UserRowMissingException());
      }
      return Result.ok(AppUserModel.fromJson(row));
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  @override
  Future<Result<AppUserModel?>> findByHandle(String handle) async {
    final q = handle.trim();
    if (q.isEmpty) return const Result.ok(null);
    try {
      // A SECURITY DEFINER RPC rather than a table select: `users` RLS only
      // exposes yourself, your friends and people you share a gathering with,
      // and a policy wide enough to search would be wide enough to scrape.
      final rows = await _client.rpc<List<dynamic>>(
        'find_user_by_handle',
        params: {'q': q},
      );
      if (rows.isEmpty) return const Result.ok(null);
      return Result.ok(
        AppUserModel.fromJson(rows.first as Map<String, dynamic>),
      );
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  @override
  Future<Result<AppUserModel>> saveMe(AppUserModel user) async {
    final uid = _uid;
    if (uid == null) return const Result.error(BackendNotWiredException());
    try {
      final row = await _client
          .from(_table)
          .update({
            'handle': user.handle?.trim(),
            'display_name': user.displayName?.trim(),
            'gender': user.gender?.wire,
            // `birthday` is a Postgres `date`; sending a full timestamp would
            // be coerced, but the date part is all that is meaningful.
            'birthday': user.birthday?.toIso8601String().split('T').first,
            'bio': user.bio?.trim(),
          })
          .eq('id', uid)
          .select()
          .single();
      return Result.ok(AppUserModel.fromJson(row));
    } on PostgrestException catch (e) {
      return Result.error(switch (e.code) {
        _uniqueViolation => HandleTakenException(user.handle ?? ''),
        _checkViolation => HandleInvalidException(user.handle ?? ''),
        _ => e,
      });
    } on Exception catch (e) {
      return Result.error(e);
    }
  }
}

/// Signed in, but `public.users` has no row for this account — the sign-up
/// trigger did not run.
class UserRowMissingException implements Exception {
  const UserRowMissingException();

  @override
  String toString() => 'UserRowMissingException';
}
