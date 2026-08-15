import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/core/error/result.dart';
import 'package:heymybro/core/services/auth_service.dart';
import 'package:heymybro/shared/models/auth_user_model.dart';
import 'package:heymybro/shared/models/debt_proposal_model.dart';
import 'package:heymybro/shared/provider/auth_provider.dart';
import 'package:heymybro/shared/provider/database_provider.dart';
import 'package:heymybro/shared/provider/debt_provider.dart';
import 'package:heymybro/shared/repositories/debt_repository.dart';

/// Signed out at first, exactly as a cold start looks before Supabase has
/// finished restoring the session — then the user arrives on the stream.
class _LateAuthService implements AuthService {
  final _controller = StreamController<AuthUserModel?>.broadcast();
  AuthUserModel? _user;

  void restoreSession() {
    _user = const AuthUserModel(id: 'me');
    _controller.add(_user);
  }

  @override
  AuthUserModel? get currentUser => _user;

  @override
  Stream<AuthUserModel?> get userChanges => _controller.stream;

  @override
  Future<Result<AuthUserModel>> signIn() async => throw UnimplementedError();

  @override
  Future<Result<void>> signOut() async => throw UnimplementedError();
}

class _Repo implements DebtRepository {
  _Repo(this.rows);
  List<DebtProposalModel> rows;

  @override
  Future<Result<List<DebtProposalModel>>> list({DateTime? since}) async =>
      Result.ok(rows);
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
  Future<Result<DebtOutcome>> proposeRepayment({
    required String id,
    required String repaysId,
    required int amount,
  }) async => const Result.ok(DebtOutcome.ok);
  @override
  Future<Result<DebtOutcome>> cancel(String id) async =>
      const Result.ok(DebtOutcome.ok);
}

final _confirmedDebt = DebtProposalModel(
  id: 'test1',
  proposerId: 'me',
  counterpartyId: 'them',
  debtorId: 'me',
  title: 'test1',
  amount: 12,
  status: 'confirmed',
  createdAt: DateTime(2026, 8, 15),
  updatedAt: DateTime(2026, 8, 15),
  resolvedAt: DateTime(2026, 8, 15),
  otherId: 'them',
  otherDisplayName: 'dev',
);

Future<void> settle() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  test('a debt still lands when the session restores after start', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    final auth = _LateAuthService();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        debtRepositoryProvider.overrideWithValue(_Repo([_confirmedDebt])),
        authServiceProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(db.close);
    addTearDown(container.dispose);
    container.listen(debtProposalsProvider, (_, __) {});

    // The app builds and the service starts before anyone is signed in.
    // Listened to, not read: DebtPopupHost watches it, and a bare read would
    // let it auto-dispose along with the sign-in listener this depends on.
    container.listen(debtServiceProvider, (_, __) {});
    container.read(debtServiceProvider);
    await settle();

    expect(
      await db.watchGroups().first,
      isEmpty,
      reason: 'projection has no "me" yet, so it correctly does nothing',
    );

    // Supabase finishes restoring the session.
    auth.restoreSession();
    await settle();

    expect(
      (await db.watchGroups().first).length,
      1,
      reason:
          'nothing else would ever retry — the proposals are already '
          'mirrored, so no push arrives to prompt one',
    );
    expect((await db.watchAllExpenses().first).single.amount, 12);
  });

  test('who I am survives the session arriving late', () async {
    final auth = _LateAuthService();
    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(auth)],
    );
    addTearDown(container.dispose);

    // Reading it before the session lands is what used to poison it: built on
    // authServiceProvider alone it computed null once and cached that answer
    // for the rest of the session.
    container.listen(myUserIdProvider, (_, __) {});
    expect(container.read(myUserIdProvider), isNull);

    auth.restoreSession();
    await settle();

    expect(container.read(myUserIdProvider), 'me');
  });
}
