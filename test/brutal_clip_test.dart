import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heymybro/shared/widgets/brutalism.dart';

/// `Container(decoration: brutalDecoration(…), clipBehavior: Clip.antiAlias)`
/// reads as "clip my child to this card", but it clips to the OUTER rounded
/// rect. The child is inset by the border while its own corners stay square,
/// so anything painting edge to edge lays those corners over the border and
/// eats it — the card's top comes out looking torn.
void main() {
  group('brutalInnerRadius', () {
    test('a border eats its own width off the radius', () {
      expect(brutalInnerRadius(20, 4), 16);
      expect(brutalInnerRadius(8, 2), 6);
    });

    test('defaults to the standard border width', () {
      expect(brutalInnerRadius(20), 20 - BrutalSpec.borderWidth);
    });

    test('never goes negative', () {
      // A radius thinner than its border is a square inside corner, not an
      // inverted curve.
      expect(brutalInnerRadius(2, 8), 0);
    });
  });

  testWidgets('an avatar photo is clipped inside its border, not over it', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: BrutalAvatar(
              name: 'A',
              size: 60,
              radius: 20,
              borderWidth: 4,
              photoUrl: 'https://example.com/a.png',
            ),
          ),
        ),
      ),
    );

    final clip = tester.widget<ClipRRect>(
      find
          .descendant(
            of: find.byType(BrutalAvatar),
            matching: find.byType(ClipRRect),
          )
          .first,
    );

    expect(
      (clip.borderRadius as BorderRadius).topLeft.x,
      16,
      reason: 'clipping at the outer 20 would let the photo cover the border',
    );
  });
}
