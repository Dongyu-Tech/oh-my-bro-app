import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/shared/provider/group_provider.dart';

/// A bare [Group] row for provider tests (no database needed).
Group _group(String id, {required bool isDirect, bool isArchived = false}) =>
    Group(
      id: id,
      name: id,
      colorValue: 0,
      isArchived: isArchived,
      isDirect: isDirect,
      createdAt: DateTime(2026, 1, 1),
    );

/// Build a container whose [groupsProvider] emits [groups], with a persistent
/// listener so the overridden stream's value actually lands before we read the
/// derived provider (a transient `read` would cancel the subscription first).
Future<ProviderContainer> _containerWith(List<Group> groups) async {
  final container = ProviderContainer(
    overrides: [groupsProvider.overrideWith((ref) => Stream.value(groups))],
  );
  addTearDown(container.dispose);
  container.listen(groupsProvider, (_, __) {});
  await container.read(groupsProvider.future);
  return container;
}

void main() {
  group('gatheringsProvider', () {
    test('hides direct-debt groups but keeps real gatherings', () async {
      final container = await _containerWith([
        _group('real', isDirect: false),
        _group('direct', isDirect: true),
      ]);

      // The synthetic direct-debt group is filtered out of the "攤" list…
      final gatheringIds = container
          .read(gatheringsProvider)
          .map((g) => g.id)
          .toList();
      expect(gatheringIds, ['real']);

      // …but it stays in groupsProvider, so 帳本/信用分 (which read the raw list)
      // still see the debt.
      final allIds = (container.read(groupsProvider).value ?? const [])
          .map((g) => g.id)
          .toSet();
      expect(allIds, {'real', 'direct'});
    });

    test(
      'keeps archived real gatherings (only isDirect is filtered)',
      () async {
        final container = await _containerWith([
          _group('active', isDirect: false),
          _group('archived', isDirect: false, isArchived: true),
          _group('direct', isDirect: true),
        ]);

        final ids = container.read(gatheringsProvider).map((g) => g.id).toSet();
        expect(ids, {'active', 'archived'});
      },
    );
  });
}
