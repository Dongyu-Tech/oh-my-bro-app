import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/core/error/result.dart';
import 'package:heymybro/shared/models/debt_proposal_model.dart';
import 'package:heymybro/shared/provider/database_provider.dart';
import 'package:heymybro/shared/provider/debt_provider.dart';
import 'package:heymybro/shared/repositories/debt_repository.dart';

/// Hands back whatever rows the test set up, and records how it was called.
class _FakeDebtRepository implements DebtRepository {
  _FakeDebtRepository(this.rows);

  List<DebtProposalModel> rows;
  final sinceArgs = <DateTime?>[];

  @override
  Future<Result<List<DebtProposalModel>>> list({DateTime? since}) async {
    sinceArgs.add(since);
    return Result.ok(rows);
  }

  @override
  Future<Result<DebtOutcome>> propose({
    required String id,
    required String counterpartyId,
    required String debtorId,
    required String title,
    int? amount,
  }) async => const Result.ok(DebtOutcome.ok);

  @override
  Future<Result<DebtOutcome>> respond({
    required String id,
    required DebtReply reply,
    int? amount,
    String? reason,
  }) async => const Result.ok(DebtOutcome.ok);

  @override
  Future<Result<DebtOutcome>> cancel(String id) async =>
      const Result.ok(DebtOutcome.ok);
}

DebtProposalModel _model({
  required String id,
  required String status,
  String? awaitingId,
  int? amount = 500,
  String proposerId = 'me',
  String counterpartyId = 'them',
  String debtorId = 'them',
  DateTime? updatedAt,
}) => DebtProposalModel(
  id: id,
  proposerId: proposerId,
  counterpartyId: counterpartyId,
  debtorId: debtorId,
  title: '晚餐',
  amount: amount,
  status: status,
  awaitingId: awaitingId,
  createdAt: DateTime(2026, 8, 15),
  updatedAt: updatedAt ?? DateTime(2026, 8, 15),
  resolvedAt: status == 'pending' ? null : DateTime(2026, 8, 15),
  otherId: 'them',
  otherDisplayName: '阿華',
);

/// Wait until [predicate] holds.
///
/// Not `await container.read(someProvider.future)`: a StreamProvider's future
/// completes on the FIRST emission, which here is the empty list the Drift
/// query yields before anything is written. Awaiting it again returns that
/// stale value instantly, so the assertion runs before the write has
/// propagated.
Future<void> waitUntil(bool Function() predicate, {String? reason}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('timed out waiting for ${reason ?? 'condition'}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late AppDatabase db;
  late _FakeDebtRepository repo;

  ProviderContainer containerWith(List<DebtProposalModel> rows) {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    repo = _FakeDebtRepository(rows);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        debtRepositoryProvider.overrideWithValue(repo),
        myUserIdProvider.overrideWithValue('me'),
      ],
    );
    // addTearDown is LIFO, so this order disposes the container *before*
    // closing the database under it. The other way round closes the database
    // while Drift stream subscriptions are still open, and the dispose that
    // follows never returns — the test just times out with no stack.
    addTearDown(db.close);
    addTearDown(container.dispose);
    container.listen(debtProposalsProvider, (_, __) {});
    return container;
  }

  test('a confirmed proposal reaches the ledger exactly once', () async {
    final container = containerWith([_model(id: 'p1', status: 'confirmed')]);
    final service = container.read(debtServiceProvider);

    // The realtime push, the catch-up fetch, the next cold start — the same
    // confirmation, three times.
    await service.refresh();
    await service.refresh();
    await service.refresh();

    expect((await db.watchGroups().first).length, 1);
    expect((await db.watchAllExpenses().first).length, 1);
    expect((await db.watchAllShares().first).length, 2);
    expect(
      (await db.watchAllShares().first).fold<int>(0, (s, e) => s + e.amount),
      500,
      reason: 'a replay must not inflate what they owe',
    );
  });

  test('a pending proposal never reaches the ledger', () async {
    final container = containerWith([
      _model(id: 'p1', status: 'pending', awaitingId: 'them'),
    ]);
    await container.read(debtServiceProvider).refresh();

    expect(await db.watchGroups().first, isEmpty);
    expect(await db.watchAllExpenses().first, isEmpty);
  });

  test('splits pending by whose turn it is', () async {
    final container = containerWith([
      _model(id: 'mine', status: 'pending', awaitingId: 'me'),
      _model(id: 'theirs', status: 'pending', awaitingId: 'them'),
    ]);
    await container.read(debtServiceProvider).refresh();
    await waitUntil(
      () => container.read(pendingForMeProvider).isNotEmpty,
      reason: 'the mirrored rows to reach the derived providers',
    );

    expect(container.read(pendingForMeProvider).map((d) => d.id), ['mine']);
    expect(container.read(pendingForThemProvider).map((d) => d.id), ['theirs']);
  });

  test('a popped proposal stops queueing for the popup', () async {
    final container = containerWith([
      _model(id: 'p1', status: 'pending', awaitingId: 'me'),
    ]);
    final service = container.read(debtServiceProvider);
    await service.refresh();
    await waitUntil(
      () => container.read(nextPopupProvider) != null,
      reason: 'the proposal to queue for the popup',
    );

    expect(container.read(nextPopupProvider)?.id, 'p1');

    await service.markPopped('p1');
    await waitUntil(
      () => container.read(nextPopupProvider) == null,
      reason: 'the popped proposal to stop queueing',
    );

    expect(container.read(nextPopupProvider), isNull);
    expect(
      container.read(pendingForMeProvider).length,
      1,
      reason: 'still waiting on an answer, just not popping again',
    );
  });

  test('syncing again does not re-arm an already shown popup', () async {
    final container = containerWith([
      _model(id: 'p1', status: 'pending', awaitingId: 'me'),
    ]);
    final service = container.read(debtServiceProvider);
    await service.refresh();
    await service.markPopped('p1');

    // The other side edits it, so the row syncs down again.
    repo.rows = [
      _model(
        id: 'p1',
        status: 'pending',
        awaitingId: 'me',
        amount: 400,
        updatedAt: DateTime(2026, 8, 16),
      ),
    ];
    await service.refresh();
    await waitUntil(
      () => container.read(pendingForMeProvider).any((d) => d.amount == 400),
      reason: 'the countered amount to land',
    );

    expect(container.read(nextPopupProvider), isNull);
    expect(container.read(pendingForMeProvider).single.amount, 400);
  });

  test('the side that agreed is not told about its own agreement', () async {
    final container = containerWith([
      _model(id: 'p1', status: 'pending', awaitingId: 'me'),
    ]);
    final service = container.read(debtServiceProvider);
    await service.refresh();

    // I accept. The fake server confirms; the next sync brings it back.
    await service.accept('p1');
    repo.rows = [_model(id: 'p1', status: 'confirmed')];
    await service.refresh();
    await waitUntil(
      () => (container.read(debtProposalsProvider).asData?.value ?? []).any(
        (d) => d.status == 'confirmed',
      ),
      reason: 'the confirmation to land',
    );

    expect(
      container.read(unseenConfirmationsProvider),
      isEmpty,
      reason: 'being told what you just did yourself is noise',
    );
  });

  test('the other side is told once the debt is agreed', () async {
    // Same row, but this device never pressed accept.
    final container = containerWith([_model(id: 'p1', status: 'confirmed')]);
    final service = container.read(debtServiceProvider);
    await service.refresh();
    await waitUntil(
      () => container.read(unseenConfirmationsProvider).isNotEmpty,
      reason: 'the announcement to queue',
    );

    expect(container.read(unseenConfirmationsProvider).single.id, 'p1');

    await service.markConfirmAlertSeen('p1');
    await waitUntil(
      () => container.read(unseenConfirmationsProvider).isEmpty,
      reason: 'announcing it once is enough',
    );
  });

  test('dead ends surface until acknowledged', () async {
    final container = containerWith([_model(id: 'p1', status: 'rejected')]);
    final service = container.read(debtServiceProvider);
    await service.refresh();
    await waitUntil(
      () => container.read(unseenDeadEndsProvider).isNotEmpty,
      reason: 'the rejection to surface',
    );

    expect(container.read(unseenDeadEndsProvider).map((d) => d.id), ['p1']);

    await service.markDismissed('p1');
    await waitUntil(
      () => container.read(unseenDeadEndsProvider).isEmpty,
      reason: 'the acknowledged rejection to disappear',
    );
  });

  test('a proposal deleted server-side stops being shown', () async {
    final container = containerWith([
      _model(id: 'gone', status: 'pending', awaitingId: 'me'),
      _model(id: 'stays', status: 'pending', awaitingId: 'me'),
    ]);
    final service = container.read(debtServiceProvider);
    await service.refresh();
    await waitUntil(
      () => container.read(pendingForMeProvider).length == 2,
      reason: 'both to land first',
    );

    // The server no longer returns 'gone'. An append-only sync would leave it
    // on the device for good — listed, tappable, and opening onto
    // "this one is no longer here".
    repo.rows = [_model(id: 'stays', status: 'pending', awaitingId: 'me')];
    await service.refresh();
    await waitUntil(
      () => container.read(pendingForMeProvider).length == 1,
      reason: 'the deleted one to disappear',
    );

    expect(container.read(pendingForMeProvider).single.id, 'stays');
  });

  test('the fetch always asks for everything', () async {
    final container = containerWith([
      _model(id: 'p1', status: 'pending', awaitingId: 'them'),
    ]);
    final service = container.read(debtServiceProvider);

    await service.refresh();
    await service.refresh();

    expect(
      repo.sinceArgs,
      everyElement(isNull),
      reason: 'an incremental fetch cannot express a deletion',
    );
  });

  test('a debt I owe lands with the direction the other way round', () async {
    final container = containerWith([
      _model(id: 'p1', status: 'confirmed', debtorId: 'me'),
    ]);
    await container.read(debtServiceProvider).refresh();

    final members = await db.watchAllMembers().first;
    final shares = await db.watchAllShares().first;
    final me = members.firstWhere((m) => m.isMe);

    expect(
      shares.firstWhere((s) => s.memberId == me.id).amount,
      500,
      reason: 'my share is the whole amount when I am the debtor',
    );
    expect(
      (await db.watchAllExpenses().first).single.payerMemberId,
      isNot(me.id),
    );
  });

  test('signed out, nothing is projected and nothing is mine', () async {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    repo = _FakeDebtRepository([_model(id: 'p1', status: 'confirmed')]);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        debtRepositoryProvider.overrideWithValue(repo),
        myUserIdProvider.overrideWithValue(null),
      ],
    );
    // addTearDown is LIFO, so this order disposes the container *before*
    // closing the database under it. The other way round closes the database
    // while Drift stream subscriptions are still open, and the dispose that
    // follows never returns — the test just times out with no stack.
    addTearDown(db.close);
    addTearDown(container.dispose);
    container.listen(debtProposalsProvider, (_, __) {});

    await container.read(debtServiceProvider).refresh();

    expect(await db.watchGroups().first, isEmpty);
    expect(container.read(pendingForMeProvider), isEmpty);
  });
}
