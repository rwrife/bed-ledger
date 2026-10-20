import 'dart:convert';
import 'dart:io';

import 'package:bed_ledger/data/file_journal_repository.dart';
import 'package:bed_ledger/data/journal_repository.dart';
import 'package:bed_ledger/data/migrations.dart';
import 'package:bed_ledger/domain/journal.dart';
import 'package:flutter_test/flutter_test.dart';

Journal sample() => Journal(
  beds: [Bed(id: 'a', name: 'North bed')],
  seasons: [Season(id: 's1', bedId: 'a', name: 'spring', year: 2025)],
  plantings: [
    Planting(
      id: 'p1',
      seasonId: 's1',
      crop: 'Peas',
      date: Day.parse('2025-04-02'),
    ),
  ],
  harvests: [
    Harvest(
      id: 'h1',
      plantingId: 'p1',
      date: Day.parse('2025-06-05'),
      quantity: 2.5,
      unit: 'kg',
    ),
  ],
);

Map<String, Object?> sampleJson() => sample().toJson();

Map<String, Object?> _identityMigration(Map<String, Object?> json) => json;

void main() {
  late Directory dir;
  late File live;
  late FileJournalRepository repo;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('bed-ledger-store');
    live = File('${dir.path}/journal.json');
    repo = FileJournalRepository(dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  void writeRawText(String content) => live.writeAsStringSync(content);

  void writeRaw(Map<String, Object?> json) => writeRawText(jsonEncode(json));

  test('first load reports missing, then save/load round-trips', () async {
    expect(await repo.load(), isA<JournalMissing>());
    final before = sample();
    await repo.save(before);
    final outcome = await repo.load();
    final journal = (outcome as JournalLoaded).journal;
    expect(journal.toJson(), before.toJson());
    expect(live.readAsStringSync(), contains('"schemaVersion": 1'));
  });

  test('create/edit/delete round-trips persist across reopening', () async {
    await repo.save(sample());
    final edited = Journal(
      beds: [Bed(id: 'a', name: 'North bed', note: 'sunny')],
      seasons: [],
      plantings: [],
      harvests: [],
    );
    await repo.save(edited);
    final reopened = FileJournalRepository(dir);
    final loaded = await reopened.load() as JournalLoaded;
    expect(loaded.journal.beds.single.note, 'sunny');
    expect(loaded.journal.plantings, isEmpty);
    await reopened.save(
      Journal(beds: [], seasons: [], plantings: [], harvests: []),
    );
    final emptied = await reopened.load() as JournalLoaded;
    expect(emptied.journal.beds, isEmpty);
  });

  test('corrupt JSON is preserved, reported and blocks saves', () async {
    const broken = '{"schemaVersion": 1, "beds": [oops';
    writeRawText(broken);
    final outcome = await repo.load();
    final unreadable = outcome as JournalUnreadable;
    expect(unreadable.reason, contains('not valid JSON'));
    expect(unreadable.path, live.path);
    expect(live.readAsStringSync(), broken);
    await expectLater(repo.save(sample()), throwsA(isA<JournalSaveBlocked>()));
    expect(live.readAsStringSync(), broken);
  });

  test('semantically invalid journal is preserved and reported', () async {
    final json = sampleJson();
    final beds = json['beds']! as List<Object?>;
    beds.add(beds.first); // duplicate ID
    writeRaw(json);
    final outcome = await repo.load() as JournalUnreadable;
    expect(outcome.reason, contains('duplicate ID'));
    expect(jsonDecode(live.readAsStringSync()), json);
  });

  test('newer schema is reported distinctly and never overwritten', () async {
    final json = sampleJson();
    json['schemaVersion'] = 99;
    writeRaw(json);
    final outcome = await repo.load() as JournalUnreadable;
    expect(outcome.newerSchemaVersion, 99);
    await expectLater(repo.save(sample()), throwsA(isA<JournalSaveBlocked>()));
    final stored = jsonDecode(live.readAsStringSync()) as Map<String, Object?>;
    expect(stored['schemaVersion'], 99);
  });

  test('startFresh preserves damage and unblocks saving', () async {
    const broken = 'nope';
    writeRawText(broken);
    expect(await repo.load(), isA<JournalUnreadable>());
    final preserved = await repo.startFresh();
    expect(preserved, isNotNull);
    expect(File(preserved!).readAsStringSync(), broken);
    expect(live.existsSync(), isFalse);
    await repo.save(sample());
    final loaded = await repo.load() as JournalLoaded;
    expect(loaded.journal.beds.single.name, 'North bed');
  });

  test('startFresh on an empty directory is a no-op', () async {
    expect(await repo.startFresh(), isNull);
    await repo.save(sample());
  });

  test('a stray temp file never replaces the live journal', () async {
    await repo.save(sample());
    File('${live.path}.tmp').writeAsStringSync('garbage');
    final loaded = await repo.load() as JournalLoaded;
    expect(loaded.journal.beds.single.name, 'North bed');
  });

  test(
    'migration upgrades old schema, keeps a backup and rewrites once',
    () async {
      final old = sampleJson();
      old['schemaVersion'] = 0;
      writeRaw(old);
      final migrating = FileJournalRepository(
        dir,
        migrator: (json) => migrate(json, migrations: {0: _identityMigration}),
      );
      final outcome = await migrating.load() as JournalLoaded;
      expect(outcome.migratedFromVersion, 0);
      expect(outcome.journal.beds.single.name, 'North bed');
      final upgraded =
          jsonDecode(live.readAsStringSync()) as Map<String, Object?>;
      expect(upgraded['schemaVersion'], 1);
      final backups = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('v0.bak'))
          .toList();
      expect(backups, hasLength(1));
      final backup =
          jsonDecode(backups.single.readAsStringSync()) as Map<String, Object?>;
      expect(backup['schemaVersion'], 0);
      final again = await migrating.load() as JournalLoaded;
      expect(again.migratedFromVersion, isNull);
      expect(
        dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.contains('.bak'))
            .length,
        1,
      );
    },
  );

  test('a migration gap blocks instead of guessing', () async {
    final old = sampleJson();
    old['schemaVersion'] = 0;
    writeRaw(old);
    final outcome = await repo.load() as JournalUnreadable;
    expect(outcome.reason, contains('no migration from schema 0'));
  });

  test('concurrent saves leave a readable latest journal', () async {
    await Future.wait([repo.save(sample()), repo.save(sample())]);
    final loaded = await repo.load() as JournalLoaded;
    expect(loaded.journal.beds, hasLength(1));
    expect(dir.listSync().whereType<File>(), hasLength(1));
  });

  test('lib/ never imports networking or platform channels', () {
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      for (final banned in [
        'HttpClient',
        'dart:html',
        'package:http',
        'WebSocket',
        'RawSocket',
        'Socket.connect',
      ]) {
        expect(source, isNot(contains(banned)), reason: 'in ${entity.path}');
      }
    }
  });
}
