import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

class LocationSamples extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get lat => real()();
  RealColumn get lng => real()();
  DateTimeColumn get timestamp => dateTime()();
}

@DriftDatabase(tables: [LocationSamples])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  /// Keep only the last 12 hours of samples (rolling window).
  static const Duration historyWindow = Duration(hours: 12);

  Future<void> insertLocation(double lat, double lng, DateTime timestamp) {
    return into(locationSamples).insert(
      LocationSamplesCompanion.insert(
        lat: lat,
        lng: lng,
        timestamp: timestamp,
      ),
    );
  }

  /// All samples from the last 12 hours, ordered by time ascending.
  Future<List<LocationSample>> getLast12Hours() async {
    final cutoff = DateTime.now().subtract(historyWindow);
    return (select(locationSamples)
          ..where((t) => t.timestamp.isBiggerOrEqualValue(cutoff))
          ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
        .get();
  }

  /// Prune rows older than the history window. Call periodically.
  Future<int> pruneOlderThan12Hours() async {
    final cutoff = DateTime.now().subtract(historyWindow);
    return (delete(locationSamples)
          ..where((t) => t.timestamp.isSmallerThanValue(cutoff)))
        .go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'location_history.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
