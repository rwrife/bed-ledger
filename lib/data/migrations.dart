import '../domain/journal.dart';

/// Upgrades raw JSON from schema version N to N + 1.
typedef Migration = Map<String, Object?> Function(Map<String, Object?> json);

/// Registered steps keyed by the version they upgrade FROM. Schema 1 is the
/// first release, so there is nothing to migrate yet; add `1: _v1ToV2` here
/// together with a fixture test when [Journal.schemaVersion] is bumped.
const Map<int, Migration> defaultMigrations = {};

/// The stored journal was written by a newer app. It is valid for that
/// version, so callers must not treat it as damaged or overwrite it.
final class UnsupportedSchemaVersion implements Exception {
  const UnsupportedSchemaVersion(this.found, this.supported);
  final int found;
  final int supported;
  @override
  String toString() =>
      'UnsupportedSchemaVersion: journal schema $found is newer than '
      'supported $supported';
}

/// Result of [migrate].
final class MigrationResult {
  const MigrationResult(this.json, this.fromVersion);
  final Map<String, Object?> json;
  final int fromVersion;
  bool get changed => fromVersion != json['schemaVersion'];
}

/// Signature of [migrate], injectable so repositories can be tested before a
/// second schema version exists.
typedef Migrator = MigrationResult Function(Map<String, Object?> json);

/// Walks [json] up to [target]. Throws [JournalFormatException] for a missing
/// or non-integer version or a gap in the migration chain, and
/// [UnsupportedSchemaVersion] for a version newer than [target]. Inputs are never mutated.
MigrationResult migrate(
  Map<String, Object?> json, {
  Map<int, Migration> migrations = defaultMigrations,
  int target = Journal.schemaVersion,
}) {
  final found = json['schemaVersion'];
  if (found is! int || found < 0) {
    throw const JournalFormatException(
      'schemaVersion must be a nonnegative integer',
    );
  }
  if (found > target) {
    throw UnsupportedSchemaVersion(found, target);
  }
  var current = json;
  for (var version = found; version < target; version++) {
    final step = migrations[version];
    if (step == null) {
      throw JournalFormatException('no migration from schema $version');
    }
    current = {...step(current), 'schemaVersion': version + 1};
  }
  return MigrationResult(current, found);
}
