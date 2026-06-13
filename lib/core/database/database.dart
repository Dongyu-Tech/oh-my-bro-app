import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

// import 'package:heymybro/shared/models/my_model.dart';

part 'database.g.dart';

// Example table — replace `MyModel` with your freezed row class.
//
// @UseRowClass(MyModel)
// class MyTable extends Table {
//   TextColumn get id => text()();
//   TextColumn get title => text()();
//   DateTimeColumn get createdAt => dateTime()();
//   RealColumn get amount => real()();
//   BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
//
//   @override
//   Set<Column<Object>> get primaryKey => {id};
// }

@DriftDatabase(tables: [/* MyTable */])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'heymybro'));

  @override
  int get schemaVersion => 1;

  // Bump schemaVersion and add a clause here for every schema change.
  // Also revisit BackupService.supportedSchemaVersions, since a schema
  // bump silently breaks older JSON backups.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      // if (from < 2) {
      //   await m.addColumn(myTable, myTable.isArchived);
      // }
    },
  );
}

// Pair the freezed row class with a toCompanion() extension so inserts/updates
// are clean. Required because TableCompanion.insert() takes individual
// Value<...> fields, not the row object.
//
// extension MyModelX on MyModel {
//   MyTableCompanion toCompanion() {
//     return MyTableCompanion.insert(
//       id: id,
//       title: title,
//       createdAt: createdAt,
//       amount: amount,
//       isArchived: Value(isArchived),
//     );
//   }
// }
