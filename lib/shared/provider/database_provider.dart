import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';

/// AppDatabase singleton — auto-disposed when the ProviderScope tears down.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

// Drift `.watch()` → StreamProvider. Derived views (totals, filters, group-bys)
// should re-map THIS stream via `whenData`, not re-query Drift directly.
//
// final myRecordsProvider = StreamProvider<List<MyModel>>((ref) {
//   final db = ref.watch(appDatabaseProvider);
//   return db.watchAll();
// });
//
// final myCountProvider = Provider<AsyncValue<int>>((ref) {
//   return ref.watch(myRecordsProvider).whenData((rs) => rs.length);
// });
