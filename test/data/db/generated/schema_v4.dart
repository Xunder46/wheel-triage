// dart format width=80
// GENERATED CODE, DO NOT EDIT BY HAND.
// ignore_for_file: type=lint
import 'package:drift/drift.dart';

class Underlying extends Table with TableInfo<Underlying, UnderlyingData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Underlying(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> ticker = GeneratedColumn<String>(
    'ticker',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UnderlyingData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UnderlyingData(
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
  Underlying createAlias(String alias) {
    return Underlying(attachedDatabase, alias);
  }
}

class UnderlyingData extends DataClass implements Insertable<UnderlyingData> {
  final String id;
  final String ticker;
  final String? displayName;
  final String? notes;
  const UnderlyingData({
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

  UnderlyingCompanion toCompanion(bool nullToAbsent) {
    return UnderlyingCompanion(
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

  factory UnderlyingData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UnderlyingData(
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

  UnderlyingData copyWith({
    String? id,
    String? ticker,
    Value<String?> displayName = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => UnderlyingData(
    id: id ?? this.id,
    ticker: ticker ?? this.ticker,
    displayName: displayName.present ? displayName.value : this.displayName,
    notes: notes.present ? notes.value : this.notes,
  );
  UnderlyingData copyWithCompanion(UnderlyingCompanion data) {
    return UnderlyingData(
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
    return (StringBuffer('UnderlyingData(')
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
      (other is UnderlyingData &&
          other.id == this.id &&
          other.ticker == this.ticker &&
          other.displayName == this.displayName &&
          other.notes == this.notes);
}

class UnderlyingCompanion extends UpdateCompanion<UnderlyingData> {
  final Value<String> id;
  final Value<String> ticker;
  final Value<String?> displayName;
  final Value<String?> notes;
  final Value<int> rowid;
  const UnderlyingCompanion({
    this.id = const Value.absent(),
    this.ticker = const Value.absent(),
    this.displayName = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UnderlyingCompanion.insert({
    required String id,
    required String ticker,
    this.displayName = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ticker = Value(ticker);
  static Insertable<UnderlyingData> custom({
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

  UnderlyingCompanion copyWith({
    Value<String>? id,
    Value<String>? ticker,
    Value<String?>? displayName,
    Value<String?>? notes,
    Value<int>? rowid,
  }) {
    return UnderlyingCompanion(
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
    return (StringBuffer('UnderlyingCompanion(')
          ..write('id: $id, ')
          ..write('ticker: $ticker, ')
          ..write('displayName: $displayName, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class WheelCycle extends Table with TableInfo<WheelCycle, WheelCycleData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  WheelCycle(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> underlyingId = GeneratedColumn<String>(
    'underlying_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> startedAtMs = GeneratedColumn<int>(
    'started_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> endedAtMs = GeneratedColumn<int>(
    'ended_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> outcome = GeneratedColumn<String>(
    'outcome',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WheelCycleData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WheelCycleData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      underlyingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}underlying_id'],
      )!,
      startedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at_ms'],
      )!,
      endedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ended_at_ms'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      outcome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outcome'],
      ),
    );
  }

  @override
  WheelCycle createAlias(String alias) {
    return WheelCycle(attachedDatabase, alias);
  }
}

class WheelCycleData extends DataClass implements Insertable<WheelCycleData> {
  final String id;
  final String underlyingId;
  final int startedAtMs;
  final int? endedAtMs;
  final String status;
  final String? outcome;
  const WheelCycleData({
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
    map['started_at_ms'] = Variable<int>(startedAtMs);
    if (!nullToAbsent || endedAtMs != null) {
      map['ended_at_ms'] = Variable<int>(endedAtMs);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || outcome != null) {
      map['outcome'] = Variable<String>(outcome);
    }
    return map;
  }

  WheelCycleCompanion toCompanion(bool nullToAbsent) {
    return WheelCycleCompanion(
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

  factory WheelCycleData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WheelCycleData(
      id: serializer.fromJson<String>(json['id']),
      underlyingId: serializer.fromJson<String>(json['underlyingId']),
      startedAtMs: serializer.fromJson<int>(json['startedAtMs']),
      endedAtMs: serializer.fromJson<int?>(json['endedAtMs']),
      status: serializer.fromJson<String>(json['status']),
      outcome: serializer.fromJson<String?>(json['outcome']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'underlyingId': serializer.toJson<String>(underlyingId),
      'startedAtMs': serializer.toJson<int>(startedAtMs),
      'endedAtMs': serializer.toJson<int?>(endedAtMs),
      'status': serializer.toJson<String>(status),
      'outcome': serializer.toJson<String?>(outcome),
    };
  }

  WheelCycleData copyWith({
    String? id,
    String? underlyingId,
    int? startedAtMs,
    Value<int?> endedAtMs = const Value.absent(),
    String? status,
    Value<String?> outcome = const Value.absent(),
  }) => WheelCycleData(
    id: id ?? this.id,
    underlyingId: underlyingId ?? this.underlyingId,
    startedAtMs: startedAtMs ?? this.startedAtMs,
    endedAtMs: endedAtMs.present ? endedAtMs.value : this.endedAtMs,
    status: status ?? this.status,
    outcome: outcome.present ? outcome.value : this.outcome,
  );
  WheelCycleData copyWithCompanion(WheelCycleCompanion data) {
    return WheelCycleData(
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
    return (StringBuffer('WheelCycleData(')
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
      (other is WheelCycleData &&
          other.id == this.id &&
          other.underlyingId == this.underlyingId &&
          other.startedAtMs == this.startedAtMs &&
          other.endedAtMs == this.endedAtMs &&
          other.status == this.status &&
          other.outcome == this.outcome);
}

class WheelCycleCompanion extends UpdateCompanion<WheelCycleData> {
  final Value<String> id;
  final Value<String> underlyingId;
  final Value<int> startedAtMs;
  final Value<int?> endedAtMs;
  final Value<String> status;
  final Value<String?> outcome;
  final Value<int> rowid;
  const WheelCycleCompanion({
    this.id = const Value.absent(),
    this.underlyingId = const Value.absent(),
    this.startedAtMs = const Value.absent(),
    this.endedAtMs = const Value.absent(),
    this.status = const Value.absent(),
    this.outcome = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WheelCycleCompanion.insert({
    required String id,
    required String underlyingId,
    required int startedAtMs,
    this.endedAtMs = const Value.absent(),
    required String status,
    this.outcome = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       underlyingId = Value(underlyingId),
       startedAtMs = Value(startedAtMs),
       status = Value(status);
  static Insertable<WheelCycleData> custom({
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

  WheelCycleCompanion copyWith({
    Value<String>? id,
    Value<String>? underlyingId,
    Value<int>? startedAtMs,
    Value<int?>? endedAtMs,
    Value<String>? status,
    Value<String?>? outcome,
    Value<int>? rowid,
  }) {
    return WheelCycleCompanion(
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
      map['started_at_ms'] = Variable<int>(startedAtMs.value);
    }
    if (endedAtMs.present) {
      map['ended_at_ms'] = Variable<int>(endedAtMs.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(outcome.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WheelCycleCompanion(')
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

class Leg extends Table with TableInfo<Leg, LegData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Leg(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> cycleId = GeneratedColumn<String>(
    'cycle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> optionType = GeneratedColumn<String>(
    'option_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> strike = GeneratedColumn<int>(
    'strike',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> expirationMs = GeneratedColumn<int>(
    'expiration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> contracts = GeneratedColumn<int>(
    'contracts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> openedAtMs = GeneratedColumn<int>(
    'opened_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> openCreditPerShare = GeneratedColumn<int>(
    'open_credit_per_share',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> closedAtMs = GeneratedColumn<int>(
    'closed_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<int> closeDebitPerShare = GeneratedColumn<int>(
    'close_debit_per_share',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> closeReason = GeneratedColumn<String>(
    'close_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> rolledFromLegId = GeneratedColumn<String>(
    'rolled_from_leg_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> ruleProfileVersionId =
      GeneratedColumn<String>(
        'rule_profile_version_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  late final GeneratedColumn<double> ivAtOpen = GeneratedColumn<double>(
    'iv_at_open',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<double> ivRankAtOpen = GeneratedColumn<double>(
    'iv_rank_at_open',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<double> deltaAtOpen = GeneratedColumn<double>(
    'delta_at_open',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<int> underlyingPriceAtOpen = GeneratedColumn<int>(
    'underlying_price_at_open',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<int> openFee = GeneratedColumn<int>(
    'open_fee',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<int> closeFee = GeneratedColumn<int>(
    'close_fee',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<bool> acceptsAssignment = GeneratedColumn<bool>(
    'accepts_assignment',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("accepts_assignment" IN (0, 1))',
    ),
    defaultValue: const CustomExpression('1'),
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LegData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LegData(
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
      optionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}option_type'],
      )!,
      strike: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}strike'],
      )!,
      expirationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expiration_ms'],
      )!,
      contracts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}contracts'],
      )!,
      openedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}opened_at_ms'],
      )!,
      openCreditPerShare: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}open_credit_per_share'],
      )!,
      closedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}closed_at_ms'],
      ),
      closeDebitPerShare: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}close_debit_per_share'],
      ),
      closeReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}close_reason'],
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
      underlyingPriceAtOpen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}underlying_price_at_open'],
      ),
      openFee: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}open_fee'],
      ),
      closeFee: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}close_fee'],
      ),
      acceptsAssignment: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}accepts_assignment'],
      )!,
    );
  }

  @override
  Leg createAlias(String alias) {
    return Leg(attachedDatabase, alias);
  }
}

class LegData extends DataClass implements Insertable<LegData> {
  final String id;
  final String cycleId;
  final int sequence;
  final String optionType;
  final int strike;
  final int expirationMs;
  final int contracts;
  final int openedAtMs;
  final int openCreditPerShare;
  final int? closedAtMs;
  final int? closeDebitPerShare;
  final String? closeReason;
  final String? rolledFromLegId;
  final String ruleProfileVersionId;
  final double? ivAtOpen;
  final double? ivRankAtOpen;
  final double? deltaAtOpen;
  final int? underlyingPriceAtOpen;
  final int? openFee;
  final int? closeFee;
  final bool acceptsAssignment;
  const LegData({
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
    map['option_type'] = Variable<String>(optionType);
    map['strike'] = Variable<int>(strike);
    map['expiration_ms'] = Variable<int>(expirationMs);
    map['contracts'] = Variable<int>(contracts);
    map['opened_at_ms'] = Variable<int>(openedAtMs);
    map['open_credit_per_share'] = Variable<int>(openCreditPerShare);
    if (!nullToAbsent || closedAtMs != null) {
      map['closed_at_ms'] = Variable<int>(closedAtMs);
    }
    if (!nullToAbsent || closeDebitPerShare != null) {
      map['close_debit_per_share'] = Variable<int>(closeDebitPerShare);
    }
    if (!nullToAbsent || closeReason != null) {
      map['close_reason'] = Variable<String>(closeReason);
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
      map['underlying_price_at_open'] = Variable<int>(underlyingPriceAtOpen);
    }
    if (!nullToAbsent || openFee != null) {
      map['open_fee'] = Variable<int>(openFee);
    }
    if (!nullToAbsent || closeFee != null) {
      map['close_fee'] = Variable<int>(closeFee);
    }
    map['accepts_assignment'] = Variable<bool>(acceptsAssignment);
    return map;
  }

  LegCompanion toCompanion(bool nullToAbsent) {
    return LegCompanion(
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

  factory LegData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LegData(
      id: serializer.fromJson<String>(json['id']),
      cycleId: serializer.fromJson<String>(json['cycleId']),
      sequence: serializer.fromJson<int>(json['sequence']),
      optionType: serializer.fromJson<String>(json['optionType']),
      strike: serializer.fromJson<int>(json['strike']),
      expirationMs: serializer.fromJson<int>(json['expirationMs']),
      contracts: serializer.fromJson<int>(json['contracts']),
      openedAtMs: serializer.fromJson<int>(json['openedAtMs']),
      openCreditPerShare: serializer.fromJson<int>(json['openCreditPerShare']),
      closedAtMs: serializer.fromJson<int?>(json['closedAtMs']),
      closeDebitPerShare: serializer.fromJson<int?>(json['closeDebitPerShare']),
      closeReason: serializer.fromJson<String?>(json['closeReason']),
      rolledFromLegId: serializer.fromJson<String?>(json['rolledFromLegId']),
      ruleProfileVersionId: serializer.fromJson<String>(
        json['ruleProfileVersionId'],
      ),
      ivAtOpen: serializer.fromJson<double?>(json['ivAtOpen']),
      ivRankAtOpen: serializer.fromJson<double?>(json['ivRankAtOpen']),
      deltaAtOpen: serializer.fromJson<double?>(json['deltaAtOpen']),
      underlyingPriceAtOpen: serializer.fromJson<int?>(
        json['underlyingPriceAtOpen'],
      ),
      openFee: serializer.fromJson<int?>(json['openFee']),
      closeFee: serializer.fromJson<int?>(json['closeFee']),
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
      'optionType': serializer.toJson<String>(optionType),
      'strike': serializer.toJson<int>(strike),
      'expirationMs': serializer.toJson<int>(expirationMs),
      'contracts': serializer.toJson<int>(contracts),
      'openedAtMs': serializer.toJson<int>(openedAtMs),
      'openCreditPerShare': serializer.toJson<int>(openCreditPerShare),
      'closedAtMs': serializer.toJson<int?>(closedAtMs),
      'closeDebitPerShare': serializer.toJson<int?>(closeDebitPerShare),
      'closeReason': serializer.toJson<String?>(closeReason),
      'rolledFromLegId': serializer.toJson<String?>(rolledFromLegId),
      'ruleProfileVersionId': serializer.toJson<String>(ruleProfileVersionId),
      'ivAtOpen': serializer.toJson<double?>(ivAtOpen),
      'ivRankAtOpen': serializer.toJson<double?>(ivRankAtOpen),
      'deltaAtOpen': serializer.toJson<double?>(deltaAtOpen),
      'underlyingPriceAtOpen': serializer.toJson<int?>(underlyingPriceAtOpen),
      'openFee': serializer.toJson<int?>(openFee),
      'closeFee': serializer.toJson<int?>(closeFee),
      'acceptsAssignment': serializer.toJson<bool>(acceptsAssignment),
    };
  }

  LegData copyWith({
    String? id,
    String? cycleId,
    int? sequence,
    String? optionType,
    int? strike,
    int? expirationMs,
    int? contracts,
    int? openedAtMs,
    int? openCreditPerShare,
    Value<int?> closedAtMs = const Value.absent(),
    Value<int?> closeDebitPerShare = const Value.absent(),
    Value<String?> closeReason = const Value.absent(),
    Value<String?> rolledFromLegId = const Value.absent(),
    String? ruleProfileVersionId,
    Value<double?> ivAtOpen = const Value.absent(),
    Value<double?> ivRankAtOpen = const Value.absent(),
    Value<double?> deltaAtOpen = const Value.absent(),
    Value<int?> underlyingPriceAtOpen = const Value.absent(),
    Value<int?> openFee = const Value.absent(),
    Value<int?> closeFee = const Value.absent(),
    bool? acceptsAssignment,
  }) => LegData(
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
  LegData copyWithCompanion(LegCompanion data) {
    return LegData(
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
    return (StringBuffer('LegData(')
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
      (other is LegData &&
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

class LegCompanion extends UpdateCompanion<LegData> {
  final Value<String> id;
  final Value<String> cycleId;
  final Value<int> sequence;
  final Value<String> optionType;
  final Value<int> strike;
  final Value<int> expirationMs;
  final Value<int> contracts;
  final Value<int> openedAtMs;
  final Value<int> openCreditPerShare;
  final Value<int?> closedAtMs;
  final Value<int?> closeDebitPerShare;
  final Value<String?> closeReason;
  final Value<String?> rolledFromLegId;
  final Value<String> ruleProfileVersionId;
  final Value<double?> ivAtOpen;
  final Value<double?> ivRankAtOpen;
  final Value<double?> deltaAtOpen;
  final Value<int?> underlyingPriceAtOpen;
  final Value<int?> openFee;
  final Value<int?> closeFee;
  final Value<bool> acceptsAssignment;
  final Value<int> rowid;
  const LegCompanion({
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
  LegCompanion.insert({
    required String id,
    required String cycleId,
    required int sequence,
    required String optionType,
    required int strike,
    required int expirationMs,
    required int contracts,
    required int openedAtMs,
    required int openCreditPerShare,
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
  static Insertable<LegData> custom({
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

  LegCompanion copyWith({
    Value<String>? id,
    Value<String>? cycleId,
    Value<int>? sequence,
    Value<String>? optionType,
    Value<int>? strike,
    Value<int>? expirationMs,
    Value<int>? contracts,
    Value<int>? openedAtMs,
    Value<int>? openCreditPerShare,
    Value<int?>? closedAtMs,
    Value<int?>? closeDebitPerShare,
    Value<String?>? closeReason,
    Value<String?>? rolledFromLegId,
    Value<String>? ruleProfileVersionId,
    Value<double?>? ivAtOpen,
    Value<double?>? ivRankAtOpen,
    Value<double?>? deltaAtOpen,
    Value<int?>? underlyingPriceAtOpen,
    Value<int?>? openFee,
    Value<int?>? closeFee,
    Value<bool>? acceptsAssignment,
    Value<int>? rowid,
  }) {
    return LegCompanion(
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
      map['option_type'] = Variable<String>(optionType.value);
    }
    if (strike.present) {
      map['strike'] = Variable<int>(strike.value);
    }
    if (expirationMs.present) {
      map['expiration_ms'] = Variable<int>(expirationMs.value);
    }
    if (contracts.present) {
      map['contracts'] = Variable<int>(contracts.value);
    }
    if (openedAtMs.present) {
      map['opened_at_ms'] = Variable<int>(openedAtMs.value);
    }
    if (openCreditPerShare.present) {
      map['open_credit_per_share'] = Variable<int>(openCreditPerShare.value);
    }
    if (closedAtMs.present) {
      map['closed_at_ms'] = Variable<int>(closedAtMs.value);
    }
    if (closeDebitPerShare.present) {
      map['close_debit_per_share'] = Variable<int>(closeDebitPerShare.value);
    }
    if (closeReason.present) {
      map['close_reason'] = Variable<String>(closeReason.value);
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
        underlyingPriceAtOpen.value,
      );
    }
    if (openFee.present) {
      map['open_fee'] = Variable<int>(openFee.value);
    }
    if (closeFee.present) {
      map['close_fee'] = Variable<int>(closeFee.value);
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
    return (StringBuffer('LegCompanion(')
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

class Snapshot extends Table with TableInfo<Snapshot, SnapshotData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Snapshot(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> legId = GeneratedColumn<String>(
    'leg_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> takenAtMs = GeneratedColumn<int>(
    'taken_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> optionMark = GeneratedColumn<int>(
    'option_mark',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> underlyingPrice = GeneratedColumn<int>(
    'underlying_price',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<double> deltaAsEntered = GeneratedColumn<double>(
    'delta_as_entered',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> deltaConvention = GeneratedColumn<String>(
    'delta_convention',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<double> gamma = GeneratedColumn<double>(
    'gamma',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<double> theta = GeneratedColumn<double>(
    'theta',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<double> vega = GeneratedColumn<double>(
    'vega',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<double> iv = GeneratedColumn<double>(
    'iv',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<int> openInterest = GeneratedColumn<int>(
    'open_interest',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SnapshotData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SnapshotData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      legId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}leg_id'],
      )!,
      takenAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}taken_at_ms'],
      )!,
      optionMark: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}option_mark'],
      )!,
      underlyingPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}underlying_price'],
      )!,
      deltaAsEntered: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}delta_as_entered'],
      )!,
      deltaConvention: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}delta_convention'],
      )!,
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
  Snapshot createAlias(String alias) {
    return Snapshot(attachedDatabase, alias);
  }
}

class SnapshotData extends DataClass implements Insertable<SnapshotData> {
  final String id;
  final String legId;
  final int takenAtMs;
  final int optionMark;
  final int underlyingPrice;
  final double deltaAsEntered;
  final String deltaConvention;
  final double? gamma;
  final double? theta;
  final double? vega;
  final double? iv;
  final int? openInterest;
  final int? volume;
  const SnapshotData({
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
    map['taken_at_ms'] = Variable<int>(takenAtMs);
    map['option_mark'] = Variable<int>(optionMark);
    map['underlying_price'] = Variable<int>(underlyingPrice);
    map['delta_as_entered'] = Variable<double>(deltaAsEntered);
    map['delta_convention'] = Variable<String>(deltaConvention);
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

  SnapshotCompanion toCompanion(bool nullToAbsent) {
    return SnapshotCompanion(
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

  factory SnapshotData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SnapshotData(
      id: serializer.fromJson<String>(json['id']),
      legId: serializer.fromJson<String>(json['legId']),
      takenAtMs: serializer.fromJson<int>(json['takenAtMs']),
      optionMark: serializer.fromJson<int>(json['optionMark']),
      underlyingPrice: serializer.fromJson<int>(json['underlyingPrice']),
      deltaAsEntered: serializer.fromJson<double>(json['deltaAsEntered']),
      deltaConvention: serializer.fromJson<String>(json['deltaConvention']),
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
      'takenAtMs': serializer.toJson<int>(takenAtMs),
      'optionMark': serializer.toJson<int>(optionMark),
      'underlyingPrice': serializer.toJson<int>(underlyingPrice),
      'deltaAsEntered': serializer.toJson<double>(deltaAsEntered),
      'deltaConvention': serializer.toJson<String>(deltaConvention),
      'gamma': serializer.toJson<double?>(gamma),
      'theta': serializer.toJson<double?>(theta),
      'vega': serializer.toJson<double?>(vega),
      'iv': serializer.toJson<double?>(iv),
      'openInterest': serializer.toJson<int?>(openInterest),
      'volume': serializer.toJson<int?>(volume),
    };
  }

  SnapshotData copyWith({
    String? id,
    String? legId,
    int? takenAtMs,
    int? optionMark,
    int? underlyingPrice,
    double? deltaAsEntered,
    String? deltaConvention,
    Value<double?> gamma = const Value.absent(),
    Value<double?> theta = const Value.absent(),
    Value<double?> vega = const Value.absent(),
    Value<double?> iv = const Value.absent(),
    Value<int?> openInterest = const Value.absent(),
    Value<int?> volume = const Value.absent(),
  }) => SnapshotData(
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
  SnapshotData copyWithCompanion(SnapshotCompanion data) {
    return SnapshotData(
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
    return (StringBuffer('SnapshotData(')
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
      (other is SnapshotData &&
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

class SnapshotCompanion extends UpdateCompanion<SnapshotData> {
  final Value<String> id;
  final Value<String> legId;
  final Value<int> takenAtMs;
  final Value<int> optionMark;
  final Value<int> underlyingPrice;
  final Value<double> deltaAsEntered;
  final Value<String> deltaConvention;
  final Value<double?> gamma;
  final Value<double?> theta;
  final Value<double?> vega;
  final Value<double?> iv;
  final Value<int?> openInterest;
  final Value<int?> volume;
  final Value<int> rowid;
  const SnapshotCompanion({
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
  SnapshotCompanion.insert({
    required String id,
    required String legId,
    required int takenAtMs,
    required int optionMark,
    required int underlyingPrice,
    required double deltaAsEntered,
    required String deltaConvention,
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
  static Insertable<SnapshotData> custom({
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

  SnapshotCompanion copyWith({
    Value<String>? id,
    Value<String>? legId,
    Value<int>? takenAtMs,
    Value<int>? optionMark,
    Value<int>? underlyingPrice,
    Value<double>? deltaAsEntered,
    Value<String>? deltaConvention,
    Value<double?>? gamma,
    Value<double?>? theta,
    Value<double?>? vega,
    Value<double?>? iv,
    Value<int?>? openInterest,
    Value<int?>? volume,
    Value<int>? rowid,
  }) {
    return SnapshotCompanion(
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
      map['taken_at_ms'] = Variable<int>(takenAtMs.value);
    }
    if (optionMark.present) {
      map['option_mark'] = Variable<int>(optionMark.value);
    }
    if (underlyingPrice.present) {
      map['underlying_price'] = Variable<int>(underlyingPrice.value);
    }
    if (deltaAsEntered.present) {
      map['delta_as_entered'] = Variable<double>(deltaAsEntered.value);
    }
    if (deltaConvention.present) {
      map['delta_convention'] = Variable<String>(deltaConvention.value);
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
    return (StringBuffer('SnapshotCompanion(')
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

class ShareLot extends Table with TableInfo<ShareLot, ShareLotData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ShareLot(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> cycleId = GeneratedColumn<String>(
    'cycle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> assignedAtMs = GeneratedColumn<int>(
    'assigned_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> assignmentStrike = GeneratedColumn<int>(
    'assignment_strike',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShareLotData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShareLotData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      cycleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cycle_id'],
      )!,
      assignedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}assigned_at_ms'],
      )!,
      assignmentStrike: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}assignment_strike'],
      )!,
      contracts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}contracts'],
      )!,
    );
  }

  @override
  ShareLot createAlias(String alias) {
    return ShareLot(attachedDatabase, alias);
  }
}

class ShareLotData extends DataClass implements Insertable<ShareLotData> {
  final String id;
  final String cycleId;
  final int assignedAtMs;
  final int assignmentStrike;
  final int contracts;
  const ShareLotData({
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
    map['assigned_at_ms'] = Variable<int>(assignedAtMs);
    map['assignment_strike'] = Variable<int>(assignmentStrike);
    map['contracts'] = Variable<int>(contracts);
    return map;
  }

  ShareLotCompanion toCompanion(bool nullToAbsent) {
    return ShareLotCompanion(
      id: Value(id),
      cycleId: Value(cycleId),
      assignedAtMs: Value(assignedAtMs),
      assignmentStrike: Value(assignmentStrike),
      contracts: Value(contracts),
    );
  }

  factory ShareLotData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShareLotData(
      id: serializer.fromJson<String>(json['id']),
      cycleId: serializer.fromJson<String>(json['cycleId']),
      assignedAtMs: serializer.fromJson<int>(json['assignedAtMs']),
      assignmentStrike: serializer.fromJson<int>(json['assignmentStrike']),
      contracts: serializer.fromJson<int>(json['contracts']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'cycleId': serializer.toJson<String>(cycleId),
      'assignedAtMs': serializer.toJson<int>(assignedAtMs),
      'assignmentStrike': serializer.toJson<int>(assignmentStrike),
      'contracts': serializer.toJson<int>(contracts),
    };
  }

  ShareLotData copyWith({
    String? id,
    String? cycleId,
    int? assignedAtMs,
    int? assignmentStrike,
    int? contracts,
  }) => ShareLotData(
    id: id ?? this.id,
    cycleId: cycleId ?? this.cycleId,
    assignedAtMs: assignedAtMs ?? this.assignedAtMs,
    assignmentStrike: assignmentStrike ?? this.assignmentStrike,
    contracts: contracts ?? this.contracts,
  );
  ShareLotData copyWithCompanion(ShareLotCompanion data) {
    return ShareLotData(
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
    return (StringBuffer('ShareLotData(')
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
      (other is ShareLotData &&
          other.id == this.id &&
          other.cycleId == this.cycleId &&
          other.assignedAtMs == this.assignedAtMs &&
          other.assignmentStrike == this.assignmentStrike &&
          other.contracts == this.contracts);
}

class ShareLotCompanion extends UpdateCompanion<ShareLotData> {
  final Value<String> id;
  final Value<String> cycleId;
  final Value<int> assignedAtMs;
  final Value<int> assignmentStrike;
  final Value<int> contracts;
  final Value<int> rowid;
  const ShareLotCompanion({
    this.id = const Value.absent(),
    this.cycleId = const Value.absent(),
    this.assignedAtMs = const Value.absent(),
    this.assignmentStrike = const Value.absent(),
    this.contracts = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ShareLotCompanion.insert({
    required String id,
    required String cycleId,
    required int assignedAtMs,
    required int assignmentStrike,
    required int contracts,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       cycleId = Value(cycleId),
       assignedAtMs = Value(assignedAtMs),
       assignmentStrike = Value(assignmentStrike),
       contracts = Value(contracts);
  static Insertable<ShareLotData> custom({
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

  ShareLotCompanion copyWith({
    Value<String>? id,
    Value<String>? cycleId,
    Value<int>? assignedAtMs,
    Value<int>? assignmentStrike,
    Value<int>? contracts,
    Value<int>? rowid,
  }) {
    return ShareLotCompanion(
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
      map['assigned_at_ms'] = Variable<int>(assignedAtMs.value);
    }
    if (assignmentStrike.present) {
      map['assignment_strike'] = Variable<int>(assignmentStrike.value);
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
    return (StringBuffer('ShareLotCompanion(')
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

class RuleProfile extends Table with TableInfo<RuleProfile, RuleProfileData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  RuleProfile(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RuleProfileData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RuleProfileData(
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
  RuleProfile createAlias(String alias) {
    return RuleProfile(attachedDatabase, alias);
  }
}

class RuleProfileData extends DataClass implements Insertable<RuleProfileData> {
  final String id;
  final String name;
  const RuleProfileData({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  RuleProfileCompanion toCompanion(bool nullToAbsent) {
    return RuleProfileCompanion(id: Value(id), name: Value(name));
  }

  factory RuleProfileData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RuleProfileData(
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

  RuleProfileData copyWith({String? id, String? name}) =>
      RuleProfileData(id: id ?? this.id, name: name ?? this.name);
  RuleProfileData copyWithCompanion(RuleProfileCompanion data) {
    return RuleProfileData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RuleProfileData(')
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
      (other is RuleProfileData &&
          other.id == this.id &&
          other.name == this.name);
}

class RuleProfileCompanion extends UpdateCompanion<RuleProfileData> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> rowid;
  const RuleProfileCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RuleProfileCompanion.insert({
    required String id,
    required String name,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<RuleProfileData> custom({
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

  RuleProfileCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? rowid,
  }) {
    return RuleProfileCompanion(
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
    return (StringBuffer('RuleProfileCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class RuleProfileVersion extends Table
    with TableInfo<RuleProfileVersion, RuleProfileVersionData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  RuleProfileVersion(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> effectiveAtMs = GeneratedColumn<int>(
    'effective_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<double> profitTargetPct = GeneratedColumn<double>(
    'profit_target_pct',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<double> assignThreshold = GeneratedColumn<double>(
    'assign_threshold',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<double> baseRollBand = GeneratedColumn<double>(
    'base_roll_band',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<double> midIvRollBand = GeneratedColumn<double>(
    'mid_iv_roll_band',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<double> highIvRollBand = GeneratedColumn<double>(
    'high_iv_roll_band',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<double> midIvCutoff = GeneratedColumn<double>(
    'mid_iv_cutoff',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<double> highIvCutoff = GeneratedColumn<double>(
    'high_iv_cutoff',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> tailDteDays = GeneratedColumn<int>(
    'tail_dte_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> tailExtrinsicThreshold = GeneratedColumn<int>(
    'tail_extrinsic_threshold',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<double> minIvRank = GeneratedColumn<double>(
    'min_iv_rank',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<double> minAnnualisedYield =
      GeneratedColumn<double>(
        'min_annualised_yield',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: true,
      );
  late final GeneratedColumn<int> targetDteMin = GeneratedColumn<int>(
    'target_dte_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  late final GeneratedColumn<int> targetDteMax = GeneratedColumn<int>(
    'target_dte_max',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {profileId, version},
  ];
  @override
  RuleProfileVersionData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RuleProfileVersionData(
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
      effectiveAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}effective_at_ms'],
      )!,
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
      tailExtrinsicThreshold: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tail_extrinsic_threshold'],
      )!,
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
  RuleProfileVersion createAlias(String alias) {
    return RuleProfileVersion(attachedDatabase, alias);
  }
}

class RuleProfileVersionData extends DataClass
    implements Insertable<RuleProfileVersionData> {
  final String id;
  final String profileId;
  final int version;
  final int effectiveAtMs;
  final double profitTargetPct;
  final double assignThreshold;
  final double baseRollBand;
  final double midIvRollBand;
  final double highIvRollBand;
  final double midIvCutoff;
  final double highIvCutoff;
  final int tailDteDays;
  final int tailExtrinsicThreshold;
  final double minIvRank;
  final double minAnnualisedYield;
  final int targetDteMin;
  final int targetDteMax;
  final double targetDelta;
  const RuleProfileVersionData({
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
    map['effective_at_ms'] = Variable<int>(effectiveAtMs);
    map['profit_target_pct'] = Variable<double>(profitTargetPct);
    map['assign_threshold'] = Variable<double>(assignThreshold);
    map['base_roll_band'] = Variable<double>(baseRollBand);
    map['mid_iv_roll_band'] = Variable<double>(midIvRollBand);
    map['high_iv_roll_band'] = Variable<double>(highIvRollBand);
    map['mid_iv_cutoff'] = Variable<double>(midIvCutoff);
    map['high_iv_cutoff'] = Variable<double>(highIvCutoff);
    map['tail_dte_days'] = Variable<int>(tailDteDays);
    map['tail_extrinsic_threshold'] = Variable<int>(tailExtrinsicThreshold);
    map['min_iv_rank'] = Variable<double>(minIvRank);
    map['min_annualised_yield'] = Variable<double>(minAnnualisedYield);
    map['target_dte_min'] = Variable<int>(targetDteMin);
    map['target_dte_max'] = Variable<int>(targetDteMax);
    map['target_delta'] = Variable<double>(targetDelta);
    return map;
  }

  RuleProfileVersionCompanion toCompanion(bool nullToAbsent) {
    return RuleProfileVersionCompanion(
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

  factory RuleProfileVersionData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RuleProfileVersionData(
      id: serializer.fromJson<String>(json['id']),
      profileId: serializer.fromJson<String>(json['profileId']),
      version: serializer.fromJson<int>(json['version']),
      effectiveAtMs: serializer.fromJson<int>(json['effectiveAtMs']),
      profitTargetPct: serializer.fromJson<double>(json['profitTargetPct']),
      assignThreshold: serializer.fromJson<double>(json['assignThreshold']),
      baseRollBand: serializer.fromJson<double>(json['baseRollBand']),
      midIvRollBand: serializer.fromJson<double>(json['midIvRollBand']),
      highIvRollBand: serializer.fromJson<double>(json['highIvRollBand']),
      midIvCutoff: serializer.fromJson<double>(json['midIvCutoff']),
      highIvCutoff: serializer.fromJson<double>(json['highIvCutoff']),
      tailDteDays: serializer.fromJson<int>(json['tailDteDays']),
      tailExtrinsicThreshold: serializer.fromJson<int>(
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
      'effectiveAtMs': serializer.toJson<int>(effectiveAtMs),
      'profitTargetPct': serializer.toJson<double>(profitTargetPct),
      'assignThreshold': serializer.toJson<double>(assignThreshold),
      'baseRollBand': serializer.toJson<double>(baseRollBand),
      'midIvRollBand': serializer.toJson<double>(midIvRollBand),
      'highIvRollBand': serializer.toJson<double>(highIvRollBand),
      'midIvCutoff': serializer.toJson<double>(midIvCutoff),
      'highIvCutoff': serializer.toJson<double>(highIvCutoff),
      'tailDteDays': serializer.toJson<int>(tailDteDays),
      'tailExtrinsicThreshold': serializer.toJson<int>(tailExtrinsicThreshold),
      'minIvRank': serializer.toJson<double>(minIvRank),
      'minAnnualisedYield': serializer.toJson<double>(minAnnualisedYield),
      'targetDteMin': serializer.toJson<int>(targetDteMin),
      'targetDteMax': serializer.toJson<int>(targetDteMax),
      'targetDelta': serializer.toJson<double>(targetDelta),
    };
  }

  RuleProfileVersionData copyWith({
    String? id,
    String? profileId,
    int? version,
    int? effectiveAtMs,
    double? profitTargetPct,
    double? assignThreshold,
    double? baseRollBand,
    double? midIvRollBand,
    double? highIvRollBand,
    double? midIvCutoff,
    double? highIvCutoff,
    int? tailDteDays,
    int? tailExtrinsicThreshold,
    double? minIvRank,
    double? minAnnualisedYield,
    int? targetDteMin,
    int? targetDteMax,
    double? targetDelta,
  }) => RuleProfileVersionData(
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
  RuleProfileVersionData copyWithCompanion(RuleProfileVersionCompanion data) {
    return RuleProfileVersionData(
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
    return (StringBuffer('RuleProfileVersionData(')
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
      (other is RuleProfileVersionData &&
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

class RuleProfileVersionCompanion
    extends UpdateCompanion<RuleProfileVersionData> {
  final Value<String> id;
  final Value<String> profileId;
  final Value<int> version;
  final Value<int> effectiveAtMs;
  final Value<double> profitTargetPct;
  final Value<double> assignThreshold;
  final Value<double> baseRollBand;
  final Value<double> midIvRollBand;
  final Value<double> highIvRollBand;
  final Value<double> midIvCutoff;
  final Value<double> highIvCutoff;
  final Value<int> tailDteDays;
  final Value<int> tailExtrinsicThreshold;
  final Value<double> minIvRank;
  final Value<double> minAnnualisedYield;
  final Value<int> targetDteMin;
  final Value<int> targetDteMax;
  final Value<double> targetDelta;
  final Value<int> rowid;
  const RuleProfileVersionCompanion({
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
  RuleProfileVersionCompanion.insert({
    required String id,
    required String profileId,
    required int version,
    required int effectiveAtMs,
    required double profitTargetPct,
    required double assignThreshold,
    required double baseRollBand,
    required double midIvRollBand,
    required double highIvRollBand,
    required double midIvCutoff,
    required double highIvCutoff,
    required int tailDteDays,
    required int tailExtrinsicThreshold,
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
  static Insertable<RuleProfileVersionData> custom({
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

  RuleProfileVersionCompanion copyWith({
    Value<String>? id,
    Value<String>? profileId,
    Value<int>? version,
    Value<int>? effectiveAtMs,
    Value<double>? profitTargetPct,
    Value<double>? assignThreshold,
    Value<double>? baseRollBand,
    Value<double>? midIvRollBand,
    Value<double>? highIvRollBand,
    Value<double>? midIvCutoff,
    Value<double>? highIvCutoff,
    Value<int>? tailDteDays,
    Value<int>? tailExtrinsicThreshold,
    Value<double>? minIvRank,
    Value<double>? minAnnualisedYield,
    Value<int>? targetDteMin,
    Value<int>? targetDteMax,
    Value<double>? targetDelta,
    Value<int>? rowid,
  }) {
    return RuleProfileVersionCompanion(
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
      map['effective_at_ms'] = Variable<int>(effectiveAtMs.value);
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
        tailExtrinsicThreshold.value,
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
    return (StringBuffer('RuleProfileVersionCompanion(')
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

class UserPreferences extends Table
    with TableInfo<UserPreferences, UserPreferencesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  UserPreferences(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
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
  late final GeneratedColumn<String> deltaConventionDefault =
      GeneratedColumn<String>(
        'delta_convention_default',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
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
        defaultValue: const CustomExpression('0'),
      );
  late final GeneratedColumn<int> lastExportAtMs = GeneratedColumn<int>(
    'last_export_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  late final GeneratedColumn<String> notificationMilestones =
      GeneratedColumn<String>(
        'notification_milestones',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const CustomExpression('\'21,7,0\''),
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
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_preferences';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserPreferencesData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserPreferencesData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      totalPerContractToggle: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}total_per_contract_toggle'],
      )!,
      deltaConventionDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}delta_convention_default'],
      )!,
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
      lastExportAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_export_at_ms'],
      ),
      notificationMilestones: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notification_milestones'],
      )!,
    );
  }

  @override
  UserPreferences createAlias(String alias) {
    return UserPreferences(attachedDatabase, alias);
  }
}

class UserPreferencesData extends DataClass
    implements Insertable<UserPreferencesData> {
  final String id;
  final bool totalPerContractToggle;
  final String deltaConventionDefault;
  final bool firstRunExplainerShown;
  final bool ivResolutionNoticeDismissed;
  final bool exportReminderDismissed;
  final int? lastExportAtMs;
  final String notificationMilestones;
  const UserPreferencesData({
    required this.id,
    required this.totalPerContractToggle,
    required this.deltaConventionDefault,
    required this.firstRunExplainerShown,
    required this.ivResolutionNoticeDismissed,
    required this.exportReminderDismissed,
    this.lastExportAtMs,
    required this.notificationMilestones,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['total_per_contract_toggle'] = Variable<bool>(totalPerContractToggle);
    map['delta_convention_default'] = Variable<String>(deltaConventionDefault);
    map['first_run_explainer_shown'] = Variable<bool>(firstRunExplainerShown);
    map['iv_resolution_notice_dismissed'] = Variable<bool>(
      ivResolutionNoticeDismissed,
    );
    map['export_reminder_dismissed'] = Variable<bool>(exportReminderDismissed);
    if (!nullToAbsent || lastExportAtMs != null) {
      map['last_export_at_ms'] = Variable<int>(lastExportAtMs);
    }
    map['notification_milestones'] = Variable<String>(notificationMilestones);
    return map;
  }

  UserPreferencesCompanion toCompanion(bool nullToAbsent) {
    return UserPreferencesCompanion(
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
    );
  }

  factory UserPreferencesData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserPreferencesData(
      id: serializer.fromJson<String>(json['id']),
      totalPerContractToggle: serializer.fromJson<bool>(
        json['totalPerContractToggle'],
      ),
      deltaConventionDefault: serializer.fromJson<String>(
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
      lastExportAtMs: serializer.fromJson<int?>(json['lastExportAtMs']),
      notificationMilestones: serializer.fromJson<String>(
        json['notificationMilestones'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'totalPerContractToggle': serializer.toJson<bool>(totalPerContractToggle),
      'deltaConventionDefault': serializer.toJson<String>(
        deltaConventionDefault,
      ),
      'firstRunExplainerShown': serializer.toJson<bool>(firstRunExplainerShown),
      'ivResolutionNoticeDismissed': serializer.toJson<bool>(
        ivResolutionNoticeDismissed,
      ),
      'exportReminderDismissed': serializer.toJson<bool>(
        exportReminderDismissed,
      ),
      'lastExportAtMs': serializer.toJson<int?>(lastExportAtMs),
      'notificationMilestones': serializer.toJson<String>(
        notificationMilestones,
      ),
    };
  }

  UserPreferencesData copyWith({
    String? id,
    bool? totalPerContractToggle,
    String? deltaConventionDefault,
    bool? firstRunExplainerShown,
    bool? ivResolutionNoticeDismissed,
    bool? exportReminderDismissed,
    Value<int?> lastExportAtMs = const Value.absent(),
    String? notificationMilestones,
  }) => UserPreferencesData(
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
  );
  UserPreferencesData copyWithCompanion(UserPreferencesCompanion data) {
    return UserPreferencesData(
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
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserPreferencesData(')
          ..write('id: $id, ')
          ..write('totalPerContractToggle: $totalPerContractToggle, ')
          ..write('deltaConventionDefault: $deltaConventionDefault, ')
          ..write('firstRunExplainerShown: $firstRunExplainerShown, ')
          ..write('ivResolutionNoticeDismissed: $ivResolutionNoticeDismissed, ')
          ..write('exportReminderDismissed: $exportReminderDismissed, ')
          ..write('lastExportAtMs: $lastExportAtMs, ')
          ..write('notificationMilestones: $notificationMilestones')
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
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserPreferencesData &&
          other.id == this.id &&
          other.totalPerContractToggle == this.totalPerContractToggle &&
          other.deltaConventionDefault == this.deltaConventionDefault &&
          other.firstRunExplainerShown == this.firstRunExplainerShown &&
          other.ivResolutionNoticeDismissed ==
              this.ivResolutionNoticeDismissed &&
          other.exportReminderDismissed == this.exportReminderDismissed &&
          other.lastExportAtMs == this.lastExportAtMs &&
          other.notificationMilestones == this.notificationMilestones);
}

class UserPreferencesCompanion extends UpdateCompanion<UserPreferencesData> {
  final Value<String> id;
  final Value<bool> totalPerContractToggle;
  final Value<String> deltaConventionDefault;
  final Value<bool> firstRunExplainerShown;
  final Value<bool> ivResolutionNoticeDismissed;
  final Value<bool> exportReminderDismissed;
  final Value<int?> lastExportAtMs;
  final Value<String> notificationMilestones;
  final Value<int> rowid;
  const UserPreferencesCompanion({
    this.id = const Value.absent(),
    this.totalPerContractToggle = const Value.absent(),
    this.deltaConventionDefault = const Value.absent(),
    this.firstRunExplainerShown = const Value.absent(),
    this.ivResolutionNoticeDismissed = const Value.absent(),
    this.exportReminderDismissed = const Value.absent(),
    this.lastExportAtMs = const Value.absent(),
    this.notificationMilestones = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserPreferencesCompanion.insert({
    required String id,
    required bool totalPerContractToggle,
    required String deltaConventionDefault,
    required bool firstRunExplainerShown,
    required bool ivResolutionNoticeDismissed,
    this.exportReminderDismissed = const Value.absent(),
    this.lastExportAtMs = const Value.absent(),
    this.notificationMilestones = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       totalPerContractToggle = Value(totalPerContractToggle),
       deltaConventionDefault = Value(deltaConventionDefault),
       firstRunExplainerShown = Value(firstRunExplainerShown),
       ivResolutionNoticeDismissed = Value(ivResolutionNoticeDismissed);
  static Insertable<UserPreferencesData> custom({
    Expression<String>? id,
    Expression<bool>? totalPerContractToggle,
    Expression<String>? deltaConventionDefault,
    Expression<bool>? firstRunExplainerShown,
    Expression<bool>? ivResolutionNoticeDismissed,
    Expression<bool>? exportReminderDismissed,
    Expression<int>? lastExportAtMs,
    Expression<String>? notificationMilestones,
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
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserPreferencesCompanion copyWith({
    Value<String>? id,
    Value<bool>? totalPerContractToggle,
    Value<String>? deltaConventionDefault,
    Value<bool>? firstRunExplainerShown,
    Value<bool>? ivResolutionNoticeDismissed,
    Value<bool>? exportReminderDismissed,
    Value<int?>? lastExportAtMs,
    Value<String>? notificationMilestones,
    Value<int>? rowid,
  }) {
    return UserPreferencesCompanion(
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
        deltaConventionDefault.value,
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
      map['last_export_at_ms'] = Variable<int>(lastExportAtMs.value);
    }
    if (notificationMilestones.present) {
      map['notification_milestones'] = Variable<String>(
        notificationMilestones.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserPreferencesCompanion(')
          ..write('id: $id, ')
          ..write('totalPerContractToggle: $totalPerContractToggle, ')
          ..write('deltaConventionDefault: $deltaConventionDefault, ')
          ..write('firstRunExplainerShown: $firstRunExplainerShown, ')
          ..write('ivResolutionNoticeDismissed: $ivResolutionNoticeDismissed, ')
          ..write('exportReminderDismissed: $exportReminderDismissed, ')
          ..write('lastExportAtMs: $lastExportAtMs, ')
          ..write('notificationMilestones: $notificationMilestones, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class DatabaseAtV4 extends GeneratedDatabase {
  DatabaseAtV4(QueryExecutor e) : super(e);
  late final Underlying underlying = Underlying(this);
  late final WheelCycle wheelCycle = WheelCycle(this);
  late final Leg leg = Leg(this);
  late final Snapshot snapshot = Snapshot(this);
  late final ShareLot shareLot = ShareLot(this);
  late final RuleProfile ruleProfile = RuleProfile(this);
  late final RuleProfileVersion ruleProfileVersion = RuleProfileVersion(this);
  late final UserPreferences userPreferences = UserPreferences(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    underlying,
    wheelCycle,
    leg,
    snapshot,
    shareLot,
    ruleProfile,
    ruleProfileVersion,
    userPreferences,
  ];
  @override
  int get schemaVersion => 4;
}
