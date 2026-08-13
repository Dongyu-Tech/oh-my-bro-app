import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heymybro/shared/widgets/brutalism.dart';

/// The avatar is the one place the app decides "photo or monogram", so the
/// fallback chain (photo → first letter → `?`) is worth pinning down.
void main() {
  Future<void> pump(WidgetTester tester, Widget avatar) async {
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: avatar)),
      ),
    );
  }

  group('fallback chain', () {
    testWidgets('renders the first letter when there is no photo', (
      tester,
    ) async {
      await pump(tester, const BrutalAvatar(name: 'Alex', size: 50));

      expect(find.text('A'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('takes the first grapheme, not the first code unit', (
      tester,
    ) async {
      await pump(tester, const BrutalAvatar(name: '王小明', size: 50));
      expect(find.text('王'), findsOneWidget);
    });

    testWidgets('falls all the way to ? on an empty name', (tester) async {
      await pump(tester, const BrutalAvatar(name: '', size: 50));
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('treats an empty photo url as no photo', (tester) async {
      await pump(
        tester,
        const BrutalAvatar(name: 'Alex', size: 50, photoUrl: '   '),
      );

      expect(find.text('A'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('shows the initial while the photo is still loading', (
      tester,
    ) async {
      await pump(
        tester,
        const BrutalAvatar(
          name: 'Alex',
          size: 50,
          photoUrl: 'https://example.com/a.png',
        ),
      );

      // The network fetch never completes in a test, which is exactly the
      // slow-connection case: the monogram must be holding the space.
      expect(find.text('A'), findsOneWidget);
    });
  });

  group('google avatar sizing', () {
    String urlOf(WidgetTester tester) =>
        (tester.widget<Image>(find.byType(Image)).image as NetworkImage).url;

    testWidgets('rewrites the size directive to the drawn pixel size', (
      tester,
    ) async {
      await pump(
        tester,
        const BrutalAvatar(
          name: 'Alex',
          size: 50,
          photoUrl: 'https://lh3.googleusercontent.com/a/ABC123=s96-c',
        ),
      );

      // 50 logical px at dpr 2 → 100 device px.
      expect(
        urlOf(tester),
        'https://lh3.googleusercontent.com/a/ABC123=s100-c',
      );
    });

    testWidgets('adds a size directive when the url carries none', (
      tester,
    ) async {
      await pump(
        tester,
        const BrutalAvatar(
          name: 'Alex',
          size: 96,
          photoUrl: 'https://lh3.googleusercontent.com/a/ABC123',
        ),
      );

      expect(
        urlOf(tester),
        'https://lh3.googleusercontent.com/a/ABC123=s192-c',
      );
    });

    testWidgets('leaves non-Google urls untouched', (tester) async {
      // Supabase Storage URLs land here once user uploads ship — appending a
      // Google size directive to one would break it.
      const url = 'https://x.supabase.co/storage/v1/object/public/av/a.png';
      await pump(
        tester,
        const BrutalAvatar(name: 'Alex', size: 50, photoUrl: url),
      );

      expect(urlOf(tester), url);
    });
  });
}
