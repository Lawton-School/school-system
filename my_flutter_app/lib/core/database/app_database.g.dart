// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $OfflineQueueEntriesTable extends OfflineQueueEntries
    with TableInfo<$OfflineQueueEntriesTable, OfflineQueueEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OfflineQueueEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schoolIdMeta = const VerificationMeta(
    'schoolId',
  );
  @override
  late final GeneratedColumn<String> schoolId = GeneratedColumn<String>(
    'school_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetTableMeta = const VerificationMeta(
    'targetTable',
  );
  @override
  late final GeneratedColumn<String> targetTable = GeneratedColumn<String>(
    'target_table',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    schoolId,
    targetTable,
    action,
    payload,
    createdAt,
    retryCount,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'offline_queue_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<OfflineQueueEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('school_id')) {
      context.handle(
        _schoolIdMeta,
        schoolId.isAcceptableOrUnknown(data['school_id']!, _schoolIdMeta),
      );
    } else if (isInserting) {
      context.missing(_schoolIdMeta);
    }
    if (data.containsKey('target_table')) {
      context.handle(
        _targetTableMeta,
        targetTable.isAcceptableOrUnknown(
          data['target_table']!,
          _targetTableMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetTableMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OfflineQueueEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OfflineQueueEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      schoolId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}school_id'],
      )!,
      targetTable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_table'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $OfflineQueueEntriesTable createAlias(String alias) {
    return $OfflineQueueEntriesTable(attachedDatabase, alias);
  }
}

class OfflineQueueEntry extends DataClass
    implements Insertable<OfflineQueueEntry> {
  final String id;
  final String schoolId;
  final String targetTable;
  final String action;
  final String payload;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;
  const OfflineQueueEntry({
    required this.id,
    required this.schoolId,
    required this.targetTable,
    required this.action,
    required this.payload,
    required this.createdAt,
    required this.retryCount,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['school_id'] = Variable<String>(schoolId);
    map['target_table'] = Variable<String>(targetTable);
    map['action'] = Variable<String>(action);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  OfflineQueueEntriesCompanion toCompanion(bool nullToAbsent) {
    return OfflineQueueEntriesCompanion(
      id: Value(id),
      schoolId: Value(schoolId),
      targetTable: Value(targetTable),
      action: Value(action),
      payload: Value(payload),
      createdAt: Value(createdAt),
      retryCount: Value(retryCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory OfflineQueueEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OfflineQueueEntry(
      id: serializer.fromJson<String>(json['id']),
      schoolId: serializer.fromJson<String>(json['schoolId']),
      targetTable: serializer.fromJson<String>(json['targetTable']),
      action: serializer.fromJson<String>(json['action']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'schoolId': serializer.toJson<String>(schoolId),
      'targetTable': serializer.toJson<String>(targetTable),
      'action': serializer.toJson<String>(action),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'retryCount': serializer.toJson<int>(retryCount),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  OfflineQueueEntry copyWith({
    String? id,
    String? schoolId,
    String? targetTable,
    String? action,
    String? payload,
    DateTime? createdAt,
    int? retryCount,
    Value<String?> lastError = const Value.absent(),
  }) => OfflineQueueEntry(
    id: id ?? this.id,
    schoolId: schoolId ?? this.schoolId,
    targetTable: targetTable ?? this.targetTable,
    action: action ?? this.action,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
    retryCount: retryCount ?? this.retryCount,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  OfflineQueueEntry copyWithCompanion(OfflineQueueEntriesCompanion data) {
    return OfflineQueueEntry(
      id: data.id.present ? data.id.value : this.id,
      schoolId: data.schoolId.present ? data.schoolId.value : this.schoolId,
      targetTable: data.targetTable.present
          ? data.targetTable.value
          : this.targetTable,
      action: data.action.present ? data.action.value : this.action,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OfflineQueueEntry(')
          ..write('id: $id, ')
          ..write('schoolId: $schoolId, ')
          ..write('targetTable: $targetTable, ')
          ..write('action: $action, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    schoolId,
    targetTable,
    action,
    payload,
    createdAt,
    retryCount,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfflineQueueEntry &&
          other.id == this.id &&
          other.schoolId == this.schoolId &&
          other.targetTable == this.targetTable &&
          other.action == this.action &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.retryCount == this.retryCount &&
          other.lastError == this.lastError);
}

class OfflineQueueEntriesCompanion extends UpdateCompanion<OfflineQueueEntry> {
  final Value<String> id;
  final Value<String> schoolId;
  final Value<String> targetTable;
  final Value<String> action;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  final Value<int> retryCount;
  final Value<String?> lastError;
  final Value<int> rowid;
  const OfflineQueueEntriesCompanion({
    this.id = const Value.absent(),
    this.schoolId = const Value.absent(),
    this.targetTable = const Value.absent(),
    this.action = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OfflineQueueEntriesCompanion.insert({
    required String id,
    required String schoolId,
    required String targetTable,
    required String action,
    required String payload,
    required DateTime createdAt,
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       schoolId = Value(schoolId),
       targetTable = Value(targetTable),
       action = Value(action),
       payload = Value(payload),
       createdAt = Value(createdAt);
  static Insertable<OfflineQueueEntry> custom({
    Expression<String>? id,
    Expression<String>? schoolId,
    Expression<String>? targetTable,
    Expression<String>? action,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
    Expression<int>? retryCount,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (schoolId != null) 'school_id': schoolId,
      if (targetTable != null) 'target_table': targetTable,
      if (action != null) 'action': action,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (retryCount != null) 'retry_count': retryCount,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OfflineQueueEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? schoolId,
    Value<String>? targetTable,
    Value<String>? action,
    Value<String>? payload,
    Value<DateTime>? createdAt,
    Value<int>? retryCount,
    Value<String?>? lastError,
    Value<int>? rowid,
  }) {
    return OfflineQueueEntriesCompanion(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      targetTable: targetTable ?? this.targetTable,
      action: action ?? this.action,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (schoolId.present) {
      map['school_id'] = Variable<String>(schoolId.value);
    }
    if (targetTable.present) {
      map['target_table'] = Variable<String>(targetTable.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OfflineQueueEntriesCompanion(')
          ..write('id: $id, ')
          ..write('schoolId: $schoolId, ')
          ..write('targetTable: $targetTable, ')
          ..write('action: $action, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedKpisTable extends CachedKpis
    with TableInfo<$CachedKpisTable, CachedKpi> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedKpisTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _kpiKeyMeta = const VerificationMeta('kpiKey');
  @override
  late final GeneratedColumn<String> kpiKey = GeneratedColumn<String>(
    'kpi_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schoolIdMeta = const VerificationMeta(
    'schoolId',
  );
  @override
  late final GeneratedColumn<String> schoolId = GeneratedColumn<String>(
    'school_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [kpiKey, schoolId, data, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_kpis';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedKpi> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('kpi_key')) {
      context.handle(
        _kpiKeyMeta,
        kpiKey.isAcceptableOrUnknown(data['kpi_key']!, _kpiKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_kpiKeyMeta);
    }
    if (data.containsKey('school_id')) {
      context.handle(
        _schoolIdMeta,
        schoolId.isAcceptableOrUnknown(data['school_id']!, _schoolIdMeta),
      );
    } else if (isInserting) {
      context.missing(_schoolIdMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {kpiKey, schoolId};
  @override
  CachedKpi map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedKpi(
      kpiKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kpi_key'],
      )!,
      schoolId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}school_id'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CachedKpisTable createAlias(String alias) {
    return $CachedKpisTable(attachedDatabase, alias);
  }
}

class CachedKpi extends DataClass implements Insertable<CachedKpi> {
  final String kpiKey;
  final String schoolId;
  final String data;
  final DateTime updatedAt;
  const CachedKpi({
    required this.kpiKey,
    required this.schoolId,
    required this.data,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['kpi_key'] = Variable<String>(kpiKey);
    map['school_id'] = Variable<String>(schoolId);
    map['data'] = Variable<String>(data);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CachedKpisCompanion toCompanion(bool nullToAbsent) {
    return CachedKpisCompanion(
      kpiKey: Value(kpiKey),
      schoolId: Value(schoolId),
      data: Value(data),
      updatedAt: Value(updatedAt),
    );
  }

  factory CachedKpi.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedKpi(
      kpiKey: serializer.fromJson<String>(json['kpiKey']),
      schoolId: serializer.fromJson<String>(json['schoolId']),
      data: serializer.fromJson<String>(json['data']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'kpiKey': serializer.toJson<String>(kpiKey),
      'schoolId': serializer.toJson<String>(schoolId),
      'data': serializer.toJson<String>(data),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CachedKpi copyWith({
    String? kpiKey,
    String? schoolId,
    String? data,
    DateTime? updatedAt,
  }) => CachedKpi(
    kpiKey: kpiKey ?? this.kpiKey,
    schoolId: schoolId ?? this.schoolId,
    data: data ?? this.data,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CachedKpi copyWithCompanion(CachedKpisCompanion data) {
    return CachedKpi(
      kpiKey: data.kpiKey.present ? data.kpiKey.value : this.kpiKey,
      schoolId: data.schoolId.present ? data.schoolId.value : this.schoolId,
      data: data.data.present ? data.data.value : this.data,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedKpi(')
          ..write('kpiKey: $kpiKey, ')
          ..write('schoolId: $schoolId, ')
          ..write('data: $data, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(kpiKey, schoolId, data, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedKpi &&
          other.kpiKey == this.kpiKey &&
          other.schoolId == this.schoolId &&
          other.data == this.data &&
          other.updatedAt == this.updatedAt);
}

class CachedKpisCompanion extends UpdateCompanion<CachedKpi> {
  final Value<String> kpiKey;
  final Value<String> schoolId;
  final Value<String> data;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CachedKpisCompanion({
    this.kpiKey = const Value.absent(),
    this.schoolId = const Value.absent(),
    this.data = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedKpisCompanion.insert({
    required String kpiKey,
    required String schoolId,
    required String data,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : kpiKey = Value(kpiKey),
       schoolId = Value(schoolId),
       data = Value(data),
       updatedAt = Value(updatedAt);
  static Insertable<CachedKpi> custom({
    Expression<String>? kpiKey,
    Expression<String>? schoolId,
    Expression<String>? data,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (kpiKey != null) 'kpi_key': kpiKey,
      if (schoolId != null) 'school_id': schoolId,
      if (data != null) 'data': data,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedKpisCompanion copyWith({
    Value<String>? kpiKey,
    Value<String>? schoolId,
    Value<String>? data,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CachedKpisCompanion(
      kpiKey: kpiKey ?? this.kpiKey,
      schoolId: schoolId ?? this.schoolId,
      data: data ?? this.data,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (kpiKey.present) {
      map['kpi_key'] = Variable<String>(kpiKey.value);
    }
    if (schoolId.present) {
      map['school_id'] = Variable<String>(schoolId.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedKpisCompanion(')
          ..write('kpiKey: $kpiKey, ')
          ..write('schoolId: $schoolId, ')
          ..write('data: $data, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedRostersTable extends CachedRosters
    with TableInfo<$CachedRostersTable, CachedRoster> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedRostersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _rosterKeyMeta = const VerificationMeta(
    'rosterKey',
  );
  @override
  late final GeneratedColumn<String> rosterKey = GeneratedColumn<String>(
    'roster_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schoolIdMeta = const VerificationMeta(
    'schoolId',
  );
  @override
  late final GeneratedColumn<String> schoolId = GeneratedColumn<String>(
    'school_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [rosterKey, schoolId, data, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_rosters';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedRoster> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('roster_key')) {
      context.handle(
        _rosterKeyMeta,
        rosterKey.isAcceptableOrUnknown(data['roster_key']!, _rosterKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_rosterKeyMeta);
    }
    if (data.containsKey('school_id')) {
      context.handle(
        _schoolIdMeta,
        schoolId.isAcceptableOrUnknown(data['school_id']!, _schoolIdMeta),
      );
    } else if (isInserting) {
      context.missing(_schoolIdMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {rosterKey, schoolId};
  @override
  CachedRoster map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedRoster(
      rosterKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}roster_key'],
      )!,
      schoolId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}school_id'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CachedRostersTable createAlias(String alias) {
    return $CachedRostersTable(attachedDatabase, alias);
  }
}

class CachedRoster extends DataClass implements Insertable<CachedRoster> {
  final String rosterKey;
  final String schoolId;
  final String data;
  final DateTime updatedAt;
  const CachedRoster({
    required this.rosterKey,
    required this.schoolId,
    required this.data,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['roster_key'] = Variable<String>(rosterKey);
    map['school_id'] = Variable<String>(schoolId);
    map['data'] = Variable<String>(data);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CachedRostersCompanion toCompanion(bool nullToAbsent) {
    return CachedRostersCompanion(
      rosterKey: Value(rosterKey),
      schoolId: Value(schoolId),
      data: Value(data),
      updatedAt: Value(updatedAt),
    );
  }

  factory CachedRoster.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedRoster(
      rosterKey: serializer.fromJson<String>(json['rosterKey']),
      schoolId: serializer.fromJson<String>(json['schoolId']),
      data: serializer.fromJson<String>(json['data']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'rosterKey': serializer.toJson<String>(rosterKey),
      'schoolId': serializer.toJson<String>(schoolId),
      'data': serializer.toJson<String>(data),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CachedRoster copyWith({
    String? rosterKey,
    String? schoolId,
    String? data,
    DateTime? updatedAt,
  }) => CachedRoster(
    rosterKey: rosterKey ?? this.rosterKey,
    schoolId: schoolId ?? this.schoolId,
    data: data ?? this.data,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CachedRoster copyWithCompanion(CachedRostersCompanion data) {
    return CachedRoster(
      rosterKey: data.rosterKey.present ? data.rosterKey.value : this.rosterKey,
      schoolId: data.schoolId.present ? data.schoolId.value : this.schoolId,
      data: data.data.present ? data.data.value : this.data,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedRoster(')
          ..write('rosterKey: $rosterKey, ')
          ..write('schoolId: $schoolId, ')
          ..write('data: $data, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(rosterKey, schoolId, data, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedRoster &&
          other.rosterKey == this.rosterKey &&
          other.schoolId == this.schoolId &&
          other.data == this.data &&
          other.updatedAt == this.updatedAt);
}

class CachedRostersCompanion extends UpdateCompanion<CachedRoster> {
  final Value<String> rosterKey;
  final Value<String> schoolId;
  final Value<String> data;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CachedRostersCompanion({
    this.rosterKey = const Value.absent(),
    this.schoolId = const Value.absent(),
    this.data = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedRostersCompanion.insert({
    required String rosterKey,
    required String schoolId,
    required String data,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : rosterKey = Value(rosterKey),
       schoolId = Value(schoolId),
       data = Value(data),
       updatedAt = Value(updatedAt);
  static Insertable<CachedRoster> custom({
    Expression<String>? rosterKey,
    Expression<String>? schoolId,
    Expression<String>? data,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (rosterKey != null) 'roster_key': rosterKey,
      if (schoolId != null) 'school_id': schoolId,
      if (data != null) 'data': data,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedRostersCompanion copyWith({
    Value<String>? rosterKey,
    Value<String>? schoolId,
    Value<String>? data,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CachedRostersCompanion(
      rosterKey: rosterKey ?? this.rosterKey,
      schoolId: schoolId ?? this.schoolId,
      data: data ?? this.data,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (rosterKey.present) {
      map['roster_key'] = Variable<String>(rosterKey.value);
    }
    if (schoolId.present) {
      map['school_id'] = Variable<String>(schoolId.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedRostersCompanion(')
          ..write('rosterKey: $rosterKey, ')
          ..write('schoolId: $schoolId, ')
          ..write('data: $data, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $OfflineQueueEntriesTable offlineQueueEntries =
      $OfflineQueueEntriesTable(this);
  late final $CachedKpisTable cachedKpis = $CachedKpisTable(this);
  late final $CachedRostersTable cachedRosters = $CachedRostersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    offlineQueueEntries,
    cachedKpis,
    cachedRosters,
  ];
}

typedef $$OfflineQueueEntriesTableCreateCompanionBuilder =
    OfflineQueueEntriesCompanion Function({
      required String id,
      required String schoolId,
      required String targetTable,
      required String action,
      required String payload,
      required DateTime createdAt,
      Value<int> retryCount,
      Value<String?> lastError,
      Value<int> rowid,
    });
typedef $$OfflineQueueEntriesTableUpdateCompanionBuilder =
    OfflineQueueEntriesCompanion Function({
      Value<String> id,
      Value<String> schoolId,
      Value<String> targetTable,
      Value<String> action,
      Value<String> payload,
      Value<DateTime> createdAt,
      Value<int> retryCount,
      Value<String?> lastError,
      Value<int> rowid,
    });

class $$OfflineQueueEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $OfflineQueueEntriesTable> {
  $$OfflineQueueEntriesTableFilterComposer({
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

  ColumnFilters<String> get schoolId => $composableBuilder(
    column: $table.schoolId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetTable => $composableBuilder(
    column: $table.targetTable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OfflineQueueEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $OfflineQueueEntriesTable> {
  $$OfflineQueueEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get schoolId => $composableBuilder(
    column: $table.schoolId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetTable => $composableBuilder(
    column: $table.targetTable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OfflineQueueEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OfflineQueueEntriesTable> {
  $$OfflineQueueEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get schoolId =>
      $composableBuilder(column: $table.schoolId, builder: (column) => column);

  GeneratedColumn<String> get targetTable => $composableBuilder(
    column: $table.targetTable,
    builder: (column) => column,
  );

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$OfflineQueueEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OfflineQueueEntriesTable,
          OfflineQueueEntry,
          $$OfflineQueueEntriesTableFilterComposer,
          $$OfflineQueueEntriesTableOrderingComposer,
          $$OfflineQueueEntriesTableAnnotationComposer,
          $$OfflineQueueEntriesTableCreateCompanionBuilder,
          $$OfflineQueueEntriesTableUpdateCompanionBuilder,
          (
            OfflineQueueEntry,
            BaseReferences<
              _$AppDatabase,
              $OfflineQueueEntriesTable,
              OfflineQueueEntry
            >,
          ),
          OfflineQueueEntry,
          PrefetchHooks Function()
        > {
  $$OfflineQueueEntriesTableTableManager(
    _$AppDatabase db,
    $OfflineQueueEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OfflineQueueEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OfflineQueueEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$OfflineQueueEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> schoolId = const Value.absent(),
                Value<String> targetTable = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OfflineQueueEntriesCompanion(
                id: id,
                schoolId: schoolId,
                targetTable: targetTable,
                action: action,
                payload: payload,
                createdAt: createdAt,
                retryCount: retryCount,
                lastError: lastError,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String schoolId,
                required String targetTable,
                required String action,
                required String payload,
                required DateTime createdAt,
                Value<int> retryCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OfflineQueueEntriesCompanion.insert(
                id: id,
                schoolId: schoolId,
                targetTable: targetTable,
                action: action,
                payload: payload,
                createdAt: createdAt,
                retryCount: retryCount,
                lastError: lastError,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OfflineQueueEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OfflineQueueEntriesTable,
      OfflineQueueEntry,
      $$OfflineQueueEntriesTableFilterComposer,
      $$OfflineQueueEntriesTableOrderingComposer,
      $$OfflineQueueEntriesTableAnnotationComposer,
      $$OfflineQueueEntriesTableCreateCompanionBuilder,
      $$OfflineQueueEntriesTableUpdateCompanionBuilder,
      (
        OfflineQueueEntry,
        BaseReferences<
          _$AppDatabase,
          $OfflineQueueEntriesTable,
          OfflineQueueEntry
        >,
      ),
      OfflineQueueEntry,
      PrefetchHooks Function()
    >;
typedef $$CachedKpisTableCreateCompanionBuilder =
    CachedKpisCompanion Function({
      required String kpiKey,
      required String schoolId,
      required String data,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CachedKpisTableUpdateCompanionBuilder =
    CachedKpisCompanion Function({
      Value<String> kpiKey,
      Value<String> schoolId,
      Value<String> data,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CachedKpisTableFilterComposer
    extends Composer<_$AppDatabase, $CachedKpisTable> {
  $$CachedKpisTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get kpiKey => $composableBuilder(
    column: $table.kpiKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get schoolId => $composableBuilder(
    column: $table.schoolId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedKpisTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedKpisTable> {
  $$CachedKpisTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get kpiKey => $composableBuilder(
    column: $table.kpiKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get schoolId => $composableBuilder(
    column: $table.schoolId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedKpisTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedKpisTable> {
  $$CachedKpisTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get kpiKey =>
      $composableBuilder(column: $table.kpiKey, builder: (column) => column);

  GeneratedColumn<String> get schoolId =>
      $composableBuilder(column: $table.schoolId, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CachedKpisTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedKpisTable,
          CachedKpi,
          $$CachedKpisTableFilterComposer,
          $$CachedKpisTableOrderingComposer,
          $$CachedKpisTableAnnotationComposer,
          $$CachedKpisTableCreateCompanionBuilder,
          $$CachedKpisTableUpdateCompanionBuilder,
          (
            CachedKpi,
            BaseReferences<_$AppDatabase, $CachedKpisTable, CachedKpi>,
          ),
          CachedKpi,
          PrefetchHooks Function()
        > {
  $$CachedKpisTableTableManager(_$AppDatabase db, $CachedKpisTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedKpisTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedKpisTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedKpisTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> kpiKey = const Value.absent(),
                Value<String> schoolId = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedKpisCompanion(
                kpiKey: kpiKey,
                schoolId: schoolId,
                data: data,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String kpiKey,
                required String schoolId,
                required String data,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedKpisCompanion.insert(
                kpiKey: kpiKey,
                schoolId: schoolId,
                data: data,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedKpisTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedKpisTable,
      CachedKpi,
      $$CachedKpisTableFilterComposer,
      $$CachedKpisTableOrderingComposer,
      $$CachedKpisTableAnnotationComposer,
      $$CachedKpisTableCreateCompanionBuilder,
      $$CachedKpisTableUpdateCompanionBuilder,
      (CachedKpi, BaseReferences<_$AppDatabase, $CachedKpisTable, CachedKpi>),
      CachedKpi,
      PrefetchHooks Function()
    >;
typedef $$CachedRostersTableCreateCompanionBuilder =
    CachedRostersCompanion Function({
      required String rosterKey,
      required String schoolId,
      required String data,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CachedRostersTableUpdateCompanionBuilder =
    CachedRostersCompanion Function({
      Value<String> rosterKey,
      Value<String> schoolId,
      Value<String> data,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CachedRostersTableFilterComposer
    extends Composer<_$AppDatabase, $CachedRostersTable> {
  $$CachedRostersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get rosterKey => $composableBuilder(
    column: $table.rosterKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get schoolId => $composableBuilder(
    column: $table.schoolId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedRostersTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedRostersTable> {
  $$CachedRostersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get rosterKey => $composableBuilder(
    column: $table.rosterKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get schoolId => $composableBuilder(
    column: $table.schoolId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedRostersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedRostersTable> {
  $$CachedRostersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get rosterKey =>
      $composableBuilder(column: $table.rosterKey, builder: (column) => column);

  GeneratedColumn<String> get schoolId =>
      $composableBuilder(column: $table.schoolId, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CachedRostersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedRostersTable,
          CachedRoster,
          $$CachedRostersTableFilterComposer,
          $$CachedRostersTableOrderingComposer,
          $$CachedRostersTableAnnotationComposer,
          $$CachedRostersTableCreateCompanionBuilder,
          $$CachedRostersTableUpdateCompanionBuilder,
          (
            CachedRoster,
            BaseReferences<_$AppDatabase, $CachedRostersTable, CachedRoster>,
          ),
          CachedRoster,
          PrefetchHooks Function()
        > {
  $$CachedRostersTableTableManager(_$AppDatabase db, $CachedRostersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedRostersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedRostersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedRostersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> rosterKey = const Value.absent(),
                Value<String> schoolId = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedRostersCompanion(
                rosterKey: rosterKey,
                schoolId: schoolId,
                data: data,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String rosterKey,
                required String schoolId,
                required String data,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedRostersCompanion.insert(
                rosterKey: rosterKey,
                schoolId: schoolId,
                data: data,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedRostersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedRostersTable,
      CachedRoster,
      $$CachedRostersTableFilterComposer,
      $$CachedRostersTableOrderingComposer,
      $$CachedRostersTableAnnotationComposer,
      $$CachedRostersTableCreateCompanionBuilder,
      $$CachedRostersTableUpdateCompanionBuilder,
      (
        CachedRoster,
        BaseReferences<_$AppDatabase, $CachedRostersTable, CachedRoster>,
      ),
      CachedRoster,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$OfflineQueueEntriesTableTableManager get offlineQueueEntries =>
      $$OfflineQueueEntriesTableTableManager(_db, _db.offlineQueueEntries);
  $$CachedKpisTableTableManager get cachedKpis =>
      $$CachedKpisTableTableManager(_db, _db.cachedKpis);
  $$CachedRostersTableTableManager get cachedRosters =>
      $$CachedRostersTableTableManager(_db, _db.cachedRosters);
}
