import 'dart:convert';

import '../domain/journal.dart';
import 'migrations.dart';

/// Read-only restore preview. Applying it never overwrites a local record:
/// an incoming record whose ID already exists locally (identical or not) is
/// dropped and, when its content differs, listed as a conflict. Malformed,
/// oversized or newer-schema backups throw before anything is applied, so the
/// live journal is never touched by a bad file.
final class RestorePreview {
  const RestorePreview({
    required this.journal,
    required this.added,
    required this.conflicts,
  });

  /// Local journal plus every non-conflicting backup record. This is the
  /// only object [JournalController.restore] accepts.
  final Journal journal;

  /// Records the backup contributes (conflict-free only).
  final int added;

  /// IDs held locally with different content; the local copy is kept.
  final List<String> conflicts;
}

RestorePreview previewBackup(String source, Journal current) {
  // ponytail: 10 MiB whole-file bound; add a streaming parser if journals grow.
  if (utf8.encode(source).length > 10 * 1024 * 1024) {
    throw const JournalFormatException('backup exceeds 10 MiB');
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException {
    throw const JournalFormatException('backup is not valid JSON');
  }
  if (decoded is! Map<String, Object?>) {
    throw const JournalFormatException('backup must be a JSON object');
  }
  final Journal incoming;
  try {
    incoming = Journal.fromJson(migrate(decoded).json);
  } on UnsupportedSchemaVersion {
    rethrow;
  } on JournalFormatException catch (e) {
    throw JournalFormatException('backup is invalid: ${e.message}');
  }

  final local = <String, String>{
    for (final b in current.beds) 'bed:${b.id}': jsonEncode(b.toJson()),
    for (final s in current.seasons) 'season:${s.id}': jsonEncode(s.toJson()),
    for (final p in current.plantings)
      'planting:${p.id}': jsonEncode(p.toJson()),
    for (final h in current.harvests) 'harvest:${h.id}': jsonEncode(h.toJson()),
  };

  final conflicts = <String>{};
  final beds = <Bed>[],
      seasons = <Season>[],
      plantings = <Planting>[],
      harvests = <Harvest>[];
  var added = 0;

  void consider<T extends Object>(
    String kind,
    T item,
    String id,
    void Function() keep,
  ) {
    final encoded = jsonEncode(_encode(kind, item));
    final held = local['$kind:$id'];
    if (held == null) {
      keep();
      added++;
    } else if (held != encoded) {
      conflicts.add(id);
    }
  }

  for (final item in incoming.beds) {
    consider('bed', item, item.id, () => beds.add(item));
  }
  for (final item in incoming.seasons) {
    consider('season', item, item.id, () => seasons.add(item));
  }
  for (final item in incoming.plantings) {
    consider('planting', item, item.id, () => plantings.add(item));
  }
  for (final item in incoming.harvests) {
    consider('harvest', item, item.id, () => harvests.add(item));
  }

  final merged = Journal(
    beds: [...current.beds, ...beds],
    seasons: [...current.seasons, ...seasons],
    plantings: [...current.plantings, ...plantings],
    harvests: [...current.harvests, ...harvests],
  );
  return RestorePreview(
    journal: merged,
    added: added,
    conflicts: conflicts.toList()..sort(),
  );
}

Map<String, Object?> _encode(String kind, Object item) => switch (kind) {
  'bed' => (item as Bed).toJson(),
  'season' => (item as Season).toJson(),
  'planting' => (item as Planting).toJson(),
  _ => (item as Harvest).toJson(),
};

String exportBackup(Journal journal) =>
    '${const JsonEncoder.withIndent('  ').convert(journal.toJson())}\n';

String exportHarvestCsv(Journal journal) {
  final beds = {for (final b in journal.beds) b.id: b};
  final seasons = {for (final s in journal.seasons) s.id: s};
  final plantings = {for (final p in journal.plantings) p.id: p};
  final rows = <List<Object?>>[
    const [
      'Bed',
      'Season',
      'Year',
      'Crop',
      'Planted',
      'Harvested',
      'Quantity',
      'Unit',
    ],
    for (final h in journal.harvests)
      [
        beds[seasons[plantings[h.plantingId]!.seasonId]!.bedId]!.name,
        seasons[plantings[h.plantingId]!.seasonId]!.name,
        seasons[plantings[h.plantingId]!.seasonId]!.year,
        plantings[h.plantingId]!.crop,
        plantings[h.plantingId]!.date,
        h.date,
        h.quantity,
        h.unit,
      ],
  ];
  return '${rows.map((row) => row.map(_csv).join(',')).join('\r\n')}\r\n';
}

/// RFC 4180 escaping plus a leading-quote guard against spreadsheet formula
/// injection (a cell starting with `=`, `+`, `@` or `-` after any leading
/// whitespace/control character).
String _csv(Object? value) {
  var text = value?.toString() ?? '';
  if (RegExp(r'^[\s\x00-\x1f]*[=+@-]').hasMatch(text)) text = "'$text";
  return '"${text.replaceAll('"', '""')}"';
}
