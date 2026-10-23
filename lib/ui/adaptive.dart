import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

bool get isApplePlatform =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

bool get isAndroidPlatform => defaultTargetPlatform == TargetPlatform.android;

/// Platform-native app frame: Cupertino nav bar on iOS/macOS, Material 3 app
/// bar on Android, compact command bar on Windows.
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.onBack,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final heading = Text(title, key: const Key('app-title'));
    if (isApplePlatform) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: heading,
          leading: onBack == null
              ? null
              : CupertinoNavigationBarBackButton(onPressed: onBack),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: actions.map(_appleAction).toList(),
          ),
        ),
        child: SafeArea(child: body),
      );
    }
    if (isAndroidPlatform) {
      return Scaffold(
        appBar: AppBar(
          title: heading,
          leading: onBack == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onBack,
                ),
          actions: actions,
        ),
        body: body,
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: heading,
        actions: actions,
        toolbarHeight: 48,
        centerTitle: false,
      ),
      body: body,
    );
  }

  Widget _appleAction(Widget action) =>
      Padding(padding: const EdgeInsets.only(left: 4), child: action);
}

/// Native button semantics, focus ring and keyboard activation per platform.
class AdaptiveButton extends StatelessWidget {
  const AdaptiveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.role = ButtonRole.text,
    this.selected = false,
  });

  final String label;
  final VoidCallback onPressed;
  final ButtonRole role;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      style: TextStyle(
        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
      ),
    );
    if (isApplePlatform) {
      return CupertinoButton(
        onPressed: onPressed,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: text,
      );
    }
    return role == ButtonRole.primary
        ? FilledButton(onPressed: onPressed, child: text)
        : TextButton(onPressed: onPressed, child: text);
  }
}

enum ButtonRole { text, primary }

Future<T?> showAppDialog<T>(
  BuildContext context,
  Widget Function(BuildContext) builder,
) => isApplePlatform
    ? showCupertinoDialog<T>(context: context, builder: builder)
    : showDialog<T>(context: context, builder: builder);

/// Workspace seam between screens and platform layout.
///
/// Wide viewports get three independently scrollable panes with Alt+arrow
/// focus traversal. Small windows keep compact desktop tabs; phones use native
/// selectors. Escape steps back one pane.
class WorkspaceLayout extends StatelessWidget {
  const WorkspaceLayout({
    super.key,
    required this.page,
    required this.onPageSelected,
    required this.beds,
    required this.seasons,
    required this.plantings,
  });

  static const double wideBreakpoint = 840;
  static const List<String> paneLabels = ['Beds', 'Seasons', 'Plantings'];

  final int page;
  final ValueChanged<int> onPageSelected;
  final Widget beds;
  final Widget seasons;
  final Widget plantings;

  static bool usePanes(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wideBreakpoint;

  @override
  Widget build(BuildContext context) {
    final panes = [beds, seasons, plantings];
    if (usePanes(context)) {
      return _DesktopPanes(page: page, onSelect: onPageSelected, panes: panes);
    }
    final safePage = page.clamp(0, 2);
    return Column(
      children: [
        if (isApplePlatform)
          CupertinoSlidingSegmentedControl<int>(
            key: const Key('workspace-tabs'),
            groupValue: safePage,
            children: {for (var i = 0; i < 3; i++) i: Text(paneLabels[i])},
            onValueChanged: (i) {
              if (i != null) onPageSelected(i);
            },
          )
        else if (isAndroidPlatform)
          NavigationBar(
            key: const Key('workspace-tabs'),
            height: 64,
            selectedIndex: safePage,
            destinations: [
              for (var i = 0; i < 3; i++)
                NavigationDestination(
                  icon: Icon(
                    const [
                      Icons.yard_outlined,
                      Icons.calendar_month_outlined,
                      Icons.grass_outlined,
                    ][i],
                  ),
                  label: paneLabels[i],
                ),
            ],
            onDestinationSelected: onPageSelected,
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SegmentedButton<int>(
              key: const Key('workspace-tabs'),
              segments: [
                for (var i = 0; i < 3; i++)
                  ButtonSegment(value: i, label: Text(paneLabels[i])),
              ],
              selected: {safePage},
              onSelectionChanged: (s) => onPageSelected(s.first),
            ),
          ),
        Expanded(
          child: Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape &&
                  safePage > 0) {
                onPageSelected(safePage - 1);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: panes[safePage],
          ),
        ),
      ],
    );
  }
}

class _DesktopPanes extends StatefulWidget {
  const _DesktopPanes({
    required this.page,
    required this.onSelect,
    required this.panes,
  });

  final int page;
  final ValueChanged<int> onSelect;
  final List<Widget> panes;

  @override
  State<_DesktopPanes> createState() => _DesktopPanesState();
}

class _DesktopPanesState extends State<_DesktopPanes> {
  final List<FocusNode> _nodes = [for (var i = 0; i < 3; i++) FocusNode()];

  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  Widget _pane(int index) => Focus(
    focusNode: _nodes[index],
    skipTraversal: false,
    onKeyEvent: (node, event) {
      if (event is KeyDownEvent && HardwareKeyboard.instance.isAltPressed) {
        if (event.logicalKey == LogicalKeyboardKey.arrowRight && index < 2) {
          widget.onSelect(index + 1);
          _nodes[index + 1].requestFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft && index > 0) {
          widget.onSelect(index - 1);
          _nodes[index - 1].requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    },
    child: widget.panes[index],
  );

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 240, child: _pane(0)),
      const VerticalDivider(width: 1),
      SizedBox(width: 240, child: _pane(1)),
      const VerticalDivider(width: 1),
      Expanded(child: _pane(2)),
    ],
  );
}
