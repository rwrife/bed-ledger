import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/journal.dart';
import 'journal_repository.dart';
import 'migrations.dart';

/// JSON-file journal in one app-private directory. Writes go to a temporary
/// file that is flushed and then renamed over the live file, so a crash
/// leaves either the old or the new journal, never a half-written one.
/// Dart's rename replaces an existing file on Linux, macOS and Windows.
///
/// ponytail: one whole-file JSON snapshot suits a single-user journal. When
/// history outgrows that, swap in a SQLite-backed [JournalRepository]; JSON
/// export (issue #6) stays.
final class FileJournalRepository implements JournalRepository {
  FileJournalRepository(this.directory, {Migrator? migrator})
    : _migrator = migrator ?? migrate;

  static const fileName = 'journal.json';

  final Directory directory;
  final Migrator _migrator;

  File get _live => File('${directory.path}${Platform.pathSeparator}$fileName');
  File get _temp => File('${_live.path}.tmp');

  bool _checked = false;
  JournalUnreadable? _blocked;
  Future<void> _queue = Future<void>.value();

  @override
  Future<LoadOutcome> load() => _serial(_load);

  @override
  Future<void> save(Journal journal) => _serial(() async {
    if (!_checked) {
      await _load();
    }
    final blocked = _blocked;
    if (blocked != null) {
      throw JournalSaveBlocked(blocked.path);
    }
    await _write(journal.toJson());
  });

  @override
  Future<String?> startFresh() => _serial(() async {
    String? preserved;
    if (_live.existsSync()) {
      preserved = _freeName('corrupt-${_stamp()}');
      await _live.rename(preserved);
    }
    _blocked = null;
    _checked = true;
    return preserved;
  });

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<LoadOutcome> _load() async {
    _checked = true;
    _blocked = null;
    if (!_live.existsSync()) {
      return const JournalMissing();
    }
    final MigrationResult migrated;
    final Journal journal;
    try {
      final Object? decoded = jsonDecode(await _live.readAsString());
      if (decoded is! Map<String, Object?>) {
        throw const JournalFormatException('top level must be an object');
      }
      migrated = _migrator(decoded);
      journal = Journal.fromJson(migrated.json);
    } on UnsupportedSchemaVersion catch (e) {
      return _block(e.toString(), newer: e.found);
    } on JournalFormatException catch (e) {
      return _block(e.message);
    } on FormatException catch (e) {
      return _block('not valid JSON: ${e.message}');
    } on FileSystemException catch (e) {
      return _block('cannot read file: ${e.message}');
    }
    if (migrated.changed) {
      // Keep the pre-upgrade bytes before rewriting; failure here surfaces.
      await _live.copy(_freeName('v${migrated.fromVersion}.bak'));
      await _write(journal.toJson());
      return JournalLoaded(journal, migratedFromVersion: migrated.fromVersion);
    }
    return JournalLoaded(journal);
  }

  JournalUnreadable _block(String reason, {int? newer}) {
    final outcome = JournalUnreadable(
      path: _live.path,
      reason: reason,
      newerSchemaVersion: newer,
    );
    _blocked = outcome;
    return outcome;
  }

  Future<void> _write(Map<String, Object?> json) async {
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    final text = const JsonEncoder.withIndent('  ').convert(json);
    await _temp.writeAsString('$text\n', flush: true);
    await _temp.rename(_live.path);
  }

  /// Unused sibling path `journal.json.<tag>[.n]`; never overwrites.
  String _freeName(String tag) {
    var candidate = '${_live.path}.$tag';
    for (var n = 2; File(candidate).existsSync(); n++) {
      candidate = '${_live.path}.$tag.$n';
    }
    return candidate;
  }

  static String _stamp() => DateTime.now().toUtc().toIso8601String().replaceAll(
    RegExp(r'[^0-9TZ]'),
    '',
  );
}
