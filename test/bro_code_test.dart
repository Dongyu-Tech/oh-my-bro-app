import 'package:flutter_test/flutter_test.dart';

import 'package:heymybro/shared/models/bro_code.dart';

/// The QR payload is written by 帳號 → 分享 ID and read by 夥伴 → 掃描. Scanning
/// skips the accept step, so whatever this carries is a pass straight into
/// someone's friend list — which is why it is a short-lived token and not an
/// account id, and why the parser is strict about what it will hand on.
void main() {
  const token = 'TPBAE2MUVG';

  group('round trip', () {
    test('survives encode then parse', () {
      expect(BroCode.parse(const BroCode(token: token).encode())?.token, token);
    });

    test('encodes to the documented shape', () {
      expect(const BroCode(token: token).encode(), 'ohmybro://friend?t=$token');
    });

    test('uppercases a lowercased scan', () {
      // Some scanners normalise case; the server compares upper.
      expect(BroCode.parse('ohmybro://friend?t=tpbae2muvg')?.token, token);
    });
  });

  group('parse rejects', () {
    test('null and empty', () {
      expect(BroCode.parse(null), isNull);
      expect(BroCode.parse(''), isNull);
      expect(BroCode.parse('   '), isNull);
    });

    test('a foreign scheme', () {
      expect(BroCode.parse('https://ohmybro.app/join/123456'), isNull);
      expect(BroCode.parse('WIFI:S:home;T:WPA;P:hunter2;;'), isNull);
      expect(BroCode.parse('mailto:bro@example.com'), isNull);
    });

    test('another host on our own scheme', () {
      expect(BroCode.parse('ohmybro://group?t=$token'), isNull);
    });

    test('a bare email — the Phase 1 payload', () {
      expect(BroCode.parse('bro@example.com'), isNull);
    });

    test('a raw account id — the payload we deliberately moved away from', () {
      // A uuid in a QR was a permanent, un-revocable pass. Old codes must not
      // still work.
      expect(
        BroCode.parse(
          'ohmybro://friend?id=3f2504e0-4f89-41d3-9a0c-0305e82c3301',
        ),
        isNull,
      );
    });

    test('a plain name', () {
      expect(BroCode.parse('王小明'), isNull);
      expect(BroCode.parse('Alex'), isNull);
    });

    test('a missing or malformed token', () {
      expect(BroCode.parse('ohmybro://friend'), isNull);
      expect(BroCode.parse('ohmybro://friend?t='), isNull);
      expect(BroCode.parse('ohmybro://friend?t=SHORT'), isNull);
      expect(BroCode.parse('ohmybro://friend?t=has-a-dash'), isNull);
      expect(BroCode.parse('ohmybro://friend?t=${'A' * 33}'), isNull);
    });
  });

  test('value equality, so a repeated scan compares equal', () {
    expect(const BroCode(token: token), const BroCode(token: token));
    expect(
      const BroCode(token: token),
      isNot(const BroCode(token: 'OTHERCODE1')),
    );
  });
}
