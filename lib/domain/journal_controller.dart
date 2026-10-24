import 'dart:math';

import '../data/journal_repository.dart';
import '../data/portability.dart';
import '../domain/journal.dart';

/// State of the interactive garden journal.
sealed class JournalState {
  const JournalState();
}

final class JournalLoading extends JournalState {
  const JournalLoading();
}

final class JournalError extends JournalState {
  const JournalError({
    required this.message,
    required this.path,
    this.newerSchemaVersion,
  });
  final String message;
  final String path;
  final int? newerSchemaVersion;
}

final class JournalReady extends JournalState {
  const JournalReady({
    required this.journal,
    this.selectedBedId,
    this.selectedSeasonId,
  });

  final Journal journal;
  final String? selectedBedId;
  final String? selectedSeasonId;

  Bed? get selectedBed {
    final id = selectedBedId;
    if (id == null) return null;
    for (final b in journal.beds) {
      if (b.id == id) return b;
    }
    return null;
  }

  Season? get selectedSeason {
    final id = selectedSeasonId;
    if (id == null) return null;
    for (final s in journal.seasons) {
      if (s.id == id) return s;
    }
    return null;
  }

  List<Season> get seasonsForSelectedBed {
    final id = selectedBedId;
    if (id == null) return const [];
    return journal.seasonsForBed(id);
  }

  List<Planting> get plantingsForSelectedSeason {
    final id = selectedSeasonId;
    if (id == null) return const [];
    return journal.plantingsForSeason(id);
  }

  JournalReady copyWith({
    Journal? journal,
    String? selectedBedId,
    bool clearSelectedBed = false,
    String? selectedSeasonId,
    bool clearSelectedSeason = false,
  }) => JournalReady(
    journal: journal ?? this.journal,
    selectedBedId: clearSelectedBed
        ? null
        : (selectedBedId ?? this.selectedBedId),
    selectedSeasonId: clearSelectedSeason
        ? null
        : (selectedSeasonId ?? this.selectedSeasonId),
  );
}

/// In-memory controller coordinating UI mutations with the [JournalRepository].
class JournalController {
  JournalController(this._repository);

  final JournalRepository _repository;
  JournalState _state = const JournalLoading();
  void Function()? onChanged;

  JournalState get state => _state;

  void _setState(JournalState value) {
    _state = value;
    onChanged?.call();
  }

  /// Deterministic pseudo-random ID generator.
  static final Random _random = Random.secure();
  static String nextId(String prefix) {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final rand = _random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return '$prefix-$stamp-$rand';
  }

  Future<void> init() async {
    final outcome = await _repository.load();
    switch (outcome) {
      case JournalMissing():
        final empty = Journal(
          beds: const [],
          seasons: const [],
          plantings: const [],
          harvests: const [],
        );
        _setState(JournalReady(journal: empty));
      case JournalLoaded(:final journal):
        final initialBed = journal.beds.isNotEmpty
            ? journal.beds.first.id
            : null;
        final initialSeason = initialBed != null
            ? (journal.seasonsForBed(initialBed).isNotEmpty
                  ? journal.seasonsForBed(initialBed).first.id
                  : null)
            : null;
        _setState(
          JournalReady(
            journal: journal,
            selectedBedId: initialBed,
            selectedSeasonId: initialSeason,
          ),
        );
      case JournalUnreadable(
        :final path,
        :final reason,
        :final newerSchemaVersion,
      ):
        _setState(
          JournalError(
            message: reason,
            path: path,
            newerSchemaVersion: newerSchemaVersion,
          ),
        );
    }
  }

  void selectBed(String? bedId) {
    final current = _state;
    if (current is! JournalReady) return;
    if (bedId == null) {
      _setState(
        current.copyWith(clearSelectedBed: true, clearSelectedSeason: true),
      );
      return;
    }
    final seasons = current.journal.seasonsForBed(bedId);
    _setState(
      current.copyWith(
        selectedBedId: bedId,
        selectedSeasonId: seasons.isNotEmpty ? seasons.first.id : null,
        clearSelectedSeason: seasons.isEmpty,
      ),
    );
  }

  void selectSeason(String? seasonId) {
    final current = _state;
    if (current is! JournalReady) return;
    _setState(
      current.copyWith(
        selectedSeasonId: seasonId,
        clearSelectedSeason: seasonId == null,
      ),
    );
  }

  // Bed CRUD

  Future<void> addBed({required String name, String? note}) async {
    final current = _state;
    if (current is! JournalReady) return;
    final bed = Bed(id: nextId('bed'), name: name, note: note);
    final nextJournal = current.journal.copyWith(
      beds: [...current.journal.beds, bed],
    );
    await _repository.save(nextJournal);
    _setState(
      current.copyWith(
        journal: nextJournal,
        selectedBedId: bed.id,
        clearSelectedSeason: true,
      ),
    );
  }

  Future<void> updateBed({
    required String id,
    required String name,
    String? note,
  }) async {
    final current = _state;
    if (current is! JournalReady) return;
    final updated = Bed(id: id, name: name, note: note);
    final nextBeds = [
      for (final b in current.journal.beds)
        if (b.id == id) updated else b,
    ];
    final nextJournal = current.journal.copyWith(beds: nextBeds);
    await _repository.save(nextJournal);
    _setState(current.copyWith(journal: nextJournal));
  }

  Future<void> deleteBed(String bedId) async {
    final current = _state;
    if (current is! JournalReady) return;
    final seasonIds = current.journal
        .seasonsForBed(bedId)
        .map((s) => s.id)
        .toSet();
    final plantingIds = current.journal.plantings
        .where((p) => seasonIds.contains(p.seasonId))
        .map((p) => p.id)
        .toSet();

    final nextJournal = Journal(
      beds: current.journal.beds.where((b) => b.id != bedId).toList(),
      seasons: current.journal.seasons.where((s) => s.bedId != bedId).toList(),
      plantings: current.journal.plantings
          .where((p) => !seasonIds.contains(p.seasonId))
          .toList(),
      harvests: current.journal.harvests
          .where((h) => !plantingIds.contains(h.plantingId))
          .toList(),
    );

    await _repository.save(nextJournal);
    final nextBedId = nextJournal.beds.isNotEmpty
        ? nextJournal.beds.first.id
        : null;
    final nextSeasons = nextBedId != null
        ? nextJournal.seasonsForBed(nextBedId)
        : <Season>[];
    _setState(
      current.copyWith(
        journal: nextJournal,
        selectedBedId: nextBedId,
        clearSelectedBed: nextBedId == null,
        selectedSeasonId: nextSeasons.isNotEmpty ? nextSeasons.first.id : null,
        clearSelectedSeason: nextSeasons.isEmpty,
      ),
    );
  }

  // Season CRUD

  Future<void> addSeason({
    required String bedId,
    required String name,
    required int year,
  }) async {
    final current = _state;
    if (current is! JournalReady) return;
    final season = Season(
      id: nextId('season'),
      bedId: bedId,
      name: name,
      year: year,
    );
    final nextJournal = current.journal.copyWith(
      seasons: [...current.journal.seasons, season],
    );
    await _repository.save(nextJournal);
    _setState(
      current.copyWith(journal: nextJournal, selectedSeasonId: season.id),
    );
  }

  Future<void> deleteSeason(String seasonId) async {
    final current = _state;
    if (current is! JournalReady) return;
    final plantingIds = current.journal.plantings
        .where((p) => p.seasonId == seasonId)
        .map((p) => p.id)
        .toSet();

    final nextJournal = Journal(
      beds: current.journal.beds,
      seasons: current.journal.seasons.where((s) => s.id != seasonId).toList(),
      plantings: current.journal.plantings
          .where((p) => p.seasonId != seasonId)
          .toList(),
      harvests: current.journal.harvests
          .where((h) => !plantingIds.contains(h.plantingId))
          .toList(),
    );

    await _repository.save(nextJournal);
    final bedId = current.selectedBedId;
    final remainingSeasons = bedId != null
        ? nextJournal.seasonsForBed(bedId)
        : <Season>[];
    _setState(
      current.copyWith(
        journal: nextJournal,
        selectedSeasonId: remainingSeasons.isNotEmpty
            ? remainingSeasons.first.id
            : null,
        clearSelectedSeason: remainingSeasons.isEmpty,
      ),
    );
  }

  // Planting CRUD

  Future<void> addPlanting({
    required String seasonId,
    required String crop,
    required Day date,
    String? position,
    String? method,
  }) async {
    final current = _state;
    if (current is! JournalReady) return;
    final planting = Planting(
      id: nextId('plant'),
      seasonId: seasonId,
      crop: crop,
      date: date,
      position: position,
      method: method,
    );
    final nextJournal = current.journal.copyWith(
      plantings: [...current.journal.plantings, planting],
    );
    await _repository.save(nextJournal);
    _setState(current.copyWith(journal: nextJournal));
  }

  Future<void> deletePlanting(String plantingId) async {
    final current = _state;
    if (current is! JournalReady) return;
    final nextJournal = Journal(
      beds: current.journal.beds,
      seasons: current.journal.seasons,
      plantings: current.journal.plantings
          .where((p) => p.id != plantingId)
          .toList(),
      harvests: current.journal.harvests
          .where((h) => h.plantingId != plantingId)
          .toList(),
    );
    await _repository.save(nextJournal);
    _setState(current.copyWith(journal: nextJournal));
  }

  // Harvest CRUD

  Future<void> addHarvest({
    required String plantingId,
    required Day date,
    double? quantity,
    String? unit,
  }) async {
    final current = _state;
    if (current is! JournalReady) return;
    final harvest = Harvest(
      id: nextId('hrv'),
      plantingId: plantingId,
      date: date,
      quantity: quantity,
      unit: unit,
    );
    final nextJournal = current.journal.copyWith(
      harvests: [...current.journal.harvests, harvest],
    );
    await _repository.save(nextJournal);
    _setState(current.copyWith(journal: nextJournal));
  }

  Future<void> deleteHarvest(String harvestId) async {
    final current = _state;
    if (current is! JournalReady) return;
    final nextJournal = current.journal.copyWith(
      harvests: current.journal.harvests
          .where((h) => h.id != harvestId)
          .toList(),
    );
    await _repository.save(nextJournal);
    _setState(current.copyWith(journal: nextJournal));
  }

  RestorePreview previewRestore(String source) {
    final current = _state;
    if (current is! JournalReady) {
      throw StateError('journal not ready');
    }
    return previewBackup(source, current.journal);
  }

  Future<void> restore(Journal restored) async {
    final current = _state;
    if (current is! JournalReady) {
      throw StateError('journal not ready');
    }
    await _repository.save(restored);
    final String? nextBedId;
    if (current.selectedBedId != null &&
        restored.beds.any((b) => b.id == current.selectedBedId)) {
      nextBedId = current.selectedBedId;
    } else {
      nextBedId = restored.beds.isEmpty ? null : restored.beds.first.id;
    }
    _setState(JournalReady(journal: restored, selectedBedId: nextBedId));
  }

  String backup() {
    final current = _state;
    if (current is! JournalReady) throw StateError('journal not ready');
    return exportBackup(current.journal);
  }

  String harvestCsv() {
    final current = _state;
    if (current is! JournalReady) throw StateError('journal not ready');
    return exportHarvestCsv(current.journal);
  }

  Future<void> startFresh() async {
    await _repository.startFresh();
    final empty = Journal(
      beds: const [],
      seasons: const [],
      plantings: const [],
      harvests: const [],
    );
    await _repository.save(empty);
    _setState(JournalReady(journal: empty));
  }
}
