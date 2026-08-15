import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/result.dart';
import '../models/friendship_model.dart';
import 'user_repository.dart' show BackendNotWiredException;

/// The mutual-friendship surface. Every write is a SECURITY DEFINER RPC — the
/// client has read-only access to `public.friendships`, so it can never mark
/// itself accepted.
abstract class FriendshipRepository {
  /// Accepted bros plus requests in both directions, each already joined to
  /// the other person's profile. This is the "pull once on app entry" call.
  Future<Result<List<FriendshipModel>>> list();

  /// Ask to be someone's bro. See [RequestOutcome].
  Future<Result<RequestOutcome>> request(String userId);

  /// Answer a request someone else sent. Only they-asked rows are answerable.
  Future<Result<bool>> respond(String userId, {required bool accept});

  /// Mint the short-lived code behind the share QR.
  Future<Result<FriendToken>> generateToken();

  /// Redeem a scanned code. Ok(null) means the code was unknown, expired or
  /// our own — all "that code doesn't work", none of them exceptional.
  Future<Result<String?>> redeemToken(String token);

  /// Unfriend. Mutual by construction — the pair is a single row, so there is
  /// no such thing as removing someone from your list only.
  ///
  /// Ok(false) means there was nothing to remove, which is a fine outcome, not
  /// a failure.
  Future<Result<bool>> remove(String userId);
}

/// What `request_friend` decided. Mirrors the strings the RPC returns; an
/// unrecognised one becomes [unknown] rather than throwing, so a newer server
/// cannot break an older build.
enum RequestOutcome {
  /// Recorded; they still have to accept.
  pending,

  /// They had already asked us, so asking back closed the loop immediately.
  accepted,

  /// Already bros.
  already,

  /// That's you.
  self,

  /// No such user.
  notFound,

  unknown;

  static RequestOutcome parse(String? wire) => switch (wire) {
    'pending' => pending,
    'accepted' => accepted,
    'already' => already,
    'self' => self,
    'not_found' => notFound,
    _ => unknown,
  };
}

/// Default: everything fails cleanly, so a build with no Supabase config still
/// boots and the 夥伴 tab degrades to its local list.
class UnavailableFriendshipRepository implements FriendshipRepository {
  const UnavailableFriendshipRepository();

  @override
  Future<Result<List<FriendshipModel>>> list() async =>
      const Result.error(BackendNotWiredException());

  @override
  Future<Result<RequestOutcome>> request(String userId) async =>
      const Result.error(BackendNotWiredException());

  @override
  Future<Result<bool>> respond(String userId, {required bool accept}) async =>
      const Result.error(BackendNotWiredException());

  @override
  Future<Result<FriendToken>> generateToken() async =>
      const Result.error(BackendNotWiredException());

  @override
  Future<Result<String?>> redeemToken(String token) async =>
      const Result.error(BackendNotWiredException());

  @override
  Future<Result<bool>> remove(String userId) async =>
      const Result.error(BackendNotWiredException());
}

class SupabaseFriendshipRepository implements FriendshipRepository {
  SupabaseFriendshipRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<Result<List<FriendshipModel>>> list() async {
    try {
      final rows = await _client.rpc<List<dynamic>>('my_friendships');
      return Result.ok([
        for (final row in rows)
          FriendshipModel.fromJson(row as Map<String, dynamic>),
      ]);
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  @override
  Future<Result<RequestOutcome>> request(String userId) async {
    try {
      final wire = await _client.rpc<String?>(
        'request_friend',
        params: {'target': userId},
      );
      return Result.ok(RequestOutcome.parse(wire));
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  @override
  Future<Result<bool>> respond(String userId, {required bool accept}) async {
    try {
      final wire = await _client.rpc<String?>(
        'respond_friend',
        params: {'other': userId, 'accept': accept},
      );
      // 'already' counts as success: the end state is what was asked for.
      return Result.ok(
        wire == 'accepted' || wire == 'rejected' || wire == 'already',
      );
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  @override
  Future<Result<FriendToken>> generateToken() async {
    try {
      final rows = await _client.rpc<List<dynamic>>('generate_friend_token');
      if (rows.isEmpty) {
        return Result.error(
          Exception('generate_friend_token returned nothing'),
        );
      }
      return Result.ok(
        FriendToken.fromJson(rows.first as Map<String, dynamic>),
      );
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  @override
  Future<Result<String?>> redeemToken(String token) async {
    try {
      final userId = await _client.rpc<String?>(
        'accept_friend_token',
        params: {'t': token},
      );
      return Result.ok(userId);
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  @override
  Future<Result<bool>> remove(String userId) async {
    try {
      final removed = await _client.rpc<bool?>(
        'remove_friend',
        params: {'other': userId},
      );
      return Result.ok(removed ?? false);
    } on Exception catch (e) {
      return Result.error(e);
    }
  }
}
