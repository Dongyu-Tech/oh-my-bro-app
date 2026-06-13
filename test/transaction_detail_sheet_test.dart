import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:heymybro/shared/pages/transaction_detail_sheet.dart';

/// 1×1 transparent PNG so the mascot `Image.asset`s decode in tests without a
/// real asset bundle.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _FakeAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    // An empty (but well-formed) manifest means "no variants", so AssetImage
    // resolves to the exact key and decodes the 1×1 PNG below.
    if (key.contains('AssetManifest')) {
      return const StandardMessageCodec().encodeMessage(<String, Object>{})!;
    }
    return ByteData.view(_png.buffer);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async => '';
}

void main() {
  const detail = TxDetail(
    target: 'Personal',
    item: 'Dinner',
    amount: -200,
    lines: [TxLine(time: '4/1', item: 'Dinner', amount: -200)],
  );

  Widget host() => DefaultAssetBundle(
    bundle: _FakeAssetBundle(),
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showTransactionDetail(context, detail),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  /// Tall surface so the whole side-sheet (including the bottom action buttons,
  /// which live in a ListView) is laid out within the viewport.
  Future<void> openPanel(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('tapping open slides in the detail panel', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(host());
    expect(find.byIcon(LucideIcons.chevronLeft), findsNothing);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Left handle + action-row icons prove the panel rendered.
    expect(find.byIcon(LucideIcons.chevronLeft), findsOneWidget);
    expect(find.byIcon(LucideIcons.checkCircle), findsOneWidget);
    expect(find.byIcon(LucideIcons.trash2), findsOneWidget);
  });

  testWidgets('the "<" handle closes the panel', (tester) async {
    await openPanel(tester);
    expect(find.byIcon(LucideIcons.chevronLeft), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.chevronLeft));
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.chevronLeft), findsNothing);
  });

  testWidgets('tapping the dimmed barrier closes the panel', (tester) async {
    await openPanel(tester);
    expect(find.byIcon(LucideIcons.chevronLeft), findsOneWidget);

    // Tap top-left (the dimmed gutter, left of the ~60%-wide panel).
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.chevronLeft), findsNothing);
  });
}
