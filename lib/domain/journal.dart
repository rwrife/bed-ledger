/// Offline journal domain. No Flutter, I/O, crop advice or yield prediction.
library;

final class JournalFormatException implements Exception {
  const JournalFormatException(this.message);
  final String message;
  @override
  String toString() => 'JournalFormatException: $message';
}

Never _bad(String message) => throw JournalFormatException(message);

String _text(String value, String field, {int max = 200}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.length > max) {
    _bad('$field must be 1..$max characters');
  }
  return trimmed;
}

String _id(String value) {
  if (!RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(value)) {
    _bad('invalid ID: $value');
  }
  return value;
}

String? _optional(String? value, String field, {int max = 2000}) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  return _text(value, field, max: max);
}

Map<String, Object?> _map(Object? value, String field) {
  if (value is! Map<String, Object?>) {
    _bad('$field must be an object');
  }
  return value;
}

List<Map<String, Object?>> _rows(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List<Object?>) {
    _bad('$key must be an array');
  }
  return value.map((row) => _map(row, key)).toList();
}

T _field<T>(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! T) {
    _bad('$key must be $T');
  }
  return value;
}

String? _optionalField(Map<String, Object?> json, String key) {
  if (json[key] == null) {
    return null;
  }
  return _field<String>(json, key);
}

/// Date without time zone; JSON uses strict YYYY-MM-DD.
final class Day implements Comparable<Day> {
  Day(this.year, this.month, this.day) {
    final canonical = DateTime.utc(year, month, day);
    if (year < 1 ||
        year > 9999 ||
        canonical.year != year ||
        canonical.month != month ||
        canonical.day != day) {
      _bad('invalid calendar date: $year-$month-$day');
    }
  }

  factory Day.parse(String value) {
    final parts = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (parts == null) {
      _bad('date must be YYYY-MM-DD: $value');
    }
    return Day(
      int.parse(parts.group(1)!),
      int.parse(parts.group(2)!),
      int.parse(parts.group(3)!),
    );
  }

  final int year;
  final int month;
  final int day;

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(Day other) => toString().compareTo(other.toString());
}

/// A named growing bed.
final class Bed {
  Bed({required String id, required String name, String? note})
    : id = _id(id),
      name = _text(name, 'bed name'),
      note = _optional(note, 'bed note');

  factory Bed.fromJson(Map<String, Object?> json) => Bed(
    id: _field<String>(json, 'id'),
    name: _field<String>(json, 'name'),
    note: _optionalField(json, 'note'),
  );

  final String id;
  final String name;
  final String? note;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'note': note};
}

/// A named season within one bed.
final class Season {
  Season({
    required String id,
    required String bedId,
    required String name,
    required this.year,
  }) : id = _id(id),
       bedId = _id(bedId),
       name = _text(name, 'season name') {
    if (year < 1 || year > 9999) {
      _bad('invalid season year: $year');
    }
  }

  factory Season.fromJson(Map<String, Object?> json) => Season(
    id: _field<String>(json, 'id'),
    bedId: _field<String>(json, 'bedId'),
    name: _field<String>(json, 'name'),
    year: _field<int>(json, 'year'),
  );

  final String id;
  final String bedId;
  final String name;
  final int year;

  Map<String, Object?> toJson() => {
    'id': id,
    'bedId': bedId,
    'name': name,
    'year': year,
  };
}

/// A sowing or transplant of a user-named crop in one season.
final class Planting {
  Planting({
    required String id,
    required String seasonId,
    required String crop,
    required this.date,
    String? position,
    this.method,
  }) : id = _id(id),
       seasonId = _id(seasonId),
       crop = _text(crop, 'crop'),
       position = _optional(position, 'position', max: 200) {
    if (method != null && method != 'sow' && method != 'transplant') {
      _bad('unknown planting method: $method');
    }
  }

  factory Planting.fromJson(Map<String, Object?> json) {
    final rawMethod = _optionalField(json, 'method');
    if (rawMethod != null && rawMethod != 'sow' && rawMethod != 'transplant') {
      _bad('unknown planting method: $rawMethod');
    }
    return Planting(
      id: _field<String>(json, 'id'),
      seasonId: _field<String>(json, 'seasonId'),
      crop: _field<String>(json, 'crop'),
      date: Day.parse(_field<String>(json, 'date')),
      position: _optionalField(json, 'position'),
      method: rawMethod,
    );
  }

  final String id;
  final String seasonId;
  final String crop;
  final Day date;
  final String? position;

  /// Null for records saved before planting method was recorded.
  final String? method;

  Map<String, Object?> toJson() => {
    'id': id,
    'seasonId': seasonId,
    'crop': crop,
    'date': date.toString(),
    'position': position,
    'method': method,
  };
}

/// A harvest from one planting. Quantity is recorded, never interpreted.
final class Harvest {
  Harvest({
    required String id,
    required String plantingId,
    required this.date,
    this.quantity,
    String? unit,
  }) : id = _id(id),
       plantingId = _id(plantingId),
       unit = _optional(unit, 'unit', max: 32) {
    if (quantity != null && (!quantity!.isFinite || quantity! <= 0)) {
      _bad('quantity must be finite and positive');
    }
    if ((quantity == null) != (this.unit == null)) {
      _bad('quantity and unit must be supplied together');
    }
  }

  factory Harvest.fromJson(Map<String, Object?> json) {
    final quantity = json['quantity'];
    if (quantity != null && quantity is! num) {
      _bad('quantity must be numeric');
    }
    return Harvest(
      id: _field<String>(json, 'id'),
      plantingId: _field<String>(json, 'plantingId'),
      date: Day.parse(_field<String>(json, 'date')),
      quantity: (quantity as num?)?.toDouble(),
      unit: _optionalField(json, 'unit'),
    );
  }

  final String id;
  final String plantingId;
  final Day date;
  final double? quantity;
  final String? unit;

  Map<String, Object?> toJson() => {
    'id': id,
    'plantingId': plantingId,
    'date': date.toString(),
    'quantity': quantity,
    'unit': unit,
  };
}

/// Complete validated snapshot: unique IDs, resolvable references and
/// deterministic ordering helpers for bed timelines.
final class Journal {
  Journal({
    required List<Bed> beds,
    required List<Season> seasons,
    required List<Planting> plantings,
    required List<Harvest> harvests,
  }) : beds = List.unmodifiable(beds),
       seasons = List.unmodifiable(seasons),
       plantings = List.unmodifiable(plantings),
       harvests = List.unmodifiable(harvests) {
    final ids = <String>{};
    for (final id in <String>[
      ...this.beds.map((b) => b.id),
      ...this.seasons.map((s) => s.id),
      ...this.plantings.map((p) => p.id),
      ...this.harvests.map((h) => h.id),
    ]) {
      if (!ids.add(id)) {
        _bad('duplicate ID: $id');
      }
    }
    final bedIds = this.beds.map((b) => b.id).toSet();
    final seasonsById = {for (final s in this.seasons) s.id: s};
    final plantingsById = {for (final p in this.plantings) p.id: p};
    for (final season in this.seasons) {
      if (!bedIds.contains(season.bedId)) {
        _bad('season ${season.id} has missing bed ${season.bedId}');
      }
    }
    for (final planting in this.plantings) {
      final season = seasonsById[planting.seasonId];
      if (season == null) {
        _bad('planting ${planting.id} has missing season ${planting.seasonId}');
      }
      if (planting.date.year != season.year) {
        _bad('planting ${planting.id} date outside season year');
      }
    }
    for (final harvest in this.harvests) {
      final planting = plantingsById[harvest.plantingId];
      if (planting == null) {
        _bad(
          'harvest ${harvest.id} has missing planting ${harvest.plantingId}',
        );
      }
      if (harvest.date.compareTo(planting.date) < 0) {
        _bad('harvest ${harvest.id} predates planting');
      }
    }
  }

  factory Journal.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != schemaVersion) {
      _bad('unsupported schemaVersion: ${json['schemaVersion']}');
    }
    return Journal(
      beds: _rows(json, 'beds').map(Bed.fromJson).toList(),
      seasons: _rows(json, 'seasons').map(Season.fromJson).toList(),
      plantings: _rows(json, 'plantings').map(Planting.fromJson).toList(),
      harvests: _rows(json, 'harvests').map(Harvest.fromJson).toList(),
    );
  }

  static const int schemaVersion = 1;

  final List<Bed> beds;
  final List<Season> seasons;
  final List<Planting> plantings;
  final List<Harvest> harvests;

  /// Creates a new Journal with updated entities, re-validating all constraints.
  Journal copyWith({
    List<Bed>? beds,
    List<Season>? seasons,
    List<Planting>? plantings,
    List<Harvest>? harvests,
  }) => Journal(
    beds: beds ?? this.beds,
    seasons: seasons ?? this.seasons,
    plantings: plantings ?? this.plantings,
    harvests: harvests ?? this.harvests,
  );

  /// Bed history in year order, ID as stable tie-break.
  List<Season> seasonsForBed(String bedId) =>
      [...seasons.where((s) => s.bedId == bedId)]..sort(
        (a, b) =>
            a.year != b.year ? a.year.compareTo(b.year) : a.id.compareTo(b.id),
      );

  /// Season plantings in date order, ID as stable tie-break.
  List<Planting> plantingsForSeason(String seasonId) =>
      [...plantings.where((p) => p.seasonId == seasonId)]
        ..sort((a, b) => _dateThenId(a.date, a.id, b.date, b.id));

  /// All harvests from one planting in date order, ID as stable tie-break.
  List<Harvest> harvestsForPlanting(String plantingId) =>
      [...harvests.where((h) => h.plantingId == plantingId)]
        ..sort((a, b) => _dateThenId(a.date, a.id, b.date, b.id));

  static int _dateThenId(Day a, String aId, Day b, String bId) {
    final byDate = a.compareTo(b);
    return byDate == 0 ? aId.compareTo(bId) : byDate;
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'beds': beds.map((b) => b.toJson()).toList(),
    'seasons': seasons.map((s) => s.toJson()).toList(),
    'plantings': plantings.map((p) => p.toJson()).toList(),
    'harvests': harvests.map((h) => h.toJson()).toList(),
  };
}
