import 'dart:convert';

import 'package:bed_ledger/domain/journal.dart';
import 'package:flutter_test/flutter_test.dart';

Day day(String value) => Day.parse(value);

Journal sample() => Journal(
  beds: [
    Bed(id: 'a', name: 'A'),
    Bed(id: 'b', name: 'B'),
  ],
  seasons: [
    Season(id: 's2', bedId: 'a', name: 'autumn', year: 2026),
    Season(id: 's1', bedId: 'a', name: 'spring', year: 2025),
    Season(id: 's3', bedId: 'b', name: 'spring', year: 2025),
  ],
  plantings: [
    Planting(id: 'p2', seasonId: 's1', crop: 'Kale', date: day('2025-04-02')),
    Planting(id: 'p1', seasonId: 's1', crop: 'Peas', date: day('2025-04-02')),
  ],
  harvests: [
    Harvest(
      id: 'h2',
      plantingId: 'p1',
      date: day('2025-06-05'),
      quantity: 2,
      unit: 'kg',
    ),
    Harvest(id: 'h1', plantingId: 'p1', date: day('2025-06-05')),
  ],
);

void main() {
  test('duplicate bed and cross-kind IDs are rejected', () {
    expect(
      () => Journal(
        beds: [
          Bed(id: 'a', name: 'A'),
          Bed(id: 'a', name: 'A'),
        ],
        seasons: [],
        plantings: [],
        harvests: [],
      ),
      throwsA(
        isA<JournalFormatException>().having(
          (e) => e.message,
          'message',
          contains('duplicate ID'),
        ),
      ),
    );
    expect(
      () => Journal(
        beds: [Bed(id: 'a', name: 'A')],
        seasons: [],
        plantings: [],
        harvests: [Harvest(id: 'a', plantingId: 'x', date: day('2025-01-02'))],
      ),
      throwsA(isA<JournalFormatException>()),
    );
  });

  test('invalid dates, quantities and names are rejected', () {
    expect(() => day('2025-02-29'), throwsA(isA<JournalFormatException>()));
    expect(() => day('2024-02-29'), returnsNormally);
    expect(() => day('2025-13-01'), throwsA(isA<JournalFormatException>()));
    expect(() => day('not-a-date'), throwsA(isA<JournalFormatException>()));
    expect(
      () => Harvest(
        id: 'h',
        plantingId: 'p',
        date: day('2025-01-01'),
        quantity: 0,
        unit: 'kg',
      ),
      throwsA(isA<JournalFormatException>()),
    );
    expect(
      () => Harvest(
        id: 'h',
        plantingId: 'p',
        date: day('2025-01-01'),
        quantity: double.nan,
        unit: 'kg',
      ),
      throwsA(isA<JournalFormatException>()),
    );
    expect(
      () => Harvest(
        id: 'h',
        plantingId: 'p',
        date: day('2025-01-01'),
        quantity: 1,
      ),
      throwsA(isA<JournalFormatException>()),
    );
    expect(
      () => Bed(id: 'a', name: '   '),
      throwsA(isA<JournalFormatException>()),
    );
  });

  test('references and season-year alignment are checked', () {
    expect(
      () => Season(id: 's', bedId: 'nope', name: 'spring', year: 2025),
      returnsNormally,
    );
    expect(
      () => Journal(
        beds: [Bed(id: 'a', name: 'A')],
        seasons: [
          Season(id: 's', bedId: 'missing', name: 'spring', year: 2025),
        ],
        plantings: [],
        harvests: [],
      ),
      throwsA(isA<JournalFormatException>()),
    );
    expect(
      () => Journal(
        beds: [Bed(id: 'a', name: 'A')],
        seasons: [Season(id: 's', bedId: 'a', name: 'spring', year: 2025)],
        plantings: [
          Planting(
            id: 'p',
            seasonId: 's',
            crop: 'Kale',
            date: day('2026-01-01'),
          ),
        ],
        harvests: [],
      ),
      throwsA(
        isA<JournalFormatException>().having(
          (e) => e.message,
          'message',
          contains('season year'),
        ),
      ),
    );
    expect(
      () => Journal(
        beds: [Bed(id: 'a', name: 'A')],
        seasons: [Season(id: 's', bedId: 'a', name: 'spring', year: 2025)],
        plantings: [
          Planting(
            id: 'p',
            seasonId: 's',
            crop: 'Kale',
            date: day('2025-04-01'),
          ),
        ],
        harvests: [Harvest(id: 'h', plantingId: 'p', date: day('2025-03-31'))],
      ),
      throwsA(
        isA<JournalFormatException>().having(
          (e) => e.message,
          'message',
          contains('predates planting'),
        ),
      ),
    );
  });

  test(
    'bed timelines span multiple seasons and multiple harvests per planting',
    () {
      final journal = sample();
      expect(journal.seasonsForBed('a').map((s) => s.id), ['s1', 's2']);
      expect(journal.plantingsForSeason('s1').map((p) => p.id), ['p1', 'p2']);
      expect(journal.harvestsForPlanting('p1').map((h) => h.id), ['h1', 'h2']);
      expect(
        journal
            .harvestsForPlanting('p1')
            .singleWhere((h) => h.id == 'h2')
            .quantity,
        2,
      );
      expect(
        journal
            .harvestsForPlanting('p1')
            .singleWhere((h) => h.id == 'h1')
            .quantity,
        isNull,
      );
    },
  );

  test('journal round-trips through versioned JSON', () {
    final original = sample();
    final json =
        jsonDecode(jsonEncode(original.toJson())) as Map<String, Object?>;
    expect(json['schemaVersion'], Journal.schemaVersion);
    final restored = Journal.fromJson(json);
    expect(jsonEncode(restored.toJson()), jsonEncode(original.toJson()));
    expect(restored.harvestsForPlanting('p1').length, 2);
  });

  test('unsupported schema version is rejected', () {
    final json = sample().toJson()..['schemaVersion'] = 99;
    expect(
      () => Journal.fromJson(json),
      throwsA(isA<JournalFormatException>()),
    );
  });
}
