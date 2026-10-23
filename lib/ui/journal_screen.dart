import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../domain/journal.dart';
import '../domain/journal_controller.dart';
import 'adaptive.dart';

/// Master-detail journal screen: beds, their seasons, plantings and harvests.
/// Pure recording — no advice, no predictions.
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key, required this.controller});

  final JournalController controller;

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  int _mobilePaneIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.onChanged = () {
      if (mounted) setState(() {});
    };
    widget.controller.init();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final body = switch (state) {
      JournalLoading() => const _LoadingView(key: Key('loading-view')),
      JournalError(:final message, :final path, :final newerSchemaVersion) =>
        _ErrorView(
          key: const Key('error-view'),
          message: message,
          path: path,
          newerSchemaVersion: newerSchemaVersion,
          onStartFresh: () => widget.controller.startFresh(),
        ),
      JournalReady() => _ReadyView(
        ready: state,
        controller: widget.controller,
        mobilePaneIndex: _mobilePaneIndex,
        onSelectMobilePane: (index) => setState(() => _mobilePaneIndex = index),
      ),
    };
    final canStepBack =
        state is JournalReady &&
        !WorkspaceLayout.usePanes(context) &&
        _mobilePaneIndex > 0;
    return PopScope(
      canPop: !canStepBack,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && canStepBack) {
          setState(() => _mobilePaneIndex--);
        }
      },
      child: AdaptiveScaffold(
        title: 'Bed Ledger',
        body: body,
        onBack: canStepBack ? () => setState(() => _mobilePaneIndex--) : null,
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Loading journal…', key: Key('loading')));
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    super.key,
    required this.message,
    required this.path,
    required this.onStartFresh,
    this.newerSchemaVersion,
  });

  final String message;
  final String path;
  final int? newerSchemaVersion;
  final VoidCallback onStartFresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your journal file cannot be opened.',
              key: Key('error-title'),
            ),
            const SizedBox(height: 8),
            Text(
              newerSchemaVersion == null
                  ? 'Reason: $message'
                  : 'This file was written by a newer version '
                        '(schema $newerSchemaVersion) and will not be '
                        'overwritten.',
              key: const Key('error-reason'),
            ),
            Text(path, key: const Key('error-path')),
            const SizedBox(height: 16),
            AdaptiveButton(
              key: const Key('start-fresh'),
              label: 'Start a fresh journal (keeps the old file)',
              onPressed: onStartFresh,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({
    required this.ready,
    required this.controller,
    required this.mobilePaneIndex,
    required this.onSelectMobilePane,
  });

  final JournalReady ready;
  final JournalController controller;
  final int mobilePaneIndex;
  final ValueChanged<int> onSelectMobilePane;

  @override
  Widget build(BuildContext context) {
    final journal = ready.journal;
    return WorkspaceLayout(
      page: mobilePaneIndex,
      onPageSelected: onSelectMobilePane,
      beds: _buildBedPane(context, journal),
      seasons: _buildSeasonPane(context),
      plantings: _buildPlantingPane(context),
    );
  }

  Widget _buildBedPane(BuildContext context, Journal journal) {
    if (journal.beds.isEmpty) {
      return _EmptyState(
        message: 'No beds yet. Add your first bed to start a journal.',
        actionLabel: 'Add bed',
        actionKey: const Key('empty-add-bed'),
        onAction: () => _promptBedForm(context),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Beds',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              AdaptiveButton(
                key: const Key('add-bed'),
                label: 'Add',
                onPressed: () => _promptBedForm(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final bed in journal.beds)
                _Tile(
                  key: Key('bed-${bed.id}'),
                  label: bed.name,
                  selected: bed.id == ready.selectedBedId,
                  onTap: () {
                    controller.selectBed(bed.id);
                    onSelectMobilePane(1);
                  },
                  actions: [
                    AdaptiveButton(
                      key: Key('edit-bed-${bed.id}'),
                      label: 'Edit',
                      onPressed: () => _promptBedForm(context, bed: bed),
                    ),
                    AdaptiveButton(
                      key: Key('delete-bed-${bed.id}'),
                      label: 'Delete',
                      onPressed: () => _confirm(
                        context,
                        title: 'Delete bed “${bed.name}”?',
                        message:
                            'Its seasons, plantings and harvests are '
                            'also deleted.',
                        onConfirm: () => controller.deleteBed(bed.id),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSeasonPane(BuildContext context) {
    final bed = ready.selectedBed;
    if (bed == null) {
      return const Center(child: Text('Select a bed to see its seasons.'));
    }
    final seasons = ready.seasonsForSelectedBed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${bed.name} — seasons',
                  key: Key('bed-title-${bed.id}'),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              AdaptiveButton(
                key: const Key('add-season'),
                label: 'Add season',
                onPressed: () => _promptSeasonForm(context, bed.id),
              ),
            ],
          ),
        ),
        if (seasons.isEmpty)
          Expanded(
            child: _EmptyState(
              message: 'No seasons recorded for ${bed.name} yet.',
              actionLabel: 'Add season',
              actionKey: const Key('empty-add-season'),
              onAction: () => _promptSeasonForm(context, bed.id),
            ),
          )
        else
          Expanded(
            child: ListView(
              key: const Key('season-list'),
              children: [
                for (final season in seasons)
                  _Tile(
                    key: Key('season-${season.id}'),
                    label: '${season.name} ${season.year}',
                    selected: season.id == ready.selectedSeasonId,
                    onTap: () {
                      controller.selectSeason(season.id);
                      onSelectMobilePane(2);
                    },
                    actions: [
                      AdaptiveButton(
                        key: Key('delete-season-${season.id}'),
                        label: 'Delete',
                        onPressed: () => _confirm(
                          context,
                          title:
                              'Delete season '
                              '“${season.name} ${season.year}”?',
                          message:
                              'Its plantings and harvests are '
                              'also deleted.',
                          onConfirm: () => controller.deleteSeason(season.id),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPlantingPane(BuildContext context) {
    final season = ready.selectedSeason;
    if (season == null) {
      return const Center(child: Text('Select a season to see plantings.'));
    }
    final plantings = ready.plantingsForSelectedSeason;
    final journal = ready.journal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${season.name} ${season.year} — plantings',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              AdaptiveButton(
                key: const Key('add-planting'),
                label: 'Sow / transplant',
                onPressed: () => _promptPlantingForm(context, season),
              ),
            ],
          ),
        ),
        if (plantings.isEmpty)
          Expanded(
            child: _EmptyState(
              message: 'Nothing planted in ${season.name} yet.',
              actionLabel: 'Record a planting',
              actionKey: const Key('empty-add-planting'),
              onAction: () => _promptPlantingForm(context, season),
            ),
          )
        else
          Expanded(
            child: ListView(
              key: const Key('planting-list'),
              children: [
                for (final planting in plantings)
                  _PlantingTile(
                    key: Key('planting-${planting.id}'),
                    planting: planting,
                    harvests: journal.harvestsForPlanting(planting.id),
                    onAddHarvest: () => _promptHarvestForm(context, planting),
                    onDeleteHarvest: (harvest) => _confirm(
                      context,
                      title:
                          'Delete harvest of ${planting.crop} on '
                          '${harvest.date}?',
                      message: 'This cannot be undone.',
                      onConfirm: () => controller.deleteHarvest(harvest.id),
                    ),
                    onDeletePlanting: () => _confirm(
                      context,
                      title:
                          'Delete ${planting.crop} planted '
                          '${planting.date}?',
                      message: 'Its harvest records are also deleted.',
                      onConfirm: () => controller.deletePlanting(planting.id),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // Forms -------------------------------------------------------------

  Future<void> _promptBedForm(BuildContext context, {Bed? bed}) async {
    final values = await _showForm(
      context,
      title: bed == null ? 'New bed' : 'Edit bed',
      fields: [
        _FormField(
          key: const Key('field-name'),
          label: 'Name',
          initial: bed?.name ?? '',
        ),
        _FormField(
          key: const Key('field-note'),
          label: 'Note (optional)',
          initial: bed?.note ?? '',
          optional: true,
        ),
      ],
    );
    if (values == null) return;
    final name = values['Name'];
    final note = values['Note (optional)'];
    if (name == null || name.isEmpty) return;
    if (bed == null) {
      await controller.addBed(name: name, note: note);
    } else {
      await controller.updateBed(id: bed.id, name: name, note: note);
    }
  }

  Future<void> _promptSeasonForm(BuildContext context, String bedId) async {
    final year = DateTime.now().year;
    final values = await _showForm(
      context,
      title: 'New season',
      fields: [
        _FormField(
          key: const Key('field-name'),
          label: 'Name',
          initial: 'Spring',
        ),
        _FormField(
          key: const Key('field-year'),
          label: 'Year',
          initial: '$year',
          numeric: true,
        ),
      ],
    );
    if (values == null) return;
    final name = values['Name'];
    final rawYear = values['Year'];
    if (name == null || name.isEmpty || rawYear == null) return;
    final parsedYear = int.tryParse(rawYear);
    if (parsedYear == null || parsedYear < 1 || parsedYear > 9999) {
      if (context.mounted) {
        await _showFormError(context, 'Year must be a number from 1 to 9999.');
      }
      return;
    }
    await controller.addSeason(bedId: bedId, name: name, year: parsedYear);
  }

  Future<void> _promptPlantingForm(BuildContext context, Season season) async {
    final values = await _showForm(
      context,
      title: 'Record planting',
      fields: [
        _FormField(key: const Key('field-crop'), label: 'Crop'),
        _FormField(
          key: const Key('field-date'),
          label: 'Date',
          initial: _today(),
          dateHint: true,
        ),
        _FormField(
          key: const Key('field-method'),
          label: 'Method',
          initial: 'sow',
          allowed: const ['sow', 'transplant'],
        ),
        _FormField(
          key: const Key('field-position'),
          label: 'Position (optional)',
          optional: true,
        ),
      ],
    );
    if (values == null) return;
    final crop = values['Crop'];
    final date = values['Date'];
    final method = values['Method'];
    if (crop == null || crop.isEmpty || date == null || date.isEmpty) return;
    final Day parsed;
    try {
      parsed = Day.parse(date);
    } on JournalFormatException {
      if (context.mounted) {
        await _showFormError(
          context,
          'Date must be a real calendar day '
          'in YYYY-MM-DD form.',
        );
      }
      return;
    }
    if (parsed.year != season.year) {
      if (context.mounted) {
        await _showFormError(
          context,
          'Planting date must fall inside the ${season.year} season.',
        );
      }
      return;
    }
    try {
      await controller.addPlanting(
        seasonId: season.id,
        crop: crop,
        date: parsed,
        position: values['Position (optional)'],
        method: method,
      );
    } on JournalFormatException catch (e) {
      if (context.mounted) await _showFormError(context, e.message);
    }
  }

  Future<void> _promptHarvestForm(
    BuildContext context,
    Planting planting,
  ) async {
    final values = await _showForm(
      context,
      title: 'Log harvest',
      fields: [
        _FormField(
          key: const Key('field-date'),
          label: 'Date',
          initial: _today(),
          dateHint: true,
        ),
        _FormField(
          key: const Key('field-quantity'),
          label: 'Quantity (optional)',
          optional: true,
          numeric: true,
        ),
        _FormField(
          key: const Key('field-unit'),
          label: 'Unit (optional)',
          optional: true,
        ),
      ],
    );
    if (values == null) return;
    final date = values['Date'];
    if (date == null || date.isEmpty) return;
    final rawQty = values['Quantity (optional)'];
    final unit = values['Unit (optional)'];
    final Day parsed;
    try {
      parsed = Day.parse(date);
    } on JournalFormatException {
      if (context.mounted) {
        await _showFormError(
          context,
          'Date must be a real calendar day '
          'in YYYY-MM-DD form.',
        );
      }
      return;
    }
    double? quantity;
    if (rawQty != null && rawQty.isNotEmpty) {
      quantity = double.tryParse(rawQty);
      if (quantity == null || !quantity.isFinite || quantity <= 0) {
        if (context.mounted) {
          await _showFormError(
            context,
            'Quantity must be a positive number, or left blank.',
          );
        }
        return;
      }
    }
    if ((quantity == null) != (unit == null || unit.isEmpty)) {
      if (context.mounted) {
        await _showFormError(
          context,
          'Quantity and unit must be filled in together.',
        );
      }
      return;
    }
    try {
      await controller.addHarvest(
        plantingId: planting.id,
        date: parsed,
        quantity: quantity,
        unit: unit == null || unit.isEmpty ? null : unit,
      );
    } on JournalFormatException catch (e) {
      if (context.mounted) await _showFormError(context, e.message);
    }
  }

  Future<Map<String, String>?> _showForm(
    BuildContext context, {
    required String title,
    required List<_FormField> fields,
  }) => showAppDialog<Map<String, String>>(
    context,
    (dialogContext) =>
        _FormDialog(key: UniqueKey(), title: title, fields: fields),
  );

  Future<void> _showFormError(BuildContext context, String message) =>
      showAppDialog<void>(
        context,
        (dialogContext) => _MessageDialog(
          key: UniqueKey(),
          message: message,
          messageKey: const Key('form-error'),
        ),
      );

  Future<void> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) async {
    final result = await showAppDialog<bool>(
      context,
      (dialogContext) =>
          _ConfirmDialog(key: UniqueKey(), title: title, message: message),
    );
    if (result == true) onConfirm();
  }
}

class _PlantingTile extends StatelessWidget {
  const _PlantingTile({
    super.key,
    required this.planting,
    required this.harvests,
    required this.onAddHarvest,
    required this.onDeleteHarvest,
    required this.onDeletePlanting,
  });

  final Planting planting;
  final List<Harvest> harvests;
  final VoidCallback onAddHarvest;
  final void Function(Harvest harvest) onDeleteHarvest;
  final VoidCallback onDeletePlanting;

  @override
  Widget build(BuildContext context) {
    final method = planting.method ?? 'unknown';
    final position = planting.position;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${planting.crop} — $method on ${planting.date}'
                  '${position == null ? '' : ' ($position)'}',
                  key: Key('planting-label-${planting.id}'),
                ),
              ),
              AdaptiveButton(
                key: Key('add-harvest-${planting.id}'),
                label: 'Log harvest',
                onPressed: onAddHarvest,
              ),
              AdaptiveButton(
                key: Key('delete-planting-${planting.id}'),
                label: 'Delete',
                onPressed: onDeletePlanting,
              ),
            ],
          ),
          if (harvests.isEmpty)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text(
                'No harvests logged.',
                style: TextStyle(fontSize: 12),
              ),
            )
          else
            for (final harvest in harvests)
              Row(
                key: Key('harvest-${harvest.id}'),
                children: [
                  Expanded(
                    child: Text(
                      harvest.quantity == null
                          ? 'Harvest ${harvest.date}'
                          : 'Harvest ${harvest.date}: '
                                '${harvest.quantity} ${harvest.unit}',
                    ),
                  ),
                  AdaptiveButton(
                    key: Key('delete-harvest-${harvest.id}'),
                    label: 'Delete',
                    onPressed: () => onDeleteHarvest(harvest),
                  ),
                ],
              ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.actions = const [],
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdaptiveButton(
            key: Key('label-$label'),
            label: label,
            selected: selected,
            onPressed: onTap,
          ),
          if (actions.isNotEmpty) Wrap(children: actions),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.message,
    this.actionLabel,
    this.actionKey,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, key: const Key('empty-state')),
          if (actionLabel != null) ...[
            const SizedBox(height: 8),
            AdaptiveButton(
              key: actionKey ?? const Key('empty-state-action'),
              label: actionLabel!,
              onPressed: onAction!,
            ),
          ],
        ],
      ),
    ),
  );
}

class _FormField {
  const _FormField({
    required this.key,
    required this.label,
    this.initial = '',
    this.optional = false,
    this.numeric = false,
    this.dateHint = false,
    this.allowed,
  });

  final Key key;
  final String label;
  final String initial;
  final bool optional;
  final bool numeric;
  final bool dateHint;
  final List<String>? allowed;
}

class _FormDialog extends StatefulWidget {
  const _FormDialog({super.key, required this.title, required this.fields});

  final String title;
  final List<_FormField> fields;

  @override
  State<_FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends State<_FormDialog> {
  late final Map<String, TextEditingController> _controllers = {
    for (final field in widget.fields)
      field.label: TextEditingController(text: field.initial),
  };

  late final Map<String, String> _selection = {
    for (final field in widget.fields)
      if (field.allowed != null) field.label: field.initial,
  };

  String? _error;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final values = <String, String>{};
    for (final field in widget.fields) {
      final raw =
          _selection[field.label] ??
          (_controllers[field.label]?.text ?? '').trim();
      if (raw.isEmpty && !field.optional) {
        setState(() => _error = '${field.label} is required.');
        return;
      }
      if (field.numeric && raw.isNotEmpty) {
        final asNumber = num.tryParse(raw);
        if (asNumber == null) {
          setState(() => _error = '${field.label} must be a number.');
          return;
        }
      }
      values[field.label] = raw;
    }
    Navigator.of(context).pop(values);
  }

  @override
  Widget build(BuildContext context) {
    if (isApplePlatform) {
      return CupertinoAlertDialog(
        title: Text(widget.title, key: const Key('form-title')),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final field in widget.fields) ...[
                Text(field.label),
                if (field.allowed == null)
                  CupertinoTextField(
                    key: field.key,
                    controller: _controllers[field.label],
                    placeholder: field.dateHint ? 'YYYY-MM-DD' : null,
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final option in field.allowed!)
                        Padding(
                          padding: const EdgeInsets.all(4),
                          child: GestureDetector(
                            key: Key('${field.label.toLowerCase()}-$option'),
                            onTap: () => setState(
                              () => _selection[field.label] = option,
                            ),
                            child: Text(
                              option,
                              style: TextStyle(
                                fontWeight: _selection[field.label] == option
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 6),
              ],
              if (_error != null)
                Text(
                  _error!,
                  key: const Key('field-validation'),
                  style: const TextStyle(color: CupertinoColors.destructiveRed),
                ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            key: const Key('form-cancel'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            key: const Key('form-save'),
            isDefaultAction: true,
            onPressed: _submit,
            child: const Text('Save'),
          ),
        ],
      );
    }
    return AlertDialog(
      title: Text(widget.title, key: const Key('form-title')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final field in widget.fields) ...[
              Text(field.label),
              const SizedBox(height: 4),
              if (field.allowed == null)
                TextField(
                  key: field.key,
                  controller: _controllers[field.label],
                  decoration: InputDecoration(
                    hintText: field.dateHint ? 'YYYY-MM-DD' : null,
                    isDense: true,
                  ),
                )
              else
                Row(
                  children: [
                    for (final option in field.allowed!)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          key: Key('${field.label.toLowerCase()}-$option'),
                          onTap: () =>
                              setState(() => _selection[field.label] = option),
                          child: Text(
                            option,
                            style: TextStyle(
                              fontWeight: _selection[field.label] == option
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 8),
            ],
            if (_error != null)
              Text(
                _error!,
                key: const Key('field-validation'),
                style: const TextStyle(color: Color(0xffff6b6b)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('form-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('form-save'),
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    if (isApplePlatform) {
      return CupertinoAlertDialog(
        title: Text(title, key: const Key('confirm-title')),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            key: const Key('confirm-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            key: const Key('confirm-delete'),
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      );
    }
    return AlertDialog(
      title: Text(title, key: const Key('confirm-title')),
      content: Text(message),
      actions: [
        TextButton(
          key: const Key('confirm-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('confirm-delete'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

class _MessageDialog extends StatelessWidget {
  const _MessageDialog({
    super.key,
    required this.message,
    required this.messageKey,
  });

  final String message;
  final Key messageKey;

  @override
  Widget build(BuildContext context) {
    if (isApplePlatform) {
      return CupertinoAlertDialog(
        content: Text(message, key: messageKey),
        actions: [
          CupertinoDialogAction(
            key: const Key('message-ok'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      );
    }
    return AlertDialog(
      content: Text(message, key: messageKey),
      actions: [
        FilledButton(
          key: const Key('message-ok'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

String _today() {
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${now.year.toString().padLeft(4, '0')}-${two(now.month)}-'
      '${two(now.day)}';
}
