import 'package:bed_ledger/data/journal_repository.dart';
import 'package:bed_ledger/domain/journal.dart';
import 'package:bed_ledger/domain/journal_controller.dart';
import 'package:bed_ledger/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryJournalRepository implements JournalRepository {
  Journal? saved;
  @override
  Future<LoadOutcome> load() async =>
      saved == null ? const JournalMissing() : JournalLoaded(saved!);
  @override
  Future<void> save(Journal journal) async => saved = journal;
  @override
  Future<String?> startFresh() async => null;
}

void main() {
  testWidgets('bed to harvest, recall, validation and deletion confirmation', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = MemoryJournalRepository();
    await tester.pumpWidget(BedLedgerApp(controller: JournalController(repo)));
    await tester.pumpAndSettle();
    expect(find.textContaining('No beds yet'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('empty-add-bed')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('empty-add-bed')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('field-name')), 'North bed');
    await tester.tap(find.byKey(const Key('form-save')));
    await tester.pumpAndSettle();
    expect(repo.saved!.beds.single.name, 'North bed');

    await tester.tap(find.byKey(const Key('add-season')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('field-year')), 'not-a-year');
    await tester.tap(find.byKey(const Key('form-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('field-validation')), findsOneWidget);
    expect(repo.saved!.seasons, isEmpty);
    await tester.enterText(find.byKey(const Key('field-year')), '2026');
    await tester.tap(find.byKey(const Key('form-save')));
    await tester.pumpAndSettle();
    expect(repo.saved!.seasons.single.year, 2026);

    await tester.tap(find.byKey(const Key('add-planting')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('field-crop')), 'Carrot');
    await tester.enterText(find.byKey(const Key('field-date')), '2026-04-10');
    await tester.tap(find.byKey(const Key('form-save')));
    await tester.pumpAndSettle();
    expect(repo.saved!.plantings.single.crop, 'Carrot');
    expect(repo.saved!.plantings.single.method, 'sow');

    final plantId = repo.saved!.plantings.single.id;
    await tester.tap(find.byKey(Key('add-harvest-$plantId')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('field-date')), '2026-04-09');
    await tester.tap(find.byKey(const Key('form-save')));
    await tester.pumpAndSettle();
    expect(repo.saved!.harvests, isEmpty);
    expect(find.byKey(const Key('form-error')), findsOneWidget);
    await tester.tap(find.byKey(const Key('message-ok')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('add-harvest-$plantId')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('field-date')), '2026-08-20');
    await tester.enterText(find.byKey(const Key('field-quantity')), '2.5');
    await tester.enterText(find.byKey(const Key('field-unit')), 'kg');
    await tester.tap(find.byKey(const Key('form-save')));
    await tester.pumpAndSettle();
    expect(repo.saved!.harvests.single.quantity, 2.5);
    expect(repo.saved!.harvests.single.unit, 'kg');

    final bedId = repo.saved!.beds.single.id;
    await tester.tap(find.byKey(Key('delete-bed-$bedId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-cancel')));
    await tester.pumpAndSettle();
    expect(repo.saved!.beds.length, 1);
    // Recreate app to prove history survives loading from storage.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(BedLedgerApp(controller: JournalController(repo)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Carrot — sow'), findsOneWidget);
    await tester.tap(find.byKey(Key('delete-bed-$bedId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();
    expect(repo.saved!.beds, isEmpty);
    expect(repo.saved!.seasons, isEmpty);
    expect(repo.saved!.plantings, isEmpty);
    expect(repo.saved!.harvests, isEmpty);
    debugDefaultTargetPlatformOverride = null;
  });
}
