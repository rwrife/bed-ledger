import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'data/file_journal_repository.dart';
import 'domain/journal_controller.dart';
import 'ui/journal_screen.dart';

void main() => runApp(const BedLedgerApp());

/// ponytail: platform sandbox path via HOME on mobile; move to
/// path_provider when platform-specific directory APIs are required.
Directory journalDirectory() {
  final root = Platform.isWindows
      ? Platform.environment['APPDATA']
      : Platform.environment['HOME'];
  if (root == null || root.isEmpty) {
    throw const FileSystemException('App storage directory unavailable');
  }
  return Directory('$root${Platform.pathSeparator}bed-ledger');
}

/// Root app shell. Supports Windows, Android and iOS from one codebase.
class BedLedgerApp extends StatefulWidget {
  const BedLedgerApp({super.key, this.controller});

  /// Injectable for tests; production always uses app-private file storage.
  final JournalController? controller;

  @override
  State<BedLedgerApp> createState() => _BedLedgerAppState();
}

class _BedLedgerAppState extends State<BedLedgerApp> {
  late final JournalController controller =
      widget.controller ??
      JournalController(FileJournalRepository(journalDirectory()));

  @override
  Widget build(BuildContext context) {
    final platform = defaultTargetPlatform;
    final screen = JournalScreen(controller: controller);
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
