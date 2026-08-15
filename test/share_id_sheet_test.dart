import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';

import 'package:heymybro/shared/models/bro_code.dart';
import 'package:heymybro/shared/pages/share_id_sheet.dart';
import 'package:heymybro/shared/widgets/brutal_qr.dart';

/// Stand-in for the native brightness channel, which does not exist under
/// `flutter test`. Extending the platform interface (rather than mocking the
/// method channel) exercises the same call path the app uses on device.
class _FakeScreenBrightness extends ScreenBrightnessPlatform {
  final List<double> applied = <double>[];
  int resets = 0;
  bool unsupported = false;

  @override
  Future<void> setApplicationScreenBrightness(double brightness) async {
    if (unsupported) {
      throw PlatformException(code: '-1', message: 'no brightness here');
    }
    applied.add(brightness);
  }

  @override
  Future<void> resetApplicationScreenBrightness() async {
    if (unsupported) {
      throw PlatformException(code: '-1', message: 'no brightness here');
    }
    resets++;
  }
}

void main() {
  // The code carries a BroCode now, not the signed-in email — a scanner needs
  // the account id to resolve a real user, and an email held up across a table
  // is handed to every phone in the room.
  const code = BroCode(token: 'TPBAE2MUVG');
  final payload = code.encode();
  const label = '@alex_1';

  late _FakeScreenBrightness brightness;

  setUp(() {
    brightness = _FakeScreenBrightness();
    ScreenBrightnessPlatform.instance = brightness;
  });

  Future<void> openSheet(WidgetTester tester) async {
    // Size the *view*, not just the layout surface: the sheet reads its height
    // off MediaQuery, and `setSurfaceSize` leaves that at the 800×600 default.
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  showShareIdSheet(context, payload: payload, label: label),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Tear the tree down inside this test, so the sheet's dispose (and the
    // brightness reset it fires) lands on THIS test's fake rather than on the
    // next test's, which `setUp` has already swapped in by then.
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  testWidgets('shows a QR carrying the bro code and the handle beneath it', (
    tester,
  ) async {
    await openSheet(tester);

    expect(
      find.byWidgetPredicate((w) => w is BrutalQrCode && w.data == payload),
      findsOneWidget,
    );
    // The label is what a human reads; the payload is not human-readable.
    expect(find.text(label), findsOneWidget);
  });

  testWidgets('the encoded payload round-trips back to the same account', (
    tester,
  ) async {
    await openSheet(tester);

    final qr = tester.widget<BrutalQrCode>(find.byType(BrutalQrCode));
    expect(BroCode.parse(qr.data)?.token, code.token);
  });

  testWidgets('the sheet QR is bigger than the card it was opened from', (
    tester,
  ) async {
    await openSheet(tester);

    // The card on 帳號 renders at 132; scanning across a table needs more.
    final qr = tester.widget<BrutalQrCode>(find.byType(BrutalQrCode));
    expect(qr.size, greaterThanOrEqualTo(200));
  });

  testWidgets('stands a fixed half-screen tall, whatever it contains', (
    tester,
  ) async {
    await openSheet(tester);

    // Content-sized would leave the code far smaller than it needs to be;
    // full-screen buried the barrier. Half, pinned, is the deal.
    expect(tester.getSize(find.byType(ShareIdSheet)), const Size(420, 450));
  });

  testWidgets('turns the screen up to full while the QR is showing', (
    tester,
  ) async {
    await openSheet(tester);

    expect(brightness.applied, <double>[1.0]);
    expect(brightness.resets, 0);
  });

  testWidgets('gives the screen back when the barrier dismisses it', (
    tester,
  ) async {
    await openSheet(tester);
    expect(brightness.resets, 0);

    // Half a screen leaves the top half tappable — the same way out every
    // other sheet in the app has.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.byType(ShareIdSheet), findsNothing);
    expect(brightness.resets, 1);
  });

  testWidgets('still opens where brightness cannot be changed', (tester) async {
    brightness.unsupported = true;

    await openSheet(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(BrutalQrCode), findsOneWidget);
  });
}
