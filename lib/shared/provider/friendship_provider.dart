import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart' show Friend;
import '../../core/error/result.dart';
import '../models/friendship_model.dart';
import '../repositories/friendship_repository.dart';
import '../repositories/user_repository.dart' show BackendNotWiredException;
import 'auth_provider.dart';
import 'friend_provider.dart';

/// Defaults to the unavailable seam; `main.dart` swaps in the Supabase-backed
/// one once Supabase has been initialized.
final friendshipRepositoryProvider = Provider<FriendshipRepository>(
  (ref) => const UnavailableFriendshipRepository(),
);

/// Every friendship touching me — accepted bros and requests both ways —
/// pulled in one call. Refreshed by `ref.invalidate` after anything that
/// changes it, which is also how the 夥伴 tab picks up an answer.
///
/// Accepted rows are mirrored into Drift on the way through, so credit scores,
/// group member pickers and the offline list keep working off the local table
/// exactly as they did before.
final friendshipsProvider = FutureProvider<List<FriendshipModel>>((ref) async {
  final signedIn =
      ref.watch(currentUserProvider).asData?.value ??
      ref.watch(authServiceProvider).currentUser;
  if (signedIn == null) return const [];

  return switch (await ref.watch(friendshipRepositoryProvider).list()) {
    Ok(value: final rows) => await _mirror(ref, rows),
    // A config-less build simply has no server friendships; the local list
    // still renders.
    Error(error: BackendNotWiredException()) => const <FriendshipModel>[],
    Error(error: final e) => throw e,
  };
}, retry: _friendshipRetry);

/// See the note on myProfileProvider's retry: Riverpod 3 otherwise retries a
/// throwing provider ten times with exponential backoff, parking the tab on a
/// spinner for half a minute.
Duration? _friendshipRetry(int retryCount, Object error) {
  if (retryCount >= 2) return null;
  return Duration(milliseconds: 300 * (retryCount + 1));
}

Future<List<FriendshipModel>> _mirror(
  Ref ref,
  List<FriendshipModel> rows,
) async {
  // Only reached on a successful fetch. syncAccepted prunes anything missing
  // from this list, so handing it a partial (or failed) result would trash
  // bros who are perfectly fine.
  await ref.read(friendServiceProvider).syncAccepted([
    for (final row in rows.where((r) => r.isAccepted))
      (
        userId: row.otherId,
        name: row.bestName,
        handle: row.handle,
        avatarUrl: row.avatarUrl,
      ),
  ]);
  return rows;
}

/// The short-lived code behind 帳號 → 分享 ID.
///
/// Minting replaces this user's previous code server-side, so only the one
/// currently on screen works. `ref.invalidate` mints a fresh one — which is
/// what the sheet does when the old one runs out.
final myShareTokenProvider = FutureProvider<FriendToken?>((ref) async {
  final signedIn =
      ref.watch(currentUserProvider).asData?.value ??
      ref.watch(authServiceProvider).currentUser;
  if (signedIn == null) return null;

  return switch (await ref
      .watch(friendshipRepositoryProvider)
      .generateToken()) {
    Ok(value: final token) => token,
    Error(error: BackendNotWiredException()) => null,
    Error(error: final e) => throw e,
  };
}, retry: _friendshipRetry);

/// Unfriend end-to-end.
///
/// The server call is what makes it mutual: the pair is a single row, so
/// removing it drops the friendship for both people at once. Only after that
/// succeeds is the local row cleared — clearing first would look like it
/// worked and then have the next pull-to-refresh bring them straight back,
/// which is exactly the bug this replaces.
///
/// Rows with no account behind them (added before bros had to be real users)
/// never existed on the server, so they are simply removed locally.
Future<Result<void>> removeBro(WidgetRef ref, Friend friend) async {
  final userId = friend.userId;

  if (userId != null) {
    switch (await ref.read(friendshipRepositoryProvider).remove(userId)) {
      case Ok():
        ref.invalidate(friendshipsProvider);
      case Error(error: final e):
        return Result.error(e);
    }
  }

  await ref.read(friendServiceProvider).deleteFriend(friend.id);
  return const Result.ok(null);
}

/// My own account id, for deciding which side of a pending row I am on.
final _myUserIdProvider = Provider<String?>((ref) {
  return (ref.watch(currentUserProvider).asData?.value ??
          ref.watch(authServiceProvider).currentUser)
      ?.id;
});

/// Requests waiting on MY answer — the only ones that get accept/reject.
final incomingRequestsProvider = Provider<List<FriendshipModel>>((ref) {
  final me = ref.watch(_myUserIdProvider);
  final all = ref.watch(friendshipsProvider).asData?.value ?? const [];
  return all.where((f) => f.incomingFor(me)).toList();
});

/// Requests I sent that nobody has answered yet — shown as 已送出邀請.
final outgoingRequestsProvider = Provider<List<FriendshipModel>>((ref) {
  final me = ref.watch(_myUserIdProvider);
  final all = ref.watch(friendshipsProvider).asData?.value ?? const [];
  return all.where((f) => f.outgoingFor(me)).toList();
});

/// Account ids I already have any relationship with, so the search result can
/// say "waiting" or "already bros" instead of offering a pointless button.
final relatedUserIdsProvider = Provider<Map<String, FriendshipModel>>((ref) {
  final all = ref.watch(friendshipsProvider).asData?.value ?? const [];
  return {for (final f in all) f.otherId: f};
});
