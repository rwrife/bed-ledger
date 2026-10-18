import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() => runApp(const BedLedgerApp());

/// Bootstrap screen; journal and Fluent-style desktop navigation follow in
/// later issues. No Android Material UI renders on Windows or iOS.
class BedLedgerApp extends StatelessWidget {
  const BedLedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    const title = Text('Bed Ledger', key: Key('app-title'));
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return const CupertinoApp(
        title: 'Bed Ledger',
        home: CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(middle: Text('Bed Ledger')),
          child: Center(child: title),
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return MaterialApp(
        title: 'Bed Ledger',
        theme: ThemeData(useMaterial3: true),
        home: const Scaffold(body: Center(child: title)),
      );
    }
    return WidgetsApp(
      color: const Color(0xfff3f3f3),
      title: 'Bed Ledger',
      onGenerateRoute: (_) => PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => const ColoredBox(
          color: Color(0xfff3f3f3),
          child: Center(
            child: DefaultTextStyle(
              style: TextStyle(color: Color(0xff202020), fontSize: 24),
              child: title,
            ),
          ),
        ),
      ),
    );
  }
}
