// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LocationSamplesTable extends LocationSamples
    with TableInfo<$LocationSamplesTable, LocationSample> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocationSamplesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
    'lng',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, lat, lng, timestamp];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'location_samples';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocationSample> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    } else if (isInserting) {
      context.missing(_latMeta);
    }
    if (data.containsKey('lng')) {
      context.handle(
        _lngMeta,
        lng.isAcceptableOrUnknown(data['lng']!, _lngMeta),
      );
    } else if (isInserting) {
      context.missing(_lngMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocationSample map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocationSample(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      )!,
      lng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lng'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
    );
  }

  @override
  $LocationSamplesTable createAlias(String alias) {
    return $LocationSamplesTable(attachedDatabase, alias);
  }
}

class LocationSample extends DataClass implements Insertable<LocationSample> {
  final int id;
  final double lat;
  final double lng;
  final DateTime timestamp;
  const LocationSample({
    required this.id,
    required this.lat,
    required this.lng,
    required this.timestamp,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['lat'] = Variable<double>(lat);
    map['lng'] = Variable<double>(lng);
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  LocationSamplesCompanion toCompanion(bool nullToAbsent) {
    return LocationSamplesCompanion(
      id: Value(id),
      lat: Value(lat),
      lng: Value(lng),
      timestamp: Value(timestamp),
    );
  }

  factory LocationSample.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocationSample(
      id: serializer.fromJson<int>(json['id']),
      lat: serializer.fromJson<double>(json['lat']),
      lng: serializer.fromJson<double>(json['lng']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'lat': serializer.toJson<double>(lat),
      'lng': serializer.toJson<double>(lng),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  LocationSample copyWith({
    int? id,
    double? lat,
    double? lng,
    DateTime? timestamp,
  }) => LocationSample(
    id: id ?? this.id,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    timestamp: timestamp ?? this.timestamp,
  );
  LocationSample copyWithCompanion(LocationSamplesCompanion data) {
    return LocationSample(
      id: data.id.present ? data.id.value : this.id,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocationSample(')
          ..write('id: $id, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, lat, lng, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocationSample &&
          other.id == this.id &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.timestamp == this.timestamp);
}

class LocationSamplesCompanion extends UpdateCompanion<LocationSample> {
  final Value<int> id;
  final Value<double> lat;
  final Value<double> lng;
  final Value<DateTime> timestamp;
  const LocationSamplesCompanion({
    this.id = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.timestamp = const Value.absent(),
  });
  LocationSamplesCompanion.insert({
    this.id = const Value.absent(),
    required double lat,
    required double lng,
    required DateTime timestamp,
  }) : lat = Value(lat),
       lng = Value(lng),
       timestamp = Value(timestamp);
  static Insertable<LocationSample> custom({
    Expression<int>? id,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<DateTime>? timestamp,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (timestamp != null) 'timestamp': timestamp,
    });
  }

  LocationSamplesCompanion copyWith({
    Value<int>? id,
    Value<double>? lat,
    Value<double>? lng,
    Value<DateTime>? timestamp,
  }) {
    return LocationSamplesCompanion(
      id: id ?? this.id,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocationSamplesCompanion(')
          ..write('id: $id, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocationSamplesTable locationSamples = $LocationSamplesTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [locationSamples];
}

typedef $$LocationSamplesTableCreateCompanionBuilder =
    LocationSamplesCompanion Function({
      Value<int> id,
      required double lat,
      required double lng,
      required DateTime timestamp,
    });
typedef $$LocationSamplesTableUpdateCompanionBuilder =
    LocationSamplesCompanion Function({
      Value<int> id,
      Value<double> lat,
      Value<double> lng,
      Value<DateTime> timestamp,
    });

class $$LocationSamplesTableFilterComposer
    extends Composer<_$AppDatabase, $LocationSamplesTable> {
  $$LocationSamplesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocationSamplesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocationSamplesTable> {
  $$LocationSamplesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocationSamplesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocationSamplesTable> {
  $$LocationSamplesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);
}

class $$LocationSamplesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocationSamplesTable,
          LocationSample,
          $$LocationSamplesTableFilterComposer,
          $$LocationSamplesTableOrderingComposer,
          $$LocationSamplesTableAnnotationComposer,
          $$LocationSamplesTableCreateCompanionBuilder,
          $$LocationSamplesTableUpdateCompanionBuilder,
          (
            LocationSample,
            BaseReferences<
              _$AppDatabase,
              $LocationSamplesTable,
              LocationSample
            >,
          ),
          LocationSample,
          PrefetchHooks Function()
        > {
  $$LocationSamplesTableTableManager(
    _$AppDatabase db,
    $LocationSamplesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocationSamplesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocationSamplesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocationSamplesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<double> lat = const Value.absent(),
                Value<double> lng = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
              }) => LocationSamplesCompanion(
                id: id,
                lat: lat,
                lng: lng,
                timestamp: timestamp,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required double lat,
                required double lng,
                required DateTime timestamp,
              }) => LocationSamplesCompanion.insert(
                id: id,
                lat: lat,
                lng: lng,
                timestamp: timestamp,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocationSamplesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocationSamplesTable,
      LocationSample,
      $$LocationSamplesTableFilterComposer,
      $$LocationSamplesTableOrderingComposer,
      $$LocationSamplesTableAnnotationComposer,
      $$LocationSamplesTableCreateCompanionBuilder,
      $$LocationSamplesTableUpdateCompanionBuilder,
      (
        LocationSample,
        BaseReferences<_$AppDatabase, $LocationSamplesTable, LocationSample>,
      ),
      LocationSample,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocationSamplesTableTableManager get locationSamples =>
      $$LocationSamplesTableTableManager(_db, _db.locationSamples);
}
