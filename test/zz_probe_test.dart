import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heymybro/core/database/database.dart';
import 'package:heymybro/shared/provider/database_provider.dart';
import 'package:heymybro/shared/provider/debt_provider.dart';

void main() {
  test(
    'probe C: db.close registered FIRST so dispose runs before it',
    () async {
      final db = AppDatabase.forExecutor(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      // LIFO: the last registered runs first, so this order disposes the
      // container before closing the database underneath it.
      addTearDown(db.close);
      addTearDown(container.dispose);
      // ignore: avoid_print
      print('C: before');
      container.read(debtProposalsProvider);
      // ignore: avoid_print
      print('C: after');
    },
    timeout: const Timeout(Duration(seconds: 8)),
  );

  test(
    'probe D: same but with an active listener',
    () async {
      final db = AppDatabase.forExecutor(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(db.close);
      addTearDown(container.dispose);
      container.listen(debtProposalsProvider, (_, __) {});
      // ignore: avoid_print
      print('D: before await');
      await container.read(debtProposalsProvider.future);
      // ignore: avoid_print
      print('D: after await');
    },
    timeout: const Timeout(Duration(seconds: 8)),
  );
}
