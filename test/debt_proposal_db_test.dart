// `show Value`: drift also exports isNull/isNotNull as query-builder helpers,
// which would shadow the matchers of the same name.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/core/services/backup_service.dart';

/// A server row as the sync layer builds it: no `poppedAt`/`dismissedAt`,
/// because those two belong to this device and the server knows nothing of
/// them.
DebtProposalsCompanion _row(String id, {required DateTime updatedAt}) =>
    DebtProposalsCompanion.insert(
      id: id,
      proposerId: 'me',
      counterpartyId: 'them',
      debtorId: 'them',
      title: '晚餐',
      amount: const Value(500),
      status: 'pending',
      awaitingId: const Value('them'),
      createdAt: DateTime(2026, 8, 15),
      updatedAt: updatedAt,
    );

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forExecutor(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('BackupService covers the current schemaVersion', () {
    expect(
      BackupService.supportedSchemaVersions.contains(db.schemaVersion),
      isTrue,
      reason:
          'bumping schemaVersion without adding it here makes older backups '
          'fail to restore, silently',
    );
  });

  test('upsert keeps the device-local popped flag', () async {
    await db.upsertDebtProposals([
      _row('p1', updatedAt: DateTime(2026, 8, 15)),
    ]);
    await db.markDebtPopped('p1');

    // The other side counters, so the row syncs again. That must not re-arm
    // a popup the user has already seen.
    await db.upsertDebtProposals([
      _row('p1', updatedAt: DateTime(2026, 8, 16)),
    ]);

    final rows = await db.watchDebtProposals().first;
    expect(rows.single.poppedAt, isNotNull);
    expect(rows.single.updatedAt, DateTime(2026, 8, 16));
  });

  test('upsert keeps the device-local dismissed flag', () async {
    await db.upsertDebtProposals([
      _row('p1', updatedAt: DateTime(2026, 8, 15)),
    ]);
    await db.markDebtDismissed('p1');
    await db.upsertDebtProposals([
      _row('p1', updatedAt: DateTime(2026, 8, 16)),
    ]);

    final rows = await db.watchDebtProposals().first;
    expect(rows.single.dismissedAt, isNotNull);
  });

  test('latestDebtProposalUpdatedAt drives the catch-up fetch', () async {
    expect(
      await db.latestDebtProposalUpdatedAt(),
      isNull,
      reason:
          'holding nothing must mean "fetch everything", not "fetch since '
          'the epoch of whatever default we picked"',
    );

    await db.upsertDebtProposals([
      _row('p1', updatedAt: DateTime(2026, 8, 15)),
      _row('p2', updatedAt: DateTime(2026, 8, 17)),
    ]);

    expect(await db.latestDebtProposalUpdatedAt(), DateTime(2026, 8, 17));
  });

  test('watch orders by newest activity first', () async {
    await db.upsertDebtProposals([
      _row('old', updatedAt: DateTime(2026, 8, 10)),
      _row('new', updatedAt: DateTime(2026, 8, 20)),
    ]);

    final rows = await db.watchDebtProposals().first;
    expect(rows.map((r) => r.id), ['new', 'old']);
  });
}
