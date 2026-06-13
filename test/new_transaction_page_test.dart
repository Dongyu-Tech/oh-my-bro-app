import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:heymybro/shared/pages/new_transaction_page.dart';

/// 1×1 transparent PNG so the mascot `Image.asset` decodes in tests without a
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
    if (key.contains('AssetManifest')) {
      return const StandardMessageCodec().encodeMessage(<String, Object>{})!;
    }
    return ByteData.view(_png.buffer);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async => '';
}

void main() {
  testWidgets('record tab shows the frameless 誰欠誰 owe-selector above the '
      'free-text input', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _FakeAssetBundle(),
        child: MaterialApp(home: NewTransactionPage(onRecorded: () {})),
      ),
    );
    await tester.pumpAndSettle();

    // Two yellow dropdown stubs ([你 ▾] / [對方 ▾]) prove the owe strip rendered.
    expect(find.byIcon(LucideIcons.chevronDown), findsNWidgets(2));
    // The free-text entry (mic affordance) still sits below it.
    expect(find.byIcon(LucideIcons.mic), findsOneWidget);
  });
}
