import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/shared/provider/friend_provider.dart';

/// Search and scan reach the same person by different routes, and a bro is now
/// keyed by their account rather than by the name you typed — so adding one
/// twice has to be a refresh, not a duplicate.
void main() {
  late AppDatabase db;
  late FriendService service;

  setUp(() {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    service = FriendService(db);
  });

  tearDown(() => db.close());

  const uid = '3f2504e0-4f89-41d3-9a0c-0305e82c3301';

  test('saves the account id handle and avatar alongside the name', () async {
    await service.addBro(
      userId: uid,
      name: 'Alex',
      handle: 'alex_1',
      avatarUrl: 'https://cdn/a.png',
    );

    final row = (await db.select(db.friends).get()).single;
    expect(row.userId, uid);
    expect(row.handle, 'alex_1');
    expect(row.avatarUrl, 'https://cdn/a.png');
    expect(row.name, 'Alex');
  });

  test('adding the same bro again refreshes instead of duplicating', () async {
    final first = await service.addBro(
      userId: uid,
      name: 'Alex',
      handle: 'alex_1',
      avatarUrl: null,
    );
    final second = await service.addBro(
      userId: uid,
      name: 'Alex Chen',
      handle: 'alex_renamed',
      avatarUrl: 'https://cdn/new.png',
    );

    expect(second, first, reason: 'same local row');

    final rows = await db.select(db.friends).get();
    expect(rows, hasLength(1));
    expect(rows.single.handle, 'alex_renamed');
    expect(rows.single.avatarUrl, 'https://cdn/new.png');
    // The name mirrors their profile, so changing it server-side has to land
    // here — a cached name that never moves again is the bug this replaces.
    expect(rows.single.name, 'Alex Chen');
  });

  test('different accounts stay separate rows', () async {
    await service.addBro(userId: uid, name: 'Alex', handle: 'alex_1');
    await service.addBro(
      userId: '11111111-2222-3333-4444-555555555555',
      name: 'Bo',
      handle: 'bo',
    );

    expect(await db.select(db.friends).get(), hasLength(2));
  });

  group('syncAccepted — what pull-to-refresh runs', () {
    const other = '11111111-2222-3333-4444-555555555555';

    ({String userId, String name, String? handle, String? avatarUrl}) bro(
      String id,
      String name,
    ) => (userId: id, name: name, handle: null, avatarUrl: null);

    Future<List<Friend>> live() => db.watchFriends().first;

    test('adds the ones the server knows about', () async {
      await service.syncAccepted([bro(uid, 'Alex'), bro(other, 'Bo')]);
      expect(await live(), hasLength(2));
    });

    test('picks up a bro who renamed themselves server-side', () async {
      await service.syncAccepted([bro(uid, 'Alex')]);

      // They edited their display name in their own profile.
      await service.syncAccepted([bro(uid, 'Alex Chen')]);

      final rows = await live();
      expect(rows, hasLength(1), reason: 'still the same bro');
      expect(rows.single.name, 'Alex Chen');
    });

    test('trashes a bro who is no longer in the list', () async {
      await service.syncAccepted([bro(uid, 'Alex'), bro(other, 'Bo')]);

      // Bo removed us on their device.
      await service.syncAccepted([bro(uid, 'Alex')]);

      final rows = await live();
      expect(rows, hasLength(1));
      expect(rows.single.userId, uid);
    });

    test('an empty accepted list clears every account-backed bro', () async {
      await service.syncAccepted([bro(uid, 'Alex')]);
      await service.syncAccepted(const []);
      expect(await live(), isEmpty);
    });

    test('never touches friends that predate accounts', () async {
      // A row from before v8: a typed name with no userId. The server list
      // cannot know about it, so a prune must not sweep it up.
      await db.insertFriend(
        FriendsCompanion.insert(
          id: 'legacy-1',
          name: '舊朋友',
          createdAt: DateTime(2026, 1, 1),
        ),
      );

      await service.syncAccepted(const []);

      final rows = await live();
      expect(rows, hasLength(1));
      expect(rows.single.name, '舊朋友');
      expect(rows.single.userId, isNull);
    });

    test('re-adding after a prune brings them back', () async {
      await service.syncAccepted([bro(uid, 'Alex')]);
      await service.syncAccepted(const []);
      await service.syncAccepted([bro(uid, 'Alex')]);

      expect(await live(), hasLength(1));
    });
  });

  test(
    'a locally trashed bro the server still lists is restored not cloned',
    () async {
      // This is the shape of the old bug: deleting a bro only trashed the local
      // row, the server still said "accepted", and the next refresh added them
      // back as a SECOND row. Unfriending now goes through the server, but if a
      // stale trashed row ever meets a server list that still contains them, the
      // server wins and the existing row is revived.
      final id = await service.addBro(userId: uid, name: 'Alex', handle: 'a');
      await service.deleteFriend(id);
      expect(await db.watchFriends().first, isEmpty);

      final again = await service.addBro(
        userId: uid,
        name: 'Alex',
        handle: 'a',
      );

      expect(again, id, reason: 'same row, not a clone');
      expect(await db.watchFriends().first, hasLength(1));
      expect(await db.select(db.friends).get(), hasLength(1));
    },
  );
}
