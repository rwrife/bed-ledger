import 'package:bed_ledger/data/backup_file_gateway.dart';
import 'package:bed_ledger/data/journal_repository.dart';
import 'package:bed_ledger/data/portability.dart';
import 'package:bed_ledger/domain/journal.dart';
import 'package:bed_ledger/domain/journal_controller.dart';
import 'package:bed_ledger/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryRepository implements JournalRepository {
  _MemoryRepository(this.saved);
  Journal saved;
  int saveCount = 0;

  @override
  Future<LoadOutcome> load() async => JournalLoaded(saved);

  @override
  Future<void> save(Journal journal) async {
    saved = journal;
    saveCount++;
  }

  @override
  Future<String?> startFresh() async => null;
}

class _FakeGateway implements BackupFileGateway {
  String? incoming;
  String? lastName;
  String? lastText;
  String? lastMimeType;
  int readCount = 0;

  @override
  Future<String?> readBackup() async {
    readCount++;
    return incoming;
  }

  @override
  Future<bool> writeText(
    String fileName,
    String text, {
    String? mimeType,
  }) async {
    lastName = fileName;
    lastText = text;
    lastMimeType = mimeType;
    return true;
  }
}

void main() {
  testWidgets('preview, cancel and confirm restore preserve local bed', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final localBed = Bed(id: 'bed-1', name: 'Local bed');
    final repository = _MemoryRepository(
      Journal(beds: [localBed], seasons: [], plantings: [], harvests: []),
    );
    final gateway = _FakeGateway();
    final remote = Journal(
      beds: [
        Bed(id: 'bed-1', name: 'Different name'),
        Bed(id: 'bed-2', name: 'New bed'),
      ],
      seasons: [],
      plantings: [],
      harvests: [],
    );
    gateway.incoming = exportBackup(remote);
    await tester.pumpWidget(
      BedLedgerApp(
        controller: JournalController(repository),
        backupGateway: gateway,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('files-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('restore-backup')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 conflicting record'), findsOneWidget);
    expect(repository.saveCount, 0);

    await tester.tap(find.byKey(const Key('restore-cancel')));
    await tester.pumpAndSettle();
    expect(repository.saved.beds.single.name, 'Local bed');
    expect(repository.saveCount, 0);

    await tester.tap(find.byKey(const Key('files-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('restore-backup')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('restore-confirm')));
    await tester.pumpAndSettle();
    expect(repository.saved.beds.length, 2);
    expect(repository.saved.beds.first.name, 'Local bed');
    expect(repository.saved.beds.last.name, 'New bed');
    expect(repository.saveCount, 1);
    expect(gateway.readCount, 2);

    await tester.tap(find.byKey(const Key('message-ok')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('files-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('export-backup')));
    await tester.pumpAndSettle();
    expect(gateway.lastName, 'bed-ledger-backup.json');
    expect(gateway.lastMimeType, 'application/json');
    expect(gateway.lastText, contains('Local bed'));
    expect(gateway.lastText, contains('New bed'));
    debugDefaultTargetPlatformOverride = null;
  });
}
