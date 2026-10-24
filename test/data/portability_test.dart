import 'dart:convert';

import 'package:bed_ledger/data/migrations.dart';
import 'package:bed_ledger/data/portability.dart';
import 'package:bed_ledger/domain/journal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Journal sampleJournal() {
    final bed = Bed(id: 'bed-1', name: 'North bed');
    final season = Season(
      id: 'sea-1',
      bedId: 'bed-1',
      name: 'Spring',
      year: 2026,
    );
    final planting = Planting(
      id: 'pl-1',
      seasonId: 'sea-1',
      crop: 'Carrot',
      method: 'sow',
      date: Day.parse('2026-04-10'),
    );
    final harvest = Harvest(
      id: 'h-1',
      plantingId: 'pl-1',
      date: Day.parse('2026-07-15'),
      quantity: 3.5,
      unit: 'kg',
    );
    return Journal(
      beds: [bed],
      seasons: [season],
      plantings: [planting],
      harvests: [harvest],
    );
  }

  group('export', () {
    test('JSON round-trips through migrate and Journal.fromJson', () {
      final original = sampleJournal();
      final exported = exportBackup(original);
      final decoded = jsonDecode(exported) as Map<String, Object?>;
      final restored = Journal.fromJson(migrate(decoded).json);
      expect(restored.beds.single.name, 'North bed');
      expect(restored.harvests.single.quantity, 3.5);
    });

    test('harvest CSV quotes fields and escapes formula prefixes', () {
      final bed = Bed(id: 'bed-1', name: 'Salad, Herb & Tea');
      final season = Season(
        id: 'sea-1',
        bedId: 'bed-1',
        name: 'Early',
        year: 2026,
      );
      final planting = Planting(
        id: 'pl-1',
        seasonId: 'sea-1',
        crop: '=SUM(1,2)',
        method: 'sow',
        date: Day.parse('2026-03-01'),
      );
      final harvest = Harvest(
        id: 'h-1',
        plantingId: 'pl-1',
        date: Day.parse('2026-04-01'),
        quantity: 1,
        unit: 'bunch',
      );
      final csv = exportHarvestCsv(
        Journal(
          beds: [bed],
          seasons: [season],
          plantings: [planting],
          harvests: [harvest],
        ),
      );
      expect(csv.contains('"Bed","Season","Year","Crop"'), isTrue);
      expect(csv.contains('"Salad, Herb & Tea"'), isTrue);
      expect(csv.contains("'=SUM(1,2)"), isTrue);
    });
  });

  group('previewBackup', () {
    test('merges new records into an empty journal', () {
      final current = Journal(
        beds: [],
        seasons: [],
        plantings: [],
        harvests: [],
      );
      final preview = previewBackup(exportBackup(sampleJournal()), current);
      expect(preview.added, 4);
      expect(preview.conflicts, isEmpty);
      expect(preview.journal.beds.length, 1);
    });

    test('retains local content when backup has a conflicting ID', () {
      final localBed = Bed(
        id: 'bed-1',
        name: 'Local bed',
        note: 'Important local notes',
      );
      final current = Journal(
        beds: [localBed],
        seasons: [],
        plantings: [],
        harvests: [],
      );
      final incoming = Journal(
        beds: [Bed(id: 'bed-1', name: 'Incoming overwrite', note: 'Remote')],
        seasons: [],
        plantings: [],
        harvests: [],
      );
      final preview = previewBackup(exportBackup(incoming), current);
      expect(preview.conflicts, ['bed-1']);
      expect(preview.added, 0);
      expect(preview.journal.beds.single.name, 'Local bed');
      expect(preview.journal.beds.single.note, 'Important local notes');
    });

    test('identical IDs do not duplicate records', () {
      final original = sampleJournal();
      final preview = previewBackup(exportBackup(original), original);
      expect(preview.conflicts, isEmpty);
      expect(preview.added, 0);
      expect(preview.journal.beds.single.name, 'North bed');
    });

    test('rejects malformed JSON backup', () {
      expect(
        () => previewBackup('not json', sampleJournal()),
        throwsA(isA<JournalFormatException>()),
      );
    });

    test('rejects non-object JSON backup', () {
      expect(
        () => previewBackup('[1, 2, 3]', sampleJournal()),
        throwsA(isA<JournalFormatException>()),
      );
    });

    test('rejects backups larger than 10 MiB', () {
      final oversized =
          '{"schemaVersion": 1, "padding": "${'x' * (11 * 1024 * 1024)}"}';
      expect(
        () => previewBackup(oversized, sampleJournal()),
        throwsA(isA<JournalFormatException>()),
      );
    });

    test('rejects future schema version', () {
      final future = jsonEncode({
        'schemaVersion': 99,
        'beds': <Object>[],
        'seasons': <Object>[],
        'plantings': <Object>[],
        'harvests': <Object>[],
      });
      expect(
        () => previewBackup(future, sampleJournal()),
        throwsA(isA<UnsupportedSchemaVersion>()),
      );
    });
  });
}
