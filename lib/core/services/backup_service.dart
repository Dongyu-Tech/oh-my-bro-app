import 'dart:convert';

import '../database/database.dart';
import '../error/result.dart';

/// JSON backup/restore for the local [AppDatabase].
///
/// Bump [AppDatabase.schemaVersion] and add the new version to
/// [supportedSchemaVersions] in the same commit — otherwise older backups
/// silently fail to restore.
class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  /// Versions this build knows how to read. Add an entry when you bump the
  /// Drift schemaVersion AND have an `onUpgrade` clause that maps old data
  /// onto the new shape (or a per-version migrator in [_migrate]).
  static const Set<int> supportedSchemaVersions = {1};

  /// Serialize the database to a JSON envelope. Add table dumps as you add
  /// tables — keep table names stable so older backups remain readable.
  Future<Result<String>> exportToJson() async {
    try {
      final payload = <String, dynamic>{
        'schemaVersion': _db.schemaVersion,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'tables': <String, List<Map<String, dynamic>>>{
          // 'my_table': await _dumpMyTable(),
        },
      };
      return Result.ok(jsonEncode(payload));
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  /// Restore from a JSON envelope produced by [exportToJson]. Refuses to
  /// restore if `schemaVersion` is unknown — easier to add an upgrade path
  /// than to silently corrupt the database.
  Future<Result<void>> restoreFromJson(String jsonString) async {
    try {
      final payload = jsonDecode(jsonString) as Map<String, dynamic>;
      final version = payload['schemaVersion'] as int?;
      if (version == null || !supportedSchemaVersions.contains(version)) {
        return Result.error(
          BackupException(
            'Unsupported backup schemaVersion: $version '
            '(supported: $supportedSchemaVersions)',
          ),
        );
      }

      final tables = (payload['tables'] as Map<String, dynamic>?) ?? const {};
      await _db.transaction(() async {
        await _migrate(tables, fromVersion: version);
        // for (final entry in tables.entries) { await _restoreTable(...); }
      });
      return const Result.ok(null);
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  /// Hook for per-version transforms when restoring an older backup into the
  /// current schema. No-op until we have multiple supported versions.
  Future<void> _migrate(
    Map<String, dynamic> tables, {
    required int fromVersion,
  }) async {
    // if (fromVersion < 2) { ...rename column, etc... }
  }
}

class BackupException implements Exception {
  BackupException(this.message);
  final String message;

  @override
  String toString() => 'BackupException: $message';
}
