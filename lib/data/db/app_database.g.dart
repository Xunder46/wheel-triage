// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $UnderlyingTableTable extends UnderlyingTable
    with TableInfo<$UnderlyingTableTable, UnderlyingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UnderlyingTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tickerMeta = const VerificationMeta('ticker');
  @override
  late final GeneratedColumn<String> ticker = GeneratedColumn<String>(
    'ticker',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, ticker, displayName, notes];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'underlying';
  @override
  VerificationContext validateIntegrity(
    Insertable<UnderlyingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('ticker')) {
      context.handle(
        _tickerMeta,
        ticker.isAcceptableOrUnknown(data['ticker']!, _tickerMeta),
      );
    } else if (isInserting) {
      context.missing(_tickerMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UnderlyingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UnderlyingRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ticker: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ticker'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $UnderlyingTableTable createAlias(String alias) {
    return $UnderlyingTableTable(attachedDatabase, alias);
  }
}

class UnderlyingRow extends DataClass implements Insertable<UnderlyingRow> {
  final String id;
  final String ticker;
  final String? displayName;
  final String? notes;
  const UnderlyingRow({
    required this.id,
    required this.ticker,
    this.displayName,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['ticker'] = Variable<String>(ticker);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  UnderlyingTableCompanion toCompanion(bool nullToAbsent) {
    return UnderlyingTableCompanion(
      id: Value(id),
      ticker: Value(ticker),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory UnderlyingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UnderlyingRow(
      id: serializer.fromJson<String>(json['id']),
      ticker: serializer.fromJson<String>(json['ticker']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ticker': serializer.toJson<String>(ticker),
      'displayName': serializer.toJson<String?>(displayName),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  UnderlyingRow copyWith({
    String? id,
    String? ticker,
    Value<String?> displayName = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => UnderlyingRow(
    id: id ?? this.id,
    ticker: ticker ?? this.ticker,
    displayName: displayName.present ? displayName.value : this.displayName,
    notes: notes.present ? notes.value : this.notes,
  );
  UnderlyingRow copyWithCompanion(UnderlyingTableCompanion data) {
    return UnderlyingRow(
      id: data.id.present ? data.id.value : this.id,
      ticker: data.ticker.present ? data.ticker.value : this.ticker,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UnderlyingRow(')
          ..write('id: $id, ')
          ..write('ticker: $ticker, ')
          ..write('displayName: $displayName, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, ticker, displayName, notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UnderlyingRow &&
          other.id == this.id &&
          other.ticker == this.ticker &&
          other.displayName == this.displayName &&
          other.notes == this.notes);
}

class UnderlyingTableCompanion extends UpdateCompanion<UnderlyingRow> {
  final Value<String> id;
  final Value<String> ticker;
  final Value<String?> displayName;
  final Value<String?> notes;
  final Value<int> rowid;
  const UnderlyingTableCompanion({
    this.id = const Value.absent(),
    this.ticker = const Value.absent(),
    this.displayName = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UnderlyingTableCompanion.insert({
    required String id,
    required String ticker,
    this.displayName = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ticker = Value(ticker);
  static Insertable<UnderlyingRow> custom({
    Expression<String>? id,
    Expression<String>? ticker,
    Expression<String>? displayName,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ticker != null) 'ticker': ticker,
      if (displayName != null) 'display_name': displayName,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UnderlyingTableCompanion copyWith({
    Value<String>? id,
    Value<String>? ticker,
    Value<String?>? displayName,
    Value<String?>? notes,
    Value<int>? rowid,
  }) {
    return UnderlyingTableCompanion(
      id: id ?? this.id,
      ticker: ticker ?? this.ticker,
      displayName: displayName ?? this.displayName,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ticker.present) {
      map['ticker'] = Variable<String>(ticker.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UnderlyingTableCompanion(')
          ..write('id: $id, ')
          ..write('ticker: $ticker, ')
          ..write('displayName: $displayName, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WheelCycleTableTable extends WheelCycleTable
    with TableInfo<$WheelCycleTableTable, WheelCycleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WheelCycleTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _underlyingIdMeta = const VerificationMeta(
    'underlyingId',
  );
  @override
  late final GeneratedColumn<String> underlyingId = GeneratedColumn<String>(
    'underlying_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> startedAtMs =
      GeneratedColumn<int>(
        'started_at_ms',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($WheelCycleTableTable.$converterstartedAtMs);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> endedAtMs =
      GeneratedColumn<int>(
        'ended_at_ms',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($WheelCycleTableTable.$converterendedAtMs);
  @override
  late final GeneratedColumnWithTypeConverter<WheelCycleStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<WheelCycleStatus>($WheelCycleTableTable.$converterstatus);
  @override
  late final GeneratedColumnWithTypeConverter<WheelCycleOutcome?, String>
  outcome = GeneratedColumn<String>(
    'outcome',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<WheelCycleOutcome?>($WheelCycleTableTable.$converteroutcome);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    underlyingId,
    startedAtMs,
    endedAtMs,
    status,
    outcome,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wheel_cycle';
  @override
  VerificationContext validateIntegrity(
    Insertable<WheelCycleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('underlying_id')) {
      context.handle(
        _underlyingIdMeta,
        underlyingId.isAcceptableOrUnknown(
          data['underlying_id']!,
          _underlyingIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_underlyingIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WheelCycleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WheelCycleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      underlyingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}underlying_id'],
      )!,
      startedAtMs: $WheelCycleTableTable.$converterstartedAtMs.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}started_at_ms'],
        )!,
      ),
      endedAtMs: $WheelCycleTableTable.$converterendedAtMs.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}ended_at_ms'],
        ),
      ),
      status: $WheelCycleTableTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      outcome: $WheelCycleTableTable.$converteroutcome.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}outcome'],
        ),
      ),
    );
  }

  @override
  $WheelCycleTableTable createAlias(String alias) {
    return $WheelCycleTableTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterstartedAtMs =
      const DateTimeMsConverter();
  static TypeConverter<DateTime?, int?> $converterendedAtMs =
      NullAwareTypeConverter.wrap(const DateTimeMsConverter());
  static TypeConverter<WheelCycleStatus, String> $converterstatus =
      const WheelCycleStatusConverter();
  static TypeConverter<WheelCycleOutcome?, String?> $converteroutcome =
      NullAwareTypeConverter.wrap(const WheelCycleOutcomeConverter());
}

class WheelCycleRow extends DataClass implements Insertable<WheelCycleRow> {
  final String id;
  final String underlyingId;
  final DateTime startedAtMs;
  final DateTime? endedAtMs;
  final WheelCycleStatus status;
  final WheelCycleOutcome? outcome;
  const WheelCycleRow({
    required this.id,
    required this.underlyingId,
    required this.startedAtMs,
    this.endedAtMs,
    required this.status,
    this.outcome,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['underlying_id'] = Variable<String>(underlyingId);
    {
      map['started_at_ms'] = Variable<int>(
        $WheelCycleTableTable.$converterstartedAtMs.toSql(startedAtMs),
      );
    }
    if (!nullToAbsent || endedAtMs != null) {
      map['ended_at_ms'] = Variable<int>(
        $WheelCycleTableTable.$converterendedAtMs.toSql(endedAtMs),
      );
    }
    {
      map['status'] = Variable<String>(
        $WheelCycleTableTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || outcome != null) {
      map['outcome'] = Variable<String>(
        $WheelCycleTableTable.$converteroutcome.toSql(outcome),
      );
    }
    return map;
  }

  WheelCycleTableCompanion toCompanion(bool nullToAbsent) {
    return WheelCycleTableCompanion(
      id: Value(id),
      underlyingId: Value(underlyingId),
      startedAtMs: Value(startedAtMs),
      endedAtMs: endedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAtMs),
      status: Value(status),
      outcome: outcome == null && nullToAbsent
          ? const Value.absent()
          : Value(outcome),
    );
  }

  factory WheelCycleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WheelCycleRow(
      id: serializer.fromJson<String>(json['id']),
      underlyingId: serializer.fromJson<String>(json['underlyingId']),
      startedAtMs: serializer.fromJson<DateTime>(json['startedAtMs']),
      endedAtMs: serializer.fromJson<DateTime?>(json['endedAtMs']),
      status: serializer.fromJson<WheelCycleStatus>(json['status']),
      outcome: serializer.fromJson<WheelCycleOutcome?>(json['outcome']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'underlyingId': serializer.toJson<String>(underlyingId),
      'startedAtMs': serializer.toJson<DateTime>(startedAtMs),
      'endedAtMs': serializer.toJson<DateTime?>(endedAtMs),
      'status': serializer.toJson<WheelCycleStatus>(status),
      'outcome': serializer.toJson<WheelCycleOutcome?>(outcome),
    };
  }

  WheelCycleRow copyWith({
    String? id,
    String? underlyingId,
    DateTime? startedAtMs,
    Value<DateTime?> endedAtMs = const Value.absent(),
    WheelCycleStatus? status,
    Value<WheelCycleOutcome?> outcome = const Value.absent(),
  }) => WheelCycleRow(
    id: id ?? this.id,
    underlyingId: underlyingId ?? this.underlyingId,
    startedAtMs: startedAtMs ?? this.startedAtMs,
    endedAtMs: endedAtMs.present ? endedAtMs.value : this.endedAtMs,
    status: status ?? this.status,
    outcome: outcome.present ? outcome.value : this.outcome,
  );
  WheelCycleRow copyWithCompanion(WheelCycleTableCompanion data) {
    return WheelCycleRow(
      id: data.id.present ? data.id.value : this.id,
      underlyingId: data.underlyingId.present
          ? data.underlyingId.value
          : this.underlyingId,
      startedAtMs: data.startedAtMs.present
          ? data.startedAtMs.value
          : this.startedAtMs,
      endedAtMs: data.endedAtMs.present ? data.endedAtMs.value : this.endedAtMs,
      status: data.status.present ? data.status.value : this.status,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WheelCycleRow(')
          ..write('id: $id, ')
          ..write('underlyingId: $underlyingId, ')
          ..write('startedAtMs: $startedAtMs, ')
          ..write('endedAtMs: $endedAtMs, ')
          ..write('status: $status, ')
          ..write('outcome: $outcome')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, underlyingId, startedAtMs, endedAtMs, status, outcome);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WheelCycleRow &&
          other.id == this.id &&
          other.underlyingId == this.underlyingId &&
          other.startedAtMs == this.startedAtMs &&
          other.endedAtMs == this.endedAtMs &&
          other.status == this.status &&
          other.outcome == this.outcome);
}

class WheelCycleTableCompanion extends UpdateCompanion<WheelCycleRow> {
  final Value<String> id;
  final Value<String> underlyingId;
  final Value<DateTime> startedAtMs;
  final Value<DateTime?> endedAtMs;
  final Value<WheelCycleStatus> status;
  final Value<WheelCycleOutcome?> outcome;
  final Value<int> rowid;
  const WheelCycleTableCompanion({
    this.id = const Value.absent(),
    this.underlyingId = const Value.absent(),
    this.startedAtMs = const Value.absent(),
    this.endedAtMs = const Value.absent(),
    this.status = const Value.absent(),
    this.outcome = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WheelCycleTableCompanion.insert({
    required String id,
    required String underlyingId,
    required DateTime startedAtMs,
    this.endedAtMs = const Value.absent(),
    required WheelCycleStatus status,
    this.outcome = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       underlyingId = Value(underlyingId),
       startedAtMs = Value(startedAtMs),
       status = Value(status);
  static Insertable<WheelCycleRow> custom({
    Expression<String>? id,
    Expression<String>? underlyingId,
    Expression<int>? startedAtMs,
    Expression<int>? endedAtMs,
    Expression<String>? status,
    Expression<String>? outcome,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (underlyingId != null) 'underlying_id': underlyingId,
      if (startedAtMs != null) 'started_at_ms': startedAtMs,
      if (endedAtMs != null) 'ended_at_ms': endedAtMs,
      if (status != null) 'status': status,
      if (outcome != null) 'outcome': outcome,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WheelCycleTableCompanion copyWith({
    Value<String>? id,
    Value<String>? underlyingId,
    Value<DateTime>? startedAtMs,
    Value<DateTime?>? endedAtMs,
    Value<WheelCycleStatus>? status,
    Value<WheelCycleOutcome?>? outcome,
    Value<int>? rowid,
  }) {
    return WheelCycleTableCompanion(
      id: id ?? this.id,
      underlyingId: underlyingId ?? this.underlyingId,
      startedAtMs: startedAtMs ?? this.startedAtMs,
      endedAtMs: endedAtMs ?? this.endedAtMs,
      status: status ?? this.status,
      outcome: outcome ?? this.outcome,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (underlyingId.present) {
      map['underlying_id'] = Variable<String>(underlyingId.value);
    }
    if (startedAtMs.present) {
      map['started_at_ms'] = Variable<int>(
        $WheelCycleTableTable.$converterstartedAtMs.toSql(startedAtMs.value),
      );
    }
    if (endedAtMs.present) {
      map['ended_at_ms'] = Variable<int>(
        $WheelCycleTableTable.$converterendedAtMs.toSql(endedAtMs.value),
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $WheelCycleTableTable.$converterstatus.toSql(status.value),
      );
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(
        $WheelCycleTableTable.$converteroutcome.toSql(outcome.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WheelCycleTableCompanion(')
          ..write('id: $id, ')
          ..write('underlyingId: $underlyingId, ')
          ..write('startedAtMs: $startedAtMs, ')
          ..write('endedAtMs: $endedAtMs, ')
          ..write('status: $status, ')
          ..write('outcome: $outcome, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LegTableTable extends LegTable with TableInfo<$LegTableTable, LegRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LegTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cycleIdMeta = const VerificationMeta(
    'cycleId',
  );
  @override
  late final GeneratedColumn<String> cycleId = GeneratedColumn<String>(
    'cycle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<OptionType, String> optionType =
      GeneratedColumn<String>(
        'option_type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<OptionType>($LegTableTable.$converteroptionType);
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, int> strike =
      GeneratedColumn<int>(
        'strike',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<Decimal>($LegTableTable.$converterstrike);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> expirationMs =
      GeneratedColumn<int>(
        'expiration_ms',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($LegTableTable.$converterexpirationMs);
  static const VerificationMeta _contractsMeta = const VerificationMeta(
    'contracts',
  );
  @override
  late final GeneratedColumn<int> contracts = GeneratedColumn<int>(
    'contracts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> openedAtMs =
      GeneratedColumn<int>(
        'opened_at_ms',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($LegTableTable.$converteropenedAtMs);
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, int> openCreditPerShare =
      GeneratedColumn<int>(
        'open_credit_per_share',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<Decimal>($LegTableTable.$converteropenCreditPerShare);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> closedAtMs =
      GeneratedColumn<int>(
        'closed_at_ms',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($LegTableTable.$converterclosedAtMs);
  @override
  late final GeneratedColumnWithTypeConverter<Decimal?, int>
  closeDebitPerShare = GeneratedColumn<int>(
    'close_debit_per_share',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  ).withConverter<Decimal?>($LegTableTable.$convertercloseDebitPerShare);
  @override
  late final GeneratedColumnWithTypeConverter<CloseReason?, String>
  closeReason = GeneratedColumn<String>(
    'close_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<CloseReason?>($LegTableTable.$convertercloseReason);
  static const VerificationMeta _rolledFromLegIdMeta = const VerificationMeta(
    'rolledFromLegId',
  );
  @override
  late final GeneratedColumn<String> rolledFromLegId = GeneratedColumn<String>(
    'rolled_from_leg_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ruleProfileVersionIdMeta =
      const VerificationMeta('ruleProfileVersionId');
  @override
  late final GeneratedColumn<String> ruleProfileVersionId =
      GeneratedColumn<String>(
        'rule_profile_version_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _ivAtOpenMeta = const VerificationMeta(
    'ivAtOpen',
  );
  @override
  late final GeneratedColumn<double> ivAtOpen = GeneratedColumn<double>(
    'iv_at_open',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ivRankAtOpenMeta = const VerificationMeta(
    'ivRankAtOpen',
  );
  @override
  late final GeneratedColumn<double> ivRankAtOpen = GeneratedColumn<double>(
    'iv_rank_at_open',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deltaAtOpenMeta = const VerificationMeta(
    'deltaAtOpen',
  );
  @override
  late final GeneratedColumn<double> deltaAtOpen = GeneratedColumn<double>(
    'delta_at_open',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Decimal?, int>
  underlyingPriceAtOpen = GeneratedColumn<int>(
    'underlying_price_at_open',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  ).withConverter<Decimal?>($LegTableTable.$converterunderlyingPriceAtOpen);
  @override
  late final GeneratedColumnWithTypeConverter<Decimal?, int> openFee =
      GeneratedColumn<int>(
        'open_fee',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<Decimal?>($LegTableTable.$converteropenFee);
  @override
  late final GeneratedColumnWithTypeConverter<Decimal?, int> closeFee =
      GeneratedColumn<int>(
        'close_fee',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<Decimal?>($LegTableTable.$convertercloseFee);
  static const VerificationMeta _acceptsAssignmentMeta = const VerificationMeta(
    'acceptsAssignment',
  );
  @override
  late final GeneratedColumn<bool> acceptsAssignment = GeneratedColumn<bool>(
    'accepts_assignment',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("accepts_assignment" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cycleId,
    sequence,
    optionType,
    strike,
    expirationMs,
    contracts,
    openedAtMs,
    openCreditPerShare,
    closedAtMs,
    closeDebitPerShare,
    closeReason,
    rolledFromLegId,
    ruleProfileVersionId,
    ivAtOpen,
    ivRankAtOpen,
    deltaAtOpen,
    underlyingPriceAtOpen,
    openFee,
    closeFee,
    acceptsAssignment,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'leg';
  @override
  VerificationContext validateIntegrity(
    Insertable<LegRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('cycle_id')) {
      context.handle(
        _cycleIdMeta,
        cycleId.isAcceptableOrUnknown(data['cycle_id']!, _cycleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cycleIdMeta);
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    } else if (isInserting) {
      context.missing(_sequenceMeta);
    }
    if (data.containsKey('contracts')) {
      context.handle(
        _contractsMeta,
        contracts.isAcceptableOrUnknown(data['contracts']!, _contractsMeta),
      );
    } else if (isInserting) {
      context.missing(_contractsMeta);
    }
    if (data.containsKey('rolled_from_leg_id')) {
      context.handle(
        _rolledFromLegIdMeta,
        rolledFromLegId.isAcceptableOrUnknown(
          data['rolled_from_leg_id']!,
          _rolledFromLegIdMeta,
        ),
      );
    }
    if (data.containsKey('rule_profile_version_id')) {
      context.handle(
        _ruleProfileVersionIdMeta,
        ruleProfileVersionId.isAcceptableOrUnknown(
          data['rule_profile_version_id']!,
          _ruleProfileVersionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ruleProfileVersionIdMeta);
    }
    if (data.containsKey('iv_at_open')) {
      context.handle(
        _ivAtOpenMeta,
        ivAtOpen.isAcceptableOrUnknown(data['iv_at_open']!, _ivAtOpenMeta),
      );
    }
    if (data.containsKey('iv_rank_at_open')) {
      context.handle(
        _ivRankAtOpenMeta,
        ivRankAtOpen.isAcceptableOrUnknown(
          data['iv_rank_at_open']!,
          _ivRankAtOpenMeta,
        ),
      );
    }
    if (data.containsKey('delta_at_open')) {
      context.handle(
        _deltaAtOpenMeta,
        deltaAtOpen.isAcceptableOrUnknown(
          data['delta_at_open']!,
          _deltaAtOpenMeta,
        ),
      );
    }
    if (data.containsKey('accepts_assignment')) {
      context.handle(
        _acceptsAssignmentMeta,
        acceptsAssignment.isAcceptableOrUnknown(
          data['accepts_assignment']!,
          _acceptsAssignmentMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LegRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LegRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      cycleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cycle_id'],
      )!,
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      )!,
      optionType: $LegTableTable.$converteroptionType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}option_type'],
        )!,
      ),
      strike: $LegTableTable.$converterstrike.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}strike'],
        )!,
      ),
      expirationMs: $LegTableTable.$converterexpirationMs.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}expiration_ms'],
        )!,
      ),
      contracts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}contracts'],
      )!,
      openedAtMs: $LegTableTable.$converteropenedAtMs.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}opened_at_ms'],
        )!,
      ),
      openCreditPerShare: $LegTableTable.$converteropenCreditPerShare.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}open_credit_per_share'],
        )!,
      ),
      closedAtMs: $LegTableTable.$converterclosedAtMs.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}closed_at_ms'],
        ),
      ),
      closeDebitPerShare: $LegTableTable.$convertercloseDebitPerShare.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}close_debit_per_share'],
        ),
      ),
      closeReason: $LegTableTable.$convertercloseReason.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}close_reason'],
        ),
      ),
      rolledFromLegId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rolled_from_leg_id'],
      ),
      ruleProfileVersionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rule_profile_version_id'],
      )!,
      ivAtOpen: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}iv_at_open'],
      ),
      ivRankAtOpen: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}iv_rank_at_open'],
      ),
      deltaAtOpen: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}delta_at_open'],
      ),
      underlyingPriceAtOpen: $LegTableTable.$converterunderlyingPriceAtOpen
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.int,
              data['${effectivePrefix}underlying_price_at_open'],
            ),
          ),
      openFee: $LegTableTable.$converteropenFee.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}open_fee'],
        ),
      ),
      closeFee: $LegTableTable.$convertercloseFee.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}close_fee'],
        ),
      ),
      acceptsAssignment: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}accepts_assignment'],
      )!,
    );
  }

  @override
  $LegTableTable createAlias(String alias) {
    return $LegTableTable(attachedDatabase, alias);
  }

  static TypeConverter<OptionType, String> $converteroptionType =
      const OptionTypeConverter();
  static TypeConverter<Decimal, int> $converterstrike = const CentsConverter();
  static TypeConverter<DateTime, int> $converterexpirationMs =
      const DateTimeMsConverter();
  static TypeConverter<DateTime, int> $converteropenedAtMs =
      const DateTimeMsConverter();
  static TypeConverter<Decimal, int> $converteropenCreditPerShare =
      const TenThousandthsConverter();
  static TypeConverter<DateTime?, int?> $converterclosedAtMs =
      NullAwareTypeConverter.wrap(const DateTimeMsConverter());
  static TypeConverter<Decimal?, int?> $convertercloseDebitPerShare =
      NullAwareTypeConverter.wrap(const TenThousandthsConverter());
  static TypeConverter<CloseReason?, String?> $convertercloseReason =
      NullAwareTypeConverter.wrap(const CloseReasonConverter());
  static TypeConverter<Decimal?, int?> $converterunderlyingPriceAtOpen =
      NullAwareTypeConverter.wrap(const CentsConverter());
  static TypeConverter<Decimal?, int?> $converteropenFee =
      NullAwareTypeConverter.wrap(const CentsConverter());
  static TypeConverter<Decimal?, int?> $convertercloseFee =
      NullAwareTypeConverter.wrap(const CentsConverter());
}

class LegRow extends DataClass implements Insertable<LegRow> {
  final String id;
  final String cycleId;
  final int sequence;
  final OptionType optionType;
  final Decimal strike;
  final DateTime expirationMs;
  final int contracts;
  final DateTime openedAtMs;
  final Decimal openCreditPerShare;
  final DateTime? closedAtMs;
  final Decimal? closeDebitPerShare;
  final CloseReason? closeReason;
  final String? rolledFromLegId;
  final String ruleProfileVersionId;
  final double? ivAtOpen;
  final double? ivRankAtOpen;
  final double? deltaAtOpen;
  final Decimal? underlyingPriceAtOpen;

  /// Integer cents, total for the transaction. Nullable with no SQL
  /// default — a pre-v3 row's `ADD COLUMN` backfills to `NULL`, never `0`
  /// (§4.3: "not recorded" is not "zero").
  final Decimal? openFee;
  final Decimal? closeFee;

  /// SQL-level default so a pre-v3 row's `ADD COLUMN` backfills existing
  /// legs to `true`, matching `Leg.acceptsAssignment`'s `@Default(true)`.
  final bool acceptsAssignment;
  const LegRow({
    required this.id,
    required this.cycleId,
    required this.sequence,
    required this.optionType,
    required this.strike,
    required this.expirationMs,
    required this.contracts,
    required this.openedAtMs,
    required this.openCreditPerShare,
    this.closedAtMs,
    this.closeDebitPerShare,
    this.closeReason,
    this.rolledFromLegId,
    required this.ruleProfileVersionId,
    this.ivAtOpen,
    this.ivRankAtOpen,
    this.deltaAtOpen,
    this.underlyingPriceAtOpen,
    this.openFee,
    this.closeFee,
    required this.acceptsAssignment,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['cycle_id'] = Variable<String>(cycleId);
    map['sequence'] = Variable<int>(sequence);
    {
      map['option_type'] = Variable<String>(
        $LegTableTable.$converteroptionType.toSql(optionType),
      );
    }
    {
      map['strike'] = Variable<int>(
        $LegTableTable.$converterstrike.toSql(strike),
      );
    }
    {
      map['expiration_ms'] = Variable<int>(
        $LegTableTable.$converterexpirationMs.toSql(expirationMs),
      );
    }
    map['contracts'] = Variable<int>(contracts);
    {
      map['opened_at_ms'] = Variable<int>(
        $LegTableTable.$converteropenedAtMs.toSql(openedAtMs),
      );
    }
    {
      map['open_credit_per_share'] = Variable<int>(
        $LegTableTable.$converteropenCreditPerShare.toSql(openCreditPerShare),
      );
    }
    if (!nullToAbsent || closedAtMs != null) {
      map['closed_at_ms'] = Variable<int>(
        $LegTableTable.$converterclosedAtMs.toSql(closedAtMs),
      );
    }
    if (!nullToAbsent || closeDebitPerShare != null) {
      map['close_debit_per_share'] = Variable<int>(
        $LegTableTable.$convertercloseDebitPerShare.toSql(closeDebitPerShare),
      );
    }
    if (!nullToAbsent || closeReason != null) {
      map['close_reason'] = Variable<String>(
        $LegTableTable.$convertercloseReason.toSql(closeReason),
      );
    }
    if (!nullToAbsent || rolledFromLegId != null) {
      map['rolled_from_leg_id'] = Variable<String>(rolledFromLegId);
    }
    map['rule_profile_version_id'] = Variable<String>(ruleProfileVersionId);
    if (!nullToAbsent || ivAtOpen != null) {
      map['iv_at_open'] = Variable<double>(ivAtOpen);
    }
    if (!nullToAbsent || ivRankAtOpen != null) {
      map['iv_rank_at_open'] = Variable<double>(ivRankAtOpen);
    }
    if (!nullToAbsent || deltaAtOpen != null) {
      map['delta_at_open'] = Variable<double>(deltaAtOpen);
    }
    if (!nullToAbsent || underlyingPriceAtOpen != null) {
      map['underlying_price_at_open'] = Variable<int>(
        $LegTableTable.$converterunderlyingPriceAtOpen.toSql(
          underlyingPriceAtOpen,
        ),
      );
    }
    if (!nullToAbsent || openFee != null) {
      map['open_fee'] = Variable<int>(
        $LegTableTable.$converteropenFee.toSql(openFee),
      );
    }
    if (!nullToAbsent || closeFee != null) {
      map['close_fee'] = Variable<int>(
        $LegTableTable.$convertercloseFee.toSql(closeFee),
      );
    }
    map['accepts_assignment'] = Variable<bool>(acceptsAssignment);
    return map;
  }

  LegTableCompanion toCompanion(bool nullToAbsent) {
    return LegTableCompanion(
      id: Value(id),
      cycleId: Value(cycleId),
      sequence: Value(sequence),
      optionType: Value(optionType),
      strike: Value(strike),
      expirationMs: Value(expirationMs),
      contracts: Value(contracts),
      openedAtMs: Value(openedAtMs),
      openCreditPerShare: Value(openCreditPerShare),
      closedAtMs: closedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(closedAtMs),
      closeDebitPerShare: closeDebitPerShare == null && nullToAbsent
          ? const Value.absent()
          : Value(closeDebitPerShare),
      closeReason: closeReason == null && nullToAbsent
          ? const Value.absent()
          : Value(closeReason),
      rolledFromLegId: rolledFromLegId == null && nullToAbsent
          ? const Value.absent()
          : Value(rolledFromLegId),
      ruleProfileVersionId: Value(ruleProfileVersionId),
      ivAtOpen: ivAtOpen == null && nullToAbsent
          ? const Value.absent()
          : Value(ivAtOpen),
      ivRankAtOpen: ivRankAtOpen == null && nullToAbsent
          ? const Value.absent()
          : Value(ivRankAtOpen),
      deltaAtOpen: deltaAtOpen == null && nullToAbsent
          ? const Value.absent()
          : Value(deltaAtOpen),
      underlyingPriceAtOpen: underlyingPriceAtOpen == null && nullToAbsent
          ? const Value.absent()
          : Value(underlyingPriceAtOpen),
      openFee: openFee == null && nullToAbsent
          ? const Value.absent()
          : Value(openFee),
      closeFee: closeFee == null && nullToAbsent
          ? const Value.absent()
          : Value(closeFee),
      acceptsAssignment: Value(acceptsAssignment),
    );
  }

  factory LegRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LegRow(
      id: serializer.fromJson<String>(json['id']),
      cycleId: serializer.fromJson<String>(json['cycleId']),
      sequence: serializer.fromJson<int>(json['sequence']),
      optionType: serializer.fromJson<OptionType>(json['optionType']),
      strike: serializer.fromJson<Decimal>(json['strike']),
      expirationMs: serializer.fromJson<DateTime>(json['expirationMs']),
      contracts: serializer.fromJson<int>(json['contracts']),
      openedAtMs: serializer.fromJson<DateTime>(json['openedAtMs']),
      openCreditPerShare: serializer.fromJson<Decimal>(
        json['openCreditPerShare'],
      ),
      closedAtMs: serializer.fromJson<DateTime?>(json['closedAtMs']),
      closeDebitPerShare: serializer.fromJson<Decimal?>(
        json['closeDebitPerShare'],
      ),
      closeReason: serializer.fromJson<CloseReason?>(json['closeReason']),
      rolledFromLegId: serializer.fromJson<String?>(json['rolledFromLegId']),
      ruleProfileVersionId: serializer.fromJson<String>(
        json['ruleProfileVersionId'],
      ),
      ivAtOpen: serializer.fromJson<double?>(json['ivAtOpen']),
      ivRankAtOpen: serializer.fromJson<double?>(json['ivRankAtOpen']),
      deltaAtOpen: serializer.fromJson<double?>(json['deltaAtOpen']),
      underlyingPriceAtOpen: serializer.fromJson<Decimal?>(
        json['underlyingPriceAtOpen'],
      ),
      openFee: serializer.fromJson<Decimal?>(json['openFee']),
      closeFee: serializer.fromJson<Decimal?>(json['closeFee']),
      acceptsAssignment: serializer.fromJson<bool>(json['acceptsAssignment']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'cycleId': serializer.toJson<String>(cycleId),
      'sequence': serializer.toJson<int>(sequence),
      'optionType': serializer.toJson<OptionType>(optionType),
      'strike': serializer.toJson<Decimal>(strike),
      'expirationMs': serializer.toJson<DateTime>(expirationMs),
      'contracts': serializer.toJson<int>(contracts),
      'openedAtMs': serializer.toJson<DateTime>(openedAtMs),
      'openCreditPerShare': serializer.toJson<Decimal>(openCreditPerShare),
      'closedAtMs': serializer.toJson<DateTime?>(closedAtMs),
      'closeDebitPerShare': serializer.toJson<Decimal?>(closeDebitPerShare),
      'closeReason': serializer.toJson<CloseReason?>(closeReason),
      'rolledFromLegId': serializer.toJson<String?>(rolledFromLegId),
      'ruleProfileVersionId': serializer.toJson<String>(ruleProfileVersionId),
      'ivAtOpen': serializer.toJson<double?>(ivAtOpen),
      'ivRankAtOpen': serializer.toJson<double?>(ivRankAtOpen),
      'deltaAtOpen': serializer.toJson<double?>(deltaAtOpen),
      'underlyingPriceAtOpen': serializer.toJson<Decimal?>(
        underlyingPriceAtOpen,
      ),
      'openFee': serializer.toJson<Decimal?>(openFee),
      'closeFee': serializer.toJson<Decimal?>(closeFee),
      'acceptsAssignment': serializer.toJson<bool>(acceptsAssignment),
    };
  }

  LegRow copyWith({
    String? id,
    String? cycleId,
    int? sequence,
    OptionType? optionType,
    Decimal? strike,
    DateTime? expirationMs,
    int? contracts,
    DateTime? openedAtMs,
    Decimal? openCreditPerShare,
    Value<DateTime?> closedAtMs = const Value.absent(),
    Value<Decimal?> closeDebitPerShare = const Value.absent(),
    Value<CloseReason?> closeReason = const Value.absent(),
    Value<String?> rolledFromLegId = const Value.absent(),
    String? ruleProfileVersionId,
    Value<double?> ivAtOpen = const Value.absent(),
    Value<double?> ivRankAtOpen = const Value.absent(),
    Value<double?> deltaAtOpen = const Value.absent(),
    Value<Decimal?> underlyingPriceAtOpen = const Value.absent(),
    Value<Decimal?> openFee = const Value.absent(),
    Value<Decimal?> closeFee = const Value.absent(),
    bool? acceptsAssignment,
  }) => LegRow(
    id: id ?? this.id,
    cycleId: cycleId ?? this.cycleId,
    sequence: sequence ?? this.sequence,
    optionType: optionType ?? this.optionType,
    strike: strike ?? this.strike,
    expirationMs: expirationMs ?? this.expirationMs,
    contracts: contracts ?? this.contracts,
    openedAtMs: openedAtMs ?? this.openedAtMs,
    openCreditPerShare: openCreditPerShare ?? this.openCreditPerShare,
    closedAtMs: closedAtMs.present ? closedAtMs.value : this.closedAtMs,
    closeDebitPerShare: closeDebitPerShare.present
        ? closeDebitPerShare.value
        : this.closeDebitPerShare,
    closeReason: closeReason.present ? closeReason.value : this.closeReason,
    rolledFromLegId: rolledFromLegId.present
        ? rolledFromLegId.value
        : this.rolledFromLegId,
    ruleProfileVersionId: ruleProfileVersionId ?? this.ruleProfileVersionId,
    ivAtOpen: ivAtOpen.present ? ivAtOpen.value : this.ivAtOpen,
    ivRankAtOpen: ivRankAtOpen.present ? ivRankAtOpen.value : this.ivRankAtOpen,
    deltaAtOpen: deltaAtOpen.present ? deltaAtOpen.value : this.deltaAtOpen,
    underlyingPriceAtOpen: underlyingPriceAtOpen.present
        ? underlyingPriceAtOpen.value
        : this.underlyingPriceAtOpen,
    openFee: openFee.present ? openFee.value : this.openFee,
    closeFee: closeFee.present ? closeFee.value : this.closeFee,
    acceptsAssignment: acceptsAssignment ?? this.acceptsAssignment,
  );
  LegRow copyWithCompanion(LegTableCompanion data) {
    return LegRow(
      id: data.id.present ? data.id.value : this.id,
      cycleId: data.cycleId.present ? data.cycleId.value : this.cycleId,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      optionType: data.optionType.present
          ? data.optionType.value
          : this.optionType,
      strike: data.strike.present ? data.strike.value : this.strike,
      expirationMs: data.expirationMs.present
          ? data.expirationMs.value
          : this.expirationMs,
      contracts: data.contracts.present ? data.contracts.value : this.contracts,
      openedAtMs: data.openedAtMs.present
          ? data.openedAtMs.value
          : this.openedAtMs,
      openCreditPerShare: data.openCreditPerShare.present
          ? data.openCreditPerShare.value
          : this.openCreditPerShare,
      closedAtMs: data.closedAtMs.present
          ? data.closedAtMs.value
          : this.closedAtMs,
      closeDebitPerShare: data.closeDebitPerShare.present
          ? data.closeDebitPerShare.value
          : this.closeDebitPerShare,
      closeReason: data.closeReason.present
          ? data.closeReason.value
          : this.closeReason,
      rolledFromLegId: data.rolledFromLegId.present
          ? data.rolledFromLegId.value
          : this.rolledFromLegId,
      ruleProfileVersionId: data.ruleProfileVersionId.present
          ? data.ruleProfileVersionId.value
          : this.ruleProfileVersionId,
      ivAtOpen: data.ivAtOpen.present ? data.ivAtOpen.value : this.ivAtOpen,
      ivRankAtOpen: data.ivRankAtOpen.present
          ? data.ivRankAtOpen.value
          : this.ivRankAtOpen,
      deltaAtOpen: data.deltaAtOpen.present
          ? data.deltaAtOpen.value
          : this.deltaAtOpen,
      underlyingPriceAtOpen: data.underlyingPriceAtOpen.present
          ? data.underlyingPriceAtOpen.value
          : this.underlyingPriceAtOpen,
      openFee: data.openFee.present ? data.openFee.value : this.openFee,
      closeFee: data.closeFee.present ? data.closeFee.value : this.closeFee,
      acceptsAssignment: data.acceptsAssignment.present
          ? data.acceptsAssignment.value
          : this.acceptsAssignment,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LegRow(')
          ..write('id: $id, ')
          ..write('cycleId: $cycleId, ')
          ..write('sequence: $sequence, ')
          ..write('optionType: $optionType, ')
          ..write('strike: $strike, ')
          ..write('expirationMs: $expirationMs, ')
          ..write('contracts: $contracts, ')
          ..write('openedAtMs: $openedAtMs, ')
          ..write('openCreditPerShare: $openCreditPerShare, ')
          ..write('closedAtMs: $closedAtMs, ')
          ..write('closeDebitPerShare: $closeDebitPerShare, ')
          ..write('closeReason: $closeReason, ')
          ..write('rolledFromLegId: $rolledFromLegId, ')
          ..write('ruleProfileVersionId: $ruleProfileVersionId, ')
          ..write('ivAtOpen: $ivAtOpen, ')
          ..write('ivRankAtOpen: $ivRankAtOpen, ')
          ..write('deltaAtOpen: $deltaAtOpen, ')
          ..write('underlyingPriceAtOpen: $underlyingPriceAtOpen, ')
          ..write('openFee: $openFee, ')
          ..write('closeFee: $closeFee, ')
          ..write('acceptsAssignment: $acceptsAssignment')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    cycleId,
    sequence,
    optionType,
    strike,
    expirationMs,
    contracts,
    openedAtMs,
    openCreditPerShare,
    closedAtMs,
    closeDebitPerShare,
    closeReason,
    rolledFromLegId,
    ruleProfileVersionId,
    ivAtOpen,
    ivRankAtOpen,
    deltaAtOpen,
    underlyingPriceAtOpen,
    openFee,
    closeFee,
    acceptsAssignment,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LegRow &&
          other.id == this.id &&
          other.cycleId == this.cycleId &&
          other.sequence == this.sequence &&
          other.optionType == this.optionType &&
          other.strike == this.strike &&
          other.expirationMs == this.expirationMs &&
          other.contracts == this.contracts &&
          other.openedAtMs == this.openedAtMs &&
          other.openCreditPerShare == this.openCreditPerShare &&
          other.closedAtMs == this.closedAtMs &&
          other.closeDebitPerShare == this.closeDebitPerShare &&
          other.closeReason == this.closeReason &&
          other.rolledFromLegId == this.rolledFromLegId &&
          other.ruleProfileVersionId == this.ruleProfileVersionId &&
          other.ivAtOpen == this.ivAtOpen &&
          other.ivRankAtOpen == this.ivRankAtOpen &&
          other.deltaAtOpen == this.deltaAtOpen &&
          other.underlyingPriceAtOpen == this.underlyingPriceAtOpen &&
          other.openFee == this.openFee &&
          other.closeFee == this.closeFee &&
          other.acceptsAssignment == this.acceptsAssignment);
}

class LegTableCompanion extends UpdateCompanion<LegRow> {
  final Value<String> id;
  final Value<String> cycleId;
  final Value<int> sequence;
  final Value<OptionType> optionType;
  final Value<Decimal> strike;
  final Value<DateTime> expirationMs;
  final Value<int> contracts;
  final Value<DateTime> openedAtMs;
  final Value<Decimal> openCreditPerShare;
  final Value<DateTime?> closedAtMs;
  final Value<Decimal?> closeDebitPerShare;
  final Value<CloseReason?> closeReason;
  final Value<String?> rolledFromLegId;
  final Value<String> ruleProfileVersionId;
  final Value<double?> ivAtOpen;
  final Value<double?> ivRankAtOpen;
  final Value<double?> deltaAtOpen;
  final Value<Decimal?> underlyingPriceAtOpen;
  final Value<Decimal?> openFee;
  final Value<Decimal?> closeFee;
  final Value<bool> acceptsAssignment;
  final Value<int> rowid;
  const LegTableCompanion({
    this.id = const Value.absent(),
    this.cycleId = const Value.absent(),
    this.sequence = const Value.absent(),
    this.optionType = const Value.absent(),
    this.strike = const Value.absent(),
    this.expirationMs = const Value.absent(),
    this.contracts = const Value.absent(),
    this.openedAtMs = const Value.absent(),
    this.openCreditPerShare = const Value.absent(),
    this.closedAtMs = const Value.absent(),
    this.closeDebitPerShare = const Value.absent(),
    this.closeReason = const Value.absent(),
    this.rolledFromLegId = const Value.absent(),
    this.ruleProfileVersionId = const Value.absent(),
    this.ivAtOpen = const Value.absent(),
    this.ivRankAtOpen = const Value.absent(),
    this.deltaAtOpen = const Value.absent(),
    this.underlyingPriceAtOpen = const Value.absent(),
    this.openFee = const Value.absent(),
    this.closeFee = const Value.absent(),
    this.acceptsAssignment = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LegTableCompanion.insert({
    required String id,
    required String cycleId,
    required int sequence,
    required OptionType optionType,
    required Decimal strike,
    required DateTime expirationMs,
    required int contracts,
    required DateTime openedAtMs,
    required Decimal openCreditPerShare,
    this.closedAtMs = const Value.absent(),
    this.closeDebitPerShare = const Value.absent(),
    this.closeReason = const Value.absent(),
    this.rolledFromLegId = const Value.absent(),
    required String ruleProfileVersionId,
    this.ivAtOpen = const Value.absent(),
    this.ivRankAtOpen = const Value.absent(),
    this.deltaAtOpen = const Value.absent(),
    this.underlyingPriceAtOpen = const Value.absent(),
    this.openFee = const Value.absent(),
    this.closeFee = const Value.absent(),
    this.acceptsAssignment = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       cycleId = Value(cycleId),
       sequence = Value(sequence),
       optionType = Value(optionType),
       strike = Value(strike),
       expirationMs = Value(expirationMs),
       contracts = Value(contracts),
       openedAtMs = Value(openedAtMs),
       openCreditPerShare = Value(openCreditPerShare),
       ruleProfileVersionId = Value(ruleProfileVersionId);
  static Insertable<LegRow> custom({
    Expression<String>? id,
    Expression<String>? cycleId,
    Expression<int>? sequence,
    Expression<String>? optionType,
    Expression<int>? strike,
    Expression<int>? expirationMs,
    Expression<int>? contracts,
    Expression<int>? openedAtMs,
    Expression<int>? openCreditPerShare,
    Expression<int>? closedAtMs,
    Expression<int>? closeDebitPerShare,
    Expression<String>? closeReason,
    Expression<String>? rolledFromLegId,
    Expression<String>? ruleProfileVersionId,
    Expression<double>? ivAtOpen,
    Expression<double>? ivRankAtOpen,
    Expression<double>? deltaAtOpen,
    Expression<int>? underlyingPriceAtOpen,
    Expression<int>? openFee,
    Expression<int>? closeFee,
    Expression<bool>? acceptsAssignment,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cycleId != null) 'cycle_id': cycleId,
      if (sequence != null) 'sequence': sequence,
      if (optionType != null) 'option_type': optionType,
      if (strike != null) 'strike': strike,
      if (expirationMs != null) 'expiration_ms': expirationMs,
      if (contracts != null) 'contracts': contracts,
      if (openedAtMs != null) 'opened_at_ms': openedAtMs,
      if (openCreditPerShare != null)
        'open_credit_per_share': openCreditPerShare,
      if (closedAtMs != null) 'closed_at_ms': closedAtMs,
      if (closeDebitPerShare != null)
        'close_debit_per_share': closeDebitPerShare,
      if (closeReason != null) 'close_reason': closeReason,
      if (rolledFromLegId != null) 'rolled_from_leg_id': rolledFromLegId,
      if (ruleProfileVersionId != null)
        'rule_profile_version_id': ruleProfileVersionId,
      if (ivAtOpen != null) 'iv_at_open': ivAtOpen,
      if (ivRankAtOpen != null) 'iv_rank_at_open': ivRankAtOpen,
      if (deltaAtOpen != null) 'delta_at_open': deltaAtOpen,
      if (underlyingPriceAtOpen != null)
        'underlying_price_at_open': underlyingPriceAtOpen,
      if (openFee != null) 'open_fee': openFee,
      if (closeFee != null) 'close_fee': closeFee,
      if (acceptsAssignment != null) 'accepts_assignment': acceptsAssignment,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LegTableCompanion copyWith({
    Value<String>? id,
    Value<String>? cycleId,
    Value<int>? sequence,
    Value<OptionType>? optionType,
    Value<Decimal>? strike,
    Value<DateTime>? expirationMs,
    Value<int>? contracts,
    Value<DateTime>? openedAtMs,
    Value<Decimal>? openCreditPerShare,
    Value<DateTime?>? closedAtMs,
    Value<Decimal?>? closeDebitPerShare,
    Value<CloseReason?>? closeReason,
    Value<String?>? rolledFromLegId,
    Value<String>? ruleProfileVersionId,
    Value<double?>? ivAtOpen,
    Value<double?>? ivRankAtOpen,
    Value<double?>? deltaAtOpen,
    Value<Decimal?>? underlyingPriceAtOpen,
    Value<Decimal?>? openFee,
    Value<Decimal?>? closeFee,
    Value<bool>? acceptsAssignment,
    Value<int>? rowid,
  }) {
    return LegTableCompanion(
      id: id ?? this.id,
      cycleId: cycleId ?? this.cycleId,
      sequence: sequence ?? this.sequence,
      optionType: optionType ?? this.optionType,
      strike: strike ?? this.strike,
      expirationMs: expirationMs ?? this.expirationMs,
      contracts: contracts ?? this.contracts,
      openedAtMs: openedAtMs ?? this.openedAtMs,
      openCreditPerShare: openCreditPerShare ?? this.openCreditPerShare,
      closedAtMs: closedAtMs ?? this.closedAtMs,
      closeDebitPerShare: closeDebitPerShare ?? this.closeDebitPerShare,
      closeReason: closeReason ?? this.closeReason,
      rolledFromLegId: rolledFromLegId ?? this.rolledFromLegId,
      ruleProfileVersionId: ruleProfileVersionId ?? this.ruleProfileVersionId,
      ivAtOpen: ivAtOpen ?? this.ivAtOpen,
      ivRankAtOpen: ivRankAtOpen ?? this.ivRankAtOpen,
      deltaAtOpen: deltaAtOpen ?? this.deltaAtOpen,
      underlyingPriceAtOpen:
          underlyingPriceAtOpen ?? this.underlyingPriceAtOpen,
      openFee: openFee ?? this.openFee,
      closeFee: closeFee ?? this.closeFee,
      acceptsAssignment: acceptsAssignment ?? this.acceptsAssignment,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (cycleId.present) {
      map['cycle_id'] = Variable<String>(cycleId.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (optionType.present) {
      map['option_type'] = Variable<String>(
        $LegTableTable.$converteroptionType.toSql(optionType.value),
      );
    }
    if (strike.present) {
      map['strike'] = Variable<int>(
        $LegTableTable.$converterstrike.toSql(strike.value),
      );
    }
    if (expirationMs.present) {
      map['expiration_ms'] = Variable<int>(
        $LegTableTable.$converterexpirationMs.toSql(expirationMs.value),
      );
    }
    if (contracts.present) {
      map['contracts'] = Variable<int>(contracts.value);
    }
    if (openedAtMs.present) {
      map['opened_at_ms'] = Variable<int>(
        $LegTableTable.$converteropenedAtMs.toSql(openedAtMs.value),
      );
    }
    if (openCreditPerShare.present) {
      map['open_credit_per_share'] = Variable<int>(
        $LegTableTable.$converteropenCreditPerShare.toSql(
          openCreditPerShare.value,
        ),
      );
    }
    if (closedAtMs.present) {
      map['closed_at_ms'] = Variable<int>(
        $LegTableTable.$converterclosedAtMs.toSql(closedAtMs.value),
      );
    }
    if (closeDebitPerShare.present) {
      map['close_debit_per_share'] = Variable<int>(
        $LegTableTable.$convertercloseDebitPerShare.toSql(
          closeDebitPerShare.value,
        ),
      );
    }
    if (closeReason.present) {
      map['close_reason'] = Variable<String>(
        $LegTableTable.$convertercloseReason.toSql(closeReason.value),
      );
    }
    if (rolledFromLegId.present) {
      map['rolled_from_leg_id'] = Variable<String>(rolledFromLegId.value);
    }
    if (ruleProfileVersionId.present) {
      map['rule_profile_version_id'] = Variable<String>(
        ruleProfileVersionId.value,
      );
    }
    if (ivAtOpen.present) {
      map['iv_at_open'] = Variable<double>(ivAtOpen.value);
    }
    if (ivRankAtOpen.present) {
      map['iv_rank_at_open'] = Variable<double>(ivRankAtOpen.value);
    }
    if (deltaAtOpen.present) {
      map['delta_at_open'] = Variable<double>(deltaAtOpen.value);
    }
    if (underlyingPriceAtOpen.present) {
      map['underlying_price_at_open'] = Variable<int>(
        $LegTableTable.$converterunderlyingPriceAtOpen.toSql(
          underlyingPriceAtOpen.value,
        ),
      );
    }
    if (openFee.present) {
      map['open_fee'] = Variable<int>(
        $LegTableTable.$converteropenFee.toSql(openFee.value),
      );
    }
    if (closeFee.present) {
      map['close_fee'] = Variable<int>(
        $LegTableTable.$convertercloseFee.toSql(closeFee.value),
      );
    }
    if (acceptsAssignment.present) {
      map['accepts_assignment'] = Variable<bool>(acceptsAssignment.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LegTableCompanion(')
          ..write('id: $id, ')
          ..write('cycleId: $cycleId, ')
          ..write('sequence: $sequence, ')
          ..write('optionType: $optionType, ')
          ..write('strike: $strike, ')
          ..write('expirationMs: $expirationMs, ')
          ..write('contracts: $contracts, ')
          ..write('openedAtMs: $openedAtMs, ')
          ..write('openCreditPerShare: $openCreditPerShare, ')
          ..write('closedAtMs: $closedAtMs, ')
          ..write('closeDebitPerShare: $closeDebitPerShare, ')
          ..write('closeReason: $closeReason, ')
          ..write('rolledFromLegId: $rolledFromLegId, ')
          ..write('ruleProfileVersionId: $ruleProfileVersionId, ')
          ..write('ivAtOpen: $ivAtOpen, ')
          ..write('ivRankAtOpen: $ivRankAtOpen, ')
          ..write('deltaAtOpen: $deltaAtOpen, ')
          ..write('underlyingPriceAtOpen: $underlyingPriceAtOpen, ')
          ..write('openFee: $openFee, ')
          ..write('closeFee: $closeFee, ')
          ..write('acceptsAssignment: $acceptsAssignment, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SnapshotTableTable extends SnapshotTable
    with TableInfo<$SnapshotTableTable, SnapshotRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SnapshotTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _legIdMeta = const VerificationMeta('legId');
  @override
  late final GeneratedColumn<String> legId = GeneratedColumn<String>(
    'leg_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> takenAtMs =
      GeneratedColumn<int>(
        'taken_at_ms',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($SnapshotTableTable.$convertertakenAtMs);
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, int> optionMark =
      GeneratedColumn<int>(
        'option_mark',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<Decimal>($SnapshotTableTable.$converteroptionMark);
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, int> underlyingPrice =
      GeneratedColumn<int>(
        'underlying_price',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<Decimal>($SnapshotTableTable.$converterunderlyingPrice);
  static const VerificationMeta _deltaAsEnteredMeta = const VerificationMeta(
    'deltaAsEntered',
  );
  @override
  late final GeneratedColumn<double> deltaAsEntered = GeneratedColumn<double>(
    'delta_as_entered',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DeltaConvention, String>
  deltaConvention =
      GeneratedColumn<String>(
        'delta_convention',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DeltaConvention>(
        $SnapshotTableTable.$converterdeltaConvention,
      );
  static const VerificationMeta _gammaMeta = const VerificationMeta('gamma');
  @override
  late final GeneratedColumn<double> gamma = GeneratedColumn<double>(
    'gamma',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thetaMeta = const VerificationMeta('theta');
  @override
  late final GeneratedColumn<double> theta = GeneratedColumn<double>(
    'theta',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vegaMeta = const VerificationMeta('vega');
  @override
  late final GeneratedColumn<double> vega = GeneratedColumn<double>(
    'vega',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ivMeta = const VerificationMeta('iv');
  @override
  late final GeneratedColumn<double> iv = GeneratedColumn<double>(
    'iv',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _openInterestMeta = const VerificationMeta(
    'openInterest',
  );
  @override
  late final GeneratedColumn<int> openInterest = GeneratedColumn<int>(
    'open_interest',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _volumeMeta = const VerificationMeta('volume');
  @override
  late final GeneratedColumn<int> volume = GeneratedColumn<int>(
    'volume',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    legId,
    takenAtMs,
    optionMark,
    underlyingPrice,
    deltaAsEntered,
    deltaConvention,
    gamma,
    theta,
    vega,
    iv,
    openInterest,
    volume,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'snapshot';
  @override
  VerificationContext validateIntegrity(
    Insertable<SnapshotRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('leg_id')) {
      context.handle(
        _legIdMeta,
        legId.isAcceptableOrUnknown(data['leg_id']!, _legIdMeta),
      );
    } else if (isInserting) {
      context.missing(_legIdMeta);
    }
    if (data.containsKey('delta_as_entered')) {
      context.handle(
        _deltaAsEnteredMeta,
        deltaAsEntered.isAcceptableOrUnknown(
          data['delta_as_entered']!,
          _deltaAsEnteredMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_deltaAsEnteredMeta);
    }
    if (data.containsKey('gamma')) {
      context.handle(
        _gammaMeta,
        gamma.isAcceptableOrUnknown(data['gamma']!, _gammaMeta),
      );
    }
    if (data.containsKey('theta')) {
      context.handle(
        _thetaMeta,
        theta.isAcceptableOrUnknown(data['theta']!, _thetaMeta),
      );
    }
    if (data.containsKey('vega')) {
      context.handle(
        _vegaMeta,
        vega.isAcceptableOrUnknown(data['vega']!, _vegaMeta),
      );
    }
    if (data.containsKey('iv')) {
      context.handle(_ivMeta, iv.isAcceptableOrUnknown(data['iv']!, _ivMeta));
    }
    if (data.containsKey('open_interest')) {
      context.handle(
        _openInterestMeta,
        openInterest.isAcceptableOrUnknown(
          data['open_interest']!,
          _openInterestMeta,
        ),
      );
    }
    if (data.containsKey('volume')) {
      context.handle(
        _volumeMeta,
        volume.isAcceptableOrUnknown(data['volume']!, _volumeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SnapshotRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SnapshotRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      legId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}leg_id'],
      )!,
      takenAtMs: $SnapshotTableTable.$convertertakenAtMs.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}taken_at_ms'],
        )!,
      ),
      optionMark: $SnapshotTableTable.$converteroptionMark.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}option_mark'],
        )!,
      ),
      underlyingPrice: $SnapshotTableTable.$converterunderlyingPrice.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}underlying_price'],
        )!,
      ),
      deltaAsEntered: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}delta_as_entered'],
      )!,
      deltaConvention: $SnapshotTableTable.$converterdeltaConvention.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}delta_convention'],
        )!,
      ),
      gamma: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}gamma'],
      ),
      theta: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}theta'],
      ),
      vega: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}vega'],
      ),
      iv: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}iv'],
      ),
      openInterest: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}open_interest'],
      ),
      volume: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}volume'],
      ),
    );
  }

  @override
  $SnapshotTableTable createAlias(String alias) {
    return $SnapshotTableTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertertakenAtMs =
      const DateTimeMsConverter();
  static TypeConverter<Decimal, int> $converteroptionMark =
      const TenThousandthsConverter();
  static TypeConverter<Decimal, int> $converterunderlyingPrice =
      const CentsConverter();
  static TypeConverter<DeltaConvention, String> $converterdeltaConvention =
      const DeltaConventionConverter();
}

class SnapshotRow extends DataClass implements Insertable<SnapshotRow> {
  final String id;
  final String legId;
  final DateTime takenAtMs;
  final Decimal optionMark;
  final Decimal underlyingPrice;
  final double deltaAsEntered;
  final DeltaConvention deltaConvention;
  final double? gamma;
  final double? theta;
  final double? vega;
  final double? iv;
  final int? openInterest;
  final int? volume;
  const SnapshotRow({
    required this.id,
    required this.legId,
    required this.takenAtMs,
    required this.optionMark,
    required this.underlyingPrice,
    required this.deltaAsEntered,
    required this.deltaConvention,
    this.gamma,
    this.theta,
    this.vega,
    this.iv,
    this.openInterest,
    this.volume,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['leg_id'] = Variable<String>(legId);
    {
      map['taken_at_ms'] = Variable<int>(
        $SnapshotTableTable.$convertertakenAtMs.toSql(takenAtMs),
      );
    }
    {
      map['option_mark'] = Variable<int>(
        $SnapshotTableTable.$converteroptionMark.toSql(optionMark),
      );
    }
    {
      map['underlying_price'] = Variable<int>(
        $SnapshotTableTable.$converterunderlyingPrice.toSql(underlyingPrice),
      );
    }
    map['delta_as_entered'] = Variable<double>(deltaAsEntered);
    {
      map['delta_convention'] = Variable<String>(
        $SnapshotTableTable.$converterdeltaConvention.toSql(deltaConvention),
      );
    }
    if (!nullToAbsent || gamma != null) {
      map['gamma'] = Variable<double>(gamma);
    }
    if (!nullToAbsent || theta != null) {
      map['theta'] = Variable<double>(theta);
    }
    if (!nullToAbsent || vega != null) {
      map['vega'] = Variable<double>(vega);
    }
    if (!nullToAbsent || iv != null) {
      map['iv'] = Variable<double>(iv);
    }
    if (!nullToAbsent || openInterest != null) {
      map['open_interest'] = Variable<int>(openInterest);
    }
    if (!nullToAbsent || volume != null) {
      map['volume'] = Variable<int>(volume);
    }
    return map;
  }

  SnapshotTableCompanion toCompanion(bool nullToAbsent) {
    return SnapshotTableCompanion(
      id: Value(id),
      legId: Value(legId),
      takenAtMs: Value(takenAtMs),
      optionMark: Value(optionMark),
      underlyingPrice: Value(underlyingPrice),
      deltaAsEntered: Value(deltaAsEntered),
      deltaConvention: Value(deltaConvention),
      gamma: gamma == null && nullToAbsent
          ? const Value.absent()
          : Value(gamma),
      theta: theta == null && nullToAbsent
          ? const Value.absent()
          : Value(theta),
      vega: vega == null && nullToAbsent ? const Value.absent() : Value(vega),
      iv: iv == null && nullToAbsent ? const Value.absent() : Value(iv),
      openInterest: openInterest == null && nullToAbsent
          ? const Value.absent()
          : Value(openInterest),
      volume: volume == null && nullToAbsent
          ? const Value.absent()
          : Value(volume),
    );
  }

  factory SnapshotRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SnapshotRow(
      id: serializer.fromJson<String>(json['id']),
      legId: serializer.fromJson<String>(json['legId']),
      takenAtMs: serializer.fromJson<DateTime>(json['takenAtMs']),
      optionMark: serializer.fromJson<Decimal>(json['optionMark']),
      underlyingPrice: serializer.fromJson<Decimal>(json['underlyingPrice']),
      deltaAsEntered: serializer.fromJson<double>(json['deltaAsEntered']),
      deltaConvention: serializer.fromJson<DeltaConvention>(
        json['deltaConvention'],
      ),
      gamma: serializer.fromJson<double?>(json['gamma']),
      theta: serializer.fromJson<double?>(json['theta']),
      vega: serializer.fromJson<double?>(json['vega']),
      iv: serializer.fromJson<double?>(json['iv']),
      openInterest: serializer.fromJson<int?>(json['openInterest']),
      volume: serializer.fromJson<int?>(json['volume']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'legId': serializer.toJson<String>(legId),
      'takenAtMs': serializer.toJson<DateTime>(takenAtMs),
      'optionMark': serializer.toJson<Decimal>(optionMark),
      'underlyingPrice': serializer.toJson<Decimal>(underlyingPrice),
      'deltaAsEntered': serializer.toJson<double>(deltaAsEntered),
      'deltaConvention': serializer.toJson<DeltaConvention>(deltaConvention),
      'gamma': serializer.toJson<double?>(gamma),
      'theta': serializer.toJson<double?>(theta),
      'vega': serializer.toJson<double?>(vega),
      'iv': serializer.toJson<double?>(iv),
      'openInterest': serializer.toJson<int?>(openInterest),
      'volume': serializer.toJson<int?>(volume),
    };
  }

  SnapshotRow copyWith({
    String? id,
    String? legId,
    DateTime? takenAtMs,
    Decimal? optionMark,
    Decimal? underlyingPrice,
    double? deltaAsEntered,
    DeltaConvention? deltaConvention,
    Value<double?> gamma = const Value.absent(),
    Value<double?> theta = const Value.absent(),
    Value<double?> vega = const Value.absent(),
    Value<double?> iv = const Value.absent(),
    Value<int?> openInterest = const Value.absent(),
    Value<int?> volume = const Value.absent(),
  }) => SnapshotRow(
    id: id ?? this.id,
    legId: legId ?? this.legId,
    takenAtMs: takenAtMs ?? this.takenAtMs,
    optionMark: optionMark ?? this.optionMark,
    underlyingPrice: underlyingPrice ?? this.underlyingPrice,
    deltaAsEntered: deltaAsEntered ?? this.deltaAsEntered,
    deltaConvention: deltaConvention ?? this.deltaConvention,
    gamma: gamma.present ? gamma.value : this.gamma,
    theta: theta.present ? theta.value : this.theta,
    vega: vega.present ? vega.value : this.vega,
    iv: iv.present ? iv.value : this.iv,
    openInterest: openInterest.present ? openInterest.value : this.openInterest,
    volume: volume.present ? volume.value : this.volume,
  );
  SnapshotRow copyWithCompanion(SnapshotTableCompanion data) {
    return SnapshotRow(
      id: data.id.present ? data.id.value : this.id,
      legId: data.legId.present ? data.legId.value : this.legId,
      takenAtMs: data.takenAtMs.present ? data.takenAtMs.value : this.takenAtMs,
      optionMark: data.optionMark.present
          ? data.optionMark.value
          : this.optionMark,
      underlyingPrice: data.underlyingPrice.present
          ? data.underlyingPrice.value
          : this.underlyingPrice,
      deltaAsEntered: data.deltaAsEntered.present
          ? data.deltaAsEntered.value
          : this.deltaAsEntered,
      deltaConvention: data.deltaConvention.present
          ? data.deltaConvention.value
          : this.deltaConvention,
      gamma: data.gamma.present ? data.gamma.value : this.gamma,
      theta: data.theta.present ? data.theta.value : this.theta,
      vega: data.vega.present ? data.vega.value : this.vega,
      iv: data.iv.present ? data.iv.value : this.iv,
      openInterest: data.openInterest.present
          ? data.openInterest.value
          : this.openInterest,
      volume: data.volume.present ? data.volume.value : this.volume,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SnapshotRow(')
          ..write('id: $id, ')
          ..write('legId: $legId, ')
          ..write('takenAtMs: $takenAtMs, ')
          ..write('optionMark: $optionMark, ')
          ..write('underlyingPrice: $underlyingPrice, ')
          ..write('deltaAsEntered: $deltaAsEntered, ')
          ..write('deltaConvention: $deltaConvention, ')
          ..write('gamma: $gamma, ')
          ..write('theta: $theta, ')
          ..write('vega: $vega, ')
          ..write('iv: $iv, ')
          ..write('openInterest: $openInterest, ')
          ..write('volume: $volume')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    legId,
    takenAtMs,
    optionMark,
    underlyingPrice,
    deltaAsEntered,
    deltaConvention,
    gamma,
    theta,
    vega,
    iv,
    openInterest,
    volume,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SnapshotRow &&
          other.id == this.id &&
          other.legId == this.legId &&
          other.takenAtMs == this.takenAtMs &&
          other.optionMark == this.optionMark &&
          other.underlyingPrice == this.underlyingPrice &&
          other.deltaAsEntered == this.deltaAsEntered &&
          other.deltaConvention == this.deltaConvention &&
          other.gamma == this.gamma &&
          other.theta == this.theta &&
          other.vega == this.vega &&
          other.iv == this.iv &&
          other.openInterest == this.openInterest &&
          other.volume == this.volume);
}

class SnapshotTableCompanion extends UpdateCompanion<SnapshotRow> {
  final Value<String> id;
  final Value<String> legId;
  final Value<DateTime> takenAtMs;
  final Value<Decimal> optionMark;
  final Value<Decimal> underlyingPrice;
  final Value<double> deltaAsEntered;
  final Value<DeltaConvention> deltaConvention;
  final Value<double?> gamma;
  final Value<double?> theta;
  final Value<double?> vega;
  final Value<double?> iv;
  final Value<int?> openInterest;
  final Value<int?> volume;
  final Value<int> rowid;
  const SnapshotTableCompanion({
    this.id = const Value.absent(),
    this.legId = const Value.absent(),
    this.takenAtMs = const Value.absent(),
    this.optionMark = const Value.absent(),
    this.underlyingPrice = const Value.absent(),
    this.deltaAsEntered = const Value.absent(),
    this.deltaConvention = const Value.absent(),
    this.gamma = const Value.absent(),
    this.theta = const Value.absent(),
    this.vega = const Value.absent(),
    this.iv = const Value.absent(),
    this.openInterest = const Value.absent(),
    this.volume = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SnapshotTableCompanion.insert({
    required String id,
    required String legId,
    required DateTime takenAtMs,
    required Decimal optionMark,
    required Decimal underlyingPrice,
    required double deltaAsEntered,
    required DeltaConvention deltaConvention,
    this.gamma = const Value.absent(),
    this.theta = const Value.absent(),
    this.vega = const Value.absent(),
    this.iv = const Value.absent(),
    this.openInterest = const Value.absent(),
    this.volume = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       legId = Value(legId),
       takenAtMs = Value(takenAtMs),
       optionMark = Value(optionMark),
       underlyingPrice = Value(underlyingPrice),
       deltaAsEntered = Value(deltaAsEntered),
       deltaConvention = Value(deltaConvention);
  static Insertable<SnapshotRow> custom({
    Expression<String>? id,
    Expression<String>? legId,
    Expression<int>? takenAtMs,
    Expression<int>? optionMark,
    Expression<int>? underlyingPrice,
    Expression<double>? deltaAsEntered,
    Expression<String>? deltaConvention,
    Expression<double>? gamma,
    Expression<double>? theta,
    Expression<double>? vega,
    Expression<double>? iv,
    Expression<int>? openInterest,
    Expression<int>? volume,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (legId != null) 'leg_id': legId,
      if (takenAtMs != null) 'taken_at_ms': takenAtMs,
      if (optionMark != null) 'option_mark': optionMark,
      if (underlyingPrice != null) 'underlying_price': underlyingPrice,
      if (deltaAsEntered != null) 'delta_as_entered': deltaAsEntered,
      if (deltaConvention != null) 'delta_convention': deltaConvention,
      if (gamma != null) 'gamma': gamma,
      if (theta != null) 'theta': theta,
      if (vega != null) 'vega': vega,
      if (iv != null) 'iv': iv,
      if (openInterest != null) 'open_interest': openInterest,
      if (volume != null) 'volume': volume,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SnapshotTableCompanion copyWith({
    Value<String>? id,
    Value<String>? legId,
    Value<DateTime>? takenAtMs,
    Value<Decimal>? optionMark,
    Value<Decimal>? underlyingPrice,
    Value<double>? deltaAsEntered,
    Value<DeltaConvention>? deltaConvention,
    Value<double?>? gamma,
    Value<double?>? theta,
    Value<double?>? vega,
    Value<double?>? iv,
    Value<int?>? openInterest,
    Value<int?>? volume,
    Value<int>? rowid,
  }) {
    return SnapshotTableCompanion(
      id: id ?? this.id,
      legId: legId ?? this.legId,
      takenAtMs: takenAtMs ?? this.takenAtMs,
      optionMark: optionMark ?? this.optionMark,
      underlyingPrice: underlyingPrice ?? this.underlyingPrice,
      deltaAsEntered: deltaAsEntered ?? this.deltaAsEntered,
      deltaConvention: deltaConvention ?? this.deltaConvention,
      gamma: gamma ?? this.gamma,
      theta: theta ?? this.theta,
      vega: vega ?? this.vega,
      iv: iv ?? this.iv,
      openInterest: openInterest ?? this.openInterest,
      volume: volume ?? this.volume,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (legId.present) {
      map['leg_id'] = Variable<String>(legId.value);
    }
    if (takenAtMs.present) {
      map['taken_at_ms'] = Variable<int>(
        $SnapshotTableTable.$convertertakenAtMs.toSql(takenAtMs.value),
      );
    }
    if (optionMark.present) {
      map['option_mark'] = Variable<int>(
        $SnapshotTableTable.$converteroptionMark.toSql(optionMark.value),
      );
    }
    if (underlyingPrice.present) {
      map['underlying_price'] = Variable<int>(
        $SnapshotTableTable.$converterunderlyingPrice.toSql(
          underlyingPrice.value,
        ),
      );
    }
    if (deltaAsEntered.present) {
      map['delta_as_entered'] = Variable<double>(deltaAsEntered.value);
    }
    if (deltaConvention.present) {
      map['delta_convention'] = Variable<String>(
        $SnapshotTableTable.$converterdeltaConvention.toSql(
          deltaConvention.value,
        ),
      );
    }
    if (gamma.present) {
      map['gamma'] = Variable<double>(gamma.value);
    }
    if (theta.present) {
      map['theta'] = Variable<double>(theta.value);
    }
    if (vega.present) {
      map['vega'] = Variable<double>(vega.value);
    }
    if (iv.present) {
      map['iv'] = Variable<double>(iv.value);
    }
    if (openInterest.present) {
      map['open_interest'] = Variable<int>(openInterest.value);
    }
    if (volume.present) {
      map['volume'] = Variable<int>(volume.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SnapshotTableCompanion(')
          ..write('id: $id, ')
          ..write('legId: $legId, ')
          ..write('takenAtMs: $takenAtMs, ')
          ..write('optionMark: $optionMark, ')
          ..write('underlyingPrice: $underlyingPrice, ')
          ..write('deltaAsEntered: $deltaAsEntered, ')
          ..write('deltaConvention: $deltaConvention, ')
          ..write('gamma: $gamma, ')
          ..write('theta: $theta, ')
          ..write('vega: $vega, ')
          ..write('iv: $iv, ')
          ..write('openInterest: $openInterest, ')
          ..write('volume: $volume, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ShareLotTableTable extends ShareLotTable
    with TableInfo<$ShareLotTableTable, ShareLotRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShareLotTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cycleIdMeta = const VerificationMeta(
    'cycleId',
  );
  @override
  late final GeneratedColumn<String> cycleId = GeneratedColumn<String>(
    'cycle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> assignedAtMs =
      GeneratedColumn<int>(
        'assigned_at_ms',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ShareLotTableTable.$converterassignedAtMs);
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, int> assignmentStrike =
      GeneratedColumn<int>(
        'assignment_strike',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<Decimal>($ShareLotTableTable.$converterassignmentStrike);
  static const VerificationMeta _contractsMeta = const VerificationMeta(
    'contracts',
  );
  @override
  late final GeneratedColumn<int> contracts = GeneratedColumn<int>(
    'contracts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cycleId,
    assignedAtMs,
    assignmentStrike,
    contracts,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'share_lot';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShareLotRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('cycle_id')) {
      context.handle(
        _cycleIdMeta,
        cycleId.isAcceptableOrUnknown(data['cycle_id']!, _cycleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cycleIdMeta);
    }
    if (data.containsKey('contracts')) {
      context.handle(
        _contractsMeta,
        contracts.isAcceptableOrUnknown(data['contracts']!, _contractsMeta),
      );
    } else if (isInserting) {
      context.missing(_contractsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShareLotRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShareLotRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      cycleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cycle_id'],
      )!,
      assignedAtMs: $ShareLotTableTable.$converterassignedAtMs.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}assigned_at_ms'],
        )!,
      ),
      assignmentStrike: $ShareLotTableTable.$converterassignmentStrike.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}assignment_strike'],
        )!,
      ),
      contracts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}contracts'],
      )!,
    );
  }

  @override
  $ShareLotTableTable createAlias(String alias) {
    return $ShareLotTableTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterassignedAtMs =
      const DateTimeMsConverter();
  static TypeConverter<Decimal, int> $converterassignmentStrike =
      const CentsConverter();
}

class ShareLotRow extends DataClass implements Insertable<ShareLotRow> {
  final String id;
  final String cycleId;
  final DateTime assignedAtMs;
  final Decimal assignmentStrike;
  final int contracts;
  const ShareLotRow({
    required this.id,
    required this.cycleId,
    required this.assignedAtMs,
    required this.assignmentStrike,
    required this.contracts,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['cycle_id'] = Variable<String>(cycleId);
    {
      map['assigned_at_ms'] = Variable<int>(
        $ShareLotTableTable.$converterassignedAtMs.toSql(assignedAtMs),
      );
    }
    {
      map['assignment_strike'] = Variable<int>(
        $ShareLotTableTable.$converterassignmentStrike.toSql(assignmentStrike),
      );
    }
    map['contracts'] = Variable<int>(contracts);
    return map;
  }

  ShareLotTableCompanion toCompanion(bool nullToAbsent) {
    return ShareLotTableCompanion(
      id: Value(id),
      cycleId: Value(cycleId),
      assignedAtMs: Value(assignedAtMs),
      assignmentStrike: Value(assignmentStrike),
      contracts: Value(contracts),
    );
  }

  factory ShareLotRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShareLotRow(
      id: serializer.fromJson<String>(json['id']),
      cycleId: serializer.fromJson<String>(json['cycleId']),
      assignedAtMs: serializer.fromJson<DateTime>(json['assignedAtMs']),
      assignmentStrike: serializer.fromJson<Decimal>(json['assignmentStrike']),
      contracts: serializer.fromJson<int>(json['contracts']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'cycleId': serializer.toJson<String>(cycleId),
      'assignedAtMs': serializer.toJson<DateTime>(assignedAtMs),
      'assignmentStrike': serializer.toJson<Decimal>(assignmentStrike),
      'contracts': serializer.toJson<int>(contracts),
    };
  }

  ShareLotRow copyWith({
    String? id,
    String? cycleId,
    DateTime? assignedAtMs,
    Decimal? assignmentStrike,
    int? contracts,
  }) => ShareLotRow(
    id: id ?? this.id,
    cycleId: cycleId ?? this.cycleId,
    assignedAtMs: assignedAtMs ?? this.assignedAtMs,
    assignmentStrike: assignmentStrike ?? this.assignmentStrike,
    contracts: contracts ?? this.contracts,
  );
  ShareLotRow copyWithCompanion(ShareLotTableCompanion data) {
    return ShareLotRow(
      id: data.id.present ? data.id.value : this.id,
      cycleId: data.cycleId.present ? data.cycleId.value : this.cycleId,
      assignedAtMs: data.assignedAtMs.present
          ? data.assignedAtMs.value
          : this.assignedAtMs,
      assignmentStrike: data.assignmentStrike.present
          ? data.assignmentStrike.value
          : this.assignmentStrike,
      contracts: data.contracts.present ? data.contracts.value : this.contracts,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShareLotRow(')
          ..write('id: $id, ')
          ..write('cycleId: $cycleId, ')
          ..write('assignedAtMs: $assignedAtMs, ')
          ..write('assignmentStrike: $assignmentStrike, ')
          ..write('contracts: $contracts')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, cycleId, assignedAtMs, assignmentStrike, contracts);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShareLotRow &&
          other.id == this.id &&
          other.cycleId == this.cycleId &&
          other.assignedAtMs == this.assignedAtMs &&
          other.assignmentStrike == this.assignmentStrike &&
          other.contracts == this.contracts);
}

class ShareLotTableCompanion extends UpdateCompanion<ShareLotRow> {
  final Value<String> id;
  final Value<String> cycleId;
  final Value<DateTime> assignedAtMs;
  final Value<Decimal> assignmentStrike;
  final Value<int> contracts;
  final Value<int> rowid;
  const ShareLotTableCompanion({
    this.id = const Value.absent(),
    this.cycleId = const Value.absent(),
    this.assignedAtMs = const Value.absent(),
    this.assignmentStrike = const Value.absent(),
    this.contracts = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ShareLotTableCompanion.insert({
    required String id,
    required String cycleId,
    required DateTime assignedAtMs,
    required Decimal assignmentStrike,
    required int contracts,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       cycleId = Value(cycleId),
       assignedAtMs = Value(assignedAtMs),
       assignmentStrike = Value(assignmentStrike),
       contracts = Value(contracts);
  static Insertable<ShareLotRow> custom({
    Expression<String>? id,
    Expression<String>? cycleId,
    Expression<int>? assignedAtMs,
    Expression<int>? assignmentStrike,
    Expression<int>? contracts,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cycleId != null) 'cycle_id': cycleId,
      if (assignedAtMs != null) 'assigned_at_ms': assignedAtMs,
      if (assignmentStrike != null) 'assignment_strike': assignmentStrike,
      if (contracts != null) 'contracts': contracts,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ShareLotTableCompanion copyWith({
    Value<String>? id,
    Value<String>? cycleId,
    Value<DateTime>? assignedAtMs,
    Value<Decimal>? assignmentStrike,
    Value<int>? contracts,
    Value<int>? rowid,
  }) {
    return ShareLotTableCompanion(
      id: id ?? this.id,
      cycleId: cycleId ?? this.cycleId,
      assignedAtMs: assignedAtMs ?? this.assignedAtMs,
      assignmentStrike: assignmentStrike ?? this.assignmentStrike,
      contracts: contracts ?? this.contracts,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (cycleId.present) {
      map['cycle_id'] = Variable<String>(cycleId.value);
    }
    if (assignedAtMs.present) {
      map['assigned_at_ms'] = Variable<int>(
        $ShareLotTableTable.$converterassignedAtMs.toSql(assignedAtMs.value),
      );
    }
    if (assignmentStrike.present) {
      map['assignment_strike'] = Variable<int>(
        $ShareLotTableTable.$converterassignmentStrike.toSql(
          assignmentStrike.value,
        ),
      );
    }
    if (contracts.present) {
      map['contracts'] = Variable<int>(contracts.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShareLotTableCompanion(')
          ..write('id: $id, ')
          ..write('cycleId: $cycleId, ')
          ..write('assignedAtMs: $assignedAtMs, ')
          ..write('assignmentStrike: $assignmentStrike, ')
          ..write('contracts: $contracts, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RuleProfileTableTable extends RuleProfileTable
    with TableInfo<$RuleProfileTableTable, RuleProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RuleProfileTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rule_profile';
  @override
  VerificationContext validateIntegrity(
    Insertable<RuleProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RuleProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RuleProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $RuleProfileTableTable createAlias(String alias) {
    return $RuleProfileTableTable(attachedDatabase, alias);
  }
}

class RuleProfileRow extends DataClass implements Insertable<RuleProfileRow> {
  final String id;
  final String name;
  const RuleProfileRow({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  RuleProfileTableCompanion toCompanion(bool nullToAbsent) {
    return RuleProfileTableCompanion(id: Value(id), name: Value(name));
  }

  factory RuleProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RuleProfileRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
    };
  }

  RuleProfileRow copyWith({String? id, String? name}) =>
      RuleProfileRow(id: id ?? this.id, name: name ?? this.name);
  RuleProfileRow copyWithCompanion(RuleProfileTableCompanion data) {
    return RuleProfileRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RuleProfileRow(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RuleProfileRow &&
          other.id == this.id &&
          other.name == this.name);
}

class RuleProfileTableCompanion extends UpdateCompanion<RuleProfileRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> rowid;
  const RuleProfileTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RuleProfileTableCompanion.insert({
    required String id,
    required String name,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<RuleProfileRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RuleProfileTableCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? rowid,
  }) {
    return RuleProfileTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RuleProfileTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RuleProfileVersionTableTable extends RuleProfileVersionTable
    with TableInfo<$RuleProfileVersionTableTable, RuleProfileVersionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RuleProfileVersionTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> effectiveAtMs =
      GeneratedColumn<int>(
        'effective_at_ms',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>(
        $RuleProfileVersionTableTable.$convertereffectiveAtMs,
      );
  static const VerificationMeta _profitTargetPctMeta = const VerificationMeta(
    'profitTargetPct',
  );
  @override
  late final GeneratedColumn<double> profitTargetPct = GeneratedColumn<double>(
    'profit_target_pct',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assignThresholdMeta = const VerificationMeta(
    'assignThreshold',
  );
  @override
  late final GeneratedColumn<double> assignThreshold = GeneratedColumn<double>(
    'assign_threshold',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseRollBandMeta = const VerificationMeta(
    'baseRollBand',
  );
  @override
  late final GeneratedColumn<double> baseRollBand = GeneratedColumn<double>(
    'base_roll_band',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _midIvRollBandMeta = const VerificationMeta(
    'midIvRollBand',
  );
  @override
  late final GeneratedColumn<double> midIvRollBand = GeneratedColumn<double>(
    'mid_iv_roll_band',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _highIvRollBandMeta = const VerificationMeta(
    'highIvRollBand',
  );
  @override
  late final GeneratedColumn<double> highIvRollBand = GeneratedColumn<double>(
    'high_iv_roll_band',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _midIvCutoffMeta = const VerificationMeta(
    'midIvCutoff',
  );
  @override
  late final GeneratedColumn<double> midIvCutoff = GeneratedColumn<double>(
    'mid_iv_cutoff',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _highIvCutoffMeta = const VerificationMeta(
    'highIvCutoff',
  );
  @override
  late final GeneratedColumn<double> highIvCutoff = GeneratedColumn<double>(
    'high_iv_cutoff',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tailDteDaysMeta = const VerificationMeta(
    'tailDteDays',
  );
  @override
  late final GeneratedColumn<int> tailDteDays = GeneratedColumn<int>(
    'tail_dte_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, int>
  tailExtrinsicThreshold =
      GeneratedColumn<int>(
        'tail_extrinsic_threshold',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<Decimal>(
        $RuleProfileVersionTableTable.$convertertailExtrinsicThreshold,
      );
  static const VerificationMeta _minIvRankMeta = const VerificationMeta(
    'minIvRank',
  );
  @override
  late final GeneratedColumn<double> minIvRank = GeneratedColumn<double>(
    'min_iv_rank',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minAnnualisedYieldMeta =
      const VerificationMeta('minAnnualisedYield');
  @override
  late final GeneratedColumn<double> minAnnualisedYield =
      GeneratedColumn<double>(
        'min_annualised_yield',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _targetDteMinMeta = const VerificationMeta(
    'targetDteMin',
  );
  @override
  late final GeneratedColumn<int> targetDteMin = GeneratedColumn<int>(
    'target_dte_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetDteMaxMeta = const VerificationMeta(
    'targetDteMax',
  );
  @override
  late final GeneratedColumn<int> targetDteMax = GeneratedColumn<int>(
    'target_dte_max',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetDeltaMeta = const VerificationMeta(
    'targetDelta',
  );
  @override
  late final GeneratedColumn<double> targetDelta = GeneratedColumn<double>(
    'target_delta',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    version,
    effectiveAtMs,
    profitTargetPct,
    assignThreshold,
    baseRollBand,
    midIvRollBand,
    highIvRollBand,
    midIvCutoff,
    highIvCutoff,
    tailDteDays,
    tailExtrinsicThreshold,
    minIvRank,
    minAnnualisedYield,
    targetDteMin,
    targetDteMax,
    targetDelta,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rule_profile_version';
  @override
  VerificationContext validateIntegrity(
    Insertable<RuleProfileVersionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('profit_target_pct')) {
      context.handle(
        _profitTargetPctMeta,
        profitTargetPct.isAcceptableOrUnknown(
          data['profit_target_pct']!,
          _profitTargetPctMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_profitTargetPctMeta);
    }
    if (data.containsKey('assign_threshold')) {
      context.handle(
        _assignThresholdMeta,
        assignThreshold.isAcceptableOrUnknown(
          data['assign_threshold']!,
          _assignThresholdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_assignThresholdMeta);
    }
    if (data.containsKey('base_roll_band')) {
      context.handle(
        _baseRollBandMeta,
        baseRollBand.isAcceptableOrUnknown(
          data['base_roll_band']!,
          _baseRollBandMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_baseRollBandMeta);
    }
    if (data.containsKey('mid_iv_roll_band')) {
      context.handle(
        _midIvRollBandMeta,
        midIvRollBand.isAcceptableOrUnknown(
          data['mid_iv_roll_band']!,
          _midIvRollBandMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_midIvRollBandMeta);
    }
    if (data.containsKey('high_iv_roll_band')) {
      context.handle(
        _highIvRollBandMeta,
        highIvRollBand.isAcceptableOrUnknown(
          data['high_iv_roll_band']!,
          _highIvRollBandMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_highIvRollBandMeta);
    }
    if (data.containsKey('mid_iv_cutoff')) {
      context.handle(
        _midIvCutoffMeta,
        midIvCutoff.isAcceptableOrUnknown(
          data['mid_iv_cutoff']!,
          _midIvCutoffMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_midIvCutoffMeta);
    }
    if (data.containsKey('high_iv_cutoff')) {
      context.handle(
        _highIvCutoffMeta,
        highIvCutoff.isAcceptableOrUnknown(
          data['high_iv_cutoff']!,
          _highIvCutoffMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_highIvCutoffMeta);
    }
    if (data.containsKey('tail_dte_days')) {
      context.handle(
        _tailDteDaysMeta,
        tailDteDays.isAcceptableOrUnknown(
          data['tail_dte_days']!,
          _tailDteDaysMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tailDteDaysMeta);
    }
    if (data.containsKey('min_iv_rank')) {
      context.handle(
        _minIvRankMeta,
        minIvRank.isAcceptableOrUnknown(data['min_iv_rank']!, _minIvRankMeta),
      );
    } else if (isInserting) {
      context.missing(_minIvRankMeta);
    }
    if (data.containsKey('min_annualised_yield')) {
      context.handle(
        _minAnnualisedYieldMeta,
        minAnnualisedYield.isAcceptableOrUnknown(
          data['min_annualised_yield']!,
          _minAnnualisedYieldMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_minAnnualisedYieldMeta);
    }
    if (data.containsKey('target_dte_min')) {
      context.handle(
        _targetDteMinMeta,
        targetDteMin.isAcceptableOrUnknown(
          data['target_dte_min']!,
          _targetDteMinMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetDteMinMeta);
    }
    if (data.containsKey('target_dte_max')) {
      context.handle(
        _targetDteMaxMeta,
        targetDteMax.isAcceptableOrUnknown(
          data['target_dte_max']!,
          _targetDteMaxMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetDteMaxMeta);
    }
    if (data.containsKey('target_delta')) {
      context.handle(
        _targetDeltaMeta,
        targetDelta.isAcceptableOrUnknown(
          data['target_delta']!,
          _targetDeltaMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetDeltaMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {profileId, version},
  ];
  @override
  RuleProfileVersionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RuleProfileVersionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      effectiveAtMs: $RuleProfileVersionTableTable.$convertereffectiveAtMs
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.int,
              data['${effectivePrefix}effective_at_ms'],
            )!,
          ),
      profitTargetPct: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}profit_target_pct'],
      )!,
      assignThreshold: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}assign_threshold'],
      )!,
      baseRollBand: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}base_roll_band'],
      )!,
      midIvRollBand: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}mid_iv_roll_band'],
      )!,
      highIvRollBand: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}high_iv_roll_band'],
      )!,
      midIvCutoff: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}mid_iv_cutoff'],
      )!,
      highIvCutoff: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}high_iv_cutoff'],
      )!,
      tailDteDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tail_dte_days'],
      )!,
      tailExtrinsicThreshold: $RuleProfileVersionTableTable
          .$convertertailExtrinsicThreshold
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.int,
              data['${effectivePrefix}tail_extrinsic_threshold'],
            )!,
          ),
      minIvRank: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}min_iv_rank'],
      )!,
      minAnnualisedYield: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}min_annualised_yield'],
      )!,
      targetDteMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_dte_min'],
      )!,
      targetDteMax: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_dte_max'],
      )!,
      targetDelta: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}target_delta'],
      )!,
    );
  }

  @override
  $RuleProfileVersionTableTable createAlias(String alias) {
    return $RuleProfileVersionTableTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertereffectiveAtMs =
      const DateTimeMsConverter();
  static TypeConverter<Decimal, int> $convertertailExtrinsicThreshold =
      const TenThousandthsConverter();
}

class RuleProfileVersionRow extends DataClass
    implements Insertable<RuleProfileVersionRow> {
  final String id;
  final String profileId;
  final int version;
  final DateTime effectiveAtMs;
  final double profitTargetPct;
  final double assignThreshold;
  final double baseRollBand;
  final double midIvRollBand;
  final double highIvRollBand;
  final double midIvCutoff;
  final double highIvCutoff;
  final int tailDteDays;
  final Decimal tailExtrinsicThreshold;
  final double minIvRank;
  final double minAnnualisedYield;
  final int targetDteMin;
  final int targetDteMax;
  final double targetDelta;
  const RuleProfileVersionRow({
    required this.id,
    required this.profileId,
    required this.version,
    required this.effectiveAtMs,
    required this.profitTargetPct,
    required this.assignThreshold,
    required this.baseRollBand,
    required this.midIvRollBand,
    required this.highIvRollBand,
    required this.midIvCutoff,
    required this.highIvCutoff,
    required this.tailDteDays,
    required this.tailExtrinsicThreshold,
    required this.minIvRank,
    required this.minAnnualisedYield,
    required this.targetDteMin,
    required this.targetDteMax,
    required this.targetDelta,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['profile_id'] = Variable<String>(profileId);
    map['version'] = Variable<int>(version);
    {
      map['effective_at_ms'] = Variable<int>(
        $RuleProfileVersionTableTable.$convertereffectiveAtMs.toSql(
          effectiveAtMs,
        ),
      );
    }
    map['profit_target_pct'] = Variable<double>(profitTargetPct);
    map['assign_threshold'] = Variable<double>(assignThreshold);
    map['base_roll_band'] = Variable<double>(baseRollBand);
    map['mid_iv_roll_band'] = Variable<double>(midIvRollBand);
    map['high_iv_roll_band'] = Variable<double>(highIvRollBand);
    map['mid_iv_cutoff'] = Variable<double>(midIvCutoff);
    map['high_iv_cutoff'] = Variable<double>(highIvCutoff);
    map['tail_dte_days'] = Variable<int>(tailDteDays);
    {
      map['tail_extrinsic_threshold'] = Variable<int>(
        $RuleProfileVersionTableTable.$convertertailExtrinsicThreshold.toSql(
          tailExtrinsicThreshold,
        ),
      );
    }
    map['min_iv_rank'] = Variable<double>(minIvRank);
    map['min_annualised_yield'] = Variable<double>(minAnnualisedYield);
    map['target_dte_min'] = Variable<int>(targetDteMin);
    map['target_dte_max'] = Variable<int>(targetDteMax);
    map['target_delta'] = Variable<double>(targetDelta);
    return map;
  }

  RuleProfileVersionTableCompanion toCompanion(bool nullToAbsent) {
    return RuleProfileVersionTableCompanion(
      id: Value(id),
      profileId: Value(profileId),
      version: Value(version),
      effectiveAtMs: Value(effectiveAtMs),
      profitTargetPct: Value(profitTargetPct),
      assignThreshold: Value(assignThreshold),
      baseRollBand: Value(baseRollBand),
      midIvRollBand: Value(midIvRollBand),
      highIvRollBand: Value(highIvRollBand),
      midIvCutoff: Value(midIvCutoff),
      highIvCutoff: Value(highIvCutoff),
      tailDteDays: Value(tailDteDays),
      tailExtrinsicThreshold: Value(tailExtrinsicThreshold),
      minIvRank: Value(minIvRank),
      minAnnualisedYield: Value(minAnnualisedYield),
      targetDteMin: Value(targetDteMin),
      targetDteMax: Value(targetDteMax),
      targetDelta: Value(targetDelta),
    );
  }

  factory RuleProfileVersionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RuleProfileVersionRow(
      id: serializer.fromJson<String>(json['id']),
      profileId: serializer.fromJson<String>(json['profileId']),
      version: serializer.fromJson<int>(json['version']),
      effectiveAtMs: serializer.fromJson<DateTime>(json['effectiveAtMs']),
      profitTargetPct: serializer.fromJson<double>(json['profitTargetPct']),
      assignThreshold: serializer.fromJson<double>(json['assignThreshold']),
      baseRollBand: serializer.fromJson<double>(json['baseRollBand']),
      midIvRollBand: serializer.fromJson<double>(json['midIvRollBand']),
      highIvRollBand: serializer.fromJson<double>(json['highIvRollBand']),
      midIvCutoff: serializer.fromJson<double>(json['midIvCutoff']),
      highIvCutoff: serializer.fromJson<double>(json['highIvCutoff']),
      tailDteDays: serializer.fromJson<int>(json['tailDteDays']),
      tailExtrinsicThreshold: serializer.fromJson<Decimal>(
        json['tailExtrinsicThreshold'],
      ),
      minIvRank: serializer.fromJson<double>(json['minIvRank']),
      minAnnualisedYield: serializer.fromJson<double>(
        json['minAnnualisedYield'],
      ),
      targetDteMin: serializer.fromJson<int>(json['targetDteMin']),
      targetDteMax: serializer.fromJson<int>(json['targetDteMax']),
      targetDelta: serializer.fromJson<double>(json['targetDelta']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'profileId': serializer.toJson<String>(profileId),
      'version': serializer.toJson<int>(version),
      'effectiveAtMs': serializer.toJson<DateTime>(effectiveAtMs),
      'profitTargetPct': serializer.toJson<double>(profitTargetPct),
      'assignThreshold': serializer.toJson<double>(assignThreshold),
      'baseRollBand': serializer.toJson<double>(baseRollBand),
      'midIvRollBand': serializer.toJson<double>(midIvRollBand),
      'highIvRollBand': serializer.toJson<double>(highIvRollBand),
      'midIvCutoff': serializer.toJson<double>(midIvCutoff),
      'highIvCutoff': serializer.toJson<double>(highIvCutoff),
      'tailDteDays': serializer.toJson<int>(tailDteDays),
      'tailExtrinsicThreshold': serializer.toJson<Decimal>(
        tailExtrinsicThreshold,
      ),
      'minIvRank': serializer.toJson<double>(minIvRank),
      'minAnnualisedYield': serializer.toJson<double>(minAnnualisedYield),
      'targetDteMin': serializer.toJson<int>(targetDteMin),
      'targetDteMax': serializer.toJson<int>(targetDteMax),
      'targetDelta': serializer.toJson<double>(targetDelta),
    };
  }

  RuleProfileVersionRow copyWith({
    String? id,
    String? profileId,
    int? version,
    DateTime? effectiveAtMs,
    double? profitTargetPct,
    double? assignThreshold,
    double? baseRollBand,
    double? midIvRollBand,
    double? highIvRollBand,
    double? midIvCutoff,
    double? highIvCutoff,
    int? tailDteDays,
    Decimal? tailExtrinsicThreshold,
    double? minIvRank,
    double? minAnnualisedYield,
    int? targetDteMin,
    int? targetDteMax,
    double? targetDelta,
  }) => RuleProfileVersionRow(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    version: version ?? this.version,
    effectiveAtMs: effectiveAtMs ?? this.effectiveAtMs,
    profitTargetPct: profitTargetPct ?? this.profitTargetPct,
    assignThreshold: assignThreshold ?? this.assignThreshold,
    baseRollBand: baseRollBand ?? this.baseRollBand,
    midIvRollBand: midIvRollBand ?? this.midIvRollBand,
    highIvRollBand: highIvRollBand ?? this.highIvRollBand,
    midIvCutoff: midIvCutoff ?? this.midIvCutoff,
    highIvCutoff: highIvCutoff ?? this.highIvCutoff,
    tailDteDays: tailDteDays ?? this.tailDteDays,
    tailExtrinsicThreshold:
        tailExtrinsicThreshold ?? this.tailExtrinsicThreshold,
    minIvRank: minIvRank ?? this.minIvRank,
    minAnnualisedYield: minAnnualisedYield ?? this.minAnnualisedYield,
    targetDteMin: targetDteMin ?? this.targetDteMin,
    targetDteMax: targetDteMax ?? this.targetDteMax,
    targetDelta: targetDelta ?? this.targetDelta,
  );
  RuleProfileVersionRow copyWithCompanion(
    RuleProfileVersionTableCompanion data,
  ) {
    return RuleProfileVersionRow(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      version: data.version.present ? data.version.value : this.version,
      effectiveAtMs: data.effectiveAtMs.present
          ? data.effectiveAtMs.value
          : this.effectiveAtMs,
      profitTargetPct: data.profitTargetPct.present
          ? data.profitTargetPct.value
          : this.profitTargetPct,
      assignThreshold: data.assignThreshold.present
          ? data.assignThreshold.value
          : this.assignThreshold,
      baseRollBand: data.baseRollBand.present
          ? data.baseRollBand.value
          : this.baseRollBand,
      midIvRollBand: data.midIvRollBand.present
          ? data.midIvRollBand.value
          : this.midIvRollBand,
      highIvRollBand: data.highIvRollBand.present
          ? data.highIvRollBand.value
          : this.highIvRollBand,
      midIvCutoff: data.midIvCutoff.present
          ? data.midIvCutoff.value
          : this.midIvCutoff,
      highIvCutoff: data.highIvCutoff.present
          ? data.highIvCutoff.value
          : this.highIvCutoff,
      tailDteDays: data.tailDteDays.present
          ? data.tailDteDays.value
          : this.tailDteDays,
      tailExtrinsicThreshold: data.tailExtrinsicThreshold.present
          ? data.tailExtrinsicThreshold.value
          : this.tailExtrinsicThreshold,
      minIvRank: data.minIvRank.present ? data.minIvRank.value : this.minIvRank,
      minAnnualisedYield: data.minAnnualisedYield.present
          ? data.minAnnualisedYield.value
          : this.minAnnualisedYield,
      targetDteMin: data.targetDteMin.present
          ? data.targetDteMin.value
          : this.targetDteMin,
      targetDteMax: data.targetDteMax.present
          ? data.targetDteMax.value
          : this.targetDteMax,
      targetDelta: data.targetDelta.present
          ? data.targetDelta.value
          : this.targetDelta,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RuleProfileVersionRow(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('version: $version, ')
          ..write('effectiveAtMs: $effectiveAtMs, ')
          ..write('profitTargetPct: $profitTargetPct, ')
          ..write('assignThreshold: $assignThreshold, ')
          ..write('baseRollBand: $baseRollBand, ')
          ..write('midIvRollBand: $midIvRollBand, ')
          ..write('highIvRollBand: $highIvRollBand, ')
          ..write('midIvCutoff: $midIvCutoff, ')
          ..write('highIvCutoff: $highIvCutoff, ')
          ..write('tailDteDays: $tailDteDays, ')
          ..write('tailExtrinsicThreshold: $tailExtrinsicThreshold, ')
          ..write('minIvRank: $minIvRank, ')
          ..write('minAnnualisedYield: $minAnnualisedYield, ')
          ..write('targetDteMin: $targetDteMin, ')
          ..write('targetDteMax: $targetDteMax, ')
          ..write('targetDelta: $targetDelta')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    version,
    effectiveAtMs,
    profitTargetPct,
    assignThreshold,
    baseRollBand,
    midIvRollBand,
    highIvRollBand,
    midIvCutoff,
    highIvCutoff,
    tailDteDays,
    tailExtrinsicThreshold,
    minIvRank,
    minAnnualisedYield,
    targetDteMin,
    targetDteMax,
    targetDelta,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RuleProfileVersionRow &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.version == this.version &&
          other.effectiveAtMs == this.effectiveAtMs &&
          other.profitTargetPct == this.profitTargetPct &&
          other.assignThreshold == this.assignThreshold &&
          other.baseRollBand == this.baseRollBand &&
          other.midIvRollBand == this.midIvRollBand &&
          other.highIvRollBand == this.highIvRollBand &&
          other.midIvCutoff == this.midIvCutoff &&
          other.highIvCutoff == this.highIvCutoff &&
          other.tailDteDays == this.tailDteDays &&
          other.tailExtrinsicThreshold == this.tailExtrinsicThreshold &&
          other.minIvRank == this.minIvRank &&
          other.minAnnualisedYield == this.minAnnualisedYield &&
          other.targetDteMin == this.targetDteMin &&
          other.targetDteMax == this.targetDteMax &&
          other.targetDelta == this.targetDelta);
}

class RuleProfileVersionTableCompanion
    extends UpdateCompanion<RuleProfileVersionRow> {
  final Value<String> id;
  final Value<String> profileId;
  final Value<int> version;
  final Value<DateTime> effectiveAtMs;
  final Value<double> profitTargetPct;
  final Value<double> assignThreshold;
  final Value<double> baseRollBand;
  final Value<double> midIvRollBand;
  final Value<double> highIvRollBand;
  final Value<double> midIvCutoff;
  final Value<double> highIvCutoff;
  final Value<int> tailDteDays;
  final Value<Decimal> tailExtrinsicThreshold;
  final Value<double> minIvRank;
  final Value<double> minAnnualisedYield;
  final Value<int> targetDteMin;
  final Value<int> targetDteMax;
  final Value<double> targetDelta;
  final Value<int> rowid;
  const RuleProfileVersionTableCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.version = const Value.absent(),
    this.effectiveAtMs = const Value.absent(),
    this.profitTargetPct = const Value.absent(),
    this.assignThreshold = const Value.absent(),
    this.baseRollBand = const Value.absent(),
    this.midIvRollBand = const Value.absent(),
    this.highIvRollBand = const Value.absent(),
    this.midIvCutoff = const Value.absent(),
    this.highIvCutoff = const Value.absent(),
    this.tailDteDays = const Value.absent(),
    this.tailExtrinsicThreshold = const Value.absent(),
    this.minIvRank = const Value.absent(),
    this.minAnnualisedYield = const Value.absent(),
    this.targetDteMin = const Value.absent(),
    this.targetDteMax = const Value.absent(),
    this.targetDelta = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RuleProfileVersionTableCompanion.insert({
    required String id,
    required String profileId,
    required int version,
    required DateTime effectiveAtMs,
    required double profitTargetPct,
    required double assignThreshold,
    required double baseRollBand,
    required double midIvRollBand,
    required double highIvRollBand,
    required double midIvCutoff,
    required double highIvCutoff,
    required int tailDteDays,
    required Decimal tailExtrinsicThreshold,
    required double minIvRank,
    required double minAnnualisedYield,
    required int targetDteMin,
    required int targetDteMax,
    required double targetDelta,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       profileId = Value(profileId),
       version = Value(version),
       effectiveAtMs = Value(effectiveAtMs),
       profitTargetPct = Value(profitTargetPct),
       assignThreshold = Value(assignThreshold),
       baseRollBand = Value(baseRollBand),
       midIvRollBand = Value(midIvRollBand),
       highIvRollBand = Value(highIvRollBand),
       midIvCutoff = Value(midIvCutoff),
       highIvCutoff = Value(highIvCutoff),
       tailDteDays = Value(tailDteDays),
       tailExtrinsicThreshold = Value(tailExtrinsicThreshold),
       minIvRank = Value(minIvRank),
       minAnnualisedYield = Value(minAnnualisedYield),
       targetDteMin = Value(targetDteMin),
       targetDteMax = Value(targetDteMax),
       targetDelta = Value(targetDelta);
  static Insertable<RuleProfileVersionRow> custom({
    Expression<String>? id,
    Expression<String>? profileId,
    Expression<int>? version,
    Expression<int>? effectiveAtMs,
    Expression<double>? profitTargetPct,
    Expression<double>? assignThreshold,
    Expression<double>? baseRollBand,
    Expression<double>? midIvRollBand,
    Expression<double>? highIvRollBand,
    Expression<double>? midIvCutoff,
    Expression<double>? highIvCutoff,
    Expression<int>? tailDteDays,
    Expression<int>? tailExtrinsicThreshold,
    Expression<double>? minIvRank,
    Expression<double>? minAnnualisedYield,
    Expression<int>? targetDteMin,
    Expression<int>? targetDteMax,
    Expression<double>? targetDelta,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (version != null) 'version': version,
      if (effectiveAtMs != null) 'effective_at_ms': effectiveAtMs,
      if (profitTargetPct != null) 'profit_target_pct': profitTargetPct,
      if (assignThreshold != null) 'assign_threshold': assignThreshold,
      if (baseRollBand != null) 'base_roll_band': baseRollBand,
      if (midIvRollBand != null) 'mid_iv_roll_band': midIvRollBand,
      if (highIvRollBand != null) 'high_iv_roll_band': highIvRollBand,
      if (midIvCutoff != null) 'mid_iv_cutoff': midIvCutoff,
      if (highIvCutoff != null) 'high_iv_cutoff': highIvCutoff,
      if (tailDteDays != null) 'tail_dte_days': tailDteDays,
      if (tailExtrinsicThreshold != null)
        'tail_extrinsic_threshold': tailExtrinsicThreshold,
      if (minIvRank != null) 'min_iv_rank': minIvRank,
      if (minAnnualisedYield != null)
        'min_annualised_yield': minAnnualisedYield,
      if (targetDteMin != null) 'target_dte_min': targetDteMin,
      if (targetDteMax != null) 'target_dte_max': targetDteMax,
      if (targetDelta != null) 'target_delta': targetDelta,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RuleProfileVersionTableCompanion copyWith({
    Value<String>? id,
    Value<String>? profileId,
    Value<int>? version,
    Value<DateTime>? effectiveAtMs,
    Value<double>? profitTargetPct,
    Value<double>? assignThreshold,
    Value<double>? baseRollBand,
    Value<double>? midIvRollBand,
    Value<double>? highIvRollBand,
    Value<double>? midIvCutoff,
    Value<double>? highIvCutoff,
    Value<int>? tailDteDays,
    Value<Decimal>? tailExtrinsicThreshold,
    Value<double>? minIvRank,
    Value<double>? minAnnualisedYield,
    Value<int>? targetDteMin,
    Value<int>? targetDteMax,
    Value<double>? targetDelta,
    Value<int>? rowid,
  }) {
    return RuleProfileVersionTableCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      version: version ?? this.version,
      effectiveAtMs: effectiveAtMs ?? this.effectiveAtMs,
      profitTargetPct: profitTargetPct ?? this.profitTargetPct,
      assignThreshold: assignThreshold ?? this.assignThreshold,
      baseRollBand: baseRollBand ?? this.baseRollBand,
      midIvRollBand: midIvRollBand ?? this.midIvRollBand,
      highIvRollBand: highIvRollBand ?? this.highIvRollBand,
      midIvCutoff: midIvCutoff ?? this.midIvCutoff,
      highIvCutoff: highIvCutoff ?? this.highIvCutoff,
      tailDteDays: tailDteDays ?? this.tailDteDays,
      tailExtrinsicThreshold:
          tailExtrinsicThreshold ?? this.tailExtrinsicThreshold,
      minIvRank: minIvRank ?? this.minIvRank,
      minAnnualisedYield: minAnnualisedYield ?? this.minAnnualisedYield,
      targetDteMin: targetDteMin ?? this.targetDteMin,
      targetDteMax: targetDteMax ?? this.targetDteMax,
      targetDelta: targetDelta ?? this.targetDelta,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (effectiveAtMs.present) {
      map['effective_at_ms'] = Variable<int>(
        $RuleProfileVersionTableTable.$convertereffectiveAtMs.toSql(
          effectiveAtMs.value,
        ),
      );
    }
    if (profitTargetPct.present) {
      map['profit_target_pct'] = Variable<double>(profitTargetPct.value);
    }
    if (assignThreshold.present) {
      map['assign_threshold'] = Variable<double>(assignThreshold.value);
    }
    if (baseRollBand.present) {
      map['base_roll_band'] = Variable<double>(baseRollBand.value);
    }
    if (midIvRollBand.present) {
      map['mid_iv_roll_band'] = Variable<double>(midIvRollBand.value);
    }
    if (highIvRollBand.present) {
      map['high_iv_roll_band'] = Variable<double>(highIvRollBand.value);
    }
    if (midIvCutoff.present) {
      map['mid_iv_cutoff'] = Variable<double>(midIvCutoff.value);
    }
    if (highIvCutoff.present) {
      map['high_iv_cutoff'] = Variable<double>(highIvCutoff.value);
    }
    if (tailDteDays.present) {
      map['tail_dte_days'] = Variable<int>(tailDteDays.value);
    }
    if (tailExtrinsicThreshold.present) {
      map['tail_extrinsic_threshold'] = Variable<int>(
        $RuleProfileVersionTableTable.$convertertailExtrinsicThreshold.toSql(
          tailExtrinsicThreshold.value,
        ),
      );
    }
    if (minIvRank.present) {
      map['min_iv_rank'] = Variable<double>(minIvRank.value);
    }
    if (minAnnualisedYield.present) {
      map['min_annualised_yield'] = Variable<double>(minAnnualisedYield.value);
    }
    if (targetDteMin.present) {
      map['target_dte_min'] = Variable<int>(targetDteMin.value);
    }
    if (targetDteMax.present) {
      map['target_dte_max'] = Variable<int>(targetDteMax.value);
    }
    if (targetDelta.present) {
      map['target_delta'] = Variable<double>(targetDelta.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RuleProfileVersionTableCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('version: $version, ')
          ..write('effectiveAtMs: $effectiveAtMs, ')
          ..write('profitTargetPct: $profitTargetPct, ')
          ..write('assignThreshold: $assignThreshold, ')
          ..write('baseRollBand: $baseRollBand, ')
          ..write('midIvRollBand: $midIvRollBand, ')
          ..write('highIvRollBand: $highIvRollBand, ')
          ..write('midIvCutoff: $midIvCutoff, ')
          ..write('highIvCutoff: $highIvCutoff, ')
          ..write('tailDteDays: $tailDteDays, ')
          ..write('tailExtrinsicThreshold: $tailExtrinsicThreshold, ')
          ..write('minIvRank: $minIvRank, ')
          ..write('minAnnualisedYield: $minAnnualisedYield, ')
          ..write('targetDteMin: $targetDteMin, ')
          ..write('targetDteMax: $targetDteMax, ')
          ..write('targetDelta: $targetDelta, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserPreferencesTableTable extends UserPreferencesTable
    with TableInfo<$UserPreferencesTableTable, UserPreferencesRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserPreferencesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalPerContractToggleMeta =
      const VerificationMeta('totalPerContractToggle');
  @override
  late final GeneratedColumn<bool> totalPerContractToggle =
      GeneratedColumn<bool>(
        'total_per_contract_toggle',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("total_per_contract_toggle" IN (0, 1))',
        ),
      );
  @override
  late final GeneratedColumnWithTypeConverter<DeltaConvention, String>
  deltaConventionDefault =
      GeneratedColumn<String>(
        'delta_convention_default',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DeltaConvention>(
        $UserPreferencesTableTable.$converterdeltaConventionDefault,
      );
  static const VerificationMeta _firstRunExplainerShownMeta =
      const VerificationMeta('firstRunExplainerShown');
  @override
  late final GeneratedColumn<bool> firstRunExplainerShown =
      GeneratedColumn<bool>(
        'first_run_explainer_shown',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("first_run_explainer_shown" IN (0, 1))',
        ),
      );
  static const VerificationMeta _ivResolutionNoticeDismissedMeta =
      const VerificationMeta('ivResolutionNoticeDismissed');
  @override
  late final GeneratedColumn<bool> ivResolutionNoticeDismissed =
      GeneratedColumn<bool>(
        'iv_resolution_notice_dismissed',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("iv_resolution_notice_dismissed" IN (0, 1))',
        ),
      );
  static const VerificationMeta _exportReminderDismissedMeta =
      const VerificationMeta('exportReminderDismissed');
  @override
  late final GeneratedColumn<bool> exportReminderDismissed =
      GeneratedColumn<bool>(
        'export_reminder_dismissed',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("export_reminder_dismissed" IN (0, 1))',
        ),
        defaultValue: const Constant(
          UserPreferencesDefaults.exportReminderDismissed,
        ),
      );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> lastExportAtMs =
      GeneratedColumn<int>(
        'last_export_at_ms',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>(
        $UserPreferencesTableTable.$converterlastExportAtMs,
      );
  @override
  late final GeneratedColumnWithTypeConverter<List<int>, String>
  notificationMilestones =
      GeneratedColumn<String>(
        'notification_milestones',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(
          UserPreferencesDefaults.notificationMilestones.join(','),
        ),
      ).withConverter<List<int>>(
        $UserPreferencesTableTable.$converternotificationMilestones,
      );
  @override
  late final GeneratedColumnWithTypeConverter<Decimal?, int> wheelCapitalCents =
      GeneratedColumn<int>(
        'wheel_capital_cents',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<Decimal?>(
        $UserPreferencesTableTable.$converterwheelCapitalCents,
      );
  static const VerificationMeta _concentrationLimitPctMeta =
      const VerificationMeta('concentrationLimitPct');
  @override
  late final GeneratedColumn<double> concentrationLimitPct =
      GeneratedColumn<double>(
        'concentration_limit_pct',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(
          UserPreferencesDefaults.concentrationLimitPct,
        ),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    totalPerContractToggle,
    deltaConventionDefault,
    firstRunExplainerShown,
    ivResolutionNoticeDismissed,
    exportReminderDismissed,
    lastExportAtMs,
    notificationMilestones,
    wheelCapitalCents,
    concentrationLimitPct,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserPreferencesRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('total_per_contract_toggle')) {
      context.handle(
        _totalPerContractToggleMeta,
        totalPerContractToggle.isAcceptableOrUnknown(
          data['total_per_contract_toggle']!,
          _totalPerContractToggleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalPerContractToggleMeta);
    }
    if (data.containsKey('first_run_explainer_shown')) {
      context.handle(
        _firstRunExplainerShownMeta,
        firstRunExplainerShown.isAcceptableOrUnknown(
          data['first_run_explainer_shown']!,
          _firstRunExplainerShownMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firstRunExplainerShownMeta);
    }
    if (data.containsKey('iv_resolution_notice_dismissed')) {
      context.handle(
        _ivResolutionNoticeDismissedMeta,
        ivResolutionNoticeDismissed.isAcceptableOrUnknown(
          data['iv_resolution_notice_dismissed']!,
          _ivResolutionNoticeDismissedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ivResolutionNoticeDismissedMeta);
    }
    if (data.containsKey('export_reminder_dismissed')) {
      context.handle(
        _exportReminderDismissedMeta,
        exportReminderDismissed.isAcceptableOrUnknown(
          data['export_reminder_dismissed']!,
          _exportReminderDismissedMeta,
        ),
      );
    }
    if (data.containsKey('concentration_limit_pct')) {
      context.handle(
        _concentrationLimitPctMeta,
        concentrationLimitPct.isAcceptableOrUnknown(
          data['concentration_limit_pct']!,
          _concentrationLimitPctMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserPreferencesRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserPreferencesRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      totalPerContractToggle: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}total_per_contract_toggle'],
      )!,
      deltaConventionDefault: $UserPreferencesTableTable
          .$converterdeltaConventionDefault
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}delta_convention_default'],
            )!,
          ),
      firstRunExplainerShown: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}first_run_explainer_shown'],
      )!,
      ivResolutionNoticeDismissed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}iv_resolution_notice_dismissed'],
      )!,
      exportReminderDismissed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}export_reminder_dismissed'],
      )!,
      lastExportAtMs: $UserPreferencesTableTable.$converterlastExportAtMs
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.int,
              data['${effectivePrefix}last_export_at_ms'],
            ),
          ),
      notificationMilestones: $UserPreferencesTableTable
          .$converternotificationMilestones
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}notification_milestones'],
            )!,
          ),
      wheelCapitalCents: $UserPreferencesTableTable.$converterwheelCapitalCents
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.int,
              data['${effectivePrefix}wheel_capital_cents'],
            ),
          ),
      concentrationLimitPct: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}concentration_limit_pct'],
      )!,
    );
  }

  @override
  $UserPreferencesTableTable createAlias(String alias) {
    return $UserPreferencesTableTable(attachedDatabase, alias);
  }

  static TypeConverter<DeltaConvention, String>
  $converterdeltaConventionDefault = const DeltaConventionConverter();
  static TypeConverter<DateTime?, int?> $converterlastExportAtMs =
      NullAwareTypeConverter.wrap(const DateTimeMsConverter());
  static TypeConverter<List<int>, String> $converternotificationMilestones =
      const IntListConverter();
  static TypeConverter<Decimal?, int?> $converterwheelCapitalCents =
      NullAwareTypeConverter.wrap(const CentsConverter());
}

class UserPreferencesRow extends DataClass
    implements Insertable<UserPreferencesRow> {
  final String id;
  final bool totalPerContractToggle;
  final DeltaConvention deltaConventionDefault;
  final bool firstRunExplainerShown;
  final bool ivResolutionNoticeDismissed;
  final bool exportReminderDismissed;
  final DateTime? lastExportAtMs;
  final List<int> notificationMilestones;
  final Decimal? wheelCapitalCents;
  final double concentrationLimitPct;
  const UserPreferencesRow({
    required this.id,
    required this.totalPerContractToggle,
    required this.deltaConventionDefault,
    required this.firstRunExplainerShown,
    required this.ivResolutionNoticeDismissed,
    required this.exportReminderDismissed,
    this.lastExportAtMs,
    required this.notificationMilestones,
    this.wheelCapitalCents,
    required this.concentrationLimitPct,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['total_per_contract_toggle'] = Variable<bool>(totalPerContractToggle);
    {
      map['delta_convention_default'] = Variable<String>(
        $UserPreferencesTableTable.$converterdeltaConventionDefault.toSql(
          deltaConventionDefault,
        ),
      );
    }
    map['first_run_explainer_shown'] = Variable<bool>(firstRunExplainerShown);
    map['iv_resolution_notice_dismissed'] = Variable<bool>(
      ivResolutionNoticeDismissed,
    );
    map['export_reminder_dismissed'] = Variable<bool>(exportReminderDismissed);
    if (!nullToAbsent || lastExportAtMs != null) {
      map['last_export_at_ms'] = Variable<int>(
        $UserPreferencesTableTable.$converterlastExportAtMs.toSql(
          lastExportAtMs,
        ),
      );
    }
    {
      map['notification_milestones'] = Variable<String>(
        $UserPreferencesTableTable.$converternotificationMilestones.toSql(
          notificationMilestones,
        ),
      );
    }
    if (!nullToAbsent || wheelCapitalCents != null) {
      map['wheel_capital_cents'] = Variable<int>(
        $UserPreferencesTableTable.$converterwheelCapitalCents.toSql(
          wheelCapitalCents,
        ),
      );
    }
    map['concentration_limit_pct'] = Variable<double>(concentrationLimitPct);
    return map;
  }

  UserPreferencesTableCompanion toCompanion(bool nullToAbsent) {
    return UserPreferencesTableCompanion(
      id: Value(id),
      totalPerContractToggle: Value(totalPerContractToggle),
      deltaConventionDefault: Value(deltaConventionDefault),
      firstRunExplainerShown: Value(firstRunExplainerShown),
      ivResolutionNoticeDismissed: Value(ivResolutionNoticeDismissed),
      exportReminderDismissed: Value(exportReminderDismissed),
      lastExportAtMs: lastExportAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(lastExportAtMs),
      notificationMilestones: Value(notificationMilestones),
      wheelCapitalCents: wheelCapitalCents == null && nullToAbsent
          ? const Value.absent()
          : Value(wheelCapitalCents),
      concentrationLimitPct: Value(concentrationLimitPct),
    );
  }

  factory UserPreferencesRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserPreferencesRow(
      id: serializer.fromJson<String>(json['id']),
      totalPerContractToggle: serializer.fromJson<bool>(
        json['totalPerContractToggle'],
      ),
      deltaConventionDefault: serializer.fromJson<DeltaConvention>(
        json['deltaConventionDefault'],
      ),
      firstRunExplainerShown: serializer.fromJson<bool>(
        json['firstRunExplainerShown'],
      ),
      ivResolutionNoticeDismissed: serializer.fromJson<bool>(
        json['ivResolutionNoticeDismissed'],
      ),
      exportReminderDismissed: serializer.fromJson<bool>(
        json['exportReminderDismissed'],
      ),
      lastExportAtMs: serializer.fromJson<DateTime?>(json['lastExportAtMs']),
      notificationMilestones: serializer.fromJson<List<int>>(
        json['notificationMilestones'],
      ),
      wheelCapitalCents: serializer.fromJson<Decimal?>(
        json['wheelCapitalCents'],
      ),
      concentrationLimitPct: serializer.fromJson<double>(
        json['concentrationLimitPct'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'totalPerContractToggle': serializer.toJson<bool>(totalPerContractToggle),
      'deltaConventionDefault': serializer.toJson<DeltaConvention>(
        deltaConventionDefault,
      ),
      'firstRunExplainerShown': serializer.toJson<bool>(firstRunExplainerShown),
      'ivResolutionNoticeDismissed': serializer.toJson<bool>(
        ivResolutionNoticeDismissed,
      ),
      'exportReminderDismissed': serializer.toJson<bool>(
        exportReminderDismissed,
      ),
      'lastExportAtMs': serializer.toJson<DateTime?>(lastExportAtMs),
      'notificationMilestones': serializer.toJson<List<int>>(
        notificationMilestones,
      ),
      'wheelCapitalCents': serializer.toJson<Decimal?>(wheelCapitalCents),
      'concentrationLimitPct': serializer.toJson<double>(concentrationLimitPct),
    };
  }

  UserPreferencesRow copyWith({
    String? id,
    bool? totalPerContractToggle,
    DeltaConvention? deltaConventionDefault,
    bool? firstRunExplainerShown,
    bool? ivResolutionNoticeDismissed,
    bool? exportReminderDismissed,
    Value<DateTime?> lastExportAtMs = const Value.absent(),
    List<int>? notificationMilestones,
    Value<Decimal?> wheelCapitalCents = const Value.absent(),
    double? concentrationLimitPct,
  }) => UserPreferencesRow(
    id: id ?? this.id,
    totalPerContractToggle:
        totalPerContractToggle ?? this.totalPerContractToggle,
    deltaConventionDefault:
        deltaConventionDefault ?? this.deltaConventionDefault,
    firstRunExplainerShown:
        firstRunExplainerShown ?? this.firstRunExplainerShown,
    ivResolutionNoticeDismissed:
        ivResolutionNoticeDismissed ?? this.ivResolutionNoticeDismissed,
    exportReminderDismissed:
        exportReminderDismissed ?? this.exportReminderDismissed,
    lastExportAtMs: lastExportAtMs.present
        ? lastExportAtMs.value
        : this.lastExportAtMs,
    notificationMilestones:
        notificationMilestones ?? this.notificationMilestones,
    wheelCapitalCents: wheelCapitalCents.present
        ? wheelCapitalCents.value
        : this.wheelCapitalCents,
    concentrationLimitPct: concentrationLimitPct ?? this.concentrationLimitPct,
  );
  UserPreferencesRow copyWithCompanion(UserPreferencesTableCompanion data) {
    return UserPreferencesRow(
      id: data.id.present ? data.id.value : this.id,
      totalPerContractToggle: data.totalPerContractToggle.present
          ? data.totalPerContractToggle.value
          : this.totalPerContractToggle,
      deltaConventionDefault: data.deltaConventionDefault.present
          ? data.deltaConventionDefault.value
          : this.deltaConventionDefault,
      firstRunExplainerShown: data.firstRunExplainerShown.present
          ? data.firstRunExplainerShown.value
          : this.firstRunExplainerShown,
      ivResolutionNoticeDismissed: data.ivResolutionNoticeDismissed.present
          ? data.ivResolutionNoticeDismissed.value
          : this.ivResolutionNoticeDismissed,
      exportReminderDismissed: data.exportReminderDismissed.present
          ? data.exportReminderDismissed.value
          : this.exportReminderDismissed,
      lastExportAtMs: data.lastExportAtMs.present
          ? data.lastExportAtMs.value
          : this.lastExportAtMs,
      notificationMilestones: data.notificationMilestones.present
          ? data.notificationMilestones.value
          : this.notificationMilestones,
      wheelCapitalCents: data.wheelCapitalCents.present
          ? data.wheelCapitalCents.value
          : this.wheelCapitalCents,
      concentrationLimitPct: data.concentrationLimitPct.present
          ? data.concentrationLimitPct.value
          : this.concentrationLimitPct,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserPreferencesRow(')
          ..write('id: $id, ')
          ..write('totalPerContractToggle: $totalPerContractToggle, ')
          ..write('deltaConventionDefault: $deltaConventionDefault, ')
          ..write('firstRunExplainerShown: $firstRunExplainerShown, ')
          ..write('ivResolutionNoticeDismissed: $ivResolutionNoticeDismissed, ')
          ..write('exportReminderDismissed: $exportReminderDismissed, ')
          ..write('lastExportAtMs: $lastExportAtMs, ')
          ..write('notificationMilestones: $notificationMilestones, ')
          ..write('wheelCapitalCents: $wheelCapitalCents, ')
          ..write('concentrationLimitPct: $concentrationLimitPct')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    totalPerContractToggle,
    deltaConventionDefault,
    firstRunExplainerShown,
    ivResolutionNoticeDismissed,
    exportReminderDismissed,
    lastExportAtMs,
    notificationMilestones,
    wheelCapitalCents,
    concentrationLimitPct,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserPreferencesRow &&
          other.id == this.id &&
          other.totalPerContractToggle == this.totalPerContractToggle &&
          other.deltaConventionDefault == this.deltaConventionDefault &&
          other.firstRunExplainerShown == this.firstRunExplainerShown &&
          other.ivResolutionNoticeDismissed ==
              this.ivResolutionNoticeDismissed &&
          other.exportReminderDismissed == this.exportReminderDismissed &&
          other.lastExportAtMs == this.lastExportAtMs &&
          other.notificationMilestones == this.notificationMilestones &&
          other.wheelCapitalCents == this.wheelCapitalCents &&
          other.concentrationLimitPct == this.concentrationLimitPct);
}

class UserPreferencesTableCompanion
    extends UpdateCompanion<UserPreferencesRow> {
  final Value<String> id;
  final Value<bool> totalPerContractToggle;
  final Value<DeltaConvention> deltaConventionDefault;
  final Value<bool> firstRunExplainerShown;
  final Value<bool> ivResolutionNoticeDismissed;
  final Value<bool> exportReminderDismissed;
  final Value<DateTime?> lastExportAtMs;
  final Value<List<int>> notificationMilestones;
  final Value<Decimal?> wheelCapitalCents;
  final Value<double> concentrationLimitPct;
  final Value<int> rowid;
  const UserPreferencesTableCompanion({
    this.id = const Value.absent(),
    this.totalPerContractToggle = const Value.absent(),
    this.deltaConventionDefault = const Value.absent(),
    this.firstRunExplainerShown = const Value.absent(),
    this.ivResolutionNoticeDismissed = const Value.absent(),
    this.exportReminderDismissed = const Value.absent(),
    this.lastExportAtMs = const Value.absent(),
    this.notificationMilestones = const Value.absent(),
    this.wheelCapitalCents = const Value.absent(),
    this.concentrationLimitPct = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserPreferencesTableCompanion.insert({
    required String id,
    required bool totalPerContractToggle,
    required DeltaConvention deltaConventionDefault,
    required bool firstRunExplainerShown,
    required bool ivResolutionNoticeDismissed,
    this.exportReminderDismissed = const Value.absent(),
    this.lastExportAtMs = const Value.absent(),
    this.notificationMilestones = const Value.absent(),
    this.wheelCapitalCents = const Value.absent(),
    this.concentrationLimitPct = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       totalPerContractToggle = Value(totalPerContractToggle),
       deltaConventionDefault = Value(deltaConventionDefault),
       firstRunExplainerShown = Value(firstRunExplainerShown),
       ivResolutionNoticeDismissed = Value(ivResolutionNoticeDismissed);
  static Insertable<UserPreferencesRow> custom({
    Expression<String>? id,
    Expression<bool>? totalPerContractToggle,
    Expression<String>? deltaConventionDefault,
    Expression<bool>? firstRunExplainerShown,
    Expression<bool>? ivResolutionNoticeDismissed,
    Expression<bool>? exportReminderDismissed,
    Expression<int>? lastExportAtMs,
    Expression<String>? notificationMilestones,
    Expression<int>? wheelCapitalCents,
    Expression<double>? concentrationLimitPct,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (totalPerContractToggle != null)
        'total_per_contract_toggle': totalPerContractToggle,
      if (deltaConventionDefault != null)
        'delta_convention_default': deltaConventionDefault,
      if (firstRunExplainerShown != null)
        'first_run_explainer_shown': firstRunExplainerShown,
      if (ivResolutionNoticeDismissed != null)
        'iv_resolution_notice_dismissed': ivResolutionNoticeDismissed,
      if (exportReminderDismissed != null)
        'export_reminder_dismissed': exportReminderDismissed,
      if (lastExportAtMs != null) 'last_export_at_ms': lastExportAtMs,
      if (notificationMilestones != null)
        'notification_milestones': notificationMilestones,
      if (wheelCapitalCents != null) 'wheel_capital_cents': wheelCapitalCents,
      if (concentrationLimitPct != null)
        'concentration_limit_pct': concentrationLimitPct,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserPreferencesTableCompanion copyWith({
    Value<String>? id,
    Value<bool>? totalPerContractToggle,
    Value<DeltaConvention>? deltaConventionDefault,
    Value<bool>? firstRunExplainerShown,
    Value<bool>? ivResolutionNoticeDismissed,
    Value<bool>? exportReminderDismissed,
    Value<DateTime?>? lastExportAtMs,
    Value<List<int>>? notificationMilestones,
    Value<Decimal?>? wheelCapitalCents,
    Value<double>? concentrationLimitPct,
    Value<int>? rowid,
  }) {
    return UserPreferencesTableCompanion(
      id: id ?? this.id,
      totalPerContractToggle:
          totalPerContractToggle ?? this.totalPerContractToggle,
      deltaConventionDefault:
          deltaConventionDefault ?? this.deltaConventionDefault,
      firstRunExplainerShown:
          firstRunExplainerShown ?? this.firstRunExplainerShown,
      ivResolutionNoticeDismissed:
          ivResolutionNoticeDismissed ?? this.ivResolutionNoticeDismissed,
      exportReminderDismissed:
          exportReminderDismissed ?? this.exportReminderDismissed,
      lastExportAtMs: lastExportAtMs ?? this.lastExportAtMs,
      notificationMilestones:
          notificationMilestones ?? this.notificationMilestones,
      wheelCapitalCents: wheelCapitalCents ?? this.wheelCapitalCents,
      concentrationLimitPct:
          concentrationLimitPct ?? this.concentrationLimitPct,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (totalPerContractToggle.present) {
      map['total_per_contract_toggle'] = Variable<bool>(
        totalPerContractToggle.value,
      );
    }
    if (deltaConventionDefault.present) {
      map['delta_convention_default'] = Variable<String>(
        $UserPreferencesTableTable.$converterdeltaConventionDefault.toSql(
          deltaConventionDefault.value,
        ),
      );
    }
    if (firstRunExplainerShown.present) {
      map['first_run_explainer_shown'] = Variable<bool>(
        firstRunExplainerShown.value,
      );
    }
    if (ivResolutionNoticeDismissed.present) {
      map['iv_resolution_notice_dismissed'] = Variable<bool>(
        ivResolutionNoticeDismissed.value,
      );
    }
    if (exportReminderDismissed.present) {
      map['export_reminder_dismissed'] = Variable<bool>(
        exportReminderDismissed.value,
      );
    }
    if (lastExportAtMs.present) {
      map['last_export_at_ms'] = Variable<int>(
        $UserPreferencesTableTable.$converterlastExportAtMs.toSql(
          lastExportAtMs.value,
        ),
      );
    }
    if (notificationMilestones.present) {
      map['notification_milestones'] = Variable<String>(
        $UserPreferencesTableTable.$converternotificationMilestones.toSql(
          notificationMilestones.value,
        ),
      );
    }
    if (wheelCapitalCents.present) {
      map['wheel_capital_cents'] = Variable<int>(
        $UserPreferencesTableTable.$converterwheelCapitalCents.toSql(
          wheelCapitalCents.value,
        ),
      );
    }
    if (concentrationLimitPct.present) {
      map['concentration_limit_pct'] = Variable<double>(
        concentrationLimitPct.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserPreferencesTableCompanion(')
          ..write('id: $id, ')
          ..write('totalPerContractToggle: $totalPerContractToggle, ')
          ..write('deltaConventionDefault: $deltaConventionDefault, ')
          ..write('firstRunExplainerShown: $firstRunExplainerShown, ')
          ..write('ivResolutionNoticeDismissed: $ivResolutionNoticeDismissed, ')
          ..write('exportReminderDismissed: $exportReminderDismissed, ')
          ..write('lastExportAtMs: $lastExportAtMs, ')
          ..write('notificationMilestones: $notificationMilestones, ')
          ..write('wheelCapitalCents: $wheelCapitalCents, ')
          ..write('concentrationLimitPct: $concentrationLimitPct, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UnderlyingTableTable underlyingTable = $UnderlyingTableTable(
    this,
  );
  late final $WheelCycleTableTable wheelCycleTable = $WheelCycleTableTable(
    this,
  );
  late final $LegTableTable legTable = $LegTableTable(this);
  late final $SnapshotTableTable snapshotTable = $SnapshotTableTable(this);
  late final $ShareLotTableTable shareLotTable = $ShareLotTableTable(this);
  late final $RuleProfileTableTable ruleProfileTable = $RuleProfileTableTable(
    this,
  );
  late final $RuleProfileVersionTableTable ruleProfileVersionTable =
      $RuleProfileVersionTableTable(this);
  late final $UserPreferencesTableTable userPreferencesTable =
      $UserPreferencesTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    underlyingTable,
    wheelCycleTable,
    legTable,
    snapshotTable,
    shareLotTable,
    ruleProfileTable,
    ruleProfileVersionTable,
    userPreferencesTable,
  ];
}

typedef $$UnderlyingTableTableCreateCompanionBuilder =
    UnderlyingTableCompanion Function({
      required String id,
      required String ticker,
      Value<String?> displayName,
      Value<String?> notes,
      Value<int> rowid,
    });
typedef $$UnderlyingTableTableUpdateCompanionBuilder =
    UnderlyingTableCompanion Function({
      Value<String> id,
      Value<String> ticker,
      Value<String?> displayName,
      Value<String?> notes,
      Value<int> rowid,
    });

class $$UnderlyingTableTableFilterComposer
    extends Composer<_$AppDatabase, $UnderlyingTableTable> {
  $$UnderlyingTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ticker => $composableBuilder(
    column: $table.ticker,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UnderlyingTableTableOrderingComposer
    extends Composer<_$AppDatabase, $UnderlyingTableTable> {
  $$UnderlyingTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ticker => $composableBuilder(
    column: $table.ticker,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UnderlyingTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $UnderlyingTableTable> {
  $$UnderlyingTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ticker =>
      $composableBuilder(column: $table.ticker, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);
}

class $$UnderlyingTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UnderlyingTableTable,
          UnderlyingRow,
          $$UnderlyingTableTableFilterComposer,
          $$UnderlyingTableTableOrderingComposer,
          $$UnderlyingTableTableAnnotationComposer,
          $$UnderlyingTableTableCreateCompanionBuilder,
          $$UnderlyingTableTableUpdateCompanionBuilder,
          (
            UnderlyingRow,
            BaseReferences<_$AppDatabase, $UnderlyingTableTable, UnderlyingRow>,
          ),
          UnderlyingRow,
          PrefetchHooks Function()
        > {
  $$UnderlyingTableTableTableManager(
    _$AppDatabase db,
    $UnderlyingTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UnderlyingTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UnderlyingTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UnderlyingTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ticker = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UnderlyingTableCompanion(
                id: id,
                ticker: ticker,
                displayName: displayName,
                notes: notes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ticker,
                Value<String?> displayName = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UnderlyingTableCompanion.insert(
                id: id,
                ticker: ticker,
                displayName: displayName,
                notes: notes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UnderlyingTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UnderlyingTableTable,
      UnderlyingRow,
      $$UnderlyingTableTableFilterComposer,
      $$UnderlyingTableTableOrderingComposer,
      $$UnderlyingTableTableAnnotationComposer,
      $$UnderlyingTableTableCreateCompanionBuilder,
      $$UnderlyingTableTableUpdateCompanionBuilder,
      (
        UnderlyingRow,
        BaseReferences<_$AppDatabase, $UnderlyingTableTable, UnderlyingRow>,
      ),
      UnderlyingRow,
      PrefetchHooks Function()
    >;
typedef $$WheelCycleTableTableCreateCompanionBuilder =
    WheelCycleTableCompanion Function({
      required String id,
      required String underlyingId,
      required DateTime startedAtMs,
      Value<DateTime?> endedAtMs,
      required WheelCycleStatus status,
      Value<WheelCycleOutcome?> outcome,
      Value<int> rowid,
    });
typedef $$WheelCycleTableTableUpdateCompanionBuilder =
    WheelCycleTableCompanion Function({
      Value<String> id,
      Value<String> underlyingId,
      Value<DateTime> startedAtMs,
      Value<DateTime?> endedAtMs,
      Value<WheelCycleStatus> status,
      Value<WheelCycleOutcome?> outcome,
      Value<int> rowid,
    });

class $$WheelCycleTableTableFilterComposer
    extends Composer<_$AppDatabase, $WheelCycleTableTable> {
  $$WheelCycleTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get underlyingId => $composableBuilder(
    column: $table.underlyingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get startedAtMs =>
      $composableBuilder(
        column: $table.startedAtMs,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get endedAtMs =>
      $composableBuilder(
        column: $table.endedAtMs,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<WheelCycleStatus, WheelCycleStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<WheelCycleOutcome?, WheelCycleOutcome, String>
  get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );
}

class $$WheelCycleTableTableOrderingComposer
    extends Composer<_$AppDatabase, $WheelCycleTableTable> {
  $$WheelCycleTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get underlyingId => $composableBuilder(
    column: $table.underlyingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAtMs => $composableBuilder(
    column: $table.startedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endedAtMs => $composableBuilder(
    column: $table.endedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WheelCycleTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $WheelCycleTableTable> {
  $$WheelCycleTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get underlyingId => $composableBuilder(
    column: $table.underlyingId,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime, int> get startedAtMs =>
      $composableBuilder(
        column: $table.startedAtMs,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<DateTime?, int> get endedAtMs =>
      $composableBuilder(column: $table.endedAtMs, builder: (column) => column);

  GeneratedColumnWithTypeConverter<WheelCycleStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumnWithTypeConverter<WheelCycleOutcome?, String> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);
}

class $$WheelCycleTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WheelCycleTableTable,
          WheelCycleRow,
          $$WheelCycleTableTableFilterComposer,
          $$WheelCycleTableTableOrderingComposer,
          $$WheelCycleTableTableAnnotationComposer,
          $$WheelCycleTableTableCreateCompanionBuilder,
          $$WheelCycleTableTableUpdateCompanionBuilder,
          (
            WheelCycleRow,
            BaseReferences<_$AppDatabase, $WheelCycleTableTable, WheelCycleRow>,
          ),
          WheelCycleRow,
          PrefetchHooks Function()
        > {
  $$WheelCycleTableTableTableManager(
    _$AppDatabase db,
    $WheelCycleTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WheelCycleTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WheelCycleTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WheelCycleTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> underlyingId = const Value.absent(),
                Value<DateTime> startedAtMs = const Value.absent(),
                Value<DateTime?> endedAtMs = const Value.absent(),
                Value<WheelCycleStatus> status = const Value.absent(),
                Value<WheelCycleOutcome?> outcome = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WheelCycleTableCompanion(
                id: id,
                underlyingId: underlyingId,
                startedAtMs: startedAtMs,
                endedAtMs: endedAtMs,
                status: status,
                outcome: outcome,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String underlyingId,
                required DateTime startedAtMs,
                Value<DateTime?> endedAtMs = const Value.absent(),
                required WheelCycleStatus status,
                Value<WheelCycleOutcome?> outcome = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WheelCycleTableCompanion.insert(
                id: id,
                underlyingId: underlyingId,
                startedAtMs: startedAtMs,
                endedAtMs: endedAtMs,
                status: status,
                outcome: outcome,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WheelCycleTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WheelCycleTableTable,
      WheelCycleRow,
      $$WheelCycleTableTableFilterComposer,
      $$WheelCycleTableTableOrderingComposer,
      $$WheelCycleTableTableAnnotationComposer,
      $$WheelCycleTableTableCreateCompanionBuilder,
      $$WheelCycleTableTableUpdateCompanionBuilder,
      (
        WheelCycleRow,
        BaseReferences<_$AppDatabase, $WheelCycleTableTable, WheelCycleRow>,
      ),
      WheelCycleRow,
      PrefetchHooks Function()
    >;
typedef $$LegTableTableCreateCompanionBuilder =
    LegTableCompanion Function({
      required String id,
      required String cycleId,
      required int sequence,
      required OptionType optionType,
      required Decimal strike,
      required DateTime expirationMs,
      required int contracts,
      required DateTime openedAtMs,
      required Decimal openCreditPerShare,
      Value<DateTime?> closedAtMs,
      Value<Decimal?> closeDebitPerShare,
      Value<CloseReason?> closeReason,
      Value<String?> rolledFromLegId,
      required String ruleProfileVersionId,
      Value<double?> ivAtOpen,
      Value<double?> ivRankAtOpen,
      Value<double?> deltaAtOpen,
      Value<Decimal?> underlyingPriceAtOpen,
      Value<Decimal?> openFee,
      Value<Decimal?> closeFee,
      Value<bool> acceptsAssignment,
      Value<int> rowid,
    });
typedef $$LegTableTableUpdateCompanionBuilder =
    LegTableCompanion Function({
      Value<String> id,
      Value<String> cycleId,
      Value<int> sequence,
      Value<OptionType> optionType,
      Value<Decimal> strike,
      Value<DateTime> expirationMs,
      Value<int> contracts,
      Value<DateTime> openedAtMs,
      Value<Decimal> openCreditPerShare,
      Value<DateTime?> closedAtMs,
      Value<Decimal?> closeDebitPerShare,
      Value<CloseReason?> closeReason,
      Value<String?> rolledFromLegId,
      Value<String> ruleProfileVersionId,
      Value<double?> ivAtOpen,
      Value<double?> ivRankAtOpen,
      Value<double?> deltaAtOpen,
      Value<Decimal?> underlyingPriceAtOpen,
      Value<Decimal?> openFee,
      Value<Decimal?> closeFee,
      Value<bool> acceptsAssignment,
      Value<int> rowid,
    });

class $$LegTableTableFilterComposer
    extends Composer<_$AppDatabase, $LegTableTable> {
  $$LegTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cycleId => $composableBuilder(
    column: $table.cycleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<OptionType, OptionType, String>
  get optionType => $composableBuilder(
    column: $table.optionType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal, Decimal, int> get strike =>
      $composableBuilder(
        column: $table.strike,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get expirationMs =>
      $composableBuilder(
        column: $table.expirationMs,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get contracts => $composableBuilder(
    column: $table.contracts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get openedAtMs =>
      $composableBuilder(
        column: $table.openedAtMs,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Decimal, Decimal, int>
  get openCreditPerShare => $composableBuilder(
    column: $table.openCreditPerShare,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get closedAtMs =>
      $composableBuilder(
        column: $table.closedAtMs,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Decimal?, Decimal, int>
  get closeDebitPerShare => $composableBuilder(
    column: $table.closeDebitPerShare,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<CloseReason?, CloseReason, String>
  get closeReason => $composableBuilder(
    column: $table.closeReason,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get rolledFromLegId => $composableBuilder(
    column: $table.rolledFromLegId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ruleProfileVersionId => $composableBuilder(
    column: $table.ruleProfileVersionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get ivAtOpen => $composableBuilder(
    column: $table.ivAtOpen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get ivRankAtOpen => $composableBuilder(
    column: $table.ivRankAtOpen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get deltaAtOpen => $composableBuilder(
    column: $table.deltaAtOpen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal?, Decimal, int>
  get underlyingPriceAtOpen => $composableBuilder(
    column: $table.underlyingPriceAtOpen,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal?, Decimal, int> get openFee =>
      $composableBuilder(
        column: $table.openFee,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Decimal?, Decimal, int> get closeFee =>
      $composableBuilder(
        column: $table.closeFee,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get acceptsAssignment => $composableBuilder(
    column: $table.acceptsAssignment,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LegTableTableOrderingComposer
    extends Composer<_$AppDatabase, $LegTableTable> {
  $$LegTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cycleId => $composableBuilder(
    column: $table.cycleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get optionType => $composableBuilder(
    column: $table.optionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get strike => $composableBuilder(
    column: $table.strike,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expirationMs => $composableBuilder(
    column: $table.expirationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get contracts => $composableBuilder(
    column: $table.contracts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get openedAtMs => $composableBuilder(
    column: $table.openedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get openCreditPerShare => $composableBuilder(
    column: $table.openCreditPerShare,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get closedAtMs => $composableBuilder(
    column: $table.closedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get closeDebitPerShare => $composableBuilder(
    column: $table.closeDebitPerShare,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get closeReason => $composableBuilder(
    column: $table.closeReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rolledFromLegId => $composableBuilder(
    column: $table.rolledFromLegId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ruleProfileVersionId => $composableBuilder(
    column: $table.ruleProfileVersionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ivAtOpen => $composableBuilder(
    column: $table.ivAtOpen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ivRankAtOpen => $composableBuilder(
    column: $table.ivRankAtOpen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get deltaAtOpen => $composableBuilder(
    column: $table.deltaAtOpen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get underlyingPriceAtOpen => $composableBuilder(
    column: $table.underlyingPriceAtOpen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get openFee => $composableBuilder(
    column: $table.openFee,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get closeFee => $composableBuilder(
    column: $table.closeFee,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get acceptsAssignment => $composableBuilder(
    column: $table.acceptsAssignment,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LegTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $LegTableTable> {
  $$LegTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get cycleId =>
      $composableBuilder(column: $table.cycleId, builder: (column) => column);

  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumnWithTypeConverter<OptionType, String> get optionType =>
      $composableBuilder(
        column: $table.optionType,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<Decimal, int> get strike =>
      $composableBuilder(column: $table.strike, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get expirationMs =>
      $composableBuilder(
        column: $table.expirationMs,
        builder: (column) => column,
      );

  GeneratedColumn<int> get contracts =>
      $composableBuilder(column: $table.contracts, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get openedAtMs =>
      $composableBuilder(
        column: $table.openedAtMs,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<Decimal, int> get openCreditPerShare =>
      $composableBuilder(
        column: $table.openCreditPerShare,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<DateTime?, int> get closedAtMs =>
      $composableBuilder(
        column: $table.closedAtMs,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<Decimal?, int> get closeDebitPerShare =>
      $composableBuilder(
        column: $table.closeDebitPerShare,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<CloseReason?, String> get closeReason =>
      $composableBuilder(
        column: $table.closeReason,
        builder: (column) => column,
      );

  GeneratedColumn<String> get rolledFromLegId => $composableBuilder(
    column: $table.rolledFromLegId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ruleProfileVersionId => $composableBuilder(
    column: $table.ruleProfileVersionId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get ivAtOpen =>
      $composableBuilder(column: $table.ivAtOpen, builder: (column) => column);

  GeneratedColumn<double> get ivRankAtOpen => $composableBuilder(
    column: $table.ivRankAtOpen,
    builder: (column) => column,
  );

  GeneratedColumn<double> get deltaAtOpen => $composableBuilder(
    column: $table.deltaAtOpen,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Decimal?, int> get underlyingPriceAtOpen =>
      $composableBuilder(
        column: $table.underlyingPriceAtOpen,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<Decimal?, int> get openFee =>
      $composableBuilder(column: $table.openFee, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Decimal?, int> get closeFee =>
      $composableBuilder(column: $table.closeFee, builder: (column) => column);

  GeneratedColumn<bool> get acceptsAssignment => $composableBuilder(
    column: $table.acceptsAssignment,
    builder: (column) => column,
  );
}

class $$LegTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LegTableTable,
          LegRow,
          $$LegTableTableFilterComposer,
          $$LegTableTableOrderingComposer,
          $$LegTableTableAnnotationComposer,
          $$LegTableTableCreateCompanionBuilder,
          $$LegTableTableUpdateCompanionBuilder,
          (LegRow, BaseReferences<_$AppDatabase, $LegTableTable, LegRow>),
          LegRow,
          PrefetchHooks Function()
        > {
  $$LegTableTableTableManager(_$AppDatabase db, $LegTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LegTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LegTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LegTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> cycleId = const Value.absent(),
                Value<int> sequence = const Value.absent(),
                Value<OptionType> optionType = const Value.absent(),
                Value<Decimal> strike = const Value.absent(),
                Value<DateTime> expirationMs = const Value.absent(),
                Value<int> contracts = const Value.absent(),
                Value<DateTime> openedAtMs = const Value.absent(),
                Value<Decimal> openCreditPerShare = const Value.absent(),
                Value<DateTime?> closedAtMs = const Value.absent(),
                Value<Decimal?> closeDebitPerShare = const Value.absent(),
                Value<CloseReason?> closeReason = const Value.absent(),
                Value<String?> rolledFromLegId = const Value.absent(),
                Value<String> ruleProfileVersionId = const Value.absent(),
                Value<double?> ivAtOpen = const Value.absent(),
                Value<double?> ivRankAtOpen = const Value.absent(),
                Value<double?> deltaAtOpen = const Value.absent(),
                Value<Decimal?> underlyingPriceAtOpen = const Value.absent(),
                Value<Decimal?> openFee = const Value.absent(),
                Value<Decimal?> closeFee = const Value.absent(),
                Value<bool> acceptsAssignment = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LegTableCompanion(
                id: id,
                cycleId: cycleId,
                sequence: sequence,
                optionType: optionType,
                strike: strike,
                expirationMs: expirationMs,
                contracts: contracts,
                openedAtMs: openedAtMs,
                openCreditPerShare: openCreditPerShare,
                closedAtMs: closedAtMs,
                closeDebitPerShare: closeDebitPerShare,
                closeReason: closeReason,
                rolledFromLegId: rolledFromLegId,
                ruleProfileVersionId: ruleProfileVersionId,
                ivAtOpen: ivAtOpen,
                ivRankAtOpen: ivRankAtOpen,
                deltaAtOpen: deltaAtOpen,
                underlyingPriceAtOpen: underlyingPriceAtOpen,
                openFee: openFee,
                closeFee: closeFee,
                acceptsAssignment: acceptsAssignment,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String cycleId,
                required int sequence,
                required OptionType optionType,
                required Decimal strike,
                required DateTime expirationMs,
                required int contracts,
                required DateTime openedAtMs,
                required Decimal openCreditPerShare,
                Value<DateTime?> closedAtMs = const Value.absent(),
                Value<Decimal?> closeDebitPerShare = const Value.absent(),
                Value<CloseReason?> closeReason = const Value.absent(),
                Value<String?> rolledFromLegId = const Value.absent(),
                required String ruleProfileVersionId,
                Value<double?> ivAtOpen = const Value.absent(),
                Value<double?> ivRankAtOpen = const Value.absent(),
                Value<double?> deltaAtOpen = const Value.absent(),
                Value<Decimal?> underlyingPriceAtOpen = const Value.absent(),
                Value<Decimal?> openFee = const Value.absent(),
                Value<Decimal?> closeFee = const Value.absent(),
                Value<bool> acceptsAssignment = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LegTableCompanion.insert(
                id: id,
                cycleId: cycleId,
                sequence: sequence,
                optionType: optionType,
                strike: strike,
                expirationMs: expirationMs,
                contracts: contracts,
                openedAtMs: openedAtMs,
                openCreditPerShare: openCreditPerShare,
                closedAtMs: closedAtMs,
                closeDebitPerShare: closeDebitPerShare,
                closeReason: closeReason,
                rolledFromLegId: rolledFromLegId,
                ruleProfileVersionId: ruleProfileVersionId,
                ivAtOpen: ivAtOpen,
                ivRankAtOpen: ivRankAtOpen,
                deltaAtOpen: deltaAtOpen,
                underlyingPriceAtOpen: underlyingPriceAtOpen,
                openFee: openFee,
                closeFee: closeFee,
                acceptsAssignment: acceptsAssignment,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LegTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LegTableTable,
      LegRow,
      $$LegTableTableFilterComposer,
      $$LegTableTableOrderingComposer,
      $$LegTableTableAnnotationComposer,
      $$LegTableTableCreateCompanionBuilder,
      $$LegTableTableUpdateCompanionBuilder,
      (LegRow, BaseReferences<_$AppDatabase, $LegTableTable, LegRow>),
      LegRow,
      PrefetchHooks Function()
    >;
typedef $$SnapshotTableTableCreateCompanionBuilder =
    SnapshotTableCompanion Function({
      required String id,
      required String legId,
      required DateTime takenAtMs,
      required Decimal optionMark,
      required Decimal underlyingPrice,
      required double deltaAsEntered,
      required DeltaConvention deltaConvention,
      Value<double?> gamma,
      Value<double?> theta,
      Value<double?> vega,
      Value<double?> iv,
      Value<int?> openInterest,
      Value<int?> volume,
      Value<int> rowid,
    });
typedef $$SnapshotTableTableUpdateCompanionBuilder =
    SnapshotTableCompanion Function({
      Value<String> id,
      Value<String> legId,
      Value<DateTime> takenAtMs,
      Value<Decimal> optionMark,
      Value<Decimal> underlyingPrice,
      Value<double> deltaAsEntered,
      Value<DeltaConvention> deltaConvention,
      Value<double?> gamma,
      Value<double?> theta,
      Value<double?> vega,
      Value<double?> iv,
      Value<int?> openInterest,
      Value<int?> volume,
      Value<int> rowid,
    });

class $$SnapshotTableTableFilterComposer
    extends Composer<_$AppDatabase, $SnapshotTableTable> {
  $$SnapshotTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get legId => $composableBuilder(
    column: $table.legId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get takenAtMs =>
      $composableBuilder(
        column: $table.takenAtMs,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Decimal, Decimal, int> get optionMark =>
      $composableBuilder(
        column: $table.optionMark,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Decimal, Decimal, int> get underlyingPrice =>
      $composableBuilder(
        column: $table.underlyingPrice,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<double> get deltaAsEntered => $composableBuilder(
    column: $table.deltaAsEntered,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DeltaConvention, DeltaConvention, String>
  get deltaConvention => $composableBuilder(
    column: $table.deltaConvention,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<double> get gamma => $composableBuilder(
    column: $table.gamma,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get theta => $composableBuilder(
    column: $table.theta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get vega => $composableBuilder(
    column: $table.vega,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get iv => $composableBuilder(
    column: $table.iv,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get openInterest => $composableBuilder(
    column: $table.openInterest,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get volume => $composableBuilder(
    column: $table.volume,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SnapshotTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SnapshotTableTable> {
  $$SnapshotTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get legId => $composableBuilder(
    column: $table.legId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get takenAtMs => $composableBuilder(
    column: $table.takenAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get optionMark => $composableBuilder(
    column: $table.optionMark,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get underlyingPrice => $composableBuilder(
    column: $table.underlyingPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get deltaAsEntered => $composableBuilder(
    column: $table.deltaAsEntered,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deltaConvention => $composableBuilder(
    column: $table.deltaConvention,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get gamma => $composableBuilder(
    column: $table.gamma,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get theta => $composableBuilder(
    column: $table.theta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get vega => $composableBuilder(
    column: $table.vega,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get iv => $composableBuilder(
    column: $table.iv,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get openInterest => $composableBuilder(
    column: $table.openInterest,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get volume => $composableBuilder(
    column: $table.volume,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SnapshotTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SnapshotTableTable> {
  $$SnapshotTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get legId =>
      $composableBuilder(column: $table.legId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get takenAtMs =>
      $composableBuilder(column: $table.takenAtMs, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Decimal, int> get optionMark =>
      $composableBuilder(
        column: $table.optionMark,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<Decimal, int> get underlyingPrice =>
      $composableBuilder(
        column: $table.underlyingPrice,
        builder: (column) => column,
      );

  GeneratedColumn<double> get deltaAsEntered => $composableBuilder(
    column: $table.deltaAsEntered,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DeltaConvention, String>
  get deltaConvention => $composableBuilder(
    column: $table.deltaConvention,
    builder: (column) => column,
  );

  GeneratedColumn<double> get gamma =>
      $composableBuilder(column: $table.gamma, builder: (column) => column);

  GeneratedColumn<double> get theta =>
      $composableBuilder(column: $table.theta, builder: (column) => column);

  GeneratedColumn<double> get vega =>
      $composableBuilder(column: $table.vega, builder: (column) => column);

  GeneratedColumn<double> get iv =>
      $composableBuilder(column: $table.iv, builder: (column) => column);

  GeneratedColumn<int> get openInterest => $composableBuilder(
    column: $table.openInterest,
    builder: (column) => column,
  );

  GeneratedColumn<int> get volume =>
      $composableBuilder(column: $table.volume, builder: (column) => column);
}

class $$SnapshotTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SnapshotTableTable,
          SnapshotRow,
          $$SnapshotTableTableFilterComposer,
          $$SnapshotTableTableOrderingComposer,
          $$SnapshotTableTableAnnotationComposer,
          $$SnapshotTableTableCreateCompanionBuilder,
          $$SnapshotTableTableUpdateCompanionBuilder,
          (
            SnapshotRow,
            BaseReferences<_$AppDatabase, $SnapshotTableTable, SnapshotRow>,
          ),
          SnapshotRow,
          PrefetchHooks Function()
        > {
  $$SnapshotTableTableTableManager(_$AppDatabase db, $SnapshotTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SnapshotTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SnapshotTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SnapshotTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> legId = const Value.absent(),
                Value<DateTime> takenAtMs = const Value.absent(),
                Value<Decimal> optionMark = const Value.absent(),
                Value<Decimal> underlyingPrice = const Value.absent(),
                Value<double> deltaAsEntered = const Value.absent(),
                Value<DeltaConvention> deltaConvention = const Value.absent(),
                Value<double?> gamma = const Value.absent(),
                Value<double?> theta = const Value.absent(),
                Value<double?> vega = const Value.absent(),
                Value<double?> iv = const Value.absent(),
                Value<int?> openInterest = const Value.absent(),
                Value<int?> volume = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SnapshotTableCompanion(
                id: id,
                legId: legId,
                takenAtMs: takenAtMs,
                optionMark: optionMark,
                underlyingPrice: underlyingPrice,
                deltaAsEntered: deltaAsEntered,
                deltaConvention: deltaConvention,
                gamma: gamma,
                theta: theta,
                vega: vega,
                iv: iv,
                openInterest: openInterest,
                volume: volume,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String legId,
                required DateTime takenAtMs,
                required Decimal optionMark,
                required Decimal underlyingPrice,
                required double deltaAsEntered,
                required DeltaConvention deltaConvention,
                Value<double?> gamma = const Value.absent(),
                Value<double?> theta = const Value.absent(),
                Value<double?> vega = const Value.absent(),
                Value<double?> iv = const Value.absent(),
                Value<int?> openInterest = const Value.absent(),
                Value<int?> volume = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SnapshotTableCompanion.insert(
                id: id,
                legId: legId,
                takenAtMs: takenAtMs,
                optionMark: optionMark,
                underlyingPrice: underlyingPrice,
                deltaAsEntered: deltaAsEntered,
                deltaConvention: deltaConvention,
                gamma: gamma,
                theta: theta,
                vega: vega,
                iv: iv,
                openInterest: openInterest,
                volume: volume,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SnapshotTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SnapshotTableTable,
      SnapshotRow,
      $$SnapshotTableTableFilterComposer,
      $$SnapshotTableTableOrderingComposer,
      $$SnapshotTableTableAnnotationComposer,
      $$SnapshotTableTableCreateCompanionBuilder,
      $$SnapshotTableTableUpdateCompanionBuilder,
      (
        SnapshotRow,
        BaseReferences<_$AppDatabase, $SnapshotTableTable, SnapshotRow>,
      ),
      SnapshotRow,
      PrefetchHooks Function()
    >;
typedef $$ShareLotTableTableCreateCompanionBuilder =
    ShareLotTableCompanion Function({
      required String id,
      required String cycleId,
      required DateTime assignedAtMs,
      required Decimal assignmentStrike,
      required int contracts,
      Value<int> rowid,
    });
typedef $$ShareLotTableTableUpdateCompanionBuilder =
    ShareLotTableCompanion Function({
      Value<String> id,
      Value<String> cycleId,
      Value<DateTime> assignedAtMs,
      Value<Decimal> assignmentStrike,
      Value<int> contracts,
      Value<int> rowid,
    });

class $$ShareLotTableTableFilterComposer
    extends Composer<_$AppDatabase, $ShareLotTableTable> {
  $$ShareLotTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cycleId => $composableBuilder(
    column: $table.cycleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get assignedAtMs =>
      $composableBuilder(
        column: $table.assignedAtMs,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Decimal, Decimal, int> get assignmentStrike =>
      $composableBuilder(
        column: $table.assignmentStrike,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get contracts => $composableBuilder(
    column: $table.contracts,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ShareLotTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ShareLotTableTable> {
  $$ShareLotTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cycleId => $composableBuilder(
    column: $table.cycleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get assignedAtMs => $composableBuilder(
    column: $table.assignedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get assignmentStrike => $composableBuilder(
    column: $table.assignmentStrike,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get contracts => $composableBuilder(
    column: $table.contracts,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ShareLotTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShareLotTableTable> {
  $$ShareLotTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get cycleId =>
      $composableBuilder(column: $table.cycleId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get assignedAtMs =>
      $composableBuilder(
        column: $table.assignedAtMs,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<Decimal, int> get assignmentStrike =>
      $composableBuilder(
        column: $table.assignmentStrike,
        builder: (column) => column,
      );

  GeneratedColumn<int> get contracts =>
      $composableBuilder(column: $table.contracts, builder: (column) => column);
}

class $$ShareLotTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShareLotTableTable,
          ShareLotRow,
          $$ShareLotTableTableFilterComposer,
          $$ShareLotTableTableOrderingComposer,
          $$ShareLotTableTableAnnotationComposer,
          $$ShareLotTableTableCreateCompanionBuilder,
          $$ShareLotTableTableUpdateCompanionBuilder,
          (
            ShareLotRow,
            BaseReferences<_$AppDatabase, $ShareLotTableTable, ShareLotRow>,
          ),
          ShareLotRow,
          PrefetchHooks Function()
        > {
  $$ShareLotTableTableTableManager(_$AppDatabase db, $ShareLotTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShareLotTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShareLotTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShareLotTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> cycleId = const Value.absent(),
                Value<DateTime> assignedAtMs = const Value.absent(),
                Value<Decimal> assignmentStrike = const Value.absent(),
                Value<int> contracts = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShareLotTableCompanion(
                id: id,
                cycleId: cycleId,
                assignedAtMs: assignedAtMs,
                assignmentStrike: assignmentStrike,
                contracts: contracts,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String cycleId,
                required DateTime assignedAtMs,
                required Decimal assignmentStrike,
                required int contracts,
                Value<int> rowid = const Value.absent(),
              }) => ShareLotTableCompanion.insert(
                id: id,
                cycleId: cycleId,
                assignedAtMs: assignedAtMs,
                assignmentStrike: assignmentStrike,
                contracts: contracts,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ShareLotTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShareLotTableTable,
      ShareLotRow,
      $$ShareLotTableTableFilterComposer,
      $$ShareLotTableTableOrderingComposer,
      $$ShareLotTableTableAnnotationComposer,
      $$ShareLotTableTableCreateCompanionBuilder,
      $$ShareLotTableTableUpdateCompanionBuilder,
      (
        ShareLotRow,
        BaseReferences<_$AppDatabase, $ShareLotTableTable, ShareLotRow>,
      ),
      ShareLotRow,
      PrefetchHooks Function()
    >;
typedef $$RuleProfileTableTableCreateCompanionBuilder =
    RuleProfileTableCompanion Function({
      required String id,
      required String name,
      Value<int> rowid,
    });
typedef $$RuleProfileTableTableUpdateCompanionBuilder =
    RuleProfileTableCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> rowid,
    });

class $$RuleProfileTableTableFilterComposer
    extends Composer<_$AppDatabase, $RuleProfileTableTable> {
  $$RuleProfileTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RuleProfileTableTableOrderingComposer
    extends Composer<_$AppDatabase, $RuleProfileTableTable> {
  $$RuleProfileTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RuleProfileTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $RuleProfileTableTable> {
  $$RuleProfileTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);
}

class $$RuleProfileTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RuleProfileTableTable,
          RuleProfileRow,
          $$RuleProfileTableTableFilterComposer,
          $$RuleProfileTableTableOrderingComposer,
          $$RuleProfileTableTableAnnotationComposer,
          $$RuleProfileTableTableCreateCompanionBuilder,
          $$RuleProfileTableTableUpdateCompanionBuilder,
          (
            RuleProfileRow,
            BaseReferences<
              _$AppDatabase,
              $RuleProfileTableTable,
              RuleProfileRow
            >,
          ),
          RuleProfileRow,
          PrefetchHooks Function()
        > {
  $$RuleProfileTableTableTableManager(
    _$AppDatabase db,
    $RuleProfileTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RuleProfileTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RuleProfileTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RuleProfileTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RuleProfileTableCompanion(id: id, name: name, rowid: rowid),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int> rowid = const Value.absent(),
              }) => RuleProfileTableCompanion.insert(
                id: id,
                name: name,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RuleProfileTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RuleProfileTableTable,
      RuleProfileRow,
      $$RuleProfileTableTableFilterComposer,
      $$RuleProfileTableTableOrderingComposer,
      $$RuleProfileTableTableAnnotationComposer,
      $$RuleProfileTableTableCreateCompanionBuilder,
      $$RuleProfileTableTableUpdateCompanionBuilder,
      (
        RuleProfileRow,
        BaseReferences<_$AppDatabase, $RuleProfileTableTable, RuleProfileRow>,
      ),
      RuleProfileRow,
      PrefetchHooks Function()
    >;
typedef $$RuleProfileVersionTableTableCreateCompanionBuilder =
    RuleProfileVersionTableCompanion Function({
      required String id,
      required String profileId,
      required int version,
      required DateTime effectiveAtMs,
      required double profitTargetPct,
      required double assignThreshold,
      required double baseRollBand,
      required double midIvRollBand,
      required double highIvRollBand,
      required double midIvCutoff,
      required double highIvCutoff,
      required int tailDteDays,
      required Decimal tailExtrinsicThreshold,
      required double minIvRank,
      required double minAnnualisedYield,
      required int targetDteMin,
      required int targetDteMax,
      required double targetDelta,
      Value<int> rowid,
    });
typedef $$RuleProfileVersionTableTableUpdateCompanionBuilder =
    RuleProfileVersionTableCompanion Function({
      Value<String> id,
      Value<String> profileId,
      Value<int> version,
      Value<DateTime> effectiveAtMs,
      Value<double> profitTargetPct,
      Value<double> assignThreshold,
      Value<double> baseRollBand,
      Value<double> midIvRollBand,
      Value<double> highIvRollBand,
      Value<double> midIvCutoff,
      Value<double> highIvCutoff,
      Value<int> tailDteDays,
      Value<Decimal> tailExtrinsicThreshold,
      Value<double> minIvRank,
      Value<double> minAnnualisedYield,
      Value<int> targetDteMin,
      Value<int> targetDteMax,
      Value<double> targetDelta,
      Value<int> rowid,
    });

class $$RuleProfileVersionTableTableFilterComposer
    extends Composer<_$AppDatabase, $RuleProfileVersionTableTable> {
  $$RuleProfileVersionTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get effectiveAtMs =>
      $composableBuilder(
        column: $table.effectiveAtMs,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<double> get profitTargetPct => $composableBuilder(
    column: $table.profitTargetPct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get assignThreshold => $composableBuilder(
    column: $table.assignThreshold,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get baseRollBand => $composableBuilder(
    column: $table.baseRollBand,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get midIvRollBand => $composableBuilder(
    column: $table.midIvRollBand,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get highIvRollBand => $composableBuilder(
    column: $table.highIvRollBand,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get midIvCutoff => $composableBuilder(
    column: $table.midIvCutoff,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get highIvCutoff => $composableBuilder(
    column: $table.highIvCutoff,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tailDteDays => $composableBuilder(
    column: $table.tailDteDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal, Decimal, int>
  get tailExtrinsicThreshold => $composableBuilder(
    column: $table.tailExtrinsicThreshold,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<double> get minIvRank => $composableBuilder(
    column: $table.minIvRank,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get minAnnualisedYield => $composableBuilder(
    column: $table.minAnnualisedYield,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetDteMin => $composableBuilder(
    column: $table.targetDteMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetDteMax => $composableBuilder(
    column: $table.targetDteMax,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get targetDelta => $composableBuilder(
    column: $table.targetDelta,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RuleProfileVersionTableTableOrderingComposer
    extends Composer<_$AppDatabase, $RuleProfileVersionTableTable> {
  $$RuleProfileVersionTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get effectiveAtMs => $composableBuilder(
    column: $table.effectiveAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get profitTargetPct => $composableBuilder(
    column: $table.profitTargetPct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get assignThreshold => $composableBuilder(
    column: $table.assignThreshold,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get baseRollBand => $composableBuilder(
    column: $table.baseRollBand,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get midIvRollBand => $composableBuilder(
    column: $table.midIvRollBand,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get highIvRollBand => $composableBuilder(
    column: $table.highIvRollBand,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get midIvCutoff => $composableBuilder(
    column: $table.midIvCutoff,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get highIvCutoff => $composableBuilder(
    column: $table.highIvCutoff,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tailDteDays => $composableBuilder(
    column: $table.tailDteDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tailExtrinsicThreshold => $composableBuilder(
    column: $table.tailExtrinsicThreshold,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get minIvRank => $composableBuilder(
    column: $table.minIvRank,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get minAnnualisedYield => $composableBuilder(
    column: $table.minAnnualisedYield,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetDteMin => $composableBuilder(
    column: $table.targetDteMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetDteMax => $composableBuilder(
    column: $table.targetDteMax,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get targetDelta => $composableBuilder(
    column: $table.targetDelta,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RuleProfileVersionTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $RuleProfileVersionTableTable> {
  $$RuleProfileVersionTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get effectiveAtMs =>
      $composableBuilder(
        column: $table.effectiveAtMs,
        builder: (column) => column,
      );

  GeneratedColumn<double> get profitTargetPct => $composableBuilder(
    column: $table.profitTargetPct,
    builder: (column) => column,
  );

  GeneratedColumn<double> get assignThreshold => $composableBuilder(
    column: $table.assignThreshold,
    builder: (column) => column,
  );

  GeneratedColumn<double> get baseRollBand => $composableBuilder(
    column: $table.baseRollBand,
    builder: (column) => column,
  );

  GeneratedColumn<double> get midIvRollBand => $composableBuilder(
    column: $table.midIvRollBand,
    builder: (column) => column,
  );

  GeneratedColumn<double> get highIvRollBand => $composableBuilder(
    column: $table.highIvRollBand,
    builder: (column) => column,
  );

  GeneratedColumn<double> get midIvCutoff => $composableBuilder(
    column: $table.midIvCutoff,
    builder: (column) => column,
  );

  GeneratedColumn<double> get highIvCutoff => $composableBuilder(
    column: $table.highIvCutoff,
    builder: (column) => column,
  );

  GeneratedColumn<int> get tailDteDays => $composableBuilder(
    column: $table.tailDteDays,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Decimal, int> get tailExtrinsicThreshold =>
      $composableBuilder(
        column: $table.tailExtrinsicThreshold,
        builder: (column) => column,
      );

  GeneratedColumn<double> get minIvRank =>
      $composableBuilder(column: $table.minIvRank, builder: (column) => column);

  GeneratedColumn<double> get minAnnualisedYield => $composableBuilder(
    column: $table.minAnnualisedYield,
    builder: (column) => column,
  );

  GeneratedColumn<int> get targetDteMin => $composableBuilder(
    column: $table.targetDteMin,
    builder: (column) => column,
  );

  GeneratedColumn<int> get targetDteMax => $composableBuilder(
    column: $table.targetDteMax,
    builder: (column) => column,
  );

  GeneratedColumn<double> get targetDelta => $composableBuilder(
    column: $table.targetDelta,
    builder: (column) => column,
  );
}

class $$RuleProfileVersionTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RuleProfileVersionTableTable,
          RuleProfileVersionRow,
          $$RuleProfileVersionTableTableFilterComposer,
          $$RuleProfileVersionTableTableOrderingComposer,
          $$RuleProfileVersionTableTableAnnotationComposer,
          $$RuleProfileVersionTableTableCreateCompanionBuilder,
          $$RuleProfileVersionTableTableUpdateCompanionBuilder,
          (
            RuleProfileVersionRow,
            BaseReferences<
              _$AppDatabase,
              $RuleProfileVersionTableTable,
              RuleProfileVersionRow
            >,
          ),
          RuleProfileVersionRow,
          PrefetchHooks Function()
        > {
  $$RuleProfileVersionTableTableTableManager(
    _$AppDatabase db,
    $RuleProfileVersionTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RuleProfileVersionTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$RuleProfileVersionTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$RuleProfileVersionTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> effectiveAtMs = const Value.absent(),
                Value<double> profitTargetPct = const Value.absent(),
                Value<double> assignThreshold = const Value.absent(),
                Value<double> baseRollBand = const Value.absent(),
                Value<double> midIvRollBand = const Value.absent(),
                Value<double> highIvRollBand = const Value.absent(),
                Value<double> midIvCutoff = const Value.absent(),
                Value<double> highIvCutoff = const Value.absent(),
                Value<int> tailDteDays = const Value.absent(),
                Value<Decimal> tailExtrinsicThreshold = const Value.absent(),
                Value<double> minIvRank = const Value.absent(),
                Value<double> minAnnualisedYield = const Value.absent(),
                Value<int> targetDteMin = const Value.absent(),
                Value<int> targetDteMax = const Value.absent(),
                Value<double> targetDelta = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RuleProfileVersionTableCompanion(
                id: id,
                profileId: profileId,
                version: version,
                effectiveAtMs: effectiveAtMs,
                profitTargetPct: profitTargetPct,
                assignThreshold: assignThreshold,
                baseRollBand: baseRollBand,
                midIvRollBand: midIvRollBand,
                highIvRollBand: highIvRollBand,
                midIvCutoff: midIvCutoff,
                highIvCutoff: highIvCutoff,
                tailDteDays: tailDteDays,
                tailExtrinsicThreshold: tailExtrinsicThreshold,
                minIvRank: minIvRank,
                minAnnualisedYield: minAnnualisedYield,
                targetDteMin: targetDteMin,
                targetDteMax: targetDteMax,
                targetDelta: targetDelta,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String profileId,
                required int version,
                required DateTime effectiveAtMs,
                required double profitTargetPct,
                required double assignThreshold,
                required double baseRollBand,
                required double midIvRollBand,
                required double highIvRollBand,
                required double midIvCutoff,
                required double highIvCutoff,
                required int tailDteDays,
                required Decimal tailExtrinsicThreshold,
                required double minIvRank,
                required double minAnnualisedYield,
                required int targetDteMin,
                required int targetDteMax,
                required double targetDelta,
                Value<int> rowid = const Value.absent(),
              }) => RuleProfileVersionTableCompanion.insert(
                id: id,
                profileId: profileId,
                version: version,
                effectiveAtMs: effectiveAtMs,
                profitTargetPct: profitTargetPct,
                assignThreshold: assignThreshold,
                baseRollBand: baseRollBand,
                midIvRollBand: midIvRollBand,
                highIvRollBand: highIvRollBand,
                midIvCutoff: midIvCutoff,
                highIvCutoff: highIvCutoff,
                tailDteDays: tailDteDays,
                tailExtrinsicThreshold: tailExtrinsicThreshold,
                minIvRank: minIvRank,
                minAnnualisedYield: minAnnualisedYield,
                targetDteMin: targetDteMin,
                targetDteMax: targetDteMax,
                targetDelta: targetDelta,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RuleProfileVersionTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RuleProfileVersionTableTable,
      RuleProfileVersionRow,
      $$RuleProfileVersionTableTableFilterComposer,
      $$RuleProfileVersionTableTableOrderingComposer,
      $$RuleProfileVersionTableTableAnnotationComposer,
      $$RuleProfileVersionTableTableCreateCompanionBuilder,
      $$RuleProfileVersionTableTableUpdateCompanionBuilder,
      (
        RuleProfileVersionRow,
        BaseReferences<
          _$AppDatabase,
          $RuleProfileVersionTableTable,
          RuleProfileVersionRow
        >,
      ),
      RuleProfileVersionRow,
      PrefetchHooks Function()
    >;
typedef $$UserPreferencesTableTableCreateCompanionBuilder =
    UserPreferencesTableCompanion Function({
      required String id,
      required bool totalPerContractToggle,
      required DeltaConvention deltaConventionDefault,
      required bool firstRunExplainerShown,
      required bool ivResolutionNoticeDismissed,
      Value<bool> exportReminderDismissed,
      Value<DateTime?> lastExportAtMs,
      Value<List<int>> notificationMilestones,
      Value<Decimal?> wheelCapitalCents,
      Value<double> concentrationLimitPct,
      Value<int> rowid,
    });
typedef $$UserPreferencesTableTableUpdateCompanionBuilder =
    UserPreferencesTableCompanion Function({
      Value<String> id,
      Value<bool> totalPerContractToggle,
      Value<DeltaConvention> deltaConventionDefault,
      Value<bool> firstRunExplainerShown,
      Value<bool> ivResolutionNoticeDismissed,
      Value<bool> exportReminderDismissed,
      Value<DateTime?> lastExportAtMs,
      Value<List<int>> notificationMilestones,
      Value<Decimal?> wheelCapitalCents,
      Value<double> concentrationLimitPct,
      Value<int> rowid,
    });

class $$UserPreferencesTableTableFilterComposer
    extends Composer<_$AppDatabase, $UserPreferencesTableTable> {
  $$UserPreferencesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get totalPerContractToggle => $composableBuilder(
    column: $table.totalPerContractToggle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DeltaConvention, DeltaConvention, String>
  get deltaConventionDefault => $composableBuilder(
    column: $table.deltaConventionDefault,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get firstRunExplainerShown => $composableBuilder(
    column: $table.firstRunExplainerShown,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get ivResolutionNoticeDismissed => $composableBuilder(
    column: $table.ivResolutionNoticeDismissed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get exportReminderDismissed => $composableBuilder(
    column: $table.exportReminderDismissed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get lastExportAtMs =>
      $composableBuilder(
        column: $table.lastExportAtMs,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<List<int>, List<int>, String>
  get notificationMilestones => $composableBuilder(
    column: $table.notificationMilestones,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal?, Decimal, int>
  get wheelCapitalCents => $composableBuilder(
    column: $table.wheelCapitalCents,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<double> get concentrationLimitPct => $composableBuilder(
    column: $table.concentrationLimitPct,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserPreferencesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $UserPreferencesTableTable> {
  $$UserPreferencesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get totalPerContractToggle => $composableBuilder(
    column: $table.totalPerContractToggle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deltaConventionDefault => $composableBuilder(
    column: $table.deltaConventionDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get firstRunExplainerShown => $composableBuilder(
    column: $table.firstRunExplainerShown,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get ivResolutionNoticeDismissed => $composableBuilder(
    column: $table.ivResolutionNoticeDismissed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get exportReminderDismissed => $composableBuilder(
    column: $table.exportReminderDismissed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastExportAtMs => $composableBuilder(
    column: $table.lastExportAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notificationMilestones => $composableBuilder(
    column: $table.notificationMilestones,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wheelCapitalCents => $composableBuilder(
    column: $table.wheelCapitalCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get concentrationLimitPct => $composableBuilder(
    column: $table.concentrationLimitPct,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserPreferencesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserPreferencesTableTable> {
  $$UserPreferencesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get totalPerContractToggle => $composableBuilder(
    column: $table.totalPerContractToggle,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DeltaConvention, String>
  get deltaConventionDefault => $composableBuilder(
    column: $table.deltaConventionDefault,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get firstRunExplainerShown => $composableBuilder(
    column: $table.firstRunExplainerShown,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get ivResolutionNoticeDismissed => $composableBuilder(
    column: $table.ivResolutionNoticeDismissed,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get exportReminderDismissed => $composableBuilder(
    column: $table.exportReminderDismissed,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime?, int> get lastExportAtMs =>
      $composableBuilder(
        column: $table.lastExportAtMs,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<List<int>, String>
  get notificationMilestones => $composableBuilder(
    column: $table.notificationMilestones,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Decimal?, int> get wheelCapitalCents =>
      $composableBuilder(
        column: $table.wheelCapitalCents,
        builder: (column) => column,
      );

  GeneratedColumn<double> get concentrationLimitPct => $composableBuilder(
    column: $table.concentrationLimitPct,
    builder: (column) => column,
  );
}

class $$UserPreferencesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserPreferencesTableTable,
          UserPreferencesRow,
          $$UserPreferencesTableTableFilterComposer,
          $$UserPreferencesTableTableOrderingComposer,
          $$UserPreferencesTableTableAnnotationComposer,
          $$UserPreferencesTableTableCreateCompanionBuilder,
          $$UserPreferencesTableTableUpdateCompanionBuilder,
          (
            UserPreferencesRow,
            BaseReferences<
              _$AppDatabase,
              $UserPreferencesTableTable,
              UserPreferencesRow
            >,
          ),
          UserPreferencesRow,
          PrefetchHooks Function()
        > {
  $$UserPreferencesTableTableTableManager(
    _$AppDatabase db,
    $UserPreferencesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserPreferencesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserPreferencesTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$UserPreferencesTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<bool> totalPerContractToggle = const Value.absent(),
                Value<DeltaConvention> deltaConventionDefault =
                    const Value.absent(),
                Value<bool> firstRunExplainerShown = const Value.absent(),
                Value<bool> ivResolutionNoticeDismissed = const Value.absent(),
                Value<bool> exportReminderDismissed = const Value.absent(),
                Value<DateTime?> lastExportAtMs = const Value.absent(),
                Value<List<int>> notificationMilestones = const Value.absent(),
                Value<Decimal?> wheelCapitalCents = const Value.absent(),
                Value<double> concentrationLimitPct = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserPreferencesTableCompanion(
                id: id,
                totalPerContractToggle: totalPerContractToggle,
                deltaConventionDefault: deltaConventionDefault,
                firstRunExplainerShown: firstRunExplainerShown,
                ivResolutionNoticeDismissed: ivResolutionNoticeDismissed,
                exportReminderDismissed: exportReminderDismissed,
                lastExportAtMs: lastExportAtMs,
                notificationMilestones: notificationMilestones,
                wheelCapitalCents: wheelCapitalCents,
                concentrationLimitPct: concentrationLimitPct,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required bool totalPerContractToggle,
                required DeltaConvention deltaConventionDefault,
                required bool firstRunExplainerShown,
                required bool ivResolutionNoticeDismissed,
                Value<bool> exportReminderDismissed = const Value.absent(),
                Value<DateTime?> lastExportAtMs = const Value.absent(),
                Value<List<int>> notificationMilestones = const Value.absent(),
                Value<Decimal?> wheelCapitalCents = const Value.absent(),
                Value<double> concentrationLimitPct = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserPreferencesTableCompanion.insert(
                id: id,
                totalPerContractToggle: totalPerContractToggle,
                deltaConventionDefault: deltaConventionDefault,
                firstRunExplainerShown: firstRunExplainerShown,
                ivResolutionNoticeDismissed: ivResolutionNoticeDismissed,
                exportReminderDismissed: exportReminderDismissed,
                lastExportAtMs: lastExportAtMs,
                notificationMilestones: notificationMilestones,
                wheelCapitalCents: wheelCapitalCents,
                concentrationLimitPct: concentrationLimitPct,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserPreferencesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserPreferencesTableTable,
      UserPreferencesRow,
      $$UserPreferencesTableTableFilterComposer,
      $$UserPreferencesTableTableOrderingComposer,
      $$UserPreferencesTableTableAnnotationComposer,
      $$UserPreferencesTableTableCreateCompanionBuilder,
      $$UserPreferencesTableTableUpdateCompanionBuilder,
      (
        UserPreferencesRow,
        BaseReferences<
          _$AppDatabase,
          $UserPreferencesTableTable,
          UserPreferencesRow
        >,
      ),
      UserPreferencesRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UnderlyingTableTableTableManager get underlyingTable =>
      $$UnderlyingTableTableTableManager(_db, _db.underlyingTable);
  $$WheelCycleTableTableTableManager get wheelCycleTable =>
      $$WheelCycleTableTableTableManager(_db, _db.wheelCycleTable);
  $$LegTableTableTableManager get legTable =>
      $$LegTableTableTableManager(_db, _db.legTable);
  $$SnapshotTableTableTableManager get snapshotTable =>
      $$SnapshotTableTableTableManager(_db, _db.snapshotTable);
  $$ShareLotTableTableTableManager get shareLotTable =>
      $$ShareLotTableTableTableManager(_db, _db.shareLotTable);
  $$RuleProfileTableTableTableManager get ruleProfileTable =>
      $$RuleProfileTableTableTableManager(_db, _db.ruleProfileTable);
  $$RuleProfileVersionTableTableTableManager get ruleProfileVersionTable =>
      $$RuleProfileVersionTableTableTableManager(
        _db,
        _db.ruleProfileVersionTable,
      );
  $$UserPreferencesTableTableTableManager get userPreferencesTable =>
      $$UserPreferencesTableTableTableManager(_db, _db.userPreferencesTable);
}
