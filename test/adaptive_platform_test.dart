import 'package:bed_ledger/data/journal_repository.dart';
import 'package:bed_ledger/domain/journal.dart';
import 'package:bed_ledger/domain/journal_controller.dart';
import 'package:bed_ledger/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _SeededRepository implements JournalRepository {
  @override
  Future<LoadOutcome> load() async => JournalLoaded(
    Journal(
      beds: [Bed(id: 'b1', name: 'North bed')],
      seasons: [Season(id: 's1', bedId: 'b1', name: 'Spring', year: 2026)],
      plantings: [
        Planting(
          id: 'p1',
          seasonId: 's1',
          crop: 'Carrot',
          date: Day.parse('2026-04-10'),
          method: 'sow',
        ),
      ],
      harvests: [],
    ),
  );
  @override
  Future<void> save(Journal journal) async {}
  @override
  Future<String?> startFresh() async => null;
}

const phone = Size(390, 780);
const tablet = Size(1000, 1100);
const desktop = Size(1400, 900);

void adaptiveTest(
  String name,
  TargetPlatform platform,
  Size size,
  Future<void> Function(WidgetTester tester) check, {
  double textScale = 1,
  bool highContrast = false,
}) {
  testWidgets(name, (tester) async {
    debugDefaultTargetPlatformOverride = platform;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(highContrast: highContrast);
    try {
      await tester.pumpWidget(
        BedLedgerApp(controller: JournalController(_SeededRepository())),
      );
      await tester.pumpAndSettle();
      await check(tester);
    } finally {
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
      tester.platformDispatcher.clearAllTestValues();
    }
  });
}

void main() {
  for (final size in [phone, tablet, desktop]) {
    adaptiveTest('iOS Cupertino at ${size.width}', TargetPlatform.iOS, size, (
      t,
    ) async {
      expect(find.byType(CupertinoNavigationBar), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(t.takeException(), isNull);
    });
    adaptiveTest(
      'Android Material 3 at ${size.width}',
      TargetPlatform.android,
      size,
      (t) async {
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.byType(CupertinoNavigationBar), findsNothing);
        expect(t.takeException(), isNull);
      },
    );
    adaptiveTest(
      'Windows chrome at ${size.width}',
      TargetPlatform.windows,
      size,
      (t) async {
        expect(t.getSize(find.byType(AppBar)).height, 48);
        expect(find.byType(CupertinoNavigationBar), findsNothing);
        expect(t.takeException(), isNull);
      },
    );
  }

  adaptiveTest(
    'desktop keeps all three panes',
    TargetPlatform.windows,
    desktop,
    (t) async {
      expect(find.byKey(const Key('workspace-tabs')), findsNothing);
      expect(find.byKey(const Key('bed-b1')), findsOneWidget);
      expect(find.byKey(const Key('season-s1')), findsOneWidget);
      expect(find.textContaining('Carrot — sow'), findsOneWidget);
    },
  );

  adaptiveTest(
    'narrow Windows uses desktop tabs',
    TargetPlatform.windows,
    phone,
    (t) async {
      expect(find.byType(SegmentedButton<int>), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  adaptiveTest(
    'Android phone drills into season and back',
    TargetPlatform.android,
    phone,
    (t) async {
      expect(find.byType(NavigationBar), findsOneWidget);
      await t.tap(find.byKey(const Key('label-North bed')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('season-s1')), findsOneWidget);
      await t.tap(find.byKey(const Key('label-Spring 2026')));
      await t.pumpAndSettle();
      expect(find.textContaining('Carrot — sow'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('season-s1')), findsOneWidget);
    },
  );

  adaptiveTest(
    'iPhone uses Cupertino segmented selector',
    TargetPlatform.iOS,
    phone,
    (t) async {
      expect(
        find.byType(CupertinoSlidingSegmentedControl<int>),
        findsOneWidget,
      );
      expect(find.byType(NavigationBar), findsNothing);
    },
  );

  adaptiveTest(
    'desktop Alt+arrows move workspace focus',
    TargetPlatform.windows,
    desktop,
    (t) async {
      final bedsNode = Focus.maybeOf(
        t.element(find.byKey(const Key('bed-b1'))),
        scopeOk: true,
      );
      expect(bedsNode, isNotNull);
      bedsNode!.requestFocus();
      await t.pumpAndSettle();
      final seasonsNode = Focus.maybeOf(
        t.element(find.byKey(const Key('season-s1'))),
        scopeOk: true,
      );
      expect(seasonsNode, isNotNull);
      expect(FocusManager.instance.primaryFocus, isNot(same(seasonsNode)));
      await t.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await t.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, same(seasonsNode));
      expect(t.takeException(), isNull);
    },
  );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    adaptiveTest(
      '${platform.name} tablet uses panes',
      platform,
      tablet,
      (t) async =>
          expect(find.byKey(const Key('workspace-tabs')), findsNothing),
    );
  }

  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.windows,
  ]) {
    adaptiveTest(
      '${platform.name} high contrast preserves controls',
      platform,
      desktop,
      highContrast: true,
      (t) async {
        final context = t.element(find.byKey(const Key('add-bed')));
        expect(MediaQuery.highContrastOf(context), isTrue);
        expect(find.byKey(const Key('add-bed')), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
    adaptiveTest('${platform.name} native confirmation', platform, desktop, (
      t,
    ) async {
      await t.tap(find.byKey(const Key('delete-bed-b1')));
      await t.pumpAndSettle();
      expect(
        platform == TargetPlatform.iOS
            ? find.byType(CupertinoAlertDialog)
            : find.byType(AlertDialog),
        findsOneWidget,
      );
      await t.tap(find.byKey(const Key('confirm-cancel')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
    adaptiveTest(
      '${platform.name} 2x text no overflow',
      platform,
      phone,
      textScale: 2,
      (t) async {
        expect(t.takeException(), isNull);
        await t.tap(find.byKey(const Key('delete-bed-b1')));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      },
    );
    adaptiveTest(
      '${platform.name} button readable and tappable',
      platform,
      desktop,
      (t) async {
        final button = find.byKey(const Key('add-bed'));
        expect(button, findsOneWidget);
        expect(t.getSize(button).width, greaterThanOrEqualTo(40));
        await t.tap(button);
        await t.pumpAndSettle();
        expect(find.byKey(const Key('form-save')), findsOneWidget);
      },
    );
  }
}
