import '../../data/local/app_database.dart';

/// Exposes last-12h location history for incident upload and local use.
/// All location data is stored only on device; uploaded only during an incident.
class LocationHistoryRepository {
  LocationHistoryRepository(this._db);

  final AppDatabase _db;

  /// Returns samples from the last 12 hours, ordered by time ascending.
  Future<List<LocationSample>> getLast12Hours() => _db.getLast12Hours();

  /// Inserts one sample. Call from location tracking service.
  Future<void> addSample(double lat, double lng, DateTime timestamp) =>
      _db.insertLocation(lat, lng, timestamp);

  /// Removes samples older than 12 hours. Call periodically (e.g. after each insert).
  Future<int> pruneOlderThan12Hours() => _db.pruneOlderThan12Hours();
}
