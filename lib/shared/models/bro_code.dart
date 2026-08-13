/// The payload the app's QR codes carry — written by 帳號 → 分享 ID and read by
/// 夥伴 → 掃描, so the two can never drift apart.
///
///     ohmybro://friend?t=<TOKEN>
///
/// It carries a **short-lived server-minted token**, not a user id. A raw id
/// would be a permanent, un-revocable pass: QR codes get screenshotted and
/// forwarded, and scanning is what skips the accept step — so anyone who ever
/// saw your code could add themselves, forever, without your say-so. A token
/// that expires in minutes bounds that to the moment you actually held the
/// phone up.
class BroCode {
  const BroCode({required this.token});

  final String token;

  static const scheme = 'ohmybro';
  static const host = 'friend';

  /// Deliberately looser than the generator's alphabet (which omits I, L, O,
  /// 0 and 1). Rejecting a code the server would happily redeem is a worse
  /// failure than passing one through for the server to refuse.
  static final _token = RegExp(r'^[A-Z0-9]{6,32}$');

  String encode() =>
      Uri(scheme: scheme, host: host, queryParameters: {'t': token}).toString();

  /// Parses a scanned payload, or null if it is not one of ours.
  static BroCode? parse(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return null;

    final uri = Uri.tryParse(text);
    if (uri == null) return null;
    if (uri.scheme != scheme || uri.host != host) return null;

    final token = (uri.queryParameters['t'] ?? '').trim().toUpperCase();
    if (!_token.hasMatch(token)) return null;

    return BroCode(token: token);
  }

  @override
  String toString() => 'BroCode($token)';

  @override
  bool operator ==(Object other) => other is BroCode && other.token == token;

  @override
  int get hashCode => token.hashCode;
}
