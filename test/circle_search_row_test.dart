import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/shared/pages/circle_page.dart';
import 'package:heymybro/shared/provider/friend_provider.dart';
import 'package:heymybro/shared/widgets/brutalism.dart';

/// The search pill and the 掃描 button used to size themselves independently,
/// so they rendered a few pixels apart. These pin that down — a Row centres its
/// children by default, so "both are in a fixed-height box" is NOT enough on
/// its own to make them equal.
void main() {
  Future<void> pumpCircle(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          friendsProvider.overrideWith((ref) => Stream.value(const <Friend>[])),
        ],
        child: const MaterialApp(home: CirclePage()),
      ),
    );
    await tester.pump();
  }

  Size sizeOfPressableAround(WidgetTester tester, Finder inner) {
    return tester.getSize(
      find.ancestor(of: inner, matching: find.byType(PressableBrutal)).first,
    );
  }

  testWidgets('search pill and scan button render the same height', (
    tester,
  ) async {
    await pumpCircle(tester);

    final pill = tester.getSize(
      find
          .ancestor(
            of: find.byType(TextField),
            matching: find.byType(Container),
          )
          .first,
    );
    final scan = sizeOfPressableAround(
      tester,
      find.byIcon(LucideIcons.scanLine),
    );

    expect(scan.height, pill.height);
  });

  testWidgets('the inline search button is square and fits inside the pill', (
    tester,
  ) async {
    await pumpCircle(tester);

    final search = sizeOfPressableAround(
      tester,
      find.byIcon(LucideIcons.search),
    );
    final pill = tester.getSize(
      find
          .ancestor(
            of: find.byType(TextField),
            matching: find.byType(Container),
          )
          .first,
    );

    expect(search.width, search.height, reason: 'must be a square');
    // Has to clear the pill's border on both sides, and leave room for its own
    // hard shadow underneath.
    expect(
      search.height,
      lessThanOrEqualTo(pill.height - 2 * BrutalSpec.borderWidth),
    );
  });
}
