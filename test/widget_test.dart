import 'package:bed_ledger/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

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
      await tester.pumpWidget(const BedLedgerApp());
      expect(find.byKey(const Key('app-title')), findsWidgets);
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
