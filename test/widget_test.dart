import 'package:bed_ledger/data/journal_repository.dart';
import 'package:bed_ledger/domain/journal.dart';
import 'package:bed_ledger/domain/journal_controller.dart';
import 'package:bed_ledger/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

final class _EmptyJournalRepository implements JournalRepository {
  @override
  Future<LoadOutcome> load() async => const JournalMissing();

  @override
  Future<void> save(Journal journal) async {}

  @override
  Future<String?> startFresh() async => null;
}

void main() {
  testWidgets('app shell displays title across target platforms', (
    tester,
  ) async {
    for (final platform in [
      TargetPlatform.windows,
      TargetPlatform.android,
      TargetPlatform.iOS,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      await tester.pumpWidget(
        BedLedgerApp(controller: JournalController(_EmptyJournalRepository())),
      );
      expect(find.byKey(const Key('app-title')), findsWidgets);
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
