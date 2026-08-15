import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/core/error/result.dart';
import 'package:heymybro/core/services/auth_service.dart';
import 'package:heymybro/shared/models/app_user_model.dart';
import 'package:heymybro/shared/models/auth_user_model.dart';
import 'package:heymybro/shared/models/bro_code.dart';
import 'package:heymybro/shared/models/friendship_model.dart';
import 'package:heymybro/shared/pages/account_page.dart';
import 'package:heymybro/shared/provider/auth_provider.dart';
import 'package:heymybro/shared/provider/friendship_provider.dart';
import 'package:heymybro/shared/provider/group_provider.dart';
import 'package:heymybro/shared/provider/settings_provider.dart';
import 'package:heymybro/shared/provider/user_provider.dart';
import 'package:heymybro/shared/widgets/brutal_qr.dart';

/// 帳號 → 掃描分享 ID was a `LucideIcons.qrCode` glyph wired to `comingSoon`.
/// These pin down that it now carries a [BroCode] — the account id a scanner
/// can resolve, no longer the signed-in email — and opens the scan-me sheet.
class _FakeAuthService implements AuthService {
  _FakeAuthService(this.user);

  final AuthUserModel? user;

  @override
  AuthUserModel? get currentUser => user;

  @override
  Stream<AuthUserModel?> get userChanges => Stream.value(user);

  @override
  Future<Result<AuthUserModel>> signIn() async => throw UnimplementedError();

  @override
  Future<Result<void>> signOut() async => const Result.ok(null);
}

void main() {
  const email = 'bro@example.com';
  const uid = '3f2504e0-4f89-41d3-9a0c-0305e82c3301';
  const profile = AppUserModel(id: uid, handle: 'alex_1', displayName: 'Alex');
  // The card encodes a short-lived share token, not the account id: scanning
  // skips the accept step, so the payload has to be something that expires.
  final shareToken = FriendToken(
    token: 'TPBAE2MUVG',
    expiresAt: DateTime(2026, 8, 13, 12, 30),
  );
  final payload = BroCode(token: shareToken.token).encode();

  Future<void> pumpAccount(WidgetTester tester, {String? userEmail}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    // Wider than a phone on purpose: with no translations loaded, `.tr()`
    // returns the raw keys, which are longer than the strings they stand for
    // and overflow 帳戶統計's rows at real phone widths.
    await tester.binding.setSurfaceSize(const Size(600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authServiceProvider.overrideWithValue(
            _FakeAuthService(
              userEmail == null
                  ? null
                  : AuthUserModel(id: 'u1', email: userEmail),
            ),
          ),
          personalEntriesProvider.overrideWith(
            (ref) => Stream.value(const <PersonalEntry>[]),
          ),
          // The card encodes the public.users row, not the auth user, so the
          // profile has to be present for there to be anything to draw.
          myProfileProvider.overrideWith(
            (ref) async => userEmail == null ? null : profile,
          ),
          myShareTokenProvider.overrideWith(
            (ref) async => userEmail == null ? null : shareToken,
          ),
        ],
        child: const MaterialApp(home: AccountPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the share card carries the account bro code', (tester) async {
    await pumpAccount(tester, userEmail: email);

    expect(
      find.byWidgetPredicate((w) => w is BrutalQrCode && w.data == payload),
      findsOneWidget,
    );
  });

  testWidgets('the code leaks neither the email nor the account id', (
    tester,
  ) async {
    await pumpAccount(tester, userEmail: email);

    final qr = tester.widget<BrutalQrCode>(find.byType(BrutalQrCode));
    expect(qr.data, isNot(contains(email)));
    // The account id would be a pass that never expires.
    expect(qr.data, isNot(contains(uid)));
    expect(BroCode.parse(qr.data)?.token, shareToken.token);
  });

  testWidgets('tapping the card opens the scan-me sheet', (tester) async {
    await pumpAccount(tester, userEmail: email);
    expect(find.byType(BrutalQrCode), findsOneWidget);

    await tester.tap(find.byType(BrutalQrCode));
    await tester.pumpAndSettle();

    // The card's own code stays behind the sheet, so a second, larger one
    // appearing is what proves the sheet opened.
    final codes = tester
        .widgetList<BrutalQrCode>(find.byType(BrutalQrCode))
        .toList();
    expect(codes, hasLength(2));
    expect(codes.map((c) => c.data).toSet(), <String>{payload});
    final sizes = codes.map((c) => c.size).toList()..sort();
    expect(sizes.last, greaterThan(sizes.first));
  });

  testWidgets('signed out, the card has nothing to encode', (tester) async {
    await pumpAccount(tester, userEmail: null);

    expect(find.byType(BrutalQrCode), findsNothing);
  });
}
