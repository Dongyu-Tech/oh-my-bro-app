import 'package:flutter_test/flutter_test.dart';

import 'package:heymybro/shared/models/friendship_model.dart';
import 'package:heymybro/shared/repositories/friendship_repository.dart';

/// A friendship is one mutual row seen from two sides, so the client's whole
/// job is working out which side it is on. Get `requested_by` backwards and the
/// person who sent the invite is offered a button to accept their own — which
/// the server rejects as `not_yours`, leaving a button that just fails.
void main() {
  const me = 'me-uuid';
  const them = 'them-uuid';

  FriendshipModel row({
    required FriendshipStatus status,
    required String requestedBy,
  }) => FriendshipModel(
    otherId: them,
    handle: 'alex_1',
    displayName: 'Alex',
    status: status,
    requestedBy: requestedBy,
    createdAt: DateTime(2026, 8, 13),
  );

  group('which side am I on', () {
    test('they asked → incoming, I owe an answer', () {
      final r = row(status: FriendshipStatus.pending, requestedBy: them);
      expect(r.incomingFor(me), isTrue);
      expect(r.outgoingFor(me), isFalse);
    });

    test('I asked → outgoing, I am waiting', () {
      final r = row(status: FriendshipStatus.pending, requestedBy: me);
      expect(r.outgoingFor(me), isTrue);
      expect(r.incomingFor(me), isFalse);
    });

    test('accepted is neither, whoever asked', () {
      for (final by in [me, them]) {
        final r = row(status: FriendshipStatus.accepted, requestedBy: by);
        expect(r.isAccepted, isTrue);
        expect(r.incomingFor(me), isFalse);
        expect(r.outgoingFor(me), isFalse);
      }
    });

    test('a null id never claims a request is mine to answer', () {
      // Signed out mid-flight: better to show nothing than to offer buttons
      // the server will refuse.
      final mine = row(status: FriendshipStatus.pending, requestedBy: me);
      expect(mine.outgoingFor(null), isFalse);
    });
  });

  group('fromJson', () {
    test('decodes the snake_case shape my_friendships() returns', () {
      final r = FriendshipModel.fromJson(const {
        'other_id': them,
        'handle': 'alex_1',
        'display_name': 'Alex',
        'avatar_url': 'https://cdn/a.png',
        'status': 'accepted',
        'requested_by': me,
        'created_at': '2026-08-13T00:00:00Z',
      });

      expect(r.otherId, them);
      expect(r.avatarUrl, 'https://cdn/a.png');
      expect(r.isAccepted, isTrue);
    });

    test('an unknown status decodes as pending rather than throwing', () {
      final r = FriendshipModel.fromJson(const {
        'other_id': them,
        'status': 'blocked_or_whatever_comes_later',
        'requested_by': me,
        'created_at': '2026-08-13T00:00:00Z',
      });
      expect(r.status, FriendshipStatus.pending);
    });

    test('bestName prefers display name then handle', () {
      expect(
        row(status: FriendshipStatus.accepted, requestedBy: me).bestName,
        'Alex',
      );
    });
  });

  group('RequestOutcome.parse — must match the RPC wire strings', () {
    test('maps every value the server returns', () {
      expect(RequestOutcome.parse('pending'), RequestOutcome.pending);
      expect(RequestOutcome.parse('accepted'), RequestOutcome.accepted);
      expect(RequestOutcome.parse('already'), RequestOutcome.already);
      expect(RequestOutcome.parse('self'), RequestOutcome.self);
      expect(RequestOutcome.parse('not_found'), RequestOutcome.notFound);
    });

    test('anything newer degrades instead of throwing', () {
      expect(RequestOutcome.parse('invented_later'), RequestOutcome.unknown);
      expect(RequestOutcome.parse(null), RequestOutcome.unknown);
    });
  });
}
