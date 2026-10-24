import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'data/backup_file_gateway.dart';
import 'data/file_journal_repository.dart';
import 'domain/journal_controller.dart';
import 'ui/journal_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final directory = await getApplicationSupportDirectory();
  runApp(
    BedLedgerApp(
      controller: JournalController(FileJournalRepository(directory)),
    ),
  );
}

/// Root app shell. Supports Windows, Android and iOS from one codebase.
class BedLedgerApp extends StatefulWidget {
  const BedLedgerApp({super.key, required this.controller, this.backupGateway});

  /// Injectable for tests; production always uses app-private file storage.
  final JournalController controller;
  final BackupFileGateway? backupGateway;

  @override
  State<BedLedgerApp> createState() => _BedLedgerAppState();
}

class _BedLedgerAppState extends State<BedLedgerApp> {
  @override
  Widget build(BuildContext context) {
    final platform = defaultTargetPlatform;
    final screen = JournalScreen(
      controller: widget.controller,
      backupGateway: widget.backupGateway ?? const FilePickerBackupGateway(),
    );
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      return CupertinoApp(
        title: 'Bed Ledger',
        localizationsDelegates: const [DefaultMaterialLocalizations.delegate],
        home: screen,
      );
    }
    if (platform == TargetPlatform.android) {
      return MaterialApp(
        title: 'Bed Ledger',
        theme: ThemeData(useMaterial3: true),
        highContrastTheme: ThemeData(
          useMaterial3: true,
          colorScheme: const ColorScheme.highContrastLight(),
        ),
        highContrastDarkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: const ColorScheme.highContrastDark(),
        ),
        home: screen,
      );
    }
    return MaterialApp(
      title: 'Bed Ledger',
      theme: ThemeData(platform: platform, useMaterial3: true),
      highContrastTheme: ThemeData(
        platform: platform,
        useMaterial3: true,
        colorScheme: const ColorScheme.highContrastLight(),
      ),
      highContrastDarkTheme: ThemeData(
        platform: platform,
        useMaterial3: true,
        colorScheme: const ColorScheme.highContrastDark(),
      ),
      home: screen,
    );
  }
}
