import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:heymybro/shared/widgets/brutal_qr.dart';

/// The share-ID card used to be a `LucideIcons.qrCode` glyph — pretty, but not
/// scannable. These pin down that [BrutalQrCode] emits a *real* code, and that
/// the payload actually reaches the modules being painted.
///
/// [QrImageView] keeps its payload in a private field, so "does this code carry
/// the right data" can only be asked of the pixels: same payload → identical
/// image, different payload → different image.
void main() {
  final boundaryKey = UniqueKey();

  Future<Uint8List> renderQr(
    WidgetTester tester, {
    required String data,
    double size = 132,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: BrutalQrCode(data: data, size: size),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary =
        tester.renderObject(find.byKey(boundaryKey)) as RenderRepaintBoundary;
    // toImage() waits on the real engine, which the fake async clock in a
    // widget test never advances — runAsync hands it a live event loop.
    late Uint8List png;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      png = bytes!.buffer.asUint8List();
      image.dispose();
    });
    return png;
  }

  testWidgets('renders a real QR code rather than a placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: BrutalQrCode(data: 'bro@example.com', size: 132)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('the payload drives the modules that get painted', (
    tester,
  ) async {
    final first = await renderQr(tester, data: 'bro@example.com');
    final same = await renderQr(tester, data: 'bro@example.com');
    final other = await renderQr(tester, data: 'someone.else@example.com');

    expect(same, equals(first), reason: 'same payload must encode the same');
    expect(other, isNot(equals(first)), reason: 'payload must reach the code');
  });

  testWidgets('lays out at the requested size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: BrutalQrCode(data: 'bro@example.com', size: 200)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(BrutalQrCode)), const Size(200, 200));
  });

  testWidgets('a long payload stays inside the frame', (tester) async {
    // A 43-char address needs a denser QR version than a short one; the frame
    // must not grow with it.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: BrutalQrCode(
              data: 'a.very.long.address.for.testing@example.com',
              size: 132,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(BrutalQrCode)), const Size(132, 132));
  });
}
