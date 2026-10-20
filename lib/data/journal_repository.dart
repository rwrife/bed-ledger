/// Storage contract for the offline journal. No network, no platform plugins.
library;

import '../domain/journal.dart';

/// Result of reading the journal. Never throws for bad stored data, so a
/// caller must handle every case and cannot silently treat damage as empty.
sealed class LoadOutcome {
  const LoadOutcome();
}

/// Nothing stored yet (first run).
final class JournalMissing extends LoadOutcome {
  const JournalMissing();
}

/// Valid journal, already migrated to the current schema in memory.
final class JournalLoaded extends LoadOutcome {
  const JournalLoaded(this.journal, {this.migratedFromVersion});
  final Journal journal;

  /// Set when an older stored schema was upgraded; the pre-upgrade file was
  /// kept as a backup before anything was rewritten.
  final int? migratedFromVersion;
}

/// Stored data exists but cannot be used. The file is left untouched and
/// further saves are refused until [JournalRepository.startFresh].
final class JournalUnreadable extends LoadOutcome {
  const JournalUnreadable({
    required this.path,
    required this.reason,
    this.newerSchemaVersion,
  });

  /// Location of the untouched file, for display to the user.
  final String path;
  final String reason;

  /// Set when the file is valid but written by a newer app version.
  final int? newerSchemaVersion;
}

/// Thrown by [JournalRepository.save] while unreadable data is unresolved.
final class JournalSaveBlocked implements Exception {
  const JournalSaveBlocked(this.path);
  final String path;
  @override
  String toString() => 'JournalSaveBlocked: unreadable journal at $path';
}

abstract interface class JournalRepository {
  Future<LoadOutcome> load();

  /// Atomically replaces the stored journal. Throws [JournalSaveBlocked] if
  /// the last [load] found unreadable data.
  Future<void> save(Journal journal);

  /// Moves unreadable data aside under a unique name (never deletes it), then
  /// allows saving a new journal. Returns the preserved file path, or null
  /// if there was nothing to move.
  Future<String?> startFresh();
}
