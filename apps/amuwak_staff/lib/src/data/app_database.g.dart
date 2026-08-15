// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $StaffTable extends Staff with TableInfo<$StaffTable, StaffData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StaffTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _mustChangePinMeta = const VerificationMeta(
    'mustChangePin',
  );
  @override
  late final GeneratedColumn<bool> mustChangePin = GeneratedColumn<bool>(
    'must_change_pin',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("must_change_pin" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    username,
    displayName,
    phone,
    role,
    active,
    mustChangePin,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'staff';
  @override
  VerificationContext validateIntegrity(
    Insertable<StaffData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('must_change_pin')) {
      context.handle(
        _mustChangePinMeta,
        mustChangePin.isAcceptableOrUnknown(
          data['must_change_pin']!,
          _mustChangePinMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StaffData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StaffData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      mustChangePin: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}must_change_pin'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $StaffTable createAlias(String alias) {
    return $StaffTable(attachedDatabase, alias);
  }
}

class StaffData extends DataClass implements Insertable<StaffData> {
  final String id;
  final String username;
  final String displayName;
  final String? phone;
  final String role;
  final bool active;
  final bool mustChangePin;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const StaffData({
    required this.id,
    required this.username,
    required this.displayName,
    this.phone,
    required this.role,
    required this.active,
    required this.mustChangePin,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['username'] = Variable<String>(username);
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    map['role'] = Variable<String>(role);
    map['active'] = Variable<bool>(active);
    map['must_change_pin'] = Variable<bool>(mustChangePin);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  StaffCompanion toCompanion(bool nullToAbsent) {
    return StaffCompanion(
      id: Value(id),
      username: Value(username),
      displayName: Value(displayName),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      role: Value(role),
      active: Value(active),
      mustChangePin: Value(mustChangePin),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory StaffData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StaffData(
      id: serializer.fromJson<String>(json['id']),
      username: serializer.fromJson<String>(json['username']),
      displayName: serializer.fromJson<String>(json['displayName']),
      phone: serializer.fromJson<String?>(json['phone']),
      role: serializer.fromJson<String>(json['role']),
      active: serializer.fromJson<bool>(json['active']),
      mustChangePin: serializer.fromJson<bool>(json['mustChangePin']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'username': serializer.toJson<String>(username),
      'displayName': serializer.toJson<String>(displayName),
      'phone': serializer.toJson<String?>(phone),
      'role': serializer.toJson<String>(role),
      'active': serializer.toJson<bool>(active),
      'mustChangePin': serializer.toJson<bool>(mustChangePin),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  StaffData copyWith({
    String? id,
    String? username,
    String? displayName,
    Value<String?> phone = const Value.absent(),
    String? role,
    bool? active,
    bool? mustChangePin,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => StaffData(
    id: id ?? this.id,
    username: username ?? this.username,
    displayName: displayName ?? this.displayName,
    phone: phone.present ? phone.value : this.phone,
    role: role ?? this.role,
    active: active ?? this.active,
    mustChangePin: mustChangePin ?? this.mustChangePin,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  StaffData copyWithCompanion(StaffCompanion data) {
    return StaffData(
      id: data.id.present ? data.id.value : this.id,
      username: data.username.present ? data.username.value : this.username,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      phone: data.phone.present ? data.phone.value : this.phone,
      role: data.role.present ? data.role.value : this.role,
      active: data.active.present ? data.active.value : this.active,
      mustChangePin: data.mustChangePin.present
          ? data.mustChangePin.value
          : this.mustChangePin,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StaffData(')
          ..write('id: $id, ')
          ..write('username: $username, ')
          ..write('displayName: $displayName, ')
          ..write('phone: $phone, ')
          ..write('role: $role, ')
          ..write('active: $active, ')
          ..write('mustChangePin: $mustChangePin, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    username,
    displayName,
    phone,
    role,
    active,
    mustChangePin,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StaffData &&
          other.id == this.id &&
          other.username == this.username &&
          other.displayName == this.displayName &&
          other.phone == this.phone &&
          other.role == this.role &&
          other.active == this.active &&
          other.mustChangePin == this.mustChangePin &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class StaffCompanion extends UpdateCompanion<StaffData> {
  final Value<String> id;
  final Value<String> username;
  final Value<String> displayName;
  final Value<String?> phone;
  final Value<String> role;
  final Value<bool> active;
  final Value<bool> mustChangePin;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const StaffCompanion({
    this.id = const Value.absent(),
    this.username = const Value.absent(),
    this.displayName = const Value.absent(),
    this.phone = const Value.absent(),
    this.role = const Value.absent(),
    this.active = const Value.absent(),
    this.mustChangePin = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StaffCompanion.insert({
    required String id,
    required String username,
    required String displayName,
    this.phone = const Value.absent(),
    required String role,
    this.active = const Value.absent(),
    this.mustChangePin = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       username = Value(username),
       displayName = Value(displayName),
       role = Value(role),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<StaffData> custom({
    Expression<String>? id,
    Expression<String>? username,
    Expression<String>? displayName,
    Expression<String>? phone,
    Expression<String>? role,
    Expression<bool>? active,
    Expression<bool>? mustChangePin,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (username != null) 'username': username,
      if (displayName != null) 'display_name': displayName,
      if (phone != null) 'phone': phone,
      if (role != null) 'role': role,
      if (active != null) 'active': active,
      if (mustChangePin != null) 'must_change_pin': mustChangePin,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StaffCompanion copyWith({
    Value<String>? id,
    Value<String>? username,
    Value<String>? displayName,
    Value<String?>? phone,
    Value<String>? role,
    Value<bool>? active,
    Value<bool>? mustChangePin,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return StaffCompanion(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      active: active ?? this.active,
      mustChangePin: mustChangePin ?? this.mustChangePin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (mustChangePin.present) {
      map['must_change_pin'] = Variable<bool>(mustChangePin.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StaffCompanion(')
          ..write('id: $id, ')
          ..write('username: $username, ')
          ..write('displayName: $displayName, ')
          ..write('phone: $phone, ')
          ..write('role: $role, ')
          ..write('active: $active, ')
          ..write('mustChangePin: $mustChangePin, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CustomersTable extends Customers
    with TableInfo<$CustomersTable, Customer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomersTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
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
  static const VerificationMeta _customRatePerKgUgxMeta =
      const VerificationMeta('customRatePerKgUgx');
  @override
  late final GeneratedColumn<double> customRatePerKgUgx =
      GeneratedColumn<double>(
        'custom_rate_per_kg_ugx',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    phone,
    address,
    notes,
    customRatePerKgUgx,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'customers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Customer> instance, {
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
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    } else if (isInserting) {
      context.missing(_phoneMeta);
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('custom_rate_per_kg_ugx')) {
      context.handle(
        _customRatePerKgUgxMeta,
        customRatePerKgUgx.isAcceptableOrUnknown(
          data['custom_rate_per_kg_ugx']!,
          _customRatePerKgUgxMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Customer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Customer(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      customRatePerKgUgx: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}custom_rate_per_kg_ugx'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $CustomersTable createAlias(String alias) {
    return $CustomersTable(attachedDatabase, alias);
  }
}

class Customer extends DataClass implements Insertable<Customer> {
  final String id;
  final String name;
  final String phone;
  final String? address;
  final String? notes;
  final double? customRatePerKgUgx;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.address,
    this.notes,
    this.customRatePerKgUgx,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['phone'] = Variable<String>(phone);
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || customRatePerKgUgx != null) {
      map['custom_rate_per_kg_ugx'] = Variable<double>(customRatePerKgUgx);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  CustomersCompanion toCompanion(bool nullToAbsent) {
    return CustomersCompanion(
      id: Value(id),
      name: Value(name),
      phone: Value(phone),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      customRatePerKgUgx: customRatePerKgUgx == null && nullToAbsent
          ? const Value.absent()
          : Value(customRatePerKgUgx),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Customer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Customer(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String>(json['phone']),
      address: serializer.fromJson<String?>(json['address']),
      notes: serializer.fromJson<String?>(json['notes']),
      customRatePerKgUgx: serializer.fromJson<double?>(
        json['customRatePerKgUgx'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String>(phone),
      'address': serializer.toJson<String?>(address),
      'notes': serializer.toJson<String?>(notes),
      'customRatePerKgUgx': serializer.toJson<double?>(customRatePerKgUgx),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    Value<String?> address = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<double?> customRatePerKgUgx = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Customer(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    address: address.present ? address.value : this.address,
    notes: notes.present ? notes.value : this.notes,
    customRatePerKgUgx: customRatePerKgUgx.present
        ? customRatePerKgUgx.value
        : this.customRatePerKgUgx,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Customer copyWithCompanion(CustomersCompanion data) {
    return Customer(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
      address: data.address.present ? data.address.value : this.address,
      notes: data.notes.present ? data.notes.value : this.notes,
      customRatePerKgUgx: data.customRatePerKgUgx.present
          ? data.customRatePerKgUgx.value
          : this.customRatePerKgUgx,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Customer(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('address: $address, ')
          ..write('notes: $notes, ')
          ..write('customRatePerKgUgx: $customRatePerKgUgx, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    phone,
    address,
    notes,
    customRatePerKgUgx,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Customer &&
          other.id == this.id &&
          other.name == this.name &&
          other.phone == this.phone &&
          other.address == this.address &&
          other.notes == this.notes &&
          other.customRatePerKgUgx == this.customRatePerKgUgx &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class CustomersCompanion extends UpdateCompanion<Customer> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> phone;
  final Value<String?> address;
  final Value<String?> notes;
  final Value<double?> customRatePerKgUgx;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const CustomersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.address = const Value.absent(),
    this.notes = const Value.absent(),
    this.customRatePerKgUgx = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CustomersCompanion.insert({
    required String id,
    required String name,
    required String phone,
    this.address = const Value.absent(),
    this.notes = const Value.absent(),
    this.customRatePerKgUgx = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       phone = Value(phone),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Customer> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<String>? address,
    Expression<String>? notes,
    Expression<double>? customRatePerKgUgx,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
      if (notes != null) 'notes': notes,
      if (customRatePerKgUgx != null)
        'custom_rate_per_kg_ugx': customRatePerKgUgx,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CustomersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? phone,
    Value<String?>? address,
    Value<String?>? notes,
    Value<double?>? customRatePerKgUgx,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return CustomersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      customRatePerKgUgx: customRatePerKgUgx ?? this.customRatePerKgUgx,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
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
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (customRatePerKgUgx.present) {
      map['custom_rate_per_kg_ugx'] = Variable<double>(
        customRatePerKgUgx.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('address: $address, ')
          ..write('notes: $notes, ')
          ..write('customRatePerKgUgx: $customRatePerKgUgx, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OrdersTable extends Orders with TableInfo<$OrdersTable, Order> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OrdersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderCodeMeta = const VerificationMeta(
    'orderCode',
  );
  @override
  late final GeneratedColumn<String> orderCode = GeneratedColumn<String>(
    'order_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta(
    'customerId',
  );
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
    'customer_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customerNameMeta = const VerificationMeta(
    'customerName',
  );
  @override
  late final GeneratedColumn<String> customerName = GeneratedColumn<String>(
    'customer_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serviceTypeMeta = const VerificationMeta(
    'serviceType',
  );
  @override
  late final GeneratedColumn<String> serviceType = GeneratedColumn<String>(
    'service_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _intakeMethodMeta = const VerificationMeta(
    'intakeMethod',
  );
  @override
  late final GeneratedColumn<String> intakeMethod = GeneratedColumn<String>(
    'intake_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fulfillmentMethodMeta = const VerificationMeta(
    'fulfillmentMethod',
  );
  @override
  late final GeneratedColumn<String> fulfillmentMethod =
      GeneratedColumn<String>(
        'fulfillment_method',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _itemCountMeta = const VerificationMeta(
    'itemCount',
  );
  @override
  late final GeneratedColumn<int> itemCount = GeneratedColumn<int>(
    'item_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _scheduledForMeta = const VerificationMeta(
    'scheduledFor',
  );
  @override
  late final GeneratedColumn<DateTime> scheduledFor = GeneratedColumn<DateTime>(
    'scheduled_for',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _expectedCollectionAtMeta =
      const VerificationMeta('expectedCollectionAt');
  @override
  late final GeneratedColumn<DateTime> expectedCollectionAt =
      GeneratedColumn<DateTime>(
        'expected_collection_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _assignedDriverMeta = const VerificationMeta(
    'assignedDriver',
  );
  @override
  late final GeneratedColumn<String> assignedDriver = GeneratedColumn<String>(
    'assigned_driver',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _intakeRecordedByMeta = const VerificationMeta(
    'intakeRecordedBy',
  );
  @override
  late final GeneratedColumn<String> intakeRecordedBy = GeneratedColumn<String>(
    'intake_recorded_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedByMeta = const VerificationMeta(
    'updatedBy',
  );
  @override
  late final GeneratedColumn<String> updatedBy = GeneratedColumn<String>(
    'updated_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedByMeta = const VerificationMeta(
    'deletedBy',
  );
  @override
  late final GeneratedColumn<String> deletedBy = GeneratedColumn<String>(
    'deleted_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratePerKgSnapshotUgxMeta =
      const VerificationMeta('ratePerKgSnapshotUgx');
  @override
  late final GeneratedColumn<double> ratePerKgSnapshotUgx =
      GeneratedColumn<double>(
        'rate_per_kg_snapshot_ugx',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _estimatedWeightKgMeta = const VerificationMeta(
    'estimatedWeightKg',
  );
  @override
  late final GeneratedColumn<double> estimatedWeightKg =
      GeneratedColumn<double>(
        'estimated_weight_kg',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _finalWeightKgMeta = const VerificationMeta(
    'finalWeightKg',
  );
  @override
  late final GeneratedColumn<double> finalWeightKg = GeneratedColumn<double>(
    'final_weight_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lineItemsMeta = const VerificationMeta(
    'lineItems',
  );
  @override
  late final GeneratedColumn<String> lineItems = GeneratedColumn<String>(
    'line_items',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _manualAdjustmentUgxMeta =
      const VerificationMeta('manualAdjustmentUgx');
  @override
  late final GeneratedColumn<int> manualAdjustmentUgx = GeneratedColumn<int>(
    'manual_adjustment_ugx',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalUgxMeta = const VerificationMeta(
    'totalUgx',
  );
  @override
  late final GeneratedColumn<int> totalUgx = GeneratedColumn<int>(
    'total_ugx',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deliveryFeeSnapshotUgxMeta =
      const VerificationMeta('deliveryFeeSnapshotUgx');
  @override
  late final GeneratedColumn<int> deliveryFeeSnapshotUgx = GeneratedColumn<int>(
    'delivery_fee_snapshot_ugx',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isExpressMeta = const VerificationMeta(
    'isExpress',
  );
  @override
  late final GeneratedColumn<bool> isExpress = GeneratedColumn<bool>(
    'is_express',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_express" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _expressFlatSnapshotUgxMeta =
      const VerificationMeta('expressFlatSnapshotUgx');
  @override
  late final GeneratedColumn<int> expressFlatSnapshotUgx = GeneratedColumn<int>(
    'express_flat_snapshot_ugx',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _expressPctSnapshotMeta =
      const VerificationMeta('expressPctSnapshot');
  @override
  late final GeneratedColumn<double> expressPctSnapshot =
      GeneratedColumn<double>(
        'express_pct_snapshot',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _paymentAmountUgxMeta = const VerificationMeta(
    'paymentAmountUgx',
  );
  @override
  late final GeneratedColumn<int> paymentAmountUgx = GeneratedColumn<int>(
    'payment_amount_ugx',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _cartItemsMeta = const VerificationMeta(
    'cartItems',
  );
  @override
  late final GeneratedColumn<String> cartItems = GeneratedColumn<String>(
    'cart_items',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    orderCode,
    customerId,
    customerName,
    phone,
    address,
    serviceType,
    status,
    intakeMethod,
    fulfillmentMethod,
    itemCount,
    notes,
    scheduledFor,
    expectedCollectionAt,
    assignedDriver,
    intakeRecordedBy,
    createdBy,
    updatedBy,
    deletedBy,
    createdAt,
    updatedAt,
    deletedAt,
    ratePerKgSnapshotUgx,
    estimatedWeightKg,
    finalWeightKg,
    lineItems,
    manualAdjustmentUgx,
    totalUgx,
    deliveryFeeSnapshotUgx,
    isExpress,
    expressFlatSnapshotUgx,
    expressPctSnapshot,
    paymentAmountUgx,
    cartItems,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'orders';
  @override
  VerificationContext validateIntegrity(
    Insertable<Order> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('order_code')) {
      context.handle(
        _orderCodeMeta,
        orderCode.isAcceptableOrUnknown(data['order_code']!, _orderCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_orderCodeMeta);
    }
    if (data.containsKey('customer_id')) {
      context.handle(
        _customerIdMeta,
        customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta),
      );
    }
    if (data.containsKey('customer_name')) {
      context.handle(
        _customerNameMeta,
        customerName.isAcceptableOrUnknown(
          data['customer_name']!,
          _customerNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_customerNameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    } else if (isInserting) {
      context.missing(_phoneMeta);
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    } else if (isInserting) {
      context.missing(_addressMeta);
    }
    if (data.containsKey('service_type')) {
      context.handle(
        _serviceTypeMeta,
        serviceType.isAcceptableOrUnknown(
          data['service_type']!,
          _serviceTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_serviceTypeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('intake_method')) {
      context.handle(
        _intakeMethodMeta,
        intakeMethod.isAcceptableOrUnknown(
          data['intake_method']!,
          _intakeMethodMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_intakeMethodMeta);
    }
    if (data.containsKey('fulfillment_method')) {
      context.handle(
        _fulfillmentMethodMeta,
        fulfillmentMethod.isAcceptableOrUnknown(
          data['fulfillment_method']!,
          _fulfillmentMethodMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fulfillmentMethodMeta);
    }
    if (data.containsKey('item_count')) {
      context.handle(
        _itemCountMeta,
        itemCount.isAcceptableOrUnknown(data['item_count']!, _itemCountMeta),
      );
    } else if (isInserting) {
      context.missing(_itemCountMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('scheduled_for')) {
      context.handle(
        _scheduledForMeta,
        scheduledFor.isAcceptableOrUnknown(
          data['scheduled_for']!,
          _scheduledForMeta,
        ),
      );
    }
    if (data.containsKey('expected_collection_at')) {
      context.handle(
        _expectedCollectionAtMeta,
        expectedCollectionAt.isAcceptableOrUnknown(
          data['expected_collection_at']!,
          _expectedCollectionAtMeta,
        ),
      );
    }
    if (data.containsKey('assigned_driver')) {
      context.handle(
        _assignedDriverMeta,
        assignedDriver.isAcceptableOrUnknown(
          data['assigned_driver']!,
          _assignedDriverMeta,
        ),
      );
    }
    if (data.containsKey('intake_recorded_by')) {
      context.handle(
        _intakeRecordedByMeta,
        intakeRecordedBy.isAcceptableOrUnknown(
          data['intake_recorded_by']!,
          _intakeRecordedByMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_intakeRecordedByMeta);
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    }
    if (data.containsKey('deleted_by')) {
      context.handle(
        _deletedByMeta,
        deletedBy.isAcceptableOrUnknown(data['deleted_by']!, _deletedByMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('rate_per_kg_snapshot_ugx')) {
      context.handle(
        _ratePerKgSnapshotUgxMeta,
        ratePerKgSnapshotUgx.isAcceptableOrUnknown(
          data['rate_per_kg_snapshot_ugx']!,
          _ratePerKgSnapshotUgxMeta,
        ),
      );
    }
    if (data.containsKey('estimated_weight_kg')) {
      context.handle(
        _estimatedWeightKgMeta,
        estimatedWeightKg.isAcceptableOrUnknown(
          data['estimated_weight_kg']!,
          _estimatedWeightKgMeta,
        ),
      );
    }
    if (data.containsKey('final_weight_kg')) {
      context.handle(
        _finalWeightKgMeta,
        finalWeightKg.isAcceptableOrUnknown(
          data['final_weight_kg']!,
          _finalWeightKgMeta,
        ),
      );
    }
    if (data.containsKey('line_items')) {
      context.handle(
        _lineItemsMeta,
        lineItems.isAcceptableOrUnknown(data['line_items']!, _lineItemsMeta),
      );
    }
    if (data.containsKey('manual_adjustment_ugx')) {
      context.handle(
        _manualAdjustmentUgxMeta,
        manualAdjustmentUgx.isAcceptableOrUnknown(
          data['manual_adjustment_ugx']!,
          _manualAdjustmentUgxMeta,
        ),
      );
    }
    if (data.containsKey('total_ugx')) {
      context.handle(
        _totalUgxMeta,
        totalUgx.isAcceptableOrUnknown(data['total_ugx']!, _totalUgxMeta),
      );
    }
    if (data.containsKey('delivery_fee_snapshot_ugx')) {
      context.handle(
        _deliveryFeeSnapshotUgxMeta,
        deliveryFeeSnapshotUgx.isAcceptableOrUnknown(
          data['delivery_fee_snapshot_ugx']!,
          _deliveryFeeSnapshotUgxMeta,
        ),
      );
    }
    if (data.containsKey('is_express')) {
      context.handle(
        _isExpressMeta,
        isExpress.isAcceptableOrUnknown(data['is_express']!, _isExpressMeta),
      );
    }
    if (data.containsKey('express_flat_snapshot_ugx')) {
      context.handle(
        _expressFlatSnapshotUgxMeta,
        expressFlatSnapshotUgx.isAcceptableOrUnknown(
          data['express_flat_snapshot_ugx']!,
          _expressFlatSnapshotUgxMeta,
        ),
      );
    }
    if (data.containsKey('express_pct_snapshot')) {
      context.handle(
        _expressPctSnapshotMeta,
        expressPctSnapshot.isAcceptableOrUnknown(
          data['express_pct_snapshot']!,
          _expressPctSnapshotMeta,
        ),
      );
    }
    if (data.containsKey('payment_amount_ugx')) {
      context.handle(
        _paymentAmountUgxMeta,
        paymentAmountUgx.isAcceptableOrUnknown(
          data['payment_amount_ugx']!,
          _paymentAmountUgxMeta,
        ),
      );
    }
    if (data.containsKey('cart_items')) {
      context.handle(
        _cartItemsMeta,
        cartItems.isAcceptableOrUnknown(data['cart_items']!, _cartItemsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Order map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Order(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      orderCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}order_code'],
      )!,
      customerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_id'],
      ),
      customerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_name'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      )!,
      serviceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}service_type'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      intakeMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}intake_method'],
      )!,
      fulfillmentMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fulfillment_method'],
      )!,
      itemCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item_count'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
      scheduledFor: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scheduled_for'],
      ),
      expectedCollectionAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expected_collection_at'],
      ),
      assignedDriver: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assigned_driver'],
      ),
      intakeRecordedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}intake_recorded_by'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_by'],
      ),
      deletedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_by'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      ratePerKgSnapshotUgx: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rate_per_kg_snapshot_ugx'],
      )!,
      estimatedWeightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}estimated_weight_kg'],
      ),
      finalWeightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}final_weight_kg'],
      ),
      lineItems: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}line_items'],
      )!,
      manualAdjustmentUgx: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}manual_adjustment_ugx'],
      )!,
      totalUgx: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_ugx'],
      )!,
      deliveryFeeSnapshotUgx: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}delivery_fee_snapshot_ugx'],
      )!,
      isExpress: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_express'],
      )!,
      expressFlatSnapshotUgx: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}express_flat_snapshot_ugx'],
      )!,
      expressPctSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}express_pct_snapshot'],
      )!,
      paymentAmountUgx: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}payment_amount_ugx'],
      )!,
      cartItems: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cart_items'],
      )!,
    );
  }

  @override
  $OrdersTable createAlias(String alias) {
    return $OrdersTable(attachedDatabase, alias);
  }
}

class Order extends DataClass implements Insertable<Order> {
  final String id;
  final String orderCode;
  final String? customerId;
  final String customerName;
  final String phone;
  final String address;
  final String serviceType;
  final String status;
  final String intakeMethod;
  final String fulfillmentMethod;
  final int itemCount;
  final String notes;
  final DateTime? scheduledFor;
  final DateTime? expectedCollectionAt;
  final String? assignedDriver;
  final String intakeRecordedBy;
  final String createdBy;
  final String? updatedBy;
  final String? deletedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final double ratePerKgSnapshotUgx;
  final double? estimatedWeightKg;
  final double? finalWeightKg;
  final String lineItems;
  final int manualAdjustmentUgx;
  final int totalUgx;
  final int deliveryFeeSnapshotUgx;
  final bool isExpress;
  final int expressFlatSnapshotUgx;
  final double expressPctSnapshot;
  final int paymentAmountUgx;
  final String cartItems;
  const Order({
    required this.id,
    required this.orderCode,
    this.customerId,
    required this.customerName,
    required this.phone,
    required this.address,
    required this.serviceType,
    required this.status,
    required this.intakeMethod,
    required this.fulfillmentMethod,
    required this.itemCount,
    required this.notes,
    this.scheduledFor,
    this.expectedCollectionAt,
    this.assignedDriver,
    required this.intakeRecordedBy,
    required this.createdBy,
    this.updatedBy,
    this.deletedBy,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.ratePerKgSnapshotUgx,
    this.estimatedWeightKg,
    this.finalWeightKg,
    required this.lineItems,
    required this.manualAdjustmentUgx,
    required this.totalUgx,
    required this.deliveryFeeSnapshotUgx,
    required this.isExpress,
    required this.expressFlatSnapshotUgx,
    required this.expressPctSnapshot,
    required this.paymentAmountUgx,
    required this.cartItems,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['order_code'] = Variable<String>(orderCode);
    if (!nullToAbsent || customerId != null) {
      map['customer_id'] = Variable<String>(customerId);
    }
    map['customer_name'] = Variable<String>(customerName);
    map['phone'] = Variable<String>(phone);
    map['address'] = Variable<String>(address);
    map['service_type'] = Variable<String>(serviceType);
    map['status'] = Variable<String>(status);
    map['intake_method'] = Variable<String>(intakeMethod);
    map['fulfillment_method'] = Variable<String>(fulfillmentMethod);
    map['item_count'] = Variable<int>(itemCount);
    map['notes'] = Variable<String>(notes);
    if (!nullToAbsent || scheduledFor != null) {
      map['scheduled_for'] = Variable<DateTime>(scheduledFor);
    }
    if (!nullToAbsent || expectedCollectionAt != null) {
      map['expected_collection_at'] = Variable<DateTime>(expectedCollectionAt);
    }
    if (!nullToAbsent || assignedDriver != null) {
      map['assigned_driver'] = Variable<String>(assignedDriver);
    }
    map['intake_recorded_by'] = Variable<String>(intakeRecordedBy);
    map['created_by'] = Variable<String>(createdBy);
    if (!nullToAbsent || updatedBy != null) {
      map['updated_by'] = Variable<String>(updatedBy);
    }
    if (!nullToAbsent || deletedBy != null) {
      map['deleted_by'] = Variable<String>(deletedBy);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['rate_per_kg_snapshot_ugx'] = Variable<double>(ratePerKgSnapshotUgx);
    if (!nullToAbsent || estimatedWeightKg != null) {
      map['estimated_weight_kg'] = Variable<double>(estimatedWeightKg);
    }
    if (!nullToAbsent || finalWeightKg != null) {
      map['final_weight_kg'] = Variable<double>(finalWeightKg);
    }
    map['line_items'] = Variable<String>(lineItems);
    map['manual_adjustment_ugx'] = Variable<int>(manualAdjustmentUgx);
    map['total_ugx'] = Variable<int>(totalUgx);
    map['delivery_fee_snapshot_ugx'] = Variable<int>(deliveryFeeSnapshotUgx);
    map['is_express'] = Variable<bool>(isExpress);
    map['express_flat_snapshot_ugx'] = Variable<int>(expressFlatSnapshotUgx);
    map['express_pct_snapshot'] = Variable<double>(expressPctSnapshot);
    map['payment_amount_ugx'] = Variable<int>(paymentAmountUgx);
    map['cart_items'] = Variable<String>(cartItems);
    return map;
  }

  OrdersCompanion toCompanion(bool nullToAbsent) {
    return OrdersCompanion(
      id: Value(id),
      orderCode: Value(orderCode),
      customerId: customerId == null && nullToAbsent
          ? const Value.absent()
          : Value(customerId),
      customerName: Value(customerName),
      phone: Value(phone),
      address: Value(address),
      serviceType: Value(serviceType),
      status: Value(status),
      intakeMethod: Value(intakeMethod),
      fulfillmentMethod: Value(fulfillmentMethod),
      itemCount: Value(itemCount),
      notes: Value(notes),
      scheduledFor: scheduledFor == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduledFor),
      expectedCollectionAt: expectedCollectionAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expectedCollectionAt),
      assignedDriver: assignedDriver == null && nullToAbsent
          ? const Value.absent()
          : Value(assignedDriver),
      intakeRecordedBy: Value(intakeRecordedBy),
      createdBy: Value(createdBy),
      updatedBy: updatedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedBy),
      deletedBy: deletedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedBy),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      ratePerKgSnapshotUgx: Value(ratePerKgSnapshotUgx),
      estimatedWeightKg: estimatedWeightKg == null && nullToAbsent
          ? const Value.absent()
          : Value(estimatedWeightKg),
      finalWeightKg: finalWeightKg == null && nullToAbsent
          ? const Value.absent()
          : Value(finalWeightKg),
      lineItems: Value(lineItems),
      manualAdjustmentUgx: Value(manualAdjustmentUgx),
      totalUgx: Value(totalUgx),
      deliveryFeeSnapshotUgx: Value(deliveryFeeSnapshotUgx),
      isExpress: Value(isExpress),
      expressFlatSnapshotUgx: Value(expressFlatSnapshotUgx),
      expressPctSnapshot: Value(expressPctSnapshot),
      paymentAmountUgx: Value(paymentAmountUgx),
      cartItems: Value(cartItems),
    );
  }

  factory Order.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Order(
      id: serializer.fromJson<String>(json['id']),
      orderCode: serializer.fromJson<String>(json['orderCode']),
      customerId: serializer.fromJson<String?>(json['customerId']),
      customerName: serializer.fromJson<String>(json['customerName']),
      phone: serializer.fromJson<String>(json['phone']),
      address: serializer.fromJson<String>(json['address']),
      serviceType: serializer.fromJson<String>(json['serviceType']),
      status: serializer.fromJson<String>(json['status']),
      intakeMethod: serializer.fromJson<String>(json['intakeMethod']),
      fulfillmentMethod: serializer.fromJson<String>(json['fulfillmentMethod']),
      itemCount: serializer.fromJson<int>(json['itemCount']),
      notes: serializer.fromJson<String>(json['notes']),
      scheduledFor: serializer.fromJson<DateTime?>(json['scheduledFor']),
      expectedCollectionAt: serializer.fromJson<DateTime?>(
        json['expectedCollectionAt'],
      ),
      assignedDriver: serializer.fromJson<String?>(json['assignedDriver']),
      intakeRecordedBy: serializer.fromJson<String>(json['intakeRecordedBy']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
      updatedBy: serializer.fromJson<String?>(json['updatedBy']),
      deletedBy: serializer.fromJson<String?>(json['deletedBy']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      ratePerKgSnapshotUgx: serializer.fromJson<double>(
        json['ratePerKgSnapshotUgx'],
      ),
      estimatedWeightKg: serializer.fromJson<double?>(
        json['estimatedWeightKg'],
      ),
      finalWeightKg: serializer.fromJson<double?>(json['finalWeightKg']),
      lineItems: serializer.fromJson<String>(json['lineItems']),
      manualAdjustmentUgx: serializer.fromJson<int>(
        json['manualAdjustmentUgx'],
      ),
      totalUgx: serializer.fromJson<int>(json['totalUgx']),
      deliveryFeeSnapshotUgx: serializer.fromJson<int>(
        json['deliveryFeeSnapshotUgx'],
      ),
      isExpress: serializer.fromJson<bool>(json['isExpress']),
      expressFlatSnapshotUgx: serializer.fromJson<int>(
        json['expressFlatSnapshotUgx'],
      ),
      expressPctSnapshot: serializer.fromJson<double>(
        json['expressPctSnapshot'],
      ),
      paymentAmountUgx: serializer.fromJson<int>(json['paymentAmountUgx']),
      cartItems: serializer.fromJson<String>(json['cartItems']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'orderCode': serializer.toJson<String>(orderCode),
      'customerId': serializer.toJson<String?>(customerId),
      'customerName': serializer.toJson<String>(customerName),
      'phone': serializer.toJson<String>(phone),
      'address': serializer.toJson<String>(address),
      'serviceType': serializer.toJson<String>(serviceType),
      'status': serializer.toJson<String>(status),
      'intakeMethod': serializer.toJson<String>(intakeMethod),
      'fulfillmentMethod': serializer.toJson<String>(fulfillmentMethod),
      'itemCount': serializer.toJson<int>(itemCount),
      'notes': serializer.toJson<String>(notes),
      'scheduledFor': serializer.toJson<DateTime?>(scheduledFor),
      'expectedCollectionAt': serializer.toJson<DateTime?>(
        expectedCollectionAt,
      ),
      'assignedDriver': serializer.toJson<String?>(assignedDriver),
      'intakeRecordedBy': serializer.toJson<String>(intakeRecordedBy),
      'createdBy': serializer.toJson<String>(createdBy),
      'updatedBy': serializer.toJson<String?>(updatedBy),
      'deletedBy': serializer.toJson<String?>(deletedBy),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'ratePerKgSnapshotUgx': serializer.toJson<double>(ratePerKgSnapshotUgx),
      'estimatedWeightKg': serializer.toJson<double?>(estimatedWeightKg),
      'finalWeightKg': serializer.toJson<double?>(finalWeightKg),
      'lineItems': serializer.toJson<String>(lineItems),
      'manualAdjustmentUgx': serializer.toJson<int>(manualAdjustmentUgx),
      'totalUgx': serializer.toJson<int>(totalUgx),
      'deliveryFeeSnapshotUgx': serializer.toJson<int>(deliveryFeeSnapshotUgx),
      'isExpress': serializer.toJson<bool>(isExpress),
      'expressFlatSnapshotUgx': serializer.toJson<int>(expressFlatSnapshotUgx),
      'expressPctSnapshot': serializer.toJson<double>(expressPctSnapshot),
      'paymentAmountUgx': serializer.toJson<int>(paymentAmountUgx),
      'cartItems': serializer.toJson<String>(cartItems),
    };
  }

  Order copyWith({
    String? id,
    String? orderCode,
    Value<String?> customerId = const Value.absent(),
    String? customerName,
    String? phone,
    String? address,
    String? serviceType,
    String? status,
    String? intakeMethod,
    String? fulfillmentMethod,
    int? itemCount,
    String? notes,
    Value<DateTime?> scheduledFor = const Value.absent(),
    Value<DateTime?> expectedCollectionAt = const Value.absent(),
    Value<String?> assignedDriver = const Value.absent(),
    String? intakeRecordedBy,
    String? createdBy,
    Value<String?> updatedBy = const Value.absent(),
    Value<String?> deletedBy = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    double? ratePerKgSnapshotUgx,
    Value<double?> estimatedWeightKg = const Value.absent(),
    Value<double?> finalWeightKg = const Value.absent(),
    String? lineItems,
    int? manualAdjustmentUgx,
    int? totalUgx,
    int? deliveryFeeSnapshotUgx,
    bool? isExpress,
    int? expressFlatSnapshotUgx,
    double? expressPctSnapshot,
    int? paymentAmountUgx,
    String? cartItems,
  }) => Order(
    id: id ?? this.id,
    orderCode: orderCode ?? this.orderCode,
    customerId: customerId.present ? customerId.value : this.customerId,
    customerName: customerName ?? this.customerName,
    phone: phone ?? this.phone,
    address: address ?? this.address,
    serviceType: serviceType ?? this.serviceType,
    status: status ?? this.status,
    intakeMethod: intakeMethod ?? this.intakeMethod,
    fulfillmentMethod: fulfillmentMethod ?? this.fulfillmentMethod,
    itemCount: itemCount ?? this.itemCount,
    notes: notes ?? this.notes,
    scheduledFor: scheduledFor.present ? scheduledFor.value : this.scheduledFor,
    expectedCollectionAt: expectedCollectionAt.present
        ? expectedCollectionAt.value
        : this.expectedCollectionAt,
    assignedDriver: assignedDriver.present
        ? assignedDriver.value
        : this.assignedDriver,
    intakeRecordedBy: intakeRecordedBy ?? this.intakeRecordedBy,
    createdBy: createdBy ?? this.createdBy,
    updatedBy: updatedBy.present ? updatedBy.value : this.updatedBy,
    deletedBy: deletedBy.present ? deletedBy.value : this.deletedBy,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    ratePerKgSnapshotUgx: ratePerKgSnapshotUgx ?? this.ratePerKgSnapshotUgx,
    estimatedWeightKg: estimatedWeightKg.present
        ? estimatedWeightKg.value
        : this.estimatedWeightKg,
    finalWeightKg: finalWeightKg.present
        ? finalWeightKg.value
        : this.finalWeightKg,
    lineItems: lineItems ?? this.lineItems,
    manualAdjustmentUgx: manualAdjustmentUgx ?? this.manualAdjustmentUgx,
    totalUgx: totalUgx ?? this.totalUgx,
    deliveryFeeSnapshotUgx:
        deliveryFeeSnapshotUgx ?? this.deliveryFeeSnapshotUgx,
    isExpress: isExpress ?? this.isExpress,
    expressFlatSnapshotUgx:
        expressFlatSnapshotUgx ?? this.expressFlatSnapshotUgx,
    expressPctSnapshot: expressPctSnapshot ?? this.expressPctSnapshot,
    paymentAmountUgx: paymentAmountUgx ?? this.paymentAmountUgx,
    cartItems: cartItems ?? this.cartItems,
  );
  Order copyWithCompanion(OrdersCompanion data) {
    return Order(
      id: data.id.present ? data.id.value : this.id,
      orderCode: data.orderCode.present ? data.orderCode.value : this.orderCode,
      customerId: data.customerId.present
          ? data.customerId.value
          : this.customerId,
      customerName: data.customerName.present
          ? data.customerName.value
          : this.customerName,
      phone: data.phone.present ? data.phone.value : this.phone,
      address: data.address.present ? data.address.value : this.address,
      serviceType: data.serviceType.present
          ? data.serviceType.value
          : this.serviceType,
      status: data.status.present ? data.status.value : this.status,
      intakeMethod: data.intakeMethod.present
          ? data.intakeMethod.value
          : this.intakeMethod,
      fulfillmentMethod: data.fulfillmentMethod.present
          ? data.fulfillmentMethod.value
          : this.fulfillmentMethod,
      itemCount: data.itemCount.present ? data.itemCount.value : this.itemCount,
      notes: data.notes.present ? data.notes.value : this.notes,
      scheduledFor: data.scheduledFor.present
          ? data.scheduledFor.value
          : this.scheduledFor,
      expectedCollectionAt: data.expectedCollectionAt.present
          ? data.expectedCollectionAt.value
          : this.expectedCollectionAt,
      assignedDriver: data.assignedDriver.present
          ? data.assignedDriver.value
          : this.assignedDriver,
      intakeRecordedBy: data.intakeRecordedBy.present
          ? data.intakeRecordedBy.value
          : this.intakeRecordedBy,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      deletedBy: data.deletedBy.present ? data.deletedBy.value : this.deletedBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      ratePerKgSnapshotUgx: data.ratePerKgSnapshotUgx.present
          ? data.ratePerKgSnapshotUgx.value
          : this.ratePerKgSnapshotUgx,
      estimatedWeightKg: data.estimatedWeightKg.present
          ? data.estimatedWeightKg.value
          : this.estimatedWeightKg,
      finalWeightKg: data.finalWeightKg.present
          ? data.finalWeightKg.value
          : this.finalWeightKg,
      lineItems: data.lineItems.present ? data.lineItems.value : this.lineItems,
      manualAdjustmentUgx: data.manualAdjustmentUgx.present
          ? data.manualAdjustmentUgx.value
          : this.manualAdjustmentUgx,
      totalUgx: data.totalUgx.present ? data.totalUgx.value : this.totalUgx,
      deliveryFeeSnapshotUgx: data.deliveryFeeSnapshotUgx.present
          ? data.deliveryFeeSnapshotUgx.value
          : this.deliveryFeeSnapshotUgx,
      isExpress: data.isExpress.present ? data.isExpress.value : this.isExpress,
      expressFlatSnapshotUgx: data.expressFlatSnapshotUgx.present
          ? data.expressFlatSnapshotUgx.value
          : this.expressFlatSnapshotUgx,
      expressPctSnapshot: data.expressPctSnapshot.present
          ? data.expressPctSnapshot.value
          : this.expressPctSnapshot,
      paymentAmountUgx: data.paymentAmountUgx.present
          ? data.paymentAmountUgx.value
          : this.paymentAmountUgx,
      cartItems: data.cartItems.present ? data.cartItems.value : this.cartItems,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Order(')
          ..write('id: $id, ')
          ..write('orderCode: $orderCode, ')
          ..write('customerId: $customerId, ')
          ..write('customerName: $customerName, ')
          ..write('phone: $phone, ')
          ..write('address: $address, ')
          ..write('serviceType: $serviceType, ')
          ..write('status: $status, ')
          ..write('intakeMethod: $intakeMethod, ')
          ..write('fulfillmentMethod: $fulfillmentMethod, ')
          ..write('itemCount: $itemCount, ')
          ..write('notes: $notes, ')
          ..write('scheduledFor: $scheduledFor, ')
          ..write('expectedCollectionAt: $expectedCollectionAt, ')
          ..write('assignedDriver: $assignedDriver, ')
          ..write('intakeRecordedBy: $intakeRecordedBy, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('ratePerKgSnapshotUgx: $ratePerKgSnapshotUgx, ')
          ..write('estimatedWeightKg: $estimatedWeightKg, ')
          ..write('finalWeightKg: $finalWeightKg, ')
          ..write('lineItems: $lineItems, ')
          ..write('manualAdjustmentUgx: $manualAdjustmentUgx, ')
          ..write('totalUgx: $totalUgx, ')
          ..write('deliveryFeeSnapshotUgx: $deliveryFeeSnapshotUgx, ')
          ..write('isExpress: $isExpress, ')
          ..write('expressFlatSnapshotUgx: $expressFlatSnapshotUgx, ')
          ..write('expressPctSnapshot: $expressPctSnapshot, ')
          ..write('paymentAmountUgx: $paymentAmountUgx, ')
          ..write('cartItems: $cartItems')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    orderCode,
    customerId,
    customerName,
    phone,
    address,
    serviceType,
    status,
    intakeMethod,
    fulfillmentMethod,
    itemCount,
    notes,
    scheduledFor,
    expectedCollectionAt,
    assignedDriver,
    intakeRecordedBy,
    createdBy,
    updatedBy,
    deletedBy,
    createdAt,
    updatedAt,
    deletedAt,
    ratePerKgSnapshotUgx,
    estimatedWeightKg,
    finalWeightKg,
    lineItems,
    manualAdjustmentUgx,
    totalUgx,
    deliveryFeeSnapshotUgx,
    isExpress,
    expressFlatSnapshotUgx,
    expressPctSnapshot,
    paymentAmountUgx,
    cartItems,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Order &&
          other.id == this.id &&
          other.orderCode == this.orderCode &&
          other.customerId == this.customerId &&
          other.customerName == this.customerName &&
          other.phone == this.phone &&
          other.address == this.address &&
          other.serviceType == this.serviceType &&
          other.status == this.status &&
          other.intakeMethod == this.intakeMethod &&
          other.fulfillmentMethod == this.fulfillmentMethod &&
          other.itemCount == this.itemCount &&
          other.notes == this.notes &&
          other.scheduledFor == this.scheduledFor &&
          other.expectedCollectionAt == this.expectedCollectionAt &&
          other.assignedDriver == this.assignedDriver &&
          other.intakeRecordedBy == this.intakeRecordedBy &&
          other.createdBy == this.createdBy &&
          other.updatedBy == this.updatedBy &&
          other.deletedBy == this.deletedBy &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.ratePerKgSnapshotUgx == this.ratePerKgSnapshotUgx &&
          other.estimatedWeightKg == this.estimatedWeightKg &&
          other.finalWeightKg == this.finalWeightKg &&
          other.lineItems == this.lineItems &&
          other.manualAdjustmentUgx == this.manualAdjustmentUgx &&
          other.totalUgx == this.totalUgx &&
          other.deliveryFeeSnapshotUgx == this.deliveryFeeSnapshotUgx &&
          other.isExpress == this.isExpress &&
          other.expressFlatSnapshotUgx == this.expressFlatSnapshotUgx &&
          other.expressPctSnapshot == this.expressPctSnapshot &&
          other.paymentAmountUgx == this.paymentAmountUgx &&
          other.cartItems == this.cartItems);
}

class OrdersCompanion extends UpdateCompanion<Order> {
  final Value<String> id;
  final Value<String> orderCode;
  final Value<String?> customerId;
  final Value<String> customerName;
  final Value<String> phone;
  final Value<String> address;
  final Value<String> serviceType;
  final Value<String> status;
  final Value<String> intakeMethod;
  final Value<String> fulfillmentMethod;
  final Value<int> itemCount;
  final Value<String> notes;
  final Value<DateTime?> scheduledFor;
  final Value<DateTime?> expectedCollectionAt;
  final Value<String?> assignedDriver;
  final Value<String> intakeRecordedBy;
  final Value<String> createdBy;
  final Value<String?> updatedBy;
  final Value<String?> deletedBy;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<double> ratePerKgSnapshotUgx;
  final Value<double?> estimatedWeightKg;
  final Value<double?> finalWeightKg;
  final Value<String> lineItems;
  final Value<int> manualAdjustmentUgx;
  final Value<int> totalUgx;
  final Value<int> deliveryFeeSnapshotUgx;
  final Value<bool> isExpress;
  final Value<int> expressFlatSnapshotUgx;
  final Value<double> expressPctSnapshot;
  final Value<int> paymentAmountUgx;
  final Value<String> cartItems;
  final Value<int> rowid;
  const OrdersCompanion({
    this.id = const Value.absent(),
    this.orderCode = const Value.absent(),
    this.customerId = const Value.absent(),
    this.customerName = const Value.absent(),
    this.phone = const Value.absent(),
    this.address = const Value.absent(),
    this.serviceType = const Value.absent(),
    this.status = const Value.absent(),
    this.intakeMethod = const Value.absent(),
    this.fulfillmentMethod = const Value.absent(),
    this.itemCount = const Value.absent(),
    this.notes = const Value.absent(),
    this.scheduledFor = const Value.absent(),
    this.expectedCollectionAt = const Value.absent(),
    this.assignedDriver = const Value.absent(),
    this.intakeRecordedBy = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.ratePerKgSnapshotUgx = const Value.absent(),
    this.estimatedWeightKg = const Value.absent(),
    this.finalWeightKg = const Value.absent(),
    this.lineItems = const Value.absent(),
    this.manualAdjustmentUgx = const Value.absent(),
    this.totalUgx = const Value.absent(),
    this.deliveryFeeSnapshotUgx = const Value.absent(),
    this.isExpress = const Value.absent(),
    this.expressFlatSnapshotUgx = const Value.absent(),
    this.expressPctSnapshot = const Value.absent(),
    this.paymentAmountUgx = const Value.absent(),
    this.cartItems = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OrdersCompanion.insert({
    required String id,
    required String orderCode,
    this.customerId = const Value.absent(),
    required String customerName,
    required String phone,
    required String address,
    required String serviceType,
    required String status,
    required String intakeMethod,
    required String fulfillmentMethod,
    required int itemCount,
    this.notes = const Value.absent(),
    this.scheduledFor = const Value.absent(),
    this.expectedCollectionAt = const Value.absent(),
    this.assignedDriver = const Value.absent(),
    required String intakeRecordedBy,
    required String createdBy,
    this.updatedBy = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.ratePerKgSnapshotUgx = const Value.absent(),
    this.estimatedWeightKg = const Value.absent(),
    this.finalWeightKg = const Value.absent(),
    this.lineItems = const Value.absent(),
    this.manualAdjustmentUgx = const Value.absent(),
    this.totalUgx = const Value.absent(),
    this.deliveryFeeSnapshotUgx = const Value.absent(),
    this.isExpress = const Value.absent(),
    this.expressFlatSnapshotUgx = const Value.absent(),
    this.expressPctSnapshot = const Value.absent(),
    this.paymentAmountUgx = const Value.absent(),
    this.cartItems = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       orderCode = Value(orderCode),
       customerName = Value(customerName),
       phone = Value(phone),
       address = Value(address),
       serviceType = Value(serviceType),
       status = Value(status),
       intakeMethod = Value(intakeMethod),
       fulfillmentMethod = Value(fulfillmentMethod),
       itemCount = Value(itemCount),
       intakeRecordedBy = Value(intakeRecordedBy),
       createdBy = Value(createdBy);
  static Insertable<Order> custom({
    Expression<String>? id,
    Expression<String>? orderCode,
    Expression<String>? customerId,
    Expression<String>? customerName,
    Expression<String>? phone,
    Expression<String>? address,
    Expression<String>? serviceType,
    Expression<String>? status,
    Expression<String>? intakeMethod,
    Expression<String>? fulfillmentMethod,
    Expression<int>? itemCount,
    Expression<String>? notes,
    Expression<DateTime>? scheduledFor,
    Expression<DateTime>? expectedCollectionAt,
    Expression<String>? assignedDriver,
    Expression<String>? intakeRecordedBy,
    Expression<String>? createdBy,
    Expression<String>? updatedBy,
    Expression<String>? deletedBy,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<double>? ratePerKgSnapshotUgx,
    Expression<double>? estimatedWeightKg,
    Expression<double>? finalWeightKg,
    Expression<String>? lineItems,
    Expression<int>? manualAdjustmentUgx,
    Expression<int>? totalUgx,
    Expression<int>? deliveryFeeSnapshotUgx,
    Expression<bool>? isExpress,
    Expression<int>? expressFlatSnapshotUgx,
    Expression<double>? expressPctSnapshot,
    Expression<int>? paymentAmountUgx,
    Expression<String>? cartItems,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (orderCode != null) 'order_code': orderCode,
      if (customerId != null) 'customer_id': customerId,
      if (customerName != null) 'customer_name': customerName,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
      if (serviceType != null) 'service_type': serviceType,
      if (status != null) 'status': status,
      if (intakeMethod != null) 'intake_method': intakeMethod,
      if (fulfillmentMethod != null) 'fulfillment_method': fulfillmentMethod,
      if (itemCount != null) 'item_count': itemCount,
      if (notes != null) 'notes': notes,
      if (scheduledFor != null) 'scheduled_for': scheduledFor,
      if (expectedCollectionAt != null)
        'expected_collection_at': expectedCollectionAt,
      if (assignedDriver != null) 'assigned_driver': assignedDriver,
      if (intakeRecordedBy != null) 'intake_recorded_by': intakeRecordedBy,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (deletedBy != null) 'deleted_by': deletedBy,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (ratePerKgSnapshotUgx != null)
        'rate_per_kg_snapshot_ugx': ratePerKgSnapshotUgx,
      if (estimatedWeightKg != null) 'estimated_weight_kg': estimatedWeightKg,
      if (finalWeightKg != null) 'final_weight_kg': finalWeightKg,
      if (lineItems != null) 'line_items': lineItems,
      if (manualAdjustmentUgx != null)
        'manual_adjustment_ugx': manualAdjustmentUgx,
      if (totalUgx != null) 'total_ugx': totalUgx,
      if (deliveryFeeSnapshotUgx != null)
        'delivery_fee_snapshot_ugx': deliveryFeeSnapshotUgx,
      if (isExpress != null) 'is_express': isExpress,
      if (expressFlatSnapshotUgx != null)
        'express_flat_snapshot_ugx': expressFlatSnapshotUgx,
      if (expressPctSnapshot != null)
        'express_pct_snapshot': expressPctSnapshot,
      if (paymentAmountUgx != null) 'payment_amount_ugx': paymentAmountUgx,
      if (cartItems != null) 'cart_items': cartItems,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OrdersCompanion copyWith({
    Value<String>? id,
    Value<String>? orderCode,
    Value<String?>? customerId,
    Value<String>? customerName,
    Value<String>? phone,
    Value<String>? address,
    Value<String>? serviceType,
    Value<String>? status,
    Value<String>? intakeMethod,
    Value<String>? fulfillmentMethod,
    Value<int>? itemCount,
    Value<String>? notes,
    Value<DateTime?>? scheduledFor,
    Value<DateTime?>? expectedCollectionAt,
    Value<String?>? assignedDriver,
    Value<String>? intakeRecordedBy,
    Value<String>? createdBy,
    Value<String?>? updatedBy,
    Value<String?>? deletedBy,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<double>? ratePerKgSnapshotUgx,
    Value<double?>? estimatedWeightKg,
    Value<double?>? finalWeightKg,
    Value<String>? lineItems,
    Value<int>? manualAdjustmentUgx,
    Value<int>? totalUgx,
    Value<int>? deliveryFeeSnapshotUgx,
    Value<bool>? isExpress,
    Value<int>? expressFlatSnapshotUgx,
    Value<double>? expressPctSnapshot,
    Value<int>? paymentAmountUgx,
    Value<String>? cartItems,
    Value<int>? rowid,
  }) {
    return OrdersCompanion(
      id: id ?? this.id,
      orderCode: orderCode ?? this.orderCode,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      serviceType: serviceType ?? this.serviceType,
      status: status ?? this.status,
      intakeMethod: intakeMethod ?? this.intakeMethod,
      fulfillmentMethod: fulfillmentMethod ?? this.fulfillmentMethod,
      itemCount: itemCount ?? this.itemCount,
      notes: notes ?? this.notes,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      expectedCollectionAt: expectedCollectionAt ?? this.expectedCollectionAt,
      assignedDriver: assignedDriver ?? this.assignedDriver,
      intakeRecordedBy: intakeRecordedBy ?? this.intakeRecordedBy,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      deletedBy: deletedBy ?? this.deletedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      ratePerKgSnapshotUgx: ratePerKgSnapshotUgx ?? this.ratePerKgSnapshotUgx,
      estimatedWeightKg: estimatedWeightKg ?? this.estimatedWeightKg,
      finalWeightKg: finalWeightKg ?? this.finalWeightKg,
      lineItems: lineItems ?? this.lineItems,
      manualAdjustmentUgx: manualAdjustmentUgx ?? this.manualAdjustmentUgx,
      totalUgx: totalUgx ?? this.totalUgx,
      deliveryFeeSnapshotUgx:
          deliveryFeeSnapshotUgx ?? this.deliveryFeeSnapshotUgx,
      isExpress: isExpress ?? this.isExpress,
      expressFlatSnapshotUgx:
          expressFlatSnapshotUgx ?? this.expressFlatSnapshotUgx,
      expressPctSnapshot: expressPctSnapshot ?? this.expressPctSnapshot,
      paymentAmountUgx: paymentAmountUgx ?? this.paymentAmountUgx,
      cartItems: cartItems ?? this.cartItems,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (orderCode.present) {
      map['order_code'] = Variable<String>(orderCode.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (customerName.present) {
      map['customer_name'] = Variable<String>(customerName.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (serviceType.present) {
      map['service_type'] = Variable<String>(serviceType.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (intakeMethod.present) {
      map['intake_method'] = Variable<String>(intakeMethod.value);
    }
    if (fulfillmentMethod.present) {
      map['fulfillment_method'] = Variable<String>(fulfillmentMethod.value);
    }
    if (itemCount.present) {
      map['item_count'] = Variable<int>(itemCount.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (scheduledFor.present) {
      map['scheduled_for'] = Variable<DateTime>(scheduledFor.value);
    }
    if (expectedCollectionAt.present) {
      map['expected_collection_at'] = Variable<DateTime>(
        expectedCollectionAt.value,
      );
    }
    if (assignedDriver.present) {
      map['assigned_driver'] = Variable<String>(assignedDriver.value);
    }
    if (intakeRecordedBy.present) {
      map['intake_recorded_by'] = Variable<String>(intakeRecordedBy.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<String>(updatedBy.value);
    }
    if (deletedBy.present) {
      map['deleted_by'] = Variable<String>(deletedBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (ratePerKgSnapshotUgx.present) {
      map['rate_per_kg_snapshot_ugx'] = Variable<double>(
        ratePerKgSnapshotUgx.value,
      );
    }
    if (estimatedWeightKg.present) {
      map['estimated_weight_kg'] = Variable<double>(estimatedWeightKg.value);
    }
    if (finalWeightKg.present) {
      map['final_weight_kg'] = Variable<double>(finalWeightKg.value);
    }
    if (lineItems.present) {
      map['line_items'] = Variable<String>(lineItems.value);
    }
    if (manualAdjustmentUgx.present) {
      map['manual_adjustment_ugx'] = Variable<int>(manualAdjustmentUgx.value);
    }
    if (totalUgx.present) {
      map['total_ugx'] = Variable<int>(totalUgx.value);
    }
    if (deliveryFeeSnapshotUgx.present) {
      map['delivery_fee_snapshot_ugx'] = Variable<int>(
        deliveryFeeSnapshotUgx.value,
      );
    }
    if (isExpress.present) {
      map['is_express'] = Variable<bool>(isExpress.value);
    }
    if (expressFlatSnapshotUgx.present) {
      map['express_flat_snapshot_ugx'] = Variable<int>(
        expressFlatSnapshotUgx.value,
      );
    }
    if (expressPctSnapshot.present) {
      map['express_pct_snapshot'] = Variable<double>(expressPctSnapshot.value);
    }
    if (paymentAmountUgx.present) {
      map['payment_amount_ugx'] = Variable<int>(paymentAmountUgx.value);
    }
    if (cartItems.present) {
      map['cart_items'] = Variable<String>(cartItems.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OrdersCompanion(')
          ..write('id: $id, ')
          ..write('orderCode: $orderCode, ')
          ..write('customerId: $customerId, ')
          ..write('customerName: $customerName, ')
          ..write('phone: $phone, ')
          ..write('address: $address, ')
          ..write('serviceType: $serviceType, ')
          ..write('status: $status, ')
          ..write('intakeMethod: $intakeMethod, ')
          ..write('fulfillmentMethod: $fulfillmentMethod, ')
          ..write('itemCount: $itemCount, ')
          ..write('notes: $notes, ')
          ..write('scheduledFor: $scheduledFor, ')
          ..write('expectedCollectionAt: $expectedCollectionAt, ')
          ..write('assignedDriver: $assignedDriver, ')
          ..write('intakeRecordedBy: $intakeRecordedBy, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('ratePerKgSnapshotUgx: $ratePerKgSnapshotUgx, ')
          ..write('estimatedWeightKg: $estimatedWeightKg, ')
          ..write('finalWeightKg: $finalWeightKg, ')
          ..write('lineItems: $lineItems, ')
          ..write('manualAdjustmentUgx: $manualAdjustmentUgx, ')
          ..write('totalUgx: $totalUgx, ')
          ..write('deliveryFeeSnapshotUgx: $deliveryFeeSnapshotUgx, ')
          ..write('isExpress: $isExpress, ')
          ..write('expressFlatSnapshotUgx: $expressFlatSnapshotUgx, ')
          ..write('expressPctSnapshot: $expressPctSnapshot, ')
          ..write('paymentAmountUgx: $paymentAmountUgx, ')
          ..write('cartItems: $cartItems, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OrderStatusEventsTable extends OrderStatusEvents
    with TableInfo<$OrderStatusEventsTable, OrderStatusEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OrderStatusEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderIdMeta = const VerificationMeta(
    'orderId',
  );
  @override
  late final GeneratedColumn<String> orderId = GeneratedColumn<String>(
    'order_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fromStatusMeta = const VerificationMeta(
    'fromStatus',
  );
  @override
  late final GeneratedColumn<String> fromStatus = GeneratedColumn<String>(
    'from_status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toStatusMeta = const VerificationMeta(
    'toStatus',
  );
  @override
  late final GeneratedColumn<String> toStatus = GeneratedColumn<String>(
    'to_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _changedByMeta = const VerificationMeta(
    'changedBy',
  );
  @override
  late final GeneratedColumn<String> changedBy = GeneratedColumn<String>(
    'changed_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _changedAtMeta = const VerificationMeta(
    'changedAt',
  );
  @override
  late final GeneratedColumn<DateTime> changedAt = GeneratedColumn<DateTime>(
    'changed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceEventIdMeta = const VerificationMeta(
    'deviceEventId',
  );
  @override
  late final GeneratedColumn<String> deviceEventId = GeneratedColumn<String>(
    'device_event_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    orderId,
    fromStatus,
    toStatus,
    changedBy,
    changedAt,
    source,
    deviceEventId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'order_status_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<OrderStatusEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('order_id')) {
      context.handle(
        _orderIdMeta,
        orderId.isAcceptableOrUnknown(data['order_id']!, _orderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIdMeta);
    }
    if (data.containsKey('from_status')) {
      context.handle(
        _fromStatusMeta,
        fromStatus.isAcceptableOrUnknown(data['from_status']!, _fromStatusMeta),
      );
    }
    if (data.containsKey('to_status')) {
      context.handle(
        _toStatusMeta,
        toStatus.isAcceptableOrUnknown(data['to_status']!, _toStatusMeta),
      );
    } else if (isInserting) {
      context.missing(_toStatusMeta);
    }
    if (data.containsKey('changed_by')) {
      context.handle(
        _changedByMeta,
        changedBy.isAcceptableOrUnknown(data['changed_by']!, _changedByMeta),
      );
    } else if (isInserting) {
      context.missing(_changedByMeta);
    }
    if (data.containsKey('changed_at')) {
      context.handle(
        _changedAtMeta,
        changedAt.isAcceptableOrUnknown(data['changed_at']!, _changedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_changedAtMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('device_event_id')) {
      context.handle(
        _deviceEventIdMeta,
        deviceEventId.isAcceptableOrUnknown(
          data['device_event_id']!,
          _deviceEventIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OrderStatusEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OrderStatusEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      orderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}order_id'],
      )!,
      fromStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_status'],
      ),
      toStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_status'],
      )!,
      changedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}changed_by'],
      )!,
      changedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}changed_at'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      deviceEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_event_id'],
      ),
    );
  }

  @override
  $OrderStatusEventsTable createAlias(String alias) {
    return $OrderStatusEventsTable(attachedDatabase, alias);
  }
}

class OrderStatusEvent extends DataClass
    implements Insertable<OrderStatusEvent> {
  final String id;
  final String orderId;
  final String? fromStatus;
  final String toStatus;
  final String changedBy;
  final DateTime changedAt;
  final String source;
  final String? deviceEventId;
  const OrderStatusEvent({
    required this.id,
    required this.orderId,
    this.fromStatus,
    required this.toStatus,
    required this.changedBy,
    required this.changedAt,
    required this.source,
    this.deviceEventId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['order_id'] = Variable<String>(orderId);
    if (!nullToAbsent || fromStatus != null) {
      map['from_status'] = Variable<String>(fromStatus);
    }
    map['to_status'] = Variable<String>(toStatus);
    map['changed_by'] = Variable<String>(changedBy);
    map['changed_at'] = Variable<DateTime>(changedAt);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || deviceEventId != null) {
      map['device_event_id'] = Variable<String>(deviceEventId);
    }
    return map;
  }

  OrderStatusEventsCompanion toCompanion(bool nullToAbsent) {
    return OrderStatusEventsCompanion(
      id: Value(id),
      orderId: Value(orderId),
      fromStatus: fromStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(fromStatus),
      toStatus: Value(toStatus),
      changedBy: Value(changedBy),
      changedAt: Value(changedAt),
      source: Value(source),
      deviceEventId: deviceEventId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceEventId),
    );
  }

  factory OrderStatusEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OrderStatusEvent(
      id: serializer.fromJson<String>(json['id']),
      orderId: serializer.fromJson<String>(json['orderId']),
      fromStatus: serializer.fromJson<String?>(json['fromStatus']),
      toStatus: serializer.fromJson<String>(json['toStatus']),
      changedBy: serializer.fromJson<String>(json['changedBy']),
      changedAt: serializer.fromJson<DateTime>(json['changedAt']),
      source: serializer.fromJson<String>(json['source']),
      deviceEventId: serializer.fromJson<String?>(json['deviceEventId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'orderId': serializer.toJson<String>(orderId),
      'fromStatus': serializer.toJson<String?>(fromStatus),
      'toStatus': serializer.toJson<String>(toStatus),
      'changedBy': serializer.toJson<String>(changedBy),
      'changedAt': serializer.toJson<DateTime>(changedAt),
      'source': serializer.toJson<String>(source),
      'deviceEventId': serializer.toJson<String?>(deviceEventId),
    };
  }

  OrderStatusEvent copyWith({
    String? id,
    String? orderId,
    Value<String?> fromStatus = const Value.absent(),
    String? toStatus,
    String? changedBy,
    DateTime? changedAt,
    String? source,
    Value<String?> deviceEventId = const Value.absent(),
  }) => OrderStatusEvent(
    id: id ?? this.id,
    orderId: orderId ?? this.orderId,
    fromStatus: fromStatus.present ? fromStatus.value : this.fromStatus,
    toStatus: toStatus ?? this.toStatus,
    changedBy: changedBy ?? this.changedBy,
    changedAt: changedAt ?? this.changedAt,
    source: source ?? this.source,
    deviceEventId: deviceEventId.present
        ? deviceEventId.value
        : this.deviceEventId,
  );
  OrderStatusEvent copyWithCompanion(OrderStatusEventsCompanion data) {
    return OrderStatusEvent(
      id: data.id.present ? data.id.value : this.id,
      orderId: data.orderId.present ? data.orderId.value : this.orderId,
      fromStatus: data.fromStatus.present
          ? data.fromStatus.value
          : this.fromStatus,
      toStatus: data.toStatus.present ? data.toStatus.value : this.toStatus,
      changedBy: data.changedBy.present ? data.changedBy.value : this.changedBy,
      changedAt: data.changedAt.present ? data.changedAt.value : this.changedAt,
      source: data.source.present ? data.source.value : this.source,
      deviceEventId: data.deviceEventId.present
          ? data.deviceEventId.value
          : this.deviceEventId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OrderStatusEvent(')
          ..write('id: $id, ')
          ..write('orderId: $orderId, ')
          ..write('fromStatus: $fromStatus, ')
          ..write('toStatus: $toStatus, ')
          ..write('changedBy: $changedBy, ')
          ..write('changedAt: $changedAt, ')
          ..write('source: $source, ')
          ..write('deviceEventId: $deviceEventId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    orderId,
    fromStatus,
    toStatus,
    changedBy,
    changedAt,
    source,
    deviceEventId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OrderStatusEvent &&
          other.id == this.id &&
          other.orderId == this.orderId &&
          other.fromStatus == this.fromStatus &&
          other.toStatus == this.toStatus &&
          other.changedBy == this.changedBy &&
          other.changedAt == this.changedAt &&
          other.source == this.source &&
          other.deviceEventId == this.deviceEventId);
}

class OrderStatusEventsCompanion extends UpdateCompanion<OrderStatusEvent> {
  final Value<String> id;
  final Value<String> orderId;
  final Value<String?> fromStatus;
  final Value<String> toStatus;
  final Value<String> changedBy;
  final Value<DateTime> changedAt;
  final Value<String> source;
  final Value<String?> deviceEventId;
  final Value<int> rowid;
  const OrderStatusEventsCompanion({
    this.id = const Value.absent(),
    this.orderId = const Value.absent(),
    this.fromStatus = const Value.absent(),
    this.toStatus = const Value.absent(),
    this.changedBy = const Value.absent(),
    this.changedAt = const Value.absent(),
    this.source = const Value.absent(),
    this.deviceEventId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OrderStatusEventsCompanion.insert({
    required String id,
    required String orderId,
    this.fromStatus = const Value.absent(),
    required String toStatus,
    required String changedBy,
    required DateTime changedAt,
    required String source,
    this.deviceEventId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       orderId = Value(orderId),
       toStatus = Value(toStatus),
       changedBy = Value(changedBy),
       changedAt = Value(changedAt),
       source = Value(source);
  static Insertable<OrderStatusEvent> custom({
    Expression<String>? id,
    Expression<String>? orderId,
    Expression<String>? fromStatus,
    Expression<String>? toStatus,
    Expression<String>? changedBy,
    Expression<DateTime>? changedAt,
    Expression<String>? source,
    Expression<String>? deviceEventId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (orderId != null) 'order_id': orderId,
      if (fromStatus != null) 'from_status': fromStatus,
      if (toStatus != null) 'to_status': toStatus,
      if (changedBy != null) 'changed_by': changedBy,
      if (changedAt != null) 'changed_at': changedAt,
      if (source != null) 'source': source,
      if (deviceEventId != null) 'device_event_id': deviceEventId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OrderStatusEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? orderId,
    Value<String?>? fromStatus,
    Value<String>? toStatus,
    Value<String>? changedBy,
    Value<DateTime>? changedAt,
    Value<String>? source,
    Value<String?>? deviceEventId,
    Value<int>? rowid,
  }) {
    return OrderStatusEventsCompanion(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      fromStatus: fromStatus ?? this.fromStatus,
      toStatus: toStatus ?? this.toStatus,
      changedBy: changedBy ?? this.changedBy,
      changedAt: changedAt ?? this.changedAt,
      source: source ?? this.source,
      deviceEventId: deviceEventId ?? this.deviceEventId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (orderId.present) {
      map['order_id'] = Variable<String>(orderId.value);
    }
    if (fromStatus.present) {
      map['from_status'] = Variable<String>(fromStatus.value);
    }
    if (toStatus.present) {
      map['to_status'] = Variable<String>(toStatus.value);
    }
    if (changedBy.present) {
      map['changed_by'] = Variable<String>(changedBy.value);
    }
    if (changedAt.present) {
      map['changed_at'] = Variable<DateTime>(changedAt.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (deviceEventId.present) {
      map['device_event_id'] = Variable<String>(deviceEventId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OrderStatusEventsCompanion(')
          ..write('id: $id, ')
          ..write('orderId: $orderId, ')
          ..write('fromStatus: $fromStatus, ')
          ..write('toStatus: $toStatus, ')
          ..write('changedBy: $changedBy, ')
          ..write('changedAt: $changedAt, ')
          ..write('source: $source, ')
          ..write('deviceEventId: $deviceEventId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProofEventsTable extends ProofEvents
    with TableInfo<$ProofEventsTable, ProofEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProofEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderIdMeta = const VerificationMeta(
    'orderId',
  );
  @override
  late final GeneratedColumn<String> orderId = GeneratedColumn<String>(
    'order_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capturedAtMeta = const VerificationMeta(
    'capturedAt',
  );
  @override
  late final GeneratedColumn<DateTime> capturedAt = GeneratedColumn<DateTime>(
    'captured_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemCountMeta = const VerificationMeta(
    'itemCount',
  );
  @override
  late final GeneratedColumn<int> itemCount = GeneratedColumn<int>(
    'item_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
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
  static const VerificationMeta _capturedByMeta = const VerificationMeta(
    'capturedBy',
  );
  @override
  late final GeneratedColumn<String> capturedBy = GeneratedColumn<String>(
    'captured_by',
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    orderId,
    type,
    capturedAt,
    itemCount,
    notes,
    capturedBy,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'proof_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProofEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('order_id')) {
      context.handle(
        _orderIdMeta,
        orderId.isAcceptableOrUnknown(data['order_id']!, _orderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('captured_at')) {
      context.handle(
        _capturedAtMeta,
        capturedAt.isAcceptableOrUnknown(data['captured_at']!, _capturedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_capturedAtMeta);
    }
    if (data.containsKey('item_count')) {
      context.handle(
        _itemCountMeta,
        itemCount.isAcceptableOrUnknown(data['item_count']!, _itemCountMeta),
      );
    } else if (isInserting) {
      context.missing(_itemCountMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('captured_by')) {
      context.handle(
        _capturedByMeta,
        capturedBy.isAcceptableOrUnknown(data['captured_by']!, _capturedByMeta),
      );
    } else if (isInserting) {
      context.missing(_capturedByMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProofEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProofEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      orderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}order_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      capturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}captured_at'],
      )!,
      itemCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item_count'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      capturedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}captured_by'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $ProofEventsTable createAlias(String alias) {
    return $ProofEventsTable(attachedDatabase, alias);
  }
}

class ProofEvent extends DataClass implements Insertable<ProofEvent> {
  final String id;
  final String orderId;
  final String type;
  final DateTime capturedAt;
  final int itemCount;
  final String? notes;
  final String capturedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const ProofEvent({
    required this.id,
    required this.orderId,
    required this.type,
    required this.capturedAt,
    required this.itemCount,
    this.notes,
    required this.capturedBy,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['order_id'] = Variable<String>(orderId);
    map['type'] = Variable<String>(type);
    map['captured_at'] = Variable<DateTime>(capturedAt);
    map['item_count'] = Variable<int>(itemCount);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['captured_by'] = Variable<String>(capturedBy);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  ProofEventsCompanion toCompanion(bool nullToAbsent) {
    return ProofEventsCompanion(
      id: Value(id),
      orderId: Value(orderId),
      type: Value(type),
      capturedAt: Value(capturedAt),
      itemCount: Value(itemCount),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      capturedBy: Value(capturedBy),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory ProofEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProofEvent(
      id: serializer.fromJson<String>(json['id']),
      orderId: serializer.fromJson<String>(json['orderId']),
      type: serializer.fromJson<String>(json['type']),
      capturedAt: serializer.fromJson<DateTime>(json['capturedAt']),
      itemCount: serializer.fromJson<int>(json['itemCount']),
      notes: serializer.fromJson<String?>(json['notes']),
      capturedBy: serializer.fromJson<String>(json['capturedBy']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'orderId': serializer.toJson<String>(orderId),
      'type': serializer.toJson<String>(type),
      'capturedAt': serializer.toJson<DateTime>(capturedAt),
      'itemCount': serializer.toJson<int>(itemCount),
      'notes': serializer.toJson<String?>(notes),
      'capturedBy': serializer.toJson<String>(capturedBy),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  ProofEvent copyWith({
    String? id,
    String? orderId,
    String? type,
    DateTime? capturedAt,
    int? itemCount,
    Value<String?> notes = const Value.absent(),
    String? capturedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => ProofEvent(
    id: id ?? this.id,
    orderId: orderId ?? this.orderId,
    type: type ?? this.type,
    capturedAt: capturedAt ?? this.capturedAt,
    itemCount: itemCount ?? this.itemCount,
    notes: notes.present ? notes.value : this.notes,
    capturedBy: capturedBy ?? this.capturedBy,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  ProofEvent copyWithCompanion(ProofEventsCompanion data) {
    return ProofEvent(
      id: data.id.present ? data.id.value : this.id,
      orderId: data.orderId.present ? data.orderId.value : this.orderId,
      type: data.type.present ? data.type.value : this.type,
      capturedAt: data.capturedAt.present
          ? data.capturedAt.value
          : this.capturedAt,
      itemCount: data.itemCount.present ? data.itemCount.value : this.itemCount,
      notes: data.notes.present ? data.notes.value : this.notes,
      capturedBy: data.capturedBy.present
          ? data.capturedBy.value
          : this.capturedBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProofEvent(')
          ..write('id: $id, ')
          ..write('orderId: $orderId, ')
          ..write('type: $type, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('itemCount: $itemCount, ')
          ..write('notes: $notes, ')
          ..write('capturedBy: $capturedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    orderId,
    type,
    capturedAt,
    itemCount,
    notes,
    capturedBy,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProofEvent &&
          other.id == this.id &&
          other.orderId == this.orderId &&
          other.type == this.type &&
          other.capturedAt == this.capturedAt &&
          other.itemCount == this.itemCount &&
          other.notes == this.notes &&
          other.capturedBy == this.capturedBy &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class ProofEventsCompanion extends UpdateCompanion<ProofEvent> {
  final Value<String> id;
  final Value<String> orderId;
  final Value<String> type;
  final Value<DateTime> capturedAt;
  final Value<int> itemCount;
  final Value<String?> notes;
  final Value<String> capturedBy;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const ProofEventsCompanion({
    this.id = const Value.absent(),
    this.orderId = const Value.absent(),
    this.type = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.itemCount = const Value.absent(),
    this.notes = const Value.absent(),
    this.capturedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProofEventsCompanion.insert({
    required String id,
    required String orderId,
    required String type,
    required DateTime capturedAt,
    required int itemCount,
    this.notes = const Value.absent(),
    required String capturedBy,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       orderId = Value(orderId),
       type = Value(type),
       capturedAt = Value(capturedAt),
       itemCount = Value(itemCount),
       capturedBy = Value(capturedBy),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ProofEvent> custom({
    Expression<String>? id,
    Expression<String>? orderId,
    Expression<String>? type,
    Expression<DateTime>? capturedAt,
    Expression<int>? itemCount,
    Expression<String>? notes,
    Expression<String>? capturedBy,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (orderId != null) 'order_id': orderId,
      if (type != null) 'type': type,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (itemCount != null) 'item_count': itemCount,
      if (notes != null) 'notes': notes,
      if (capturedBy != null) 'captured_by': capturedBy,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProofEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? orderId,
    Value<String>? type,
    Value<DateTime>? capturedAt,
    Value<int>? itemCount,
    Value<String?>? notes,
    Value<String>? capturedBy,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return ProofEventsCompanion(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      type: type ?? this.type,
      capturedAt: capturedAt ?? this.capturedAt,
      itemCount: itemCount ?? this.itemCount,
      notes: notes ?? this.notes,
      capturedBy: capturedBy ?? this.capturedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (orderId.present) {
      map['order_id'] = Variable<String>(orderId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<DateTime>(capturedAt.value);
    }
    if (itemCount.present) {
      map['item_count'] = Variable<int>(itemCount.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (capturedBy.present) {
      map['captured_by'] = Variable<String>(capturedBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProofEventsCompanion(')
          ..write('id: $id, ')
          ..write('orderId: $orderId, ')
          ..write('type: $type, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('itemCount: $itemCount, ')
          ..write('notes: $notes, ')
          ..write('capturedBy: $capturedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProofPhotosTable extends ProofPhotos
    with TableInfo<$ProofPhotosTable, ProofPhoto> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProofPhotosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _proofEventIdMeta = const VerificationMeta(
    'proofEventId',
  );
  @override
  late final GeneratedColumn<String> proofEventId = GeneratedColumn<String>(
    'proof_event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storagePathMeta = const VerificationMeta(
    'storagePath',
  );
  @override
  late final GeneratedColumn<String> storagePath = GeneratedColumn<String>(
    'storage_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
    'bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _uploadedAtMeta = const VerificationMeta(
    'uploadedAt',
  );
  @override
  late final GeneratedColumn<DateTime> uploadedAt = GeneratedColumn<DateTime>(
    'uploaded_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    proofEventId,
    storagePath,
    width,
    height,
    bytes,
    uploadedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'proof_photos';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProofPhoto> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('proof_event_id')) {
      context.handle(
        _proofEventIdMeta,
        proofEventId.isAcceptableOrUnknown(
          data['proof_event_id']!,
          _proofEventIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_proofEventIdMeta);
    }
    if (data.containsKey('storage_path')) {
      context.handle(
        _storagePathMeta,
        storagePath.isAcceptableOrUnknown(
          data['storage_path']!,
          _storagePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_storagePathMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    }
    if (data.containsKey('uploaded_at')) {
      context.handle(
        _uploadedAtMeta,
        uploadedAt.isAcceptableOrUnknown(data['uploaded_at']!, _uploadedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProofPhoto map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProofPhoto(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      proofEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}proof_event_id'],
      )!,
      storagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}storage_path'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      ),
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      ),
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes'],
      ),
      uploadedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}uploaded_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ProofPhotosTable createAlias(String alias) {
    return $ProofPhotosTable(attachedDatabase, alias);
  }
}

class ProofPhoto extends DataClass implements Insertable<ProofPhoto> {
  final String id;
  final String proofEventId;
  final String storagePath;
  final int? width;
  final int? height;
  final int? bytes;
  final DateTime? uploadedAt;
  final DateTime createdAt;
  const ProofPhoto({
    required this.id,
    required this.proofEventId,
    required this.storagePath,
    this.width,
    this.height,
    this.bytes,
    this.uploadedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['proof_event_id'] = Variable<String>(proofEventId);
    map['storage_path'] = Variable<String>(storagePath);
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<int>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<int>(height);
    }
    if (!nullToAbsent || bytes != null) {
      map['bytes'] = Variable<int>(bytes);
    }
    if (!nullToAbsent || uploadedAt != null) {
      map['uploaded_at'] = Variable<DateTime>(uploadedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ProofPhotosCompanion toCompanion(bool nullToAbsent) {
    return ProofPhotosCompanion(
      id: Value(id),
      proofEventId: Value(proofEventId),
      storagePath: Value(storagePath),
      width: width == null && nullToAbsent
          ? const Value.absent()
          : Value(width),
      height: height == null && nullToAbsent
          ? const Value.absent()
          : Value(height),
      bytes: bytes == null && nullToAbsent
          ? const Value.absent()
          : Value(bytes),
      uploadedAt: uploadedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(uploadedAt),
      createdAt: Value(createdAt),
    );
  }

  factory ProofPhoto.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProofPhoto(
      id: serializer.fromJson<String>(json['id']),
      proofEventId: serializer.fromJson<String>(json['proofEventId']),
      storagePath: serializer.fromJson<String>(json['storagePath']),
      width: serializer.fromJson<int?>(json['width']),
      height: serializer.fromJson<int?>(json['height']),
      bytes: serializer.fromJson<int?>(json['bytes']),
      uploadedAt: serializer.fromJson<DateTime?>(json['uploadedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'proofEventId': serializer.toJson<String>(proofEventId),
      'storagePath': serializer.toJson<String>(storagePath),
      'width': serializer.toJson<int?>(width),
      'height': serializer.toJson<int?>(height),
      'bytes': serializer.toJson<int?>(bytes),
      'uploadedAt': serializer.toJson<DateTime?>(uploadedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ProofPhoto copyWith({
    String? id,
    String? proofEventId,
    String? storagePath,
    Value<int?> width = const Value.absent(),
    Value<int?> height = const Value.absent(),
    Value<int?> bytes = const Value.absent(),
    Value<DateTime?> uploadedAt = const Value.absent(),
    DateTime? createdAt,
  }) => ProofPhoto(
    id: id ?? this.id,
    proofEventId: proofEventId ?? this.proofEventId,
    storagePath: storagePath ?? this.storagePath,
    width: width.present ? width.value : this.width,
    height: height.present ? height.value : this.height,
    bytes: bytes.present ? bytes.value : this.bytes,
    uploadedAt: uploadedAt.present ? uploadedAt.value : this.uploadedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  ProofPhoto copyWithCompanion(ProofPhotosCompanion data) {
    return ProofPhoto(
      id: data.id.present ? data.id.value : this.id,
      proofEventId: data.proofEventId.present
          ? data.proofEventId.value
          : this.proofEventId,
      storagePath: data.storagePath.present
          ? data.storagePath.value
          : this.storagePath,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      uploadedAt: data.uploadedAt.present
          ? data.uploadedAt.value
          : this.uploadedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProofPhoto(')
          ..write('id: $id, ')
          ..write('proofEventId: $proofEventId, ')
          ..write('storagePath: $storagePath, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('bytes: $bytes, ')
          ..write('uploadedAt: $uploadedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    proofEventId,
    storagePath,
    width,
    height,
    bytes,
    uploadedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProofPhoto &&
          other.id == this.id &&
          other.proofEventId == this.proofEventId &&
          other.storagePath == this.storagePath &&
          other.width == this.width &&
          other.height == this.height &&
          other.bytes == this.bytes &&
          other.uploadedAt == this.uploadedAt &&
          other.createdAt == this.createdAt);
}

class ProofPhotosCompanion extends UpdateCompanion<ProofPhoto> {
  final Value<String> id;
  final Value<String> proofEventId;
  final Value<String> storagePath;
  final Value<int?> width;
  final Value<int?> height;
  final Value<int?> bytes;
  final Value<DateTime?> uploadedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ProofPhotosCompanion({
    this.id = const Value.absent(),
    this.proofEventId = const Value.absent(),
    this.storagePath = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.bytes = const Value.absent(),
    this.uploadedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProofPhotosCompanion.insert({
    required String id,
    required String proofEventId,
    required String storagePath,
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.bytes = const Value.absent(),
    this.uploadedAt = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       proofEventId = Value(proofEventId),
       storagePath = Value(storagePath),
       createdAt = Value(createdAt);
  static Insertable<ProofPhoto> custom({
    Expression<String>? id,
    Expression<String>? proofEventId,
    Expression<String>? storagePath,
    Expression<int>? width,
    Expression<int>? height,
    Expression<int>? bytes,
    Expression<DateTime>? uploadedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (proofEventId != null) 'proof_event_id': proofEventId,
      if (storagePath != null) 'storage_path': storagePath,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (bytes != null) 'bytes': bytes,
      if (uploadedAt != null) 'uploaded_at': uploadedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProofPhotosCompanion copyWith({
    Value<String>? id,
    Value<String>? proofEventId,
    Value<String>? storagePath,
    Value<int?>? width,
    Value<int?>? height,
    Value<int?>? bytes,
    Value<DateTime?>? uploadedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ProofPhotosCompanion(
      id: id ?? this.id,
      proofEventId: proofEventId ?? this.proofEventId,
      storagePath: storagePath ?? this.storagePath,
      width: width ?? this.width,
      height: height ?? this.height,
      bytes: bytes ?? this.bytes,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (proofEventId.present) {
      map['proof_event_id'] = Variable<String>(proofEventId.value);
    }
    if (storagePath.present) {
      map['storage_path'] = Variable<String>(storagePath.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<int>(bytes.value);
    }
    if (uploadedAt.present) {
      map['uploaded_at'] = Variable<DateTime>(uploadedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProofPhotosCompanion(')
          ..write('id: $id, ')
          ..write('proofEventId: $proofEventId, ')
          ..write('storagePath: $storagePath, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('bytes: $bytes, ')
          ..write('uploadedAt: $uploadedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $IssuesTable extends Issues with TableInfo<$IssuesTable, Issue> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IssuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderIdMeta = const VerificationMeta(
    'orderId',
  );
  @override
  late final GeneratedColumn<String> orderId = GeneratedColumn<String>(
    'order_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reportedByMeta = const VerificationMeta(
    'reportedBy',
  );
  @override
  late final GeneratedColumn<String> reportedBy = GeneratedColumn<String>(
    'reported_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reportedAtMeta = const VerificationMeta(
    'reportedAt',
  );
  @override
  late final GeneratedColumn<DateTime> reportedAt = GeneratedColumn<DateTime>(
    'reported_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resolvedAtMeta = const VerificationMeta(
    'resolvedAt',
  );
  @override
  late final GeneratedColumn<DateTime> resolvedAt = GeneratedColumn<DateTime>(
    'resolved_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resolvedByMeta = const VerificationMeta(
    'resolvedBy',
  );
  @override
  late final GeneratedColumn<String> resolvedBy = GeneratedColumn<String>(
    'resolved_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    orderId,
    kind,
    description,
    reportedBy,
    reportedAt,
    resolvedAt,
    resolvedBy,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'issues';
  @override
  VerificationContext validateIntegrity(
    Insertable<Issue> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('order_id')) {
      context.handle(
        _orderIdMeta,
        orderId.isAcceptableOrUnknown(data['order_id']!, _orderIdMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('reported_by')) {
      context.handle(
        _reportedByMeta,
        reportedBy.isAcceptableOrUnknown(data['reported_by']!, _reportedByMeta),
      );
    } else if (isInserting) {
      context.missing(_reportedByMeta);
    }
    if (data.containsKey('reported_at')) {
      context.handle(
        _reportedAtMeta,
        reportedAt.isAcceptableOrUnknown(data['reported_at']!, _reportedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_reportedAtMeta);
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
        _resolvedAtMeta,
        resolvedAt.isAcceptableOrUnknown(data['resolved_at']!, _resolvedAtMeta),
      );
    }
    if (data.containsKey('resolved_by')) {
      context.handle(
        _resolvedByMeta,
        resolvedBy.isAcceptableOrUnknown(data['resolved_by']!, _resolvedByMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Issue map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Issue(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      orderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}order_id'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      reportedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reported_by'],
      )!,
      reportedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}reported_at'],
      )!,
      resolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}resolved_at'],
      ),
      resolvedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resolved_by'],
      ),
    );
  }

  @override
  $IssuesTable createAlias(String alias) {
    return $IssuesTable(attachedDatabase, alias);
  }
}

class Issue extends DataClass implements Insertable<Issue> {
  final String id;
  final String? orderId;
  final String kind;
  final String description;
  final String reportedBy;
  final DateTime reportedAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  const Issue({
    required this.id,
    this.orderId,
    required this.kind,
    required this.description,
    required this.reportedBy,
    required this.reportedAt,
    this.resolvedAt,
    this.resolvedBy,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || orderId != null) {
      map['order_id'] = Variable<String>(orderId);
    }
    map['kind'] = Variable<String>(kind);
    map['description'] = Variable<String>(description);
    map['reported_by'] = Variable<String>(reportedBy);
    map['reported_at'] = Variable<DateTime>(reportedAt);
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt);
    }
    if (!nullToAbsent || resolvedBy != null) {
      map['resolved_by'] = Variable<String>(resolvedBy);
    }
    return map;
  }

  IssuesCompanion toCompanion(bool nullToAbsent) {
    return IssuesCompanion(
      id: Value(id),
      orderId: orderId == null && nullToAbsent
          ? const Value.absent()
          : Value(orderId),
      kind: Value(kind),
      description: Value(description),
      reportedBy: Value(reportedBy),
      reportedAt: Value(reportedAt),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
      resolvedBy: resolvedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedBy),
    );
  }

  factory Issue.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Issue(
      id: serializer.fromJson<String>(json['id']),
      orderId: serializer.fromJson<String?>(json['orderId']),
      kind: serializer.fromJson<String>(json['kind']),
      description: serializer.fromJson<String>(json['description']),
      reportedBy: serializer.fromJson<String>(json['reportedBy']),
      reportedAt: serializer.fromJson<DateTime>(json['reportedAt']),
      resolvedAt: serializer.fromJson<DateTime?>(json['resolvedAt']),
      resolvedBy: serializer.fromJson<String?>(json['resolvedBy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'orderId': serializer.toJson<String?>(orderId),
      'kind': serializer.toJson<String>(kind),
      'description': serializer.toJson<String>(description),
      'reportedBy': serializer.toJson<String>(reportedBy),
      'reportedAt': serializer.toJson<DateTime>(reportedAt),
      'resolvedAt': serializer.toJson<DateTime?>(resolvedAt),
      'resolvedBy': serializer.toJson<String?>(resolvedBy),
    };
  }

  Issue copyWith({
    String? id,
    Value<String?> orderId = const Value.absent(),
    String? kind,
    String? description,
    String? reportedBy,
    DateTime? reportedAt,
    Value<DateTime?> resolvedAt = const Value.absent(),
    Value<String?> resolvedBy = const Value.absent(),
  }) => Issue(
    id: id ?? this.id,
    orderId: orderId.present ? orderId.value : this.orderId,
    kind: kind ?? this.kind,
    description: description ?? this.description,
    reportedBy: reportedBy ?? this.reportedBy,
    reportedAt: reportedAt ?? this.reportedAt,
    resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
    resolvedBy: resolvedBy.present ? resolvedBy.value : this.resolvedBy,
  );
  Issue copyWithCompanion(IssuesCompanion data) {
    return Issue(
      id: data.id.present ? data.id.value : this.id,
      orderId: data.orderId.present ? data.orderId.value : this.orderId,
      kind: data.kind.present ? data.kind.value : this.kind,
      description: data.description.present
          ? data.description.value
          : this.description,
      reportedBy: data.reportedBy.present
          ? data.reportedBy.value
          : this.reportedBy,
      reportedAt: data.reportedAt.present
          ? data.reportedAt.value
          : this.reportedAt,
      resolvedAt: data.resolvedAt.present
          ? data.resolvedAt.value
          : this.resolvedAt,
      resolvedBy: data.resolvedBy.present
          ? data.resolvedBy.value
          : this.resolvedBy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Issue(')
          ..write('id: $id, ')
          ..write('orderId: $orderId, ')
          ..write('kind: $kind, ')
          ..write('description: $description, ')
          ..write('reportedBy: $reportedBy, ')
          ..write('reportedAt: $reportedAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('resolvedBy: $resolvedBy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    orderId,
    kind,
    description,
    reportedBy,
    reportedAt,
    resolvedAt,
    resolvedBy,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Issue &&
          other.id == this.id &&
          other.orderId == this.orderId &&
          other.kind == this.kind &&
          other.description == this.description &&
          other.reportedBy == this.reportedBy &&
          other.reportedAt == this.reportedAt &&
          other.resolvedAt == this.resolvedAt &&
          other.resolvedBy == this.resolvedBy);
}

class IssuesCompanion extends UpdateCompanion<Issue> {
  final Value<String> id;
  final Value<String?> orderId;
  final Value<String> kind;
  final Value<String> description;
  final Value<String> reportedBy;
  final Value<DateTime> reportedAt;
  final Value<DateTime?> resolvedAt;
  final Value<String?> resolvedBy;
  final Value<int> rowid;
  const IssuesCompanion({
    this.id = const Value.absent(),
    this.orderId = const Value.absent(),
    this.kind = const Value.absent(),
    this.description = const Value.absent(),
    this.reportedBy = const Value.absent(),
    this.reportedAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.resolvedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IssuesCompanion.insert({
    required String id,
    this.orderId = const Value.absent(),
    required String kind,
    required String description,
    required String reportedBy,
    required DateTime reportedAt,
    this.resolvedAt = const Value.absent(),
    this.resolvedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       description = Value(description),
       reportedBy = Value(reportedBy),
       reportedAt = Value(reportedAt);
  static Insertable<Issue> custom({
    Expression<String>? id,
    Expression<String>? orderId,
    Expression<String>? kind,
    Expression<String>? description,
    Expression<String>? reportedBy,
    Expression<DateTime>? reportedAt,
    Expression<DateTime>? resolvedAt,
    Expression<String>? resolvedBy,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (orderId != null) 'order_id': orderId,
      if (kind != null) 'kind': kind,
      if (description != null) 'description': description,
      if (reportedBy != null) 'reported_by': reportedBy,
      if (reportedAt != null) 'reported_at': reportedAt,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
      if (resolvedBy != null) 'resolved_by': resolvedBy,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IssuesCompanion copyWith({
    Value<String>? id,
    Value<String?>? orderId,
    Value<String>? kind,
    Value<String>? description,
    Value<String>? reportedBy,
    Value<DateTime>? reportedAt,
    Value<DateTime?>? resolvedAt,
    Value<String?>? resolvedBy,
    Value<int>? rowid,
  }) {
    return IssuesCompanion(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      kind: kind ?? this.kind,
      description: description ?? this.description,
      reportedBy: reportedBy ?? this.reportedBy,
      reportedAt: reportedAt ?? this.reportedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (orderId.present) {
      map['order_id'] = Variable<String>(orderId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (reportedBy.present) {
      map['reported_by'] = Variable<String>(reportedBy.value);
    }
    if (reportedAt.present) {
      map['reported_at'] = Variable<DateTime>(reportedAt.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt.value);
    }
    if (resolvedBy.present) {
      map['resolved_by'] = Variable<String>(resolvedBy.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IssuesCompanion(')
          ..write('id: $id, ')
          ..write('orderId: $orderId, ')
          ..write('kind: $kind, ')
          ..write('description: $description, ')
          ..write('reportedBy: $reportedBy, ')
          ..write('reportedAt: $reportedAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('resolvedBy: $resolvedBy, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ShiftsTable extends Shifts with TableInfo<$ShiftsTable, Shift> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShiftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _staffIdMeta = const VerificationMeta(
    'staffId',
  );
  @override
  late final GeneratedColumn<String> staffId = GeneratedColumn<String>(
    'staff_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedLatMeta = const VerificationMeta(
    'startedLat',
  );
  @override
  late final GeneratedColumn<double> startedLat = GeneratedColumn<double>(
    'started_lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startedLngMeta = const VerificationMeta(
    'startedLng',
  );
  @override
  late final GeneratedColumn<double> startedLng = GeneratedColumn<double>(
    'started_lng',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endedLatMeta = const VerificationMeta(
    'endedLat',
  );
  @override
  late final GeneratedColumn<double> endedLat = GeneratedColumn<double>(
    'ended_lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endedLngMeta = const VerificationMeta(
    'endedLng',
  );
  @override
  late final GeneratedColumn<double> endedLng = GeneratedColumn<double>(
    'ended_lng',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    staffId,
    startedAt,
    startedLat,
    startedLng,
    endedAt,
    endedLat,
    endedLng,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shifts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Shift> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('staff_id')) {
      context.handle(
        _staffIdMeta,
        staffId.isAcceptableOrUnknown(data['staff_id']!, _staffIdMeta),
      );
    } else if (isInserting) {
      context.missing(_staffIdMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('started_lat')) {
      context.handle(
        _startedLatMeta,
        startedLat.isAcceptableOrUnknown(data['started_lat']!, _startedLatMeta),
      );
    }
    if (data.containsKey('started_lng')) {
      context.handle(
        _startedLngMeta,
        startedLng.isAcceptableOrUnknown(data['started_lng']!, _startedLngMeta),
      );
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('ended_lat')) {
      context.handle(
        _endedLatMeta,
        endedLat.isAcceptableOrUnknown(data['ended_lat']!, _endedLatMeta),
      );
    }
    if (data.containsKey('ended_lng')) {
      context.handle(
        _endedLngMeta,
        endedLng.isAcceptableOrUnknown(data['ended_lng']!, _endedLngMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Shift map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Shift(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      staffId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}staff_id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      startedLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}started_lat'],
      ),
      startedLng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}started_lng'],
      ),
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      endedLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ended_lat'],
      ),
      endedLng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ended_lng'],
      ),
    );
  }

  @override
  $ShiftsTable createAlias(String alias) {
    return $ShiftsTable(attachedDatabase, alias);
  }
}

class Shift extends DataClass implements Insertable<Shift> {
  final String id;
  final String staffId;
  final DateTime startedAt;
  final double? startedLat;
  final double? startedLng;
  final DateTime? endedAt;
  final double? endedLat;
  final double? endedLng;
  const Shift({
    required this.id,
    required this.staffId,
    required this.startedAt,
    this.startedLat,
    this.startedLng,
    this.endedAt,
    this.endedLat,
    this.endedLng,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['staff_id'] = Variable<String>(staffId);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || startedLat != null) {
      map['started_lat'] = Variable<double>(startedLat);
    }
    if (!nullToAbsent || startedLng != null) {
      map['started_lng'] = Variable<double>(startedLng);
    }
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    if (!nullToAbsent || endedLat != null) {
      map['ended_lat'] = Variable<double>(endedLat);
    }
    if (!nullToAbsent || endedLng != null) {
      map['ended_lng'] = Variable<double>(endedLng);
    }
    return map;
  }

  ShiftsCompanion toCompanion(bool nullToAbsent) {
    return ShiftsCompanion(
      id: Value(id),
      staffId: Value(staffId),
      startedAt: Value(startedAt),
      startedLat: startedLat == null && nullToAbsent
          ? const Value.absent()
          : Value(startedLat),
      startedLng: startedLng == null && nullToAbsent
          ? const Value.absent()
          : Value(startedLng),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      endedLat: endedLat == null && nullToAbsent
          ? const Value.absent()
          : Value(endedLat),
      endedLng: endedLng == null && nullToAbsent
          ? const Value.absent()
          : Value(endedLng),
    );
  }

  factory Shift.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Shift(
      id: serializer.fromJson<String>(json['id']),
      staffId: serializer.fromJson<String>(json['staffId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      startedLat: serializer.fromJson<double?>(json['startedLat']),
      startedLng: serializer.fromJson<double?>(json['startedLng']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      endedLat: serializer.fromJson<double?>(json['endedLat']),
      endedLng: serializer.fromJson<double?>(json['endedLng']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'staffId': serializer.toJson<String>(staffId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'startedLat': serializer.toJson<double?>(startedLat),
      'startedLng': serializer.toJson<double?>(startedLng),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'endedLat': serializer.toJson<double?>(endedLat),
      'endedLng': serializer.toJson<double?>(endedLng),
    };
  }

  Shift copyWith({
    String? id,
    String? staffId,
    DateTime? startedAt,
    Value<double?> startedLat = const Value.absent(),
    Value<double?> startedLng = const Value.absent(),
    Value<DateTime?> endedAt = const Value.absent(),
    Value<double?> endedLat = const Value.absent(),
    Value<double?> endedLng = const Value.absent(),
  }) => Shift(
    id: id ?? this.id,
    staffId: staffId ?? this.staffId,
    startedAt: startedAt ?? this.startedAt,
    startedLat: startedLat.present ? startedLat.value : this.startedLat,
    startedLng: startedLng.present ? startedLng.value : this.startedLng,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    endedLat: endedLat.present ? endedLat.value : this.endedLat,
    endedLng: endedLng.present ? endedLng.value : this.endedLng,
  );
  Shift copyWithCompanion(ShiftsCompanion data) {
    return Shift(
      id: data.id.present ? data.id.value : this.id,
      staffId: data.staffId.present ? data.staffId.value : this.staffId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      startedLat: data.startedLat.present
          ? data.startedLat.value
          : this.startedLat,
      startedLng: data.startedLng.present
          ? data.startedLng.value
          : this.startedLng,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      endedLat: data.endedLat.present ? data.endedLat.value : this.endedLat,
      endedLng: data.endedLng.present ? data.endedLng.value : this.endedLng,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Shift(')
          ..write('id: $id, ')
          ..write('staffId: $staffId, ')
          ..write('startedAt: $startedAt, ')
          ..write('startedLat: $startedLat, ')
          ..write('startedLng: $startedLng, ')
          ..write('endedAt: $endedAt, ')
          ..write('endedLat: $endedLat, ')
          ..write('endedLng: $endedLng')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    staffId,
    startedAt,
    startedLat,
    startedLng,
    endedAt,
    endedLat,
    endedLng,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Shift &&
          other.id == this.id &&
          other.staffId == this.staffId &&
          other.startedAt == this.startedAt &&
          other.startedLat == this.startedLat &&
          other.startedLng == this.startedLng &&
          other.endedAt == this.endedAt &&
          other.endedLat == this.endedLat &&
          other.endedLng == this.endedLng);
}

class ShiftsCompanion extends UpdateCompanion<Shift> {
  final Value<String> id;
  final Value<String> staffId;
  final Value<DateTime> startedAt;
  final Value<double?> startedLat;
  final Value<double?> startedLng;
  final Value<DateTime?> endedAt;
  final Value<double?> endedLat;
  final Value<double?> endedLng;
  final Value<int> rowid;
  const ShiftsCompanion({
    this.id = const Value.absent(),
    this.staffId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.startedLat = const Value.absent(),
    this.startedLng = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.endedLat = const Value.absent(),
    this.endedLng = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ShiftsCompanion.insert({
    required String id,
    required String staffId,
    required DateTime startedAt,
    this.startedLat = const Value.absent(),
    this.startedLng = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.endedLat = const Value.absent(),
    this.endedLng = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       staffId = Value(staffId),
       startedAt = Value(startedAt);
  static Insertable<Shift> custom({
    Expression<String>? id,
    Expression<String>? staffId,
    Expression<DateTime>? startedAt,
    Expression<double>? startedLat,
    Expression<double>? startedLng,
    Expression<DateTime>? endedAt,
    Expression<double>? endedLat,
    Expression<double>? endedLng,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (staffId != null) 'staff_id': staffId,
      if (startedAt != null) 'started_at': startedAt,
      if (startedLat != null) 'started_lat': startedLat,
      if (startedLng != null) 'started_lng': startedLng,
      if (endedAt != null) 'ended_at': endedAt,
      if (endedLat != null) 'ended_lat': endedLat,
      if (endedLng != null) 'ended_lng': endedLng,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ShiftsCompanion copyWith({
    Value<String>? id,
    Value<String>? staffId,
    Value<DateTime>? startedAt,
    Value<double?>? startedLat,
    Value<double?>? startedLng,
    Value<DateTime?>? endedAt,
    Value<double?>? endedLat,
    Value<double?>? endedLng,
    Value<int>? rowid,
  }) {
    return ShiftsCompanion(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      startedAt: startedAt ?? this.startedAt,
      startedLat: startedLat ?? this.startedLat,
      startedLng: startedLng ?? this.startedLng,
      endedAt: endedAt ?? this.endedAt,
      endedLat: endedLat ?? this.endedLat,
      endedLng: endedLng ?? this.endedLng,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (staffId.present) {
      map['staff_id'] = Variable<String>(staffId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (startedLat.present) {
      map['started_lat'] = Variable<double>(startedLat.value);
    }
    if (startedLng.present) {
      map['started_lng'] = Variable<double>(startedLng.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (endedLat.present) {
      map['ended_lat'] = Variable<double>(endedLat.value);
    }
    if (endedLng.present) {
      map['ended_lng'] = Variable<double>(endedLng.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShiftsCompanion(')
          ..write('id: $id, ')
          ..write('staffId: $staffId, ')
          ..write('startedAt: $startedAt, ')
          ..write('startedLat: $startedLat, ')
          ..write('startedLng: $startedLng, ')
          ..write('endedAt: $endedAt, ')
          ..write('endedLat: $endedLat, ')
          ..write('endedLng: $endedLng, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ValidTransitionsTable extends ValidTransitions
    with TableInfo<$ValidTransitionsTable, ValidTransition> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ValidTransitionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _intakeMethodMeta = const VerificationMeta(
    'intakeMethod',
  );
  @override
  late final GeneratedColumn<String> intakeMethod = GeneratedColumn<String>(
    'intake_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fulfillmentMethodMeta = const VerificationMeta(
    'fulfillmentMethod',
  );
  @override
  late final GeneratedColumn<String> fulfillmentMethod =
      GeneratedColumn<String>(
        'fulfillment_method',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _fromStatusMeta = const VerificationMeta(
    'fromStatus',
  );
  @override
  late final GeneratedColumn<String> fromStatus = GeneratedColumn<String>(
    'from_status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toStatusMeta = const VerificationMeta(
    'toStatus',
  );
  @override
  late final GeneratedColumn<String> toStatus = GeneratedColumn<String>(
    'to_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    intakeMethod,
    fulfillmentMethod,
    fromStatus,
    toStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'valid_transitions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ValidTransition> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('intake_method')) {
      context.handle(
        _intakeMethodMeta,
        intakeMethod.isAcceptableOrUnknown(
          data['intake_method']!,
          _intakeMethodMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_intakeMethodMeta);
    }
    if (data.containsKey('fulfillment_method')) {
      context.handle(
        _fulfillmentMethodMeta,
        fulfillmentMethod.isAcceptableOrUnknown(
          data['fulfillment_method']!,
          _fulfillmentMethodMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fulfillmentMethodMeta);
    }
    if (data.containsKey('from_status')) {
      context.handle(
        _fromStatusMeta,
        fromStatus.isAcceptableOrUnknown(data['from_status']!, _fromStatusMeta),
      );
    }
    if (data.containsKey('to_status')) {
      context.handle(
        _toStatusMeta,
        toStatus.isAcceptableOrUnknown(data['to_status']!, _toStatusMeta),
      );
    } else if (isInserting) {
      context.missing(_toStatusMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ValidTransition map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ValidTransition(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      intakeMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}intake_method'],
      )!,
      fulfillmentMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fulfillment_method'],
      )!,
      fromStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_status'],
      ),
      toStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_status'],
      )!,
    );
  }

  @override
  $ValidTransitionsTable createAlias(String alias) {
    return $ValidTransitionsTable(attachedDatabase, alias);
  }
}

class ValidTransition extends DataClass implements Insertable<ValidTransition> {
  final String id;
  final String intakeMethod;
  final String fulfillmentMethod;
  final String? fromStatus;
  final String toStatus;
  const ValidTransition({
    required this.id,
    required this.intakeMethod,
    required this.fulfillmentMethod,
    this.fromStatus,
    required this.toStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['intake_method'] = Variable<String>(intakeMethod);
    map['fulfillment_method'] = Variable<String>(fulfillmentMethod);
    if (!nullToAbsent || fromStatus != null) {
      map['from_status'] = Variable<String>(fromStatus);
    }
    map['to_status'] = Variable<String>(toStatus);
    return map;
  }

  ValidTransitionsCompanion toCompanion(bool nullToAbsent) {
    return ValidTransitionsCompanion(
      id: Value(id),
      intakeMethod: Value(intakeMethod),
      fulfillmentMethod: Value(fulfillmentMethod),
      fromStatus: fromStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(fromStatus),
      toStatus: Value(toStatus),
    );
  }

  factory ValidTransition.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ValidTransition(
      id: serializer.fromJson<String>(json['id']),
      intakeMethod: serializer.fromJson<String>(json['intakeMethod']),
      fulfillmentMethod: serializer.fromJson<String>(json['fulfillmentMethod']),
      fromStatus: serializer.fromJson<String?>(json['fromStatus']),
      toStatus: serializer.fromJson<String>(json['toStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'intakeMethod': serializer.toJson<String>(intakeMethod),
      'fulfillmentMethod': serializer.toJson<String>(fulfillmentMethod),
      'fromStatus': serializer.toJson<String?>(fromStatus),
      'toStatus': serializer.toJson<String>(toStatus),
    };
  }

  ValidTransition copyWith({
    String? id,
    String? intakeMethod,
    String? fulfillmentMethod,
    Value<String?> fromStatus = const Value.absent(),
    String? toStatus,
  }) => ValidTransition(
    id: id ?? this.id,
    intakeMethod: intakeMethod ?? this.intakeMethod,
    fulfillmentMethod: fulfillmentMethod ?? this.fulfillmentMethod,
    fromStatus: fromStatus.present ? fromStatus.value : this.fromStatus,
    toStatus: toStatus ?? this.toStatus,
  );
  ValidTransition copyWithCompanion(ValidTransitionsCompanion data) {
    return ValidTransition(
      id: data.id.present ? data.id.value : this.id,
      intakeMethod: data.intakeMethod.present
          ? data.intakeMethod.value
          : this.intakeMethod,
      fulfillmentMethod: data.fulfillmentMethod.present
          ? data.fulfillmentMethod.value
          : this.fulfillmentMethod,
      fromStatus: data.fromStatus.present
          ? data.fromStatus.value
          : this.fromStatus,
      toStatus: data.toStatus.present ? data.toStatus.value : this.toStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ValidTransition(')
          ..write('id: $id, ')
          ..write('intakeMethod: $intakeMethod, ')
          ..write('fulfillmentMethod: $fulfillmentMethod, ')
          ..write('fromStatus: $fromStatus, ')
          ..write('toStatus: $toStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, intakeMethod, fulfillmentMethod, fromStatus, toStatus);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ValidTransition &&
          other.id == this.id &&
          other.intakeMethod == this.intakeMethod &&
          other.fulfillmentMethod == this.fulfillmentMethod &&
          other.fromStatus == this.fromStatus &&
          other.toStatus == this.toStatus);
}

class ValidTransitionsCompanion extends UpdateCompanion<ValidTransition> {
  final Value<String> id;
  final Value<String> intakeMethod;
  final Value<String> fulfillmentMethod;
  final Value<String?> fromStatus;
  final Value<String> toStatus;
  final Value<int> rowid;
  const ValidTransitionsCompanion({
    this.id = const Value.absent(),
    this.intakeMethod = const Value.absent(),
    this.fulfillmentMethod = const Value.absent(),
    this.fromStatus = const Value.absent(),
    this.toStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ValidTransitionsCompanion.insert({
    required String id,
    required String intakeMethod,
    required String fulfillmentMethod,
    this.fromStatus = const Value.absent(),
    required String toStatus,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       intakeMethod = Value(intakeMethod),
       fulfillmentMethod = Value(fulfillmentMethod),
       toStatus = Value(toStatus);
  static Insertable<ValidTransition> custom({
    Expression<String>? id,
    Expression<String>? intakeMethod,
    Expression<String>? fulfillmentMethod,
    Expression<String>? fromStatus,
    Expression<String>? toStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (intakeMethod != null) 'intake_method': intakeMethod,
      if (fulfillmentMethod != null) 'fulfillment_method': fulfillmentMethod,
      if (fromStatus != null) 'from_status': fromStatus,
      if (toStatus != null) 'to_status': toStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ValidTransitionsCompanion copyWith({
    Value<String>? id,
    Value<String>? intakeMethod,
    Value<String>? fulfillmentMethod,
    Value<String?>? fromStatus,
    Value<String>? toStatus,
    Value<int>? rowid,
  }) {
    return ValidTransitionsCompanion(
      id: id ?? this.id,
      intakeMethod: intakeMethod ?? this.intakeMethod,
      fulfillmentMethod: fulfillmentMethod ?? this.fulfillmentMethod,
      fromStatus: fromStatus ?? this.fromStatus,
      toStatus: toStatus ?? this.toStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (intakeMethod.present) {
      map['intake_method'] = Variable<String>(intakeMethod.value);
    }
    if (fulfillmentMethod.present) {
      map['fulfillment_method'] = Variable<String>(fulfillmentMethod.value);
    }
    if (fromStatus.present) {
      map['from_status'] = Variable<String>(fromStatus.value);
    }
    if (toStatus.present) {
      map['to_status'] = Variable<String>(toStatus.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ValidTransitionsCompanion(')
          ..write('id: $id, ')
          ..write('intakeMethod: $intakeMethod, ')
          ..write('fulfillmentMethod: $fulfillmentMethod, ')
          ..write('fromStatus: $fromStatus, ')
          ..write('toStatus: $toStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _forTableMeta = const VerificationMeta(
    'forTable',
  );
  @override
  late final GeneratedColumn<String> forTable = GeneratedColumn<String>(
    'table_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  @override
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<String> rowId = GeneratedColumn<String>(
    'row_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
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
  static const VerificationMeta _lastAttemptedAtMeta = const VerificationMeta(
    'lastAttemptedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttemptedAt =
      GeneratedColumn<DateTime>(
        'last_attempted_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
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
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    forTable,
    op,
    rowId,
    payloadJson,
    createdAt,
    retryCount,
    lastAttemptedAt,
    lastError,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('table_name')) {
      context.handle(
        _forTableMeta,
        forTable.isAcceptableOrUnknown(data['table_name']!, _forTableMeta),
      );
    } else if (isInserting) {
      context.missing(_forTableMeta);
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    } else if (isInserting) {
      context.missing(_opMeta);
    }
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rowIdMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('last_attempted_at')) {
      context.handle(
        _lastAttemptedAtMeta,
        lastAttemptedAt.isAcceptableOrUnknown(
          data['last_attempted_at']!,
          _lastAttemptedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      forTable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}table_name'],
      )!,
      op: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op'],
      )!,
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_id'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      lastAttemptedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempted_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxData extends DataClass implements Insertable<OutboxData> {
  final String id;
  final String forTable;
  final String op;
  final String rowId;
  final String payloadJson;
  final DateTime createdAt;
  final int retryCount;
  final DateTime? lastAttemptedAt;
  final String? lastError;
  final String status;
  const OutboxData({
    required this.id,
    required this.forTable,
    required this.op,
    required this.rowId,
    required this.payloadJson,
    required this.createdAt,
    required this.retryCount,
    this.lastAttemptedAt,
    this.lastError,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['table_name'] = Variable<String>(forTable);
    map['op'] = Variable<String>(op);
    map['row_id'] = Variable<String>(rowId);
    map['payload_json'] = Variable<String>(payloadJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || lastAttemptedAt != null) {
      map['last_attempted_at'] = Variable<DateTime>(lastAttemptedAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['status'] = Variable<String>(status);
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      id: Value(id),
      forTable: Value(forTable),
      op: Value(op),
      rowId: Value(rowId),
      payloadJson: Value(payloadJson),
      createdAt: Value(createdAt),
      retryCount: Value(retryCount),
      lastAttemptedAt: lastAttemptedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptedAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      status: Value(status),
    );
  }

  factory OutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxData(
      id: serializer.fromJson<String>(json['id']),
      forTable: serializer.fromJson<String>(json['forTable']),
      op: serializer.fromJson<String>(json['op']),
      rowId: serializer.fromJson<String>(json['rowId']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      lastAttemptedAt: serializer.fromJson<DateTime?>(json['lastAttemptedAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'forTable': serializer.toJson<String>(forTable),
      'op': serializer.toJson<String>(op),
      'rowId': serializer.toJson<String>(rowId),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'retryCount': serializer.toJson<int>(retryCount),
      'lastAttemptedAt': serializer.toJson<DateTime?>(lastAttemptedAt),
      'lastError': serializer.toJson<String?>(lastError),
      'status': serializer.toJson<String>(status),
    };
  }

  OutboxData copyWith({
    String? id,
    String? forTable,
    String? op,
    String? rowId,
    String? payloadJson,
    DateTime? createdAt,
    int? retryCount,
    Value<DateTime?> lastAttemptedAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    String? status,
  }) => OutboxData(
    id: id ?? this.id,
    forTable: forTable ?? this.forTable,
    op: op ?? this.op,
    rowId: rowId ?? this.rowId,
    payloadJson: payloadJson ?? this.payloadJson,
    createdAt: createdAt ?? this.createdAt,
    retryCount: retryCount ?? this.retryCount,
    lastAttemptedAt: lastAttemptedAt.present
        ? lastAttemptedAt.value
        : this.lastAttemptedAt,
    lastError: lastError.present ? lastError.value : this.lastError,
    status: status ?? this.status,
  );
  OutboxData copyWithCompanion(OutboxCompanion data) {
    return OutboxData(
      id: data.id.present ? data.id.value : this.id,
      forTable: data.forTable.present ? data.forTable.value : this.forTable,
      op: data.op.present ? data.op.value : this.op,
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      lastAttemptedAt: data.lastAttemptedAt.present
          ? data.lastAttemptedAt.value
          : this.lastAttemptedAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxData(')
          ..write('id: $id, ')
          ..write('forTable: $forTable, ')
          ..write('op: $op, ')
          ..write('rowId: $rowId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastAttemptedAt: $lastAttemptedAt, ')
          ..write('lastError: $lastError, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    forTable,
    op,
    rowId,
    payloadJson,
    createdAt,
    retryCount,
    lastAttemptedAt,
    lastError,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxData &&
          other.id == this.id &&
          other.forTable == this.forTable &&
          other.op == this.op &&
          other.rowId == this.rowId &&
          other.payloadJson == this.payloadJson &&
          other.createdAt == this.createdAt &&
          other.retryCount == this.retryCount &&
          other.lastAttemptedAt == this.lastAttemptedAt &&
          other.lastError == this.lastError &&
          other.status == this.status);
}

class OutboxCompanion extends UpdateCompanion<OutboxData> {
  final Value<String> id;
  final Value<String> forTable;
  final Value<String> op;
  final Value<String> rowId;
  final Value<String> payloadJson;
  final Value<DateTime> createdAt;
  final Value<int> retryCount;
  final Value<DateTime?> lastAttemptedAt;
  final Value<String?> lastError;
  final Value<String> status;
  final Value<int> rowid;
  const OutboxCompanion({
    this.id = const Value.absent(),
    this.forTable = const Value.absent(),
    this.op = const Value.absent(),
    this.rowId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastAttemptedAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxCompanion.insert({
    required String id,
    required String forTable,
    required String op,
    required String rowId,
    required String payloadJson,
    this.createdAt = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastAttemptedAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       forTable = Value(forTable),
       op = Value(op),
       rowId = Value(rowId),
       payloadJson = Value(payloadJson);
  static Insertable<OutboxData> custom({
    Expression<String>? id,
    Expression<String>? forTable,
    Expression<String>? op,
    Expression<String>? rowId,
    Expression<String>? payloadJson,
    Expression<DateTime>? createdAt,
    Expression<int>? retryCount,
    Expression<DateTime>? lastAttemptedAt,
    Expression<String>? lastError,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (forTable != null) 'table_name': forTable,
      if (op != null) 'op': op,
      if (rowId != null) 'row_id': rowId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (createdAt != null) 'created_at': createdAt,
      if (retryCount != null) 'retry_count': retryCount,
      if (lastAttemptedAt != null) 'last_attempted_at': lastAttemptedAt,
      if (lastError != null) 'last_error': lastError,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxCompanion copyWith({
    Value<String>? id,
    Value<String>? forTable,
    Value<String>? op,
    Value<String>? rowId,
    Value<String>? payloadJson,
    Value<DateTime>? createdAt,
    Value<int>? retryCount,
    Value<DateTime?>? lastAttemptedAt,
    Value<String?>? lastError,
    Value<String>? status,
    Value<int>? rowid,
  }) {
    return OutboxCompanion(
      id: id ?? this.id,
      forTable: forTable ?? this.forTable,
      op: op ?? this.op,
      rowId: rowId ?? this.rowId,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastAttemptedAt: lastAttemptedAt ?? this.lastAttemptedAt,
      lastError: lastError ?? this.lastError,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (forTable.present) {
      map['table_name'] = Variable<String>(forTable.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (rowId.present) {
      map['row_id'] = Variable<String>(rowId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (lastAttemptedAt.present) {
      map['last_attempted_at'] = Variable<DateTime>(lastAttemptedAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('id: $id, ')
          ..write('forTable: $forTable, ')
          ..write('op: $op, ')
          ..write('rowId: $rowId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastAttemptedAt: $lastAttemptedAt, ')
          ..write('lastError: $lastError, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncWatermarksTable extends SyncWatermarks
    with TableInfo<$SyncWatermarksTable, SyncWatermark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncWatermarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _forTableMeta = const VerificationMeta(
    'forTable',
  );
  @override
  late final GeneratedColumn<String> forTable = GeneratedColumn<String>(
    'table_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [forTable, lastSyncedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_watermarks';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncWatermark> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('table_name')) {
      context.handle(
        _forTableMeta,
        forTable.isAcceptableOrUnknown(data['table_name']!, _forTableMeta),
      );
    } else if (isInserting) {
      context.missing(_forTableMeta);
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSyncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {forTable};
  @override
  SyncWatermark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncWatermark(
      forTable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}table_name'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      )!,
    );
  }

  @override
  $SyncWatermarksTable createAlias(String alias) {
    return $SyncWatermarksTable(attachedDatabase, alias);
  }
}

class SyncWatermark extends DataClass implements Insertable<SyncWatermark> {
  final String forTable;
  final DateTime lastSyncedAt;
  const SyncWatermark({required this.forTable, required this.lastSyncedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['table_name'] = Variable<String>(forTable);
    map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    return map;
  }

  SyncWatermarksCompanion toCompanion(bool nullToAbsent) {
    return SyncWatermarksCompanion(
      forTable: Value(forTable),
      lastSyncedAt: Value(lastSyncedAt),
    );
  }

  factory SyncWatermark.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncWatermark(
      forTable: serializer.fromJson<String>(json['forTable']),
      lastSyncedAt: serializer.fromJson<DateTime>(json['lastSyncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'forTable': serializer.toJson<String>(forTable),
      'lastSyncedAt': serializer.toJson<DateTime>(lastSyncedAt),
    };
  }

  SyncWatermark copyWith({String? forTable, DateTime? lastSyncedAt}) =>
      SyncWatermark(
        forTable: forTable ?? this.forTable,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      );
  SyncWatermark copyWithCompanion(SyncWatermarksCompanion data) {
    return SyncWatermark(
      forTable: data.forTable.present ? data.forTable.value : this.forTable,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncWatermark(')
          ..write('forTable: $forTable, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(forTable, lastSyncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncWatermark &&
          other.forTable == this.forTable &&
          other.lastSyncedAt == this.lastSyncedAt);
}

class SyncWatermarksCompanion extends UpdateCompanion<SyncWatermark> {
  final Value<String> forTable;
  final Value<DateTime> lastSyncedAt;
  final Value<int> rowid;
  const SyncWatermarksCompanion({
    this.forTable = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncWatermarksCompanion.insert({
    required String forTable,
    required DateTime lastSyncedAt,
    this.rowid = const Value.absent(),
  }) : forTable = Value(forTable),
       lastSyncedAt = Value(lastSyncedAt);
  static Insertable<SyncWatermark> custom({
    Expression<String>? forTable,
    Expression<DateTime>? lastSyncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (forTable != null) 'table_name': forTable,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncWatermarksCompanion copyWith({
    Value<String>? forTable,
    Value<DateTime>? lastSyncedAt,
    Value<int>? rowid,
  }) {
    return SyncWatermarksCompanion(
      forTable: forTable ?? this.forTable,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (forTable.present) {
      map['table_name'] = Variable<String>(forTable.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncWatermarksCompanion(')
          ..write('forTable: $forTable, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PullDeadLetterTable extends PullDeadLetter
    with TableInfo<$PullDeadLetterTable, PullDeadLetterData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PullDeadLetterTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _forTableMeta = const VerificationMeta(
    'forTable',
  );
  @override
  late final GeneratedColumn<String> forTable = GeneratedColumn<String>(
    'table_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowPayloadJsonMeta = const VerificationMeta(
    'rowPayloadJson',
  );
  @override
  late final GeneratedColumn<String> rowPayloadJson = GeneratedColumn<String>(
    'row_payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _errorTextMeta = const VerificationMeta(
    'errorText',
  );
  @override
  late final GeneratedColumn<String> errorText = GeneratedColumn<String>(
    'error_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordedAtMeta = const VerificationMeta(
    'recordedAt',
  );
  @override
  late final GeneratedColumn<DateTime> recordedAt = GeneratedColumn<DateTime>(
    'recorded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    forTable,
    rowPayloadJson,
    errorText,
    recordedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pull_dead_letter';
  @override
  VerificationContext validateIntegrity(
    Insertable<PullDeadLetterData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('table_name')) {
      context.handle(
        _forTableMeta,
        forTable.isAcceptableOrUnknown(data['table_name']!, _forTableMeta),
      );
    } else if (isInserting) {
      context.missing(_forTableMeta);
    }
    if (data.containsKey('row_payload_json')) {
      context.handle(
        _rowPayloadJsonMeta,
        rowPayloadJson.isAcceptableOrUnknown(
          data['row_payload_json']!,
          _rowPayloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rowPayloadJsonMeta);
    }
    if (data.containsKey('error_text')) {
      context.handle(
        _errorTextMeta,
        errorText.isAcceptableOrUnknown(data['error_text']!, _errorTextMeta),
      );
    } else if (isInserting) {
      context.missing(_errorTextMeta);
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
        _recordedAtMeta,
        recordedAt.isAcceptableOrUnknown(data['recorded_at']!, _recordedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PullDeadLetterData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PullDeadLetterData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      forTable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}table_name'],
      )!,
      rowPayloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_payload_json'],
      )!,
      errorText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_text'],
      )!,
      recordedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}recorded_at'],
      )!,
    );
  }

  @override
  $PullDeadLetterTable createAlias(String alias) {
    return $PullDeadLetterTable(attachedDatabase, alias);
  }
}

class PullDeadLetterData extends DataClass
    implements Insertable<PullDeadLetterData> {
  final String id;
  final String forTable;
  final String rowPayloadJson;
  final String errorText;
  final DateTime recordedAt;
  const PullDeadLetterData({
    required this.id,
    required this.forTable,
    required this.rowPayloadJson,
    required this.errorText,
    required this.recordedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['table_name'] = Variable<String>(forTable);
    map['row_payload_json'] = Variable<String>(rowPayloadJson);
    map['error_text'] = Variable<String>(errorText);
    map['recorded_at'] = Variable<DateTime>(recordedAt);
    return map;
  }

  PullDeadLetterCompanion toCompanion(bool nullToAbsent) {
    return PullDeadLetterCompanion(
      id: Value(id),
      forTable: Value(forTable),
      rowPayloadJson: Value(rowPayloadJson),
      errorText: Value(errorText),
      recordedAt: Value(recordedAt),
    );
  }

  factory PullDeadLetterData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PullDeadLetterData(
      id: serializer.fromJson<String>(json['id']),
      forTable: serializer.fromJson<String>(json['forTable']),
      rowPayloadJson: serializer.fromJson<String>(json['rowPayloadJson']),
      errorText: serializer.fromJson<String>(json['errorText']),
      recordedAt: serializer.fromJson<DateTime>(json['recordedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'forTable': serializer.toJson<String>(forTable),
      'rowPayloadJson': serializer.toJson<String>(rowPayloadJson),
      'errorText': serializer.toJson<String>(errorText),
      'recordedAt': serializer.toJson<DateTime>(recordedAt),
    };
  }

  PullDeadLetterData copyWith({
    String? id,
    String? forTable,
    String? rowPayloadJson,
    String? errorText,
    DateTime? recordedAt,
  }) => PullDeadLetterData(
    id: id ?? this.id,
    forTable: forTable ?? this.forTable,
    rowPayloadJson: rowPayloadJson ?? this.rowPayloadJson,
    errorText: errorText ?? this.errorText,
    recordedAt: recordedAt ?? this.recordedAt,
  );
  PullDeadLetterData copyWithCompanion(PullDeadLetterCompanion data) {
    return PullDeadLetterData(
      id: data.id.present ? data.id.value : this.id,
      forTable: data.forTable.present ? data.forTable.value : this.forTable,
      rowPayloadJson: data.rowPayloadJson.present
          ? data.rowPayloadJson.value
          : this.rowPayloadJson,
      errorText: data.errorText.present ? data.errorText.value : this.errorText,
      recordedAt: data.recordedAt.present
          ? data.recordedAt.value
          : this.recordedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PullDeadLetterData(')
          ..write('id: $id, ')
          ..write('forTable: $forTable, ')
          ..write('rowPayloadJson: $rowPayloadJson, ')
          ..write('errorText: $errorText, ')
          ..write('recordedAt: $recordedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, forTable, rowPayloadJson, errorText, recordedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PullDeadLetterData &&
          other.id == this.id &&
          other.forTable == this.forTable &&
          other.rowPayloadJson == this.rowPayloadJson &&
          other.errorText == this.errorText &&
          other.recordedAt == this.recordedAt);
}

class PullDeadLetterCompanion extends UpdateCompanion<PullDeadLetterData> {
  final Value<String> id;
  final Value<String> forTable;
  final Value<String> rowPayloadJson;
  final Value<String> errorText;
  final Value<DateTime> recordedAt;
  final Value<int> rowid;
  const PullDeadLetterCompanion({
    this.id = const Value.absent(),
    this.forTable = const Value.absent(),
    this.rowPayloadJson = const Value.absent(),
    this.errorText = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PullDeadLetterCompanion.insert({
    required String id,
    required String forTable,
    required String rowPayloadJson,
    required String errorText,
    this.recordedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       forTable = Value(forTable),
       rowPayloadJson = Value(rowPayloadJson),
       errorText = Value(errorText);
  static Insertable<PullDeadLetterData> custom({
    Expression<String>? id,
    Expression<String>? forTable,
    Expression<String>? rowPayloadJson,
    Expression<String>? errorText,
    Expression<DateTime>? recordedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (forTable != null) 'table_name': forTable,
      if (rowPayloadJson != null) 'row_payload_json': rowPayloadJson,
      if (errorText != null) 'error_text': errorText,
      if (recordedAt != null) 'recorded_at': recordedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PullDeadLetterCompanion copyWith({
    Value<String>? id,
    Value<String>? forTable,
    Value<String>? rowPayloadJson,
    Value<String>? errorText,
    Value<DateTime>? recordedAt,
    Value<int>? rowid,
  }) {
    return PullDeadLetterCompanion(
      id: id ?? this.id,
      forTable: forTable ?? this.forTable,
      rowPayloadJson: rowPayloadJson ?? this.rowPayloadJson,
      errorText: errorText ?? this.errorText,
      recordedAt: recordedAt ?? this.recordedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (forTable.present) {
      map['table_name'] = Variable<String>(forTable.value);
    }
    if (rowPayloadJson.present) {
      map['row_payload_json'] = Variable<String>(rowPayloadJson.value);
    }
    if (errorText.present) {
      map['error_text'] = Variable<String>(errorText.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<DateTime>(recordedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PullDeadLetterCompanion(')
          ..write('id: $id, ')
          ..write('forTable: $forTable, ')
          ..write('rowPayloadJson: $rowPayloadJson, ')
          ..write('errorText: $errorText, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PricingSettingsTable extends PricingSettings
    with TableInfo<$PricingSettingsTable, PricingSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PricingSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _defaultRatePerKgUgxMeta =
      const VerificationMeta('defaultRatePerKgUgx');
  @override
  late final GeneratedColumn<double> defaultRatePerKgUgx =
      GeneratedColumn<double>(
        'default_rate_per_kg_ugx',
        aliasedName,
        false,
        type: DriftSqlType.double,
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
  static const VerificationMeta _updatedByMeta = const VerificationMeta(
    'updatedBy',
  );
  @override
  late final GeneratedColumn<String> updatedBy = GeneratedColumn<String>(
    'updated_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deliveryFeeUgxMeta = const VerificationMeta(
    'deliveryFeeUgx',
  );
  @override
  late final GeneratedColumn<int> deliveryFeeUgx = GeneratedColumn<int>(
    'delivery_fee_ugx',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _expressSurchargeFlatUgxMeta =
      const VerificationMeta('expressSurchargeFlatUgx');
  @override
  late final GeneratedColumn<int> expressSurchargeFlatUgx =
      GeneratedColumn<int>(
        'express_surcharge_flat_ugx',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _expressSurchargePctMeta =
      const VerificationMeta('expressSurchargePct');
  @override
  late final GeneratedColumn<double> expressSurchargePct =
      GeneratedColumn<double>(
        'express_surcharge_pct',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    defaultRatePerKgUgx,
    updatedAt,
    updatedBy,
    deliveryFeeUgx,
    expressSurchargeFlatUgx,
    expressSurchargePct,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pricing_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<PricingSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('default_rate_per_kg_ugx')) {
      context.handle(
        _defaultRatePerKgUgxMeta,
        defaultRatePerKgUgx.isAcceptableOrUnknown(
          data['default_rate_per_kg_ugx']!,
          _defaultRatePerKgUgxMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_defaultRatePerKgUgxMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    }
    if (data.containsKey('delivery_fee_ugx')) {
      context.handle(
        _deliveryFeeUgxMeta,
        deliveryFeeUgx.isAcceptableOrUnknown(
          data['delivery_fee_ugx']!,
          _deliveryFeeUgxMeta,
        ),
      );
    }
    if (data.containsKey('express_surcharge_flat_ugx')) {
      context.handle(
        _expressSurchargeFlatUgxMeta,
        expressSurchargeFlatUgx.isAcceptableOrUnknown(
          data['express_surcharge_flat_ugx']!,
          _expressSurchargeFlatUgxMeta,
        ),
      );
    }
    if (data.containsKey('express_surcharge_pct')) {
      context.handle(
        _expressSurchargePctMeta,
        expressSurchargePct.isAcceptableOrUnknown(
          data['express_surcharge_pct']!,
          _expressSurchargePctMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PricingSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PricingSetting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      defaultRatePerKgUgx: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}default_rate_per_kg_ugx'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_by'],
      ),
      deliveryFeeUgx: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}delivery_fee_ugx'],
      )!,
      expressSurchargeFlatUgx: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}express_surcharge_flat_ugx'],
      )!,
      expressSurchargePct: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}express_surcharge_pct'],
      )!,
    );
  }

  @override
  $PricingSettingsTable createAlias(String alias) {
    return $PricingSettingsTable(attachedDatabase, alias);
  }
}

class PricingSetting extends DataClass implements Insertable<PricingSetting> {
  final String id;
  final double defaultRatePerKgUgx;
  final DateTime updatedAt;
  final String? updatedBy;
  final int deliveryFeeUgx;
  final int expressSurchargeFlatUgx;
  final double expressSurchargePct;
  const PricingSetting({
    required this.id,
    required this.defaultRatePerKgUgx,
    required this.updatedAt,
    this.updatedBy,
    required this.deliveryFeeUgx,
    required this.expressSurchargeFlatUgx,
    required this.expressSurchargePct,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['default_rate_per_kg_ugx'] = Variable<double>(defaultRatePerKgUgx);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || updatedBy != null) {
      map['updated_by'] = Variable<String>(updatedBy);
    }
    map['delivery_fee_ugx'] = Variable<int>(deliveryFeeUgx);
    map['express_surcharge_flat_ugx'] = Variable<int>(expressSurchargeFlatUgx);
    map['express_surcharge_pct'] = Variable<double>(expressSurchargePct);
    return map;
  }

  PricingSettingsCompanion toCompanion(bool nullToAbsent) {
    return PricingSettingsCompanion(
      id: Value(id),
      defaultRatePerKgUgx: Value(defaultRatePerKgUgx),
      updatedAt: Value(updatedAt),
      updatedBy: updatedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedBy),
      deliveryFeeUgx: Value(deliveryFeeUgx),
      expressSurchargeFlatUgx: Value(expressSurchargeFlatUgx),
      expressSurchargePct: Value(expressSurchargePct),
    );
  }

  factory PricingSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PricingSetting(
      id: serializer.fromJson<String>(json['id']),
      defaultRatePerKgUgx: serializer.fromJson<double>(
        json['defaultRatePerKgUgx'],
      ),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      updatedBy: serializer.fromJson<String?>(json['updatedBy']),
      deliveryFeeUgx: serializer.fromJson<int>(json['deliveryFeeUgx']),
      expressSurchargeFlatUgx: serializer.fromJson<int>(
        json['expressSurchargeFlatUgx'],
      ),
      expressSurchargePct: serializer.fromJson<double>(
        json['expressSurchargePct'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'defaultRatePerKgUgx': serializer.toJson<double>(defaultRatePerKgUgx),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'updatedBy': serializer.toJson<String?>(updatedBy),
      'deliveryFeeUgx': serializer.toJson<int>(deliveryFeeUgx),
      'expressSurchargeFlatUgx': serializer.toJson<int>(
        expressSurchargeFlatUgx,
      ),
      'expressSurchargePct': serializer.toJson<double>(expressSurchargePct),
    };
  }

  PricingSetting copyWith({
    String? id,
    double? defaultRatePerKgUgx,
    DateTime? updatedAt,
    Value<String?> updatedBy = const Value.absent(),
    int? deliveryFeeUgx,
    int? expressSurchargeFlatUgx,
    double? expressSurchargePct,
  }) => PricingSetting(
    id: id ?? this.id,
    defaultRatePerKgUgx: defaultRatePerKgUgx ?? this.defaultRatePerKgUgx,
    updatedAt: updatedAt ?? this.updatedAt,
    updatedBy: updatedBy.present ? updatedBy.value : this.updatedBy,
    deliveryFeeUgx: deliveryFeeUgx ?? this.deliveryFeeUgx,
    expressSurchargeFlatUgx:
        expressSurchargeFlatUgx ?? this.expressSurchargeFlatUgx,
    expressSurchargePct: expressSurchargePct ?? this.expressSurchargePct,
  );
  PricingSetting copyWithCompanion(PricingSettingsCompanion data) {
    return PricingSetting(
      id: data.id.present ? data.id.value : this.id,
      defaultRatePerKgUgx: data.defaultRatePerKgUgx.present
          ? data.defaultRatePerKgUgx.value
          : this.defaultRatePerKgUgx,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      deliveryFeeUgx: data.deliveryFeeUgx.present
          ? data.deliveryFeeUgx.value
          : this.deliveryFeeUgx,
      expressSurchargeFlatUgx: data.expressSurchargeFlatUgx.present
          ? data.expressSurchargeFlatUgx.value
          : this.expressSurchargeFlatUgx,
      expressSurchargePct: data.expressSurchargePct.present
          ? data.expressSurchargePct.value
          : this.expressSurchargePct,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PricingSetting(')
          ..write('id: $id, ')
          ..write('defaultRatePerKgUgx: $defaultRatePerKgUgx, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('deliveryFeeUgx: $deliveryFeeUgx, ')
          ..write('expressSurchargeFlatUgx: $expressSurchargeFlatUgx, ')
          ..write('expressSurchargePct: $expressSurchargePct')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    defaultRatePerKgUgx,
    updatedAt,
    updatedBy,
    deliveryFeeUgx,
    expressSurchargeFlatUgx,
    expressSurchargePct,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PricingSetting &&
          other.id == this.id &&
          other.defaultRatePerKgUgx == this.defaultRatePerKgUgx &&
          other.updatedAt == this.updatedAt &&
          other.updatedBy == this.updatedBy &&
          other.deliveryFeeUgx == this.deliveryFeeUgx &&
          other.expressSurchargeFlatUgx == this.expressSurchargeFlatUgx &&
          other.expressSurchargePct == this.expressSurchargePct);
}

class PricingSettingsCompanion extends UpdateCompanion<PricingSetting> {
  final Value<String> id;
  final Value<double> defaultRatePerKgUgx;
  final Value<DateTime> updatedAt;
  final Value<String?> updatedBy;
  final Value<int> deliveryFeeUgx;
  final Value<int> expressSurchargeFlatUgx;
  final Value<double> expressSurchargePct;
  final Value<int> rowid;
  const PricingSettingsCompanion({
    this.id = const Value.absent(),
    this.defaultRatePerKgUgx = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.deliveryFeeUgx = const Value.absent(),
    this.expressSurchargeFlatUgx = const Value.absent(),
    this.expressSurchargePct = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PricingSettingsCompanion.insert({
    required String id,
    required double defaultRatePerKgUgx,
    required DateTime updatedAt,
    this.updatedBy = const Value.absent(),
    this.deliveryFeeUgx = const Value.absent(),
    this.expressSurchargeFlatUgx = const Value.absent(),
    this.expressSurchargePct = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       defaultRatePerKgUgx = Value(defaultRatePerKgUgx),
       updatedAt = Value(updatedAt);
  static Insertable<PricingSetting> custom({
    Expression<String>? id,
    Expression<double>? defaultRatePerKgUgx,
    Expression<DateTime>? updatedAt,
    Expression<String>? updatedBy,
    Expression<int>? deliveryFeeUgx,
    Expression<int>? expressSurchargeFlatUgx,
    Expression<double>? expressSurchargePct,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (defaultRatePerKgUgx != null)
        'default_rate_per_kg_ugx': defaultRatePerKgUgx,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (deliveryFeeUgx != null) 'delivery_fee_ugx': deliveryFeeUgx,
      if (expressSurchargeFlatUgx != null)
        'express_surcharge_flat_ugx': expressSurchargeFlatUgx,
      if (expressSurchargePct != null)
        'express_surcharge_pct': expressSurchargePct,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PricingSettingsCompanion copyWith({
    Value<String>? id,
    Value<double>? defaultRatePerKgUgx,
    Value<DateTime>? updatedAt,
    Value<String?>? updatedBy,
    Value<int>? deliveryFeeUgx,
    Value<int>? expressSurchargeFlatUgx,
    Value<double>? expressSurchargePct,
    Value<int>? rowid,
  }) {
    return PricingSettingsCompanion(
      id: id ?? this.id,
      defaultRatePerKgUgx: defaultRatePerKgUgx ?? this.defaultRatePerKgUgx,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      deliveryFeeUgx: deliveryFeeUgx ?? this.deliveryFeeUgx,
      expressSurchargeFlatUgx:
          expressSurchargeFlatUgx ?? this.expressSurchargeFlatUgx,
      expressSurchargePct: expressSurchargePct ?? this.expressSurchargePct,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (defaultRatePerKgUgx.present) {
      map['default_rate_per_kg_ugx'] = Variable<double>(
        defaultRatePerKgUgx.value,
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<String>(updatedBy.value);
    }
    if (deliveryFeeUgx.present) {
      map['delivery_fee_ugx'] = Variable<int>(deliveryFeeUgx.value);
    }
    if (expressSurchargeFlatUgx.present) {
      map['express_surcharge_flat_ugx'] = Variable<int>(
        expressSurchargeFlatUgx.value,
      );
    }
    if (expressSurchargePct.present) {
      map['express_surcharge_pct'] = Variable<double>(
        expressSurchargePct.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PricingSettingsCompanion(')
          ..write('id: $id, ')
          ..write('defaultRatePerKgUgx: $defaultRatePerKgUgx, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('deliveryFeeUgx: $deliveryFeeUgx, ')
          ..write('expressSurchargeFlatUgx: $expressSurchargeFlatUgx, ')
          ..write('expressSurchargePct: $expressSurchargePct, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PricingCatalogItemsTable extends PricingCatalogItems
    with TableInfo<$PricingCatalogItemsTable, PricingCatalogItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PricingCatalogItemsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _amountUgxMeta = const VerificationMeta(
    'amountUgx',
  );
  @override
  late final GeneratedColumn<int> amountUgx = GeneratedColumn<int>(
    'amount_ugx',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    amountUgx,
    active,
    sortOrder,
    category,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pricing_catalog_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<PricingCatalogItem> instance, {
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
    if (data.containsKey('amount_ugx')) {
      context.handle(
        _amountUgxMeta,
        amountUgx.isAcceptableOrUnknown(data['amount_ugx']!, _amountUgxMeta),
      );
    } else if (isInserting) {
      context.missing(_amountUgxMeta);
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PricingCatalogItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PricingCatalogItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      amountUgx: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_ugx'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
    );
  }

  @override
  $PricingCatalogItemsTable createAlias(String alias) {
    return $PricingCatalogItemsTable(attachedDatabase, alias);
  }
}

class PricingCatalogItem extends DataClass
    implements Insertable<PricingCatalogItem> {
  final String id;
  final String name;
  final int amountUgx;
  final bool active;
  final int sortOrder;
  final String? category;
  const PricingCatalogItem({
    required this.id,
    required this.name,
    required this.amountUgx,
    required this.active,
    required this.sortOrder,
    this.category,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['amount_ugx'] = Variable<int>(amountUgx);
    map['active'] = Variable<bool>(active);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    return map;
  }

  PricingCatalogItemsCompanion toCompanion(bool nullToAbsent) {
    return PricingCatalogItemsCompanion(
      id: Value(id),
      name: Value(name),
      amountUgx: Value(amountUgx),
      active: Value(active),
      sortOrder: Value(sortOrder),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
    );
  }

  factory PricingCatalogItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PricingCatalogItem(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      amountUgx: serializer.fromJson<int>(json['amountUgx']),
      active: serializer.fromJson<bool>(json['active']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      category: serializer.fromJson<String?>(json['category']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'amountUgx': serializer.toJson<int>(amountUgx),
      'active': serializer.toJson<bool>(active),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'category': serializer.toJson<String?>(category),
    };
  }

  PricingCatalogItem copyWith({
    String? id,
    String? name,
    int? amountUgx,
    bool? active,
    int? sortOrder,
    Value<String?> category = const Value.absent(),
  }) => PricingCatalogItem(
    id: id ?? this.id,
    name: name ?? this.name,
    amountUgx: amountUgx ?? this.amountUgx,
    active: active ?? this.active,
    sortOrder: sortOrder ?? this.sortOrder,
    category: category.present ? category.value : this.category,
  );
  PricingCatalogItem copyWithCompanion(PricingCatalogItemsCompanion data) {
    return PricingCatalogItem(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      amountUgx: data.amountUgx.present ? data.amountUgx.value : this.amountUgx,
      active: data.active.present ? data.active.value : this.active,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      category: data.category.present ? data.category.value : this.category,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PricingCatalogItem(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('amountUgx: $amountUgx, ')
          ..write('active: $active, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('category: $category')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, amountUgx, active, sortOrder, category);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PricingCatalogItem &&
          other.id == this.id &&
          other.name == this.name &&
          other.amountUgx == this.amountUgx &&
          other.active == this.active &&
          other.sortOrder == this.sortOrder &&
          other.category == this.category);
}

class PricingCatalogItemsCompanion extends UpdateCompanion<PricingCatalogItem> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> amountUgx;
  final Value<bool> active;
  final Value<int> sortOrder;
  final Value<String?> category;
  final Value<int> rowid;
  const PricingCatalogItemsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.amountUgx = const Value.absent(),
    this.active = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.category = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PricingCatalogItemsCompanion.insert({
    required String id,
    required String name,
    required int amountUgx,
    this.active = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.category = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       amountUgx = Value(amountUgx);
  static Insertable<PricingCatalogItem> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? amountUgx,
    Expression<bool>? active,
    Expression<int>? sortOrder,
    Expression<String>? category,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (amountUgx != null) 'amount_ugx': amountUgx,
      if (active != null) 'active': active,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (category != null) 'category': category,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PricingCatalogItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? amountUgx,
    Value<bool>? active,
    Value<int>? sortOrder,
    Value<String?>? category,
    Value<int>? rowid,
  }) {
    return PricingCatalogItemsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      amountUgx: amountUgx ?? this.amountUgx,
      active: active ?? this.active,
      sortOrder: sortOrder ?? this.sortOrder,
      category: category ?? this.category,
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
    if (amountUgx.present) {
      map['amount_ugx'] = Variable<int>(amountUgx.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PricingCatalogItemsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('amountUgx: $amountUgx, ')
          ..write('active: $active, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('category: $category, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $StaffTable staff = $StaffTable(this);
  late final $CustomersTable customers = $CustomersTable(this);
  late final $OrdersTable orders = $OrdersTable(this);
  late final $OrderStatusEventsTable orderStatusEvents =
      $OrderStatusEventsTable(this);
  late final $ProofEventsTable proofEvents = $ProofEventsTable(this);
  late final $ProofPhotosTable proofPhotos = $ProofPhotosTable(this);
  late final $IssuesTable issues = $IssuesTable(this);
  late final $ShiftsTable shifts = $ShiftsTable(this);
  late final $ValidTransitionsTable validTransitions = $ValidTransitionsTable(
    this,
  );
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $SyncWatermarksTable syncWatermarks = $SyncWatermarksTable(this);
  late final $PullDeadLetterTable pullDeadLetter = $PullDeadLetterTable(this);
  late final $PricingSettingsTable pricingSettings = $PricingSettingsTable(
    this,
  );
  late final $PricingCatalogItemsTable pricingCatalogItems =
      $PricingCatalogItemsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    staff,
    customers,
    orders,
    orderStatusEvents,
    proofEvents,
    proofPhotos,
    issues,
    shifts,
    validTransitions,
    outbox,
    syncWatermarks,
    pullDeadLetter,
    pricingSettings,
    pricingCatalogItems,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$StaffTableCreateCompanionBuilder =
    StaffCompanion Function({
      required String id,
      required String username,
      required String displayName,
      Value<String?> phone,
      required String role,
      Value<bool> active,
      Value<bool> mustChangePin,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$StaffTableUpdateCompanionBuilder =
    StaffCompanion Function({
      Value<String> id,
      Value<String> username,
      Value<String> displayName,
      Value<String?> phone,
      Value<String> role,
      Value<bool> active,
      Value<bool> mustChangePin,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$StaffTableFilterComposer extends Composer<_$AppDatabase, $StaffTable> {
  $$StaffTableFilterComposer({
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

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get mustChangePin => $composableBuilder(
    column: $table.mustChangePin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StaffTableOrderingComposer
    extends Composer<_$AppDatabase, $StaffTable> {
  $$StaffTableOrderingComposer({
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

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get mustChangePin => $composableBuilder(
    column: $table.mustChangePin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StaffTableAnnotationComposer
    extends Composer<_$AppDatabase, $StaffTable> {
  $$StaffTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<bool> get mustChangePin => $composableBuilder(
    column: $table.mustChangePin,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$StaffTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StaffTable,
          StaffData,
          $$StaffTableFilterComposer,
          $$StaffTableOrderingComposer,
          $$StaffTableAnnotationComposer,
          $$StaffTableCreateCompanionBuilder,
          $$StaffTableUpdateCompanionBuilder,
          (StaffData, BaseReferences<_$AppDatabase, $StaffTable, StaffData>),
          StaffData,
          PrefetchHooks Function()
        > {
  $$StaffTableTableManager(_$AppDatabase db, $StaffTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StaffTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StaffTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StaffTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> username = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<bool> mustChangePin = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StaffCompanion(
                id: id,
                username: username,
                displayName: displayName,
                phone: phone,
                role: role,
                active: active,
                mustChangePin: mustChangePin,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String username,
                required String displayName,
                Value<String?> phone = const Value.absent(),
                required String role,
                Value<bool> active = const Value.absent(),
                Value<bool> mustChangePin = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StaffCompanion.insert(
                id: id,
                username: username,
                displayName: displayName,
                phone: phone,
                role: role,
                active: active,
                mustChangePin: mustChangePin,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StaffTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StaffTable,
      StaffData,
      $$StaffTableFilterComposer,
      $$StaffTableOrderingComposer,
      $$StaffTableAnnotationComposer,
      $$StaffTableCreateCompanionBuilder,
      $$StaffTableUpdateCompanionBuilder,
      (StaffData, BaseReferences<_$AppDatabase, $StaffTable, StaffData>),
      StaffData,
      PrefetchHooks Function()
    >;
typedef $$CustomersTableCreateCompanionBuilder =
    CustomersCompanion Function({
      required String id,
      required String name,
      required String phone,
      Value<String?> address,
      Value<String?> notes,
      Value<double?> customRatePerKgUgx,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$CustomersTableUpdateCompanionBuilder =
    CustomersCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> phone,
      Value<String?> address,
      Value<String?> notes,
      Value<double?> customRatePerKgUgx,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$CustomersTableFilterComposer
    extends Composer<_$AppDatabase, $CustomersTable> {
  $$CustomersTableFilterComposer({
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

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get customRatePerKgUgx => $composableBuilder(
    column: $table.customRatePerKgUgx,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CustomersTableOrderingComposer
    extends Composer<_$AppDatabase, $CustomersTable> {
  $$CustomersTableOrderingComposer({
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

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get customRatePerKgUgx => $composableBuilder(
    column: $table.customRatePerKgUgx,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CustomersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CustomersTable> {
  $$CustomersTableAnnotationComposer({
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

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<double> get customRatePerKgUgx => $composableBuilder(
    column: $table.customRatePerKgUgx,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$CustomersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CustomersTable,
          Customer,
          $$CustomersTableFilterComposer,
          $$CustomersTableOrderingComposer,
          $$CustomersTableAnnotationComposer,
          $$CustomersTableCreateCompanionBuilder,
          $$CustomersTableUpdateCompanionBuilder,
          (Customer, BaseReferences<_$AppDatabase, $CustomersTable, Customer>),
          Customer,
          PrefetchHooks Function()
        > {
  $$CustomersTableTableManager(_$AppDatabase db, $CustomersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CustomersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CustomersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> phone = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<double?> customRatePerKgUgx = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomersCompanion(
                id: id,
                name: name,
                phone: phone,
                address: address,
                notes: notes,
                customRatePerKgUgx: customRatePerKgUgx,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String phone,
                Value<String?> address = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<double?> customRatePerKgUgx = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomersCompanion.insert(
                id: id,
                name: name,
                phone: phone,
                address: address,
                notes: notes,
                customRatePerKgUgx: customRatePerKgUgx,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CustomersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CustomersTable,
      Customer,
      $$CustomersTableFilterComposer,
      $$CustomersTableOrderingComposer,
      $$CustomersTableAnnotationComposer,
      $$CustomersTableCreateCompanionBuilder,
      $$CustomersTableUpdateCompanionBuilder,
      (Customer, BaseReferences<_$AppDatabase, $CustomersTable, Customer>),
      Customer,
      PrefetchHooks Function()
    >;
typedef $$OrdersTableCreateCompanionBuilder =
    OrdersCompanion Function({
      required String id,
      required String orderCode,
      Value<String?> customerId,
      required String customerName,
      required String phone,
      required String address,
      required String serviceType,
      required String status,
      required String intakeMethod,
      required String fulfillmentMethod,
      required int itemCount,
      Value<String> notes,
      Value<DateTime?> scheduledFor,
      Value<DateTime?> expectedCollectionAt,
      Value<String?> assignedDriver,
      required String intakeRecordedBy,
      required String createdBy,
      Value<String?> updatedBy,
      Value<String?> deletedBy,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<double> ratePerKgSnapshotUgx,
      Value<double?> estimatedWeightKg,
      Value<double?> finalWeightKg,
      Value<String> lineItems,
      Value<int> manualAdjustmentUgx,
      Value<int> totalUgx,
      Value<int> deliveryFeeSnapshotUgx,
      Value<bool> isExpress,
      Value<int> expressFlatSnapshotUgx,
      Value<double> expressPctSnapshot,
      Value<int> paymentAmountUgx,
      Value<String> cartItems,
      Value<int> rowid,
    });
typedef $$OrdersTableUpdateCompanionBuilder =
    OrdersCompanion Function({
      Value<String> id,
      Value<String> orderCode,
      Value<String?> customerId,
      Value<String> customerName,
      Value<String> phone,
      Value<String> address,
      Value<String> serviceType,
      Value<String> status,
      Value<String> intakeMethod,
      Value<String> fulfillmentMethod,
      Value<int> itemCount,
      Value<String> notes,
      Value<DateTime?> scheduledFor,
      Value<DateTime?> expectedCollectionAt,
      Value<String?> assignedDriver,
      Value<String> intakeRecordedBy,
      Value<String> createdBy,
      Value<String?> updatedBy,
      Value<String?> deletedBy,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<double> ratePerKgSnapshotUgx,
      Value<double?> estimatedWeightKg,
      Value<double?> finalWeightKg,
      Value<String> lineItems,
      Value<int> manualAdjustmentUgx,
      Value<int> totalUgx,
      Value<int> deliveryFeeSnapshotUgx,
      Value<bool> isExpress,
      Value<int> expressFlatSnapshotUgx,
      Value<double> expressPctSnapshot,
      Value<int> paymentAmountUgx,
      Value<String> cartItems,
      Value<int> rowid,
    });

class $$OrdersTableFilterComposer
    extends Composer<_$AppDatabase, $OrdersTable> {
  $$OrdersTableFilterComposer({
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

  ColumnFilters<String> get orderCode => $composableBuilder(
    column: $table.orderCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serviceType => $composableBuilder(
    column: $table.serviceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get intakeMethod => $composableBuilder(
    column: $table.intakeMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fulfillmentMethod => $composableBuilder(
    column: $table.fulfillmentMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get itemCount => $composableBuilder(
    column: $table.itemCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scheduledFor => $composableBuilder(
    column: $table.scheduledFor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expectedCollectionAt => $composableBuilder(
    column: $table.expectedCollectionAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assignedDriver => $composableBuilder(
    column: $table.assignedDriver,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get intakeRecordedBy => $composableBuilder(
    column: $table.intakeRecordedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedBy => $composableBuilder(
    column: $table.deletedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get ratePerKgSnapshotUgx => $composableBuilder(
    column: $table.ratePerKgSnapshotUgx,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get estimatedWeightKg => $composableBuilder(
    column: $table.estimatedWeightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get finalWeightKg => $composableBuilder(
    column: $table.finalWeightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lineItems => $composableBuilder(
    column: $table.lineItems,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get manualAdjustmentUgx => $composableBuilder(
    column: $table.manualAdjustmentUgx,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalUgx => $composableBuilder(
    column: $table.totalUgx,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deliveryFeeSnapshotUgx => $composableBuilder(
    column: $table.deliveryFeeSnapshotUgx,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isExpress => $composableBuilder(
    column: $table.isExpress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expressFlatSnapshotUgx => $composableBuilder(
    column: $table.expressFlatSnapshotUgx,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get expressPctSnapshot => $composableBuilder(
    column: $table.expressPctSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paymentAmountUgx => $composableBuilder(
    column: $table.paymentAmountUgx,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cartItems => $composableBuilder(
    column: $table.cartItems,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OrdersTableOrderingComposer
    extends Composer<_$AppDatabase, $OrdersTable> {
  $$OrdersTableOrderingComposer({
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

  ColumnOrderings<String> get orderCode => $composableBuilder(
    column: $table.orderCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serviceType => $composableBuilder(
    column: $table.serviceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get intakeMethod => $composableBuilder(
    column: $table.intakeMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fulfillmentMethod => $composableBuilder(
    column: $table.fulfillmentMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get itemCount => $composableBuilder(
    column: $table.itemCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scheduledFor => $composableBuilder(
    column: $table.scheduledFor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expectedCollectionAt => $composableBuilder(
    column: $table.expectedCollectionAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assignedDriver => $composableBuilder(
    column: $table.assignedDriver,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get intakeRecordedBy => $composableBuilder(
    column: $table.intakeRecordedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedBy => $composableBuilder(
    column: $table.deletedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ratePerKgSnapshotUgx => $composableBuilder(
    column: $table.ratePerKgSnapshotUgx,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get estimatedWeightKg => $composableBuilder(
    column: $table.estimatedWeightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get finalWeightKg => $composableBuilder(
    column: $table.finalWeightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lineItems => $composableBuilder(
    column: $table.lineItems,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get manualAdjustmentUgx => $composableBuilder(
    column: $table.manualAdjustmentUgx,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalUgx => $composableBuilder(
    column: $table.totalUgx,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deliveryFeeSnapshotUgx => $composableBuilder(
    column: $table.deliveryFeeSnapshotUgx,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isExpress => $composableBuilder(
    column: $table.isExpress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expressFlatSnapshotUgx => $composableBuilder(
    column: $table.expressFlatSnapshotUgx,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get expressPctSnapshot => $composableBuilder(
    column: $table.expressPctSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paymentAmountUgx => $composableBuilder(
    column: $table.paymentAmountUgx,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cartItems => $composableBuilder(
    column: $table.cartItems,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OrdersTableAnnotationComposer
    extends Composer<_$AppDatabase, $OrdersTable> {
  $$OrdersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get orderCode =>
      $composableBuilder(column: $table.orderCode, builder: (column) => column);

  GeneratedColumn<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get serviceType => $composableBuilder(
    column: $table.serviceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get intakeMethod => $composableBuilder(
    column: $table.intakeMethod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fulfillmentMethod => $composableBuilder(
    column: $table.fulfillmentMethod,
    builder: (column) => column,
  );

  GeneratedColumn<int> get itemCount =>
      $composableBuilder(column: $table.itemCount, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get scheduledFor => $composableBuilder(
    column: $table.scheduledFor,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get expectedCollectionAt => $composableBuilder(
    column: $table.expectedCollectionAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get assignedDriver => $composableBuilder(
    column: $table.assignedDriver,
    builder: (column) => column,
  );

  GeneratedColumn<String> get intakeRecordedBy => $composableBuilder(
    column: $table.intakeRecordedBy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumn<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<double> get ratePerKgSnapshotUgx => $composableBuilder(
    column: $table.ratePerKgSnapshotUgx,
    builder: (column) => column,
  );

  GeneratedColumn<double> get estimatedWeightKg => $composableBuilder(
    column: $table.estimatedWeightKg,
    builder: (column) => column,
  );

  GeneratedColumn<double> get finalWeightKg => $composableBuilder(
    column: $table.finalWeightKg,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lineItems =>
      $composableBuilder(column: $table.lineItems, builder: (column) => column);

  GeneratedColumn<int> get manualAdjustmentUgx => $composableBuilder(
    column: $table.manualAdjustmentUgx,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalUgx =>
      $composableBuilder(column: $table.totalUgx, builder: (column) => column);

  GeneratedColumn<int> get deliveryFeeSnapshotUgx => $composableBuilder(
    column: $table.deliveryFeeSnapshotUgx,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isExpress =>
      $composableBuilder(column: $table.isExpress, builder: (column) => column);

  GeneratedColumn<int> get expressFlatSnapshotUgx => $composableBuilder(
    column: $table.expressFlatSnapshotUgx,
    builder: (column) => column,
  );

  GeneratedColumn<double> get expressPctSnapshot => $composableBuilder(
    column: $table.expressPctSnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<int> get paymentAmountUgx => $composableBuilder(
    column: $table.paymentAmountUgx,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cartItems =>
      $composableBuilder(column: $table.cartItems, builder: (column) => column);
}

class $$OrdersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OrdersTable,
          Order,
          $$OrdersTableFilterComposer,
          $$OrdersTableOrderingComposer,
          $$OrdersTableAnnotationComposer,
          $$OrdersTableCreateCompanionBuilder,
          $$OrdersTableUpdateCompanionBuilder,
          (Order, BaseReferences<_$AppDatabase, $OrdersTable, Order>),
          Order,
          PrefetchHooks Function()
        > {
  $$OrdersTableTableManager(_$AppDatabase db, $OrdersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OrdersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OrdersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OrdersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> orderCode = const Value.absent(),
                Value<String?> customerId = const Value.absent(),
                Value<String> customerName = const Value.absent(),
                Value<String> phone = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<String> serviceType = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> intakeMethod = const Value.absent(),
                Value<String> fulfillmentMethod = const Value.absent(),
                Value<int> itemCount = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<DateTime?> scheduledFor = const Value.absent(),
                Value<DateTime?> expectedCollectionAt = const Value.absent(),
                Value<String?> assignedDriver = const Value.absent(),
                Value<String> intakeRecordedBy = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<String?> updatedBy = const Value.absent(),
                Value<String?> deletedBy = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<double> ratePerKgSnapshotUgx = const Value.absent(),
                Value<double?> estimatedWeightKg = const Value.absent(),
                Value<double?> finalWeightKg = const Value.absent(),
                Value<String> lineItems = const Value.absent(),
                Value<int> manualAdjustmentUgx = const Value.absent(),
                Value<int> totalUgx = const Value.absent(),
                Value<int> deliveryFeeSnapshotUgx = const Value.absent(),
                Value<bool> isExpress = const Value.absent(),
                Value<int> expressFlatSnapshotUgx = const Value.absent(),
                Value<double> expressPctSnapshot = const Value.absent(),
                Value<int> paymentAmountUgx = const Value.absent(),
                Value<String> cartItems = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OrdersCompanion(
                id: id,
                orderCode: orderCode,
                customerId: customerId,
                customerName: customerName,
                phone: phone,
                address: address,
                serviceType: serviceType,
                status: status,
                intakeMethod: intakeMethod,
                fulfillmentMethod: fulfillmentMethod,
                itemCount: itemCount,
                notes: notes,
                scheduledFor: scheduledFor,
                expectedCollectionAt: expectedCollectionAt,
                assignedDriver: assignedDriver,
                intakeRecordedBy: intakeRecordedBy,
                createdBy: createdBy,
                updatedBy: updatedBy,
                deletedBy: deletedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                ratePerKgSnapshotUgx: ratePerKgSnapshotUgx,
                estimatedWeightKg: estimatedWeightKg,
                finalWeightKg: finalWeightKg,
                lineItems: lineItems,
                manualAdjustmentUgx: manualAdjustmentUgx,
                totalUgx: totalUgx,
                deliveryFeeSnapshotUgx: deliveryFeeSnapshotUgx,
                isExpress: isExpress,
                expressFlatSnapshotUgx: expressFlatSnapshotUgx,
                expressPctSnapshot: expressPctSnapshot,
                paymentAmountUgx: paymentAmountUgx,
                cartItems: cartItems,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String orderCode,
                Value<String?> customerId = const Value.absent(),
                required String customerName,
                required String phone,
                required String address,
                required String serviceType,
                required String status,
                required String intakeMethod,
                required String fulfillmentMethod,
                required int itemCount,
                Value<String> notes = const Value.absent(),
                Value<DateTime?> scheduledFor = const Value.absent(),
                Value<DateTime?> expectedCollectionAt = const Value.absent(),
                Value<String?> assignedDriver = const Value.absent(),
                required String intakeRecordedBy,
                required String createdBy,
                Value<String?> updatedBy = const Value.absent(),
                Value<String?> deletedBy = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<double> ratePerKgSnapshotUgx = const Value.absent(),
                Value<double?> estimatedWeightKg = const Value.absent(),
                Value<double?> finalWeightKg = const Value.absent(),
                Value<String> lineItems = const Value.absent(),
                Value<int> manualAdjustmentUgx = const Value.absent(),
                Value<int> totalUgx = const Value.absent(),
                Value<int> deliveryFeeSnapshotUgx = const Value.absent(),
                Value<bool> isExpress = const Value.absent(),
                Value<int> expressFlatSnapshotUgx = const Value.absent(),
                Value<double> expressPctSnapshot = const Value.absent(),
                Value<int> paymentAmountUgx = const Value.absent(),
                Value<String> cartItems = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OrdersCompanion.insert(
                id: id,
                orderCode: orderCode,
                customerId: customerId,
                customerName: customerName,
                phone: phone,
                address: address,
                serviceType: serviceType,
                status: status,
                intakeMethod: intakeMethod,
                fulfillmentMethod: fulfillmentMethod,
                itemCount: itemCount,
                notes: notes,
                scheduledFor: scheduledFor,
                expectedCollectionAt: expectedCollectionAt,
                assignedDriver: assignedDriver,
                intakeRecordedBy: intakeRecordedBy,
                createdBy: createdBy,
                updatedBy: updatedBy,
                deletedBy: deletedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                ratePerKgSnapshotUgx: ratePerKgSnapshotUgx,
                estimatedWeightKg: estimatedWeightKg,
                finalWeightKg: finalWeightKg,
                lineItems: lineItems,
                manualAdjustmentUgx: manualAdjustmentUgx,
                totalUgx: totalUgx,
                deliveryFeeSnapshotUgx: deliveryFeeSnapshotUgx,
                isExpress: isExpress,
                expressFlatSnapshotUgx: expressFlatSnapshotUgx,
                expressPctSnapshot: expressPctSnapshot,
                paymentAmountUgx: paymentAmountUgx,
                cartItems: cartItems,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OrdersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OrdersTable,
      Order,
      $$OrdersTableFilterComposer,
      $$OrdersTableOrderingComposer,
      $$OrdersTableAnnotationComposer,
      $$OrdersTableCreateCompanionBuilder,
      $$OrdersTableUpdateCompanionBuilder,
      (Order, BaseReferences<_$AppDatabase, $OrdersTable, Order>),
      Order,
      PrefetchHooks Function()
    >;
typedef $$OrderStatusEventsTableCreateCompanionBuilder =
    OrderStatusEventsCompanion Function({
      required String id,
      required String orderId,
      Value<String?> fromStatus,
      required String toStatus,
      required String changedBy,
      required DateTime changedAt,
      required String source,
      Value<String?> deviceEventId,
      Value<int> rowid,
    });
typedef $$OrderStatusEventsTableUpdateCompanionBuilder =
    OrderStatusEventsCompanion Function({
      Value<String> id,
      Value<String> orderId,
      Value<String?> fromStatus,
      Value<String> toStatus,
      Value<String> changedBy,
      Value<DateTime> changedAt,
      Value<String> source,
      Value<String?> deviceEventId,
      Value<int> rowid,
    });

class $$OrderStatusEventsTableFilterComposer
    extends Composer<_$AppDatabase, $OrderStatusEventsTable> {
  $$OrderStatusEventsTableFilterComposer({
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

  ColumnFilters<String> get orderId => $composableBuilder(
    column: $table.orderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromStatus => $composableBuilder(
    column: $table.fromStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toStatus => $composableBuilder(
    column: $table.toStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get changedBy => $composableBuilder(
    column: $table.changedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get changedAt => $composableBuilder(
    column: $table.changedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceEventId => $composableBuilder(
    column: $table.deviceEventId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OrderStatusEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $OrderStatusEventsTable> {
  $$OrderStatusEventsTableOrderingComposer({
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

  ColumnOrderings<String> get orderId => $composableBuilder(
    column: $table.orderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromStatus => $composableBuilder(
    column: $table.fromStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toStatus => $composableBuilder(
    column: $table.toStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get changedBy => $composableBuilder(
    column: $table.changedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get changedAt => $composableBuilder(
    column: $table.changedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceEventId => $composableBuilder(
    column: $table.deviceEventId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OrderStatusEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OrderStatusEventsTable> {
  $$OrderStatusEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get orderId =>
      $composableBuilder(column: $table.orderId, builder: (column) => column);

  GeneratedColumn<String> get fromStatus => $composableBuilder(
    column: $table.fromStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get toStatus =>
      $composableBuilder(column: $table.toStatus, builder: (column) => column);

  GeneratedColumn<String> get changedBy =>
      $composableBuilder(column: $table.changedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get changedAt =>
      $composableBuilder(column: $table.changedAt, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get deviceEventId => $composableBuilder(
    column: $table.deviceEventId,
    builder: (column) => column,
  );
}

class $$OrderStatusEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OrderStatusEventsTable,
          OrderStatusEvent,
          $$OrderStatusEventsTableFilterComposer,
          $$OrderStatusEventsTableOrderingComposer,
          $$OrderStatusEventsTableAnnotationComposer,
          $$OrderStatusEventsTableCreateCompanionBuilder,
          $$OrderStatusEventsTableUpdateCompanionBuilder,
          (
            OrderStatusEvent,
            BaseReferences<
              _$AppDatabase,
              $OrderStatusEventsTable,
              OrderStatusEvent
            >,
          ),
          OrderStatusEvent,
          PrefetchHooks Function()
        > {
  $$OrderStatusEventsTableTableManager(
    _$AppDatabase db,
    $OrderStatusEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OrderStatusEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OrderStatusEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OrderStatusEventsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> orderId = const Value.absent(),
                Value<String?> fromStatus = const Value.absent(),
                Value<String> toStatus = const Value.absent(),
                Value<String> changedBy = const Value.absent(),
                Value<DateTime> changedAt = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> deviceEventId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OrderStatusEventsCompanion(
                id: id,
                orderId: orderId,
                fromStatus: fromStatus,
                toStatus: toStatus,
                changedBy: changedBy,
                changedAt: changedAt,
                source: source,
                deviceEventId: deviceEventId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String orderId,
                Value<String?> fromStatus = const Value.absent(),
                required String toStatus,
                required String changedBy,
                required DateTime changedAt,
                required String source,
                Value<String?> deviceEventId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OrderStatusEventsCompanion.insert(
                id: id,
                orderId: orderId,
                fromStatus: fromStatus,
                toStatus: toStatus,
                changedBy: changedBy,
                changedAt: changedAt,
                source: source,
                deviceEventId: deviceEventId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OrderStatusEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OrderStatusEventsTable,
      OrderStatusEvent,
      $$OrderStatusEventsTableFilterComposer,
      $$OrderStatusEventsTableOrderingComposer,
      $$OrderStatusEventsTableAnnotationComposer,
      $$OrderStatusEventsTableCreateCompanionBuilder,
      $$OrderStatusEventsTableUpdateCompanionBuilder,
      (
        OrderStatusEvent,
        BaseReferences<
          _$AppDatabase,
          $OrderStatusEventsTable,
          OrderStatusEvent
        >,
      ),
      OrderStatusEvent,
      PrefetchHooks Function()
    >;
typedef $$ProofEventsTableCreateCompanionBuilder =
    ProofEventsCompanion Function({
      required String id,
      required String orderId,
      required String type,
      required DateTime capturedAt,
      required int itemCount,
      Value<String?> notes,
      required String capturedBy,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$ProofEventsTableUpdateCompanionBuilder =
    ProofEventsCompanion Function({
      Value<String> id,
      Value<String> orderId,
      Value<String> type,
      Value<DateTime> capturedAt,
      Value<int> itemCount,
      Value<String?> notes,
      Value<String> capturedBy,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$ProofEventsTableFilterComposer
    extends Composer<_$AppDatabase, $ProofEventsTable> {
  $$ProofEventsTableFilterComposer({
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

  ColumnFilters<String> get orderId => $composableBuilder(
    column: $table.orderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get itemCount => $composableBuilder(
    column: $table.itemCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capturedBy => $composableBuilder(
    column: $table.capturedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProofEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProofEventsTable> {
  $$ProofEventsTableOrderingComposer({
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

  ColumnOrderings<String> get orderId => $composableBuilder(
    column: $table.orderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get itemCount => $composableBuilder(
    column: $table.itemCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capturedBy => $composableBuilder(
    column: $table.capturedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProofEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProofEventsTable> {
  $$ProofEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get orderId =>
      $composableBuilder(column: $table.orderId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get itemCount =>
      $composableBuilder(column: $table.itemCount, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get capturedBy => $composableBuilder(
    column: $table.capturedBy,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$ProofEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProofEventsTable,
          ProofEvent,
          $$ProofEventsTableFilterComposer,
          $$ProofEventsTableOrderingComposer,
          $$ProofEventsTableAnnotationComposer,
          $$ProofEventsTableCreateCompanionBuilder,
          $$ProofEventsTableUpdateCompanionBuilder,
          (
            ProofEvent,
            BaseReferences<_$AppDatabase, $ProofEventsTable, ProofEvent>,
          ),
          ProofEvent,
          PrefetchHooks Function()
        > {
  $$ProofEventsTableTableManager(_$AppDatabase db, $ProofEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProofEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProofEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProofEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> orderId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<DateTime> capturedAt = const Value.absent(),
                Value<int> itemCount = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> capturedBy = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProofEventsCompanion(
                id: id,
                orderId: orderId,
                type: type,
                capturedAt: capturedAt,
                itemCount: itemCount,
                notes: notes,
                capturedBy: capturedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String orderId,
                required String type,
                required DateTime capturedAt,
                required int itemCount,
                Value<String?> notes = const Value.absent(),
                required String capturedBy,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProofEventsCompanion.insert(
                id: id,
                orderId: orderId,
                type: type,
                capturedAt: capturedAt,
                itemCount: itemCount,
                notes: notes,
                capturedBy: capturedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProofEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProofEventsTable,
      ProofEvent,
      $$ProofEventsTableFilterComposer,
      $$ProofEventsTableOrderingComposer,
      $$ProofEventsTableAnnotationComposer,
      $$ProofEventsTableCreateCompanionBuilder,
      $$ProofEventsTableUpdateCompanionBuilder,
      (
        ProofEvent,
        BaseReferences<_$AppDatabase, $ProofEventsTable, ProofEvent>,
      ),
      ProofEvent,
      PrefetchHooks Function()
    >;
typedef $$ProofPhotosTableCreateCompanionBuilder =
    ProofPhotosCompanion Function({
      required String id,
      required String proofEventId,
      required String storagePath,
      Value<int?> width,
      Value<int?> height,
      Value<int?> bytes,
      Value<DateTime?> uploadedAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ProofPhotosTableUpdateCompanionBuilder =
    ProofPhotosCompanion Function({
      Value<String> id,
      Value<String> proofEventId,
      Value<String> storagePath,
      Value<int?> width,
      Value<int?> height,
      Value<int?> bytes,
      Value<DateTime?> uploadedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$ProofPhotosTableFilterComposer
    extends Composer<_$AppDatabase, $ProofPhotosTable> {
  $$ProofPhotosTableFilterComposer({
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

  ColumnFilters<String> get proofEventId => $composableBuilder(
    column: $table.proofEventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storagePath => $composableBuilder(
    column: $table.storagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get uploadedAt => $composableBuilder(
    column: $table.uploadedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProofPhotosTableOrderingComposer
    extends Composer<_$AppDatabase, $ProofPhotosTable> {
  $$ProofPhotosTableOrderingComposer({
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

  ColumnOrderings<String> get proofEventId => $composableBuilder(
    column: $table.proofEventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storagePath => $composableBuilder(
    column: $table.storagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get uploadedAt => $composableBuilder(
    column: $table.uploadedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProofPhotosTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProofPhotosTable> {
  $$ProofPhotosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get proofEventId => $composableBuilder(
    column: $table.proofEventId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get storagePath => $composableBuilder(
    column: $table.storagePath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<int> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<DateTime> get uploadedAt => $composableBuilder(
    column: $table.uploadedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ProofPhotosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProofPhotosTable,
          ProofPhoto,
          $$ProofPhotosTableFilterComposer,
          $$ProofPhotosTableOrderingComposer,
          $$ProofPhotosTableAnnotationComposer,
          $$ProofPhotosTableCreateCompanionBuilder,
          $$ProofPhotosTableUpdateCompanionBuilder,
          (
            ProofPhoto,
            BaseReferences<_$AppDatabase, $ProofPhotosTable, ProofPhoto>,
          ),
          ProofPhoto,
          PrefetchHooks Function()
        > {
  $$ProofPhotosTableTableManager(_$AppDatabase db, $ProofPhotosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProofPhotosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProofPhotosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProofPhotosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> proofEventId = const Value.absent(),
                Value<String> storagePath = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<int?> bytes = const Value.absent(),
                Value<DateTime?> uploadedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProofPhotosCompanion(
                id: id,
                proofEventId: proofEventId,
                storagePath: storagePath,
                width: width,
                height: height,
                bytes: bytes,
                uploadedAt: uploadedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String proofEventId,
                required String storagePath,
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<int?> bytes = const Value.absent(),
                Value<DateTime?> uploadedAt = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ProofPhotosCompanion.insert(
                id: id,
                proofEventId: proofEventId,
                storagePath: storagePath,
                width: width,
                height: height,
                bytes: bytes,
                uploadedAt: uploadedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProofPhotosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProofPhotosTable,
      ProofPhoto,
      $$ProofPhotosTableFilterComposer,
      $$ProofPhotosTableOrderingComposer,
      $$ProofPhotosTableAnnotationComposer,
      $$ProofPhotosTableCreateCompanionBuilder,
      $$ProofPhotosTableUpdateCompanionBuilder,
      (
        ProofPhoto,
        BaseReferences<_$AppDatabase, $ProofPhotosTable, ProofPhoto>,
      ),
      ProofPhoto,
      PrefetchHooks Function()
    >;
typedef $$IssuesTableCreateCompanionBuilder =
    IssuesCompanion Function({
      required String id,
      Value<String?> orderId,
      required String kind,
      required String description,
      required String reportedBy,
      required DateTime reportedAt,
      Value<DateTime?> resolvedAt,
      Value<String?> resolvedBy,
      Value<int> rowid,
    });
typedef $$IssuesTableUpdateCompanionBuilder =
    IssuesCompanion Function({
      Value<String> id,
      Value<String?> orderId,
      Value<String> kind,
      Value<String> description,
      Value<String> reportedBy,
      Value<DateTime> reportedAt,
      Value<DateTime?> resolvedAt,
      Value<String?> resolvedBy,
      Value<int> rowid,
    });

class $$IssuesTableFilterComposer
    extends Composer<_$AppDatabase, $IssuesTable> {
  $$IssuesTableFilterComposer({
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

  ColumnFilters<String> get orderId => $composableBuilder(
    column: $table.orderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reportedBy => $composableBuilder(
    column: $table.reportedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get reportedAt => $composableBuilder(
    column: $table.reportedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resolvedBy => $composableBuilder(
    column: $table.resolvedBy,
    builder: (column) => ColumnFilters(column),
  );
}

class $$IssuesTableOrderingComposer
    extends Composer<_$AppDatabase, $IssuesTable> {
  $$IssuesTableOrderingComposer({
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

  ColumnOrderings<String> get orderId => $composableBuilder(
    column: $table.orderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reportedBy => $composableBuilder(
    column: $table.reportedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get reportedAt => $composableBuilder(
    column: $table.reportedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resolvedBy => $composableBuilder(
    column: $table.resolvedBy,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IssuesTableAnnotationComposer
    extends Composer<_$AppDatabase, $IssuesTable> {
  $$IssuesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get orderId =>
      $composableBuilder(column: $table.orderId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reportedBy => $composableBuilder(
    column: $table.reportedBy,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get reportedAt => $composableBuilder(
    column: $table.reportedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resolvedBy => $composableBuilder(
    column: $table.resolvedBy,
    builder: (column) => column,
  );
}

class $$IssuesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $IssuesTable,
          Issue,
          $$IssuesTableFilterComposer,
          $$IssuesTableOrderingComposer,
          $$IssuesTableAnnotationComposer,
          $$IssuesTableCreateCompanionBuilder,
          $$IssuesTableUpdateCompanionBuilder,
          (Issue, BaseReferences<_$AppDatabase, $IssuesTable, Issue>),
          Issue,
          PrefetchHooks Function()
        > {
  $$IssuesTableTableManager(_$AppDatabase db, $IssuesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IssuesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IssuesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IssuesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> orderId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> reportedBy = const Value.absent(),
                Value<DateTime> reportedAt = const Value.absent(),
                Value<DateTime?> resolvedAt = const Value.absent(),
                Value<String?> resolvedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IssuesCompanion(
                id: id,
                orderId: orderId,
                kind: kind,
                description: description,
                reportedBy: reportedBy,
                reportedAt: reportedAt,
                resolvedAt: resolvedAt,
                resolvedBy: resolvedBy,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> orderId = const Value.absent(),
                required String kind,
                required String description,
                required String reportedBy,
                required DateTime reportedAt,
                Value<DateTime?> resolvedAt = const Value.absent(),
                Value<String?> resolvedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IssuesCompanion.insert(
                id: id,
                orderId: orderId,
                kind: kind,
                description: description,
                reportedBy: reportedBy,
                reportedAt: reportedAt,
                resolvedAt: resolvedAt,
                resolvedBy: resolvedBy,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$IssuesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $IssuesTable,
      Issue,
      $$IssuesTableFilterComposer,
      $$IssuesTableOrderingComposer,
      $$IssuesTableAnnotationComposer,
      $$IssuesTableCreateCompanionBuilder,
      $$IssuesTableUpdateCompanionBuilder,
      (Issue, BaseReferences<_$AppDatabase, $IssuesTable, Issue>),
      Issue,
      PrefetchHooks Function()
    >;
typedef $$ShiftsTableCreateCompanionBuilder =
    ShiftsCompanion Function({
      required String id,
      required String staffId,
      required DateTime startedAt,
      Value<double?> startedLat,
      Value<double?> startedLng,
      Value<DateTime?> endedAt,
      Value<double?> endedLat,
      Value<double?> endedLng,
      Value<int> rowid,
    });
typedef $$ShiftsTableUpdateCompanionBuilder =
    ShiftsCompanion Function({
      Value<String> id,
      Value<String> staffId,
      Value<DateTime> startedAt,
      Value<double?> startedLat,
      Value<double?> startedLng,
      Value<DateTime?> endedAt,
      Value<double?> endedLat,
      Value<double?> endedLng,
      Value<int> rowid,
    });

class $$ShiftsTableFilterComposer
    extends Composer<_$AppDatabase, $ShiftsTable> {
  $$ShiftsTableFilterComposer({
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

  ColumnFilters<String> get staffId => $composableBuilder(
    column: $table.staffId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get startedLat => $composableBuilder(
    column: $table.startedLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get startedLng => $composableBuilder(
    column: $table.startedLng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get endedLat => $composableBuilder(
    column: $table.endedLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get endedLng => $composableBuilder(
    column: $table.endedLng,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ShiftsTableOrderingComposer
    extends Composer<_$AppDatabase, $ShiftsTable> {
  $$ShiftsTableOrderingComposer({
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

  ColumnOrderings<String> get staffId => $composableBuilder(
    column: $table.staffId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get startedLat => $composableBuilder(
    column: $table.startedLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get startedLng => $composableBuilder(
    column: $table.startedLng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get endedLat => $composableBuilder(
    column: $table.endedLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get endedLng => $composableBuilder(
    column: $table.endedLng,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ShiftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShiftsTable> {
  $$ShiftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get staffId =>
      $composableBuilder(column: $table.staffId, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<double> get startedLat => $composableBuilder(
    column: $table.startedLat,
    builder: (column) => column,
  );

  GeneratedColumn<double> get startedLng => $composableBuilder(
    column: $table.startedLng,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<double> get endedLat =>
      $composableBuilder(column: $table.endedLat, builder: (column) => column);

  GeneratedColumn<double> get endedLng =>
      $composableBuilder(column: $table.endedLng, builder: (column) => column);
}

class $$ShiftsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShiftsTable,
          Shift,
          $$ShiftsTableFilterComposer,
          $$ShiftsTableOrderingComposer,
          $$ShiftsTableAnnotationComposer,
          $$ShiftsTableCreateCompanionBuilder,
          $$ShiftsTableUpdateCompanionBuilder,
          (Shift, BaseReferences<_$AppDatabase, $ShiftsTable, Shift>),
          Shift,
          PrefetchHooks Function()
        > {
  $$ShiftsTableTableManager(_$AppDatabase db, $ShiftsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShiftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShiftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShiftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> staffId = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<double?> startedLat = const Value.absent(),
                Value<double?> startedLng = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<double?> endedLat = const Value.absent(),
                Value<double?> endedLng = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShiftsCompanion(
                id: id,
                staffId: staffId,
                startedAt: startedAt,
                startedLat: startedLat,
                startedLng: startedLng,
                endedAt: endedAt,
                endedLat: endedLat,
                endedLng: endedLng,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String staffId,
                required DateTime startedAt,
                Value<double?> startedLat = const Value.absent(),
                Value<double?> startedLng = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<double?> endedLat = const Value.absent(),
                Value<double?> endedLng = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShiftsCompanion.insert(
                id: id,
                staffId: staffId,
                startedAt: startedAt,
                startedLat: startedLat,
                startedLng: startedLng,
                endedAt: endedAt,
                endedLat: endedLat,
                endedLng: endedLng,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ShiftsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShiftsTable,
      Shift,
      $$ShiftsTableFilterComposer,
      $$ShiftsTableOrderingComposer,
      $$ShiftsTableAnnotationComposer,
      $$ShiftsTableCreateCompanionBuilder,
      $$ShiftsTableUpdateCompanionBuilder,
      (Shift, BaseReferences<_$AppDatabase, $ShiftsTable, Shift>),
      Shift,
      PrefetchHooks Function()
    >;
typedef $$ValidTransitionsTableCreateCompanionBuilder =
    ValidTransitionsCompanion Function({
      required String id,
      required String intakeMethod,
      required String fulfillmentMethod,
      Value<String?> fromStatus,
      required String toStatus,
      Value<int> rowid,
    });
typedef $$ValidTransitionsTableUpdateCompanionBuilder =
    ValidTransitionsCompanion Function({
      Value<String> id,
      Value<String> intakeMethod,
      Value<String> fulfillmentMethod,
      Value<String?> fromStatus,
      Value<String> toStatus,
      Value<int> rowid,
    });

class $$ValidTransitionsTableFilterComposer
    extends Composer<_$AppDatabase, $ValidTransitionsTable> {
  $$ValidTransitionsTableFilterComposer({
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

  ColumnFilters<String> get intakeMethod => $composableBuilder(
    column: $table.intakeMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fulfillmentMethod => $composableBuilder(
    column: $table.fulfillmentMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromStatus => $composableBuilder(
    column: $table.fromStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toStatus => $composableBuilder(
    column: $table.toStatus,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ValidTransitionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ValidTransitionsTable> {
  $$ValidTransitionsTableOrderingComposer({
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

  ColumnOrderings<String> get intakeMethod => $composableBuilder(
    column: $table.intakeMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fulfillmentMethod => $composableBuilder(
    column: $table.fulfillmentMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromStatus => $composableBuilder(
    column: $table.fromStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toStatus => $composableBuilder(
    column: $table.toStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ValidTransitionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ValidTransitionsTable> {
  $$ValidTransitionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get intakeMethod => $composableBuilder(
    column: $table.intakeMethod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fulfillmentMethod => $composableBuilder(
    column: $table.fulfillmentMethod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fromStatus => $composableBuilder(
    column: $table.fromStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get toStatus =>
      $composableBuilder(column: $table.toStatus, builder: (column) => column);
}

class $$ValidTransitionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ValidTransitionsTable,
          ValidTransition,
          $$ValidTransitionsTableFilterComposer,
          $$ValidTransitionsTableOrderingComposer,
          $$ValidTransitionsTableAnnotationComposer,
          $$ValidTransitionsTableCreateCompanionBuilder,
          $$ValidTransitionsTableUpdateCompanionBuilder,
          (
            ValidTransition,
            BaseReferences<
              _$AppDatabase,
              $ValidTransitionsTable,
              ValidTransition
            >,
          ),
          ValidTransition,
          PrefetchHooks Function()
        > {
  $$ValidTransitionsTableTableManager(
    _$AppDatabase db,
    $ValidTransitionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ValidTransitionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ValidTransitionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ValidTransitionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> intakeMethod = const Value.absent(),
                Value<String> fulfillmentMethod = const Value.absent(),
                Value<String?> fromStatus = const Value.absent(),
                Value<String> toStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ValidTransitionsCompanion(
                id: id,
                intakeMethod: intakeMethod,
                fulfillmentMethod: fulfillmentMethod,
                fromStatus: fromStatus,
                toStatus: toStatus,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String intakeMethod,
                required String fulfillmentMethod,
                Value<String?> fromStatus = const Value.absent(),
                required String toStatus,
                Value<int> rowid = const Value.absent(),
              }) => ValidTransitionsCompanion.insert(
                id: id,
                intakeMethod: intakeMethod,
                fulfillmentMethod: fulfillmentMethod,
                fromStatus: fromStatus,
                toStatus: toStatus,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ValidTransitionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ValidTransitionsTable,
      ValidTransition,
      $$ValidTransitionsTableFilterComposer,
      $$ValidTransitionsTableOrderingComposer,
      $$ValidTransitionsTableAnnotationComposer,
      $$ValidTransitionsTableCreateCompanionBuilder,
      $$ValidTransitionsTableUpdateCompanionBuilder,
      (
        ValidTransition,
        BaseReferences<_$AppDatabase, $ValidTransitionsTable, ValidTransition>,
      ),
      ValidTransition,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder =
    OutboxCompanion Function({
      required String id,
      required String forTable,
      required String op,
      required String rowId,
      required String payloadJson,
      Value<DateTime> createdAt,
      Value<int> retryCount,
      Value<DateTime?> lastAttemptedAt,
      Value<String?> lastError,
      Value<String> status,
      Value<int> rowid,
    });
typedef $$OutboxTableUpdateCompanionBuilder =
    OutboxCompanion Function({
      Value<String> id,
      Value<String> forTable,
      Value<String> op,
      Value<String> rowId,
      Value<String> payloadJson,
      Value<DateTime> createdAt,
      Value<int> retryCount,
      Value<DateTime?> lastAttemptedAt,
      Value<String?> lastError,
      Value<String> status,
      Value<int> rowid,
    });

class $$OutboxTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
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

  ColumnFilters<String> get forTable => $composableBuilder(
    column: $table.forTable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
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

  ColumnFilters<DateTime> get lastAttemptedAt => $composableBuilder(
    column: $table.lastAttemptedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
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

  ColumnOrderings<String> get forTable => $composableBuilder(
    column: $table.forTable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
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

  ColumnOrderings<DateTime> get lastAttemptedAt => $composableBuilder(
    column: $table.lastAttemptedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get forTable =>
      $composableBuilder(column: $table.forTable, builder: (column) => column);

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<String> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastAttemptedAt => $composableBuilder(
    column: $table.lastAttemptedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxTable,
          OutboxData,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
          OutboxData,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> forTable = const Value.absent(),
                Value<String> op = const Value.absent(),
                Value<String> rowId = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime?> lastAttemptedAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion(
                id: id,
                forTable: forTable,
                op: op,
                rowId: rowId,
                payloadJson: payloadJson,
                createdAt: createdAt,
                retryCount: retryCount,
                lastAttemptedAt: lastAttemptedAt,
                lastError: lastError,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String forTable,
                required String op,
                required String rowId,
                required String payloadJson,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime?> lastAttemptedAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion.insert(
                id: id,
                forTable: forTable,
                op: op,
                rowId: rowId,
                payloadJson: payloadJson,
                createdAt: createdAt,
                retryCount: retryCount,
                lastAttemptedAt: lastAttemptedAt,
                lastError: lastError,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxTable,
      OutboxData,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
      OutboxData,
      PrefetchHooks Function()
    >;
typedef $$SyncWatermarksTableCreateCompanionBuilder =
    SyncWatermarksCompanion Function({
      required String forTable,
      required DateTime lastSyncedAt,
      Value<int> rowid,
    });
typedef $$SyncWatermarksTableUpdateCompanionBuilder =
    SyncWatermarksCompanion Function({
      Value<String> forTable,
      Value<DateTime> lastSyncedAt,
      Value<int> rowid,
    });

class $$SyncWatermarksTableFilterComposer
    extends Composer<_$AppDatabase, $SyncWatermarksTable> {
  $$SyncWatermarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get forTable => $composableBuilder(
    column: $table.forTable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncWatermarksTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncWatermarksTable> {
  $$SyncWatermarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get forTable => $composableBuilder(
    column: $table.forTable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncWatermarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncWatermarksTable> {
  $$SyncWatermarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get forTable =>
      $composableBuilder(column: $table.forTable, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );
}

class $$SyncWatermarksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncWatermarksTable,
          SyncWatermark,
          $$SyncWatermarksTableFilterComposer,
          $$SyncWatermarksTableOrderingComposer,
          $$SyncWatermarksTableAnnotationComposer,
          $$SyncWatermarksTableCreateCompanionBuilder,
          $$SyncWatermarksTableUpdateCompanionBuilder,
          (
            SyncWatermark,
            BaseReferences<_$AppDatabase, $SyncWatermarksTable, SyncWatermark>,
          ),
          SyncWatermark,
          PrefetchHooks Function()
        > {
  $$SyncWatermarksTableTableManager(
    _$AppDatabase db,
    $SyncWatermarksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncWatermarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncWatermarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncWatermarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> forTable = const Value.absent(),
                Value<DateTime> lastSyncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncWatermarksCompanion(
                forTable: forTable,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String forTable,
                required DateTime lastSyncedAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncWatermarksCompanion.insert(
                forTable: forTable,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncWatermarksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncWatermarksTable,
      SyncWatermark,
      $$SyncWatermarksTableFilterComposer,
      $$SyncWatermarksTableOrderingComposer,
      $$SyncWatermarksTableAnnotationComposer,
      $$SyncWatermarksTableCreateCompanionBuilder,
      $$SyncWatermarksTableUpdateCompanionBuilder,
      (
        SyncWatermark,
        BaseReferences<_$AppDatabase, $SyncWatermarksTable, SyncWatermark>,
      ),
      SyncWatermark,
      PrefetchHooks Function()
    >;
typedef $$PullDeadLetterTableCreateCompanionBuilder =
    PullDeadLetterCompanion Function({
      required String id,
      required String forTable,
      required String rowPayloadJson,
      required String errorText,
      Value<DateTime> recordedAt,
      Value<int> rowid,
    });
typedef $$PullDeadLetterTableUpdateCompanionBuilder =
    PullDeadLetterCompanion Function({
      Value<String> id,
      Value<String> forTable,
      Value<String> rowPayloadJson,
      Value<String> errorText,
      Value<DateTime> recordedAt,
      Value<int> rowid,
    });

class $$PullDeadLetterTableFilterComposer
    extends Composer<_$AppDatabase, $PullDeadLetterTable> {
  $$PullDeadLetterTableFilterComposer({
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

  ColumnFilters<String> get forTable => $composableBuilder(
    column: $table.forTable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rowPayloadJson => $composableBuilder(
    column: $table.rowPayloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorText => $composableBuilder(
    column: $table.errorText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PullDeadLetterTableOrderingComposer
    extends Composer<_$AppDatabase, $PullDeadLetterTable> {
  $$PullDeadLetterTableOrderingComposer({
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

  ColumnOrderings<String> get forTable => $composableBuilder(
    column: $table.forTable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rowPayloadJson => $composableBuilder(
    column: $table.rowPayloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorText => $composableBuilder(
    column: $table.errorText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PullDeadLetterTableAnnotationComposer
    extends Composer<_$AppDatabase, $PullDeadLetterTable> {
  $$PullDeadLetterTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get forTable =>
      $composableBuilder(column: $table.forTable, builder: (column) => column);

  GeneratedColumn<String> get rowPayloadJson => $composableBuilder(
    column: $table.rowPayloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorText =>
      $composableBuilder(column: $table.errorText, builder: (column) => column);

  GeneratedColumn<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => column,
  );
}

class $$PullDeadLetterTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PullDeadLetterTable,
          PullDeadLetterData,
          $$PullDeadLetterTableFilterComposer,
          $$PullDeadLetterTableOrderingComposer,
          $$PullDeadLetterTableAnnotationComposer,
          $$PullDeadLetterTableCreateCompanionBuilder,
          $$PullDeadLetterTableUpdateCompanionBuilder,
          (
            PullDeadLetterData,
            BaseReferences<
              _$AppDatabase,
              $PullDeadLetterTable,
              PullDeadLetterData
            >,
          ),
          PullDeadLetterData,
          PrefetchHooks Function()
        > {
  $$PullDeadLetterTableTableManager(
    _$AppDatabase db,
    $PullDeadLetterTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PullDeadLetterTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PullDeadLetterTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PullDeadLetterTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> forTable = const Value.absent(),
                Value<String> rowPayloadJson = const Value.absent(),
                Value<String> errorText = const Value.absent(),
                Value<DateTime> recordedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PullDeadLetterCompanion(
                id: id,
                forTable: forTable,
                rowPayloadJson: rowPayloadJson,
                errorText: errorText,
                recordedAt: recordedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String forTable,
                required String rowPayloadJson,
                required String errorText,
                Value<DateTime> recordedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PullDeadLetterCompanion.insert(
                id: id,
                forTable: forTable,
                rowPayloadJson: rowPayloadJson,
                errorText: errorText,
                recordedAt: recordedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PullDeadLetterTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PullDeadLetterTable,
      PullDeadLetterData,
      $$PullDeadLetterTableFilterComposer,
      $$PullDeadLetterTableOrderingComposer,
      $$PullDeadLetterTableAnnotationComposer,
      $$PullDeadLetterTableCreateCompanionBuilder,
      $$PullDeadLetterTableUpdateCompanionBuilder,
      (
        PullDeadLetterData,
        BaseReferences<_$AppDatabase, $PullDeadLetterTable, PullDeadLetterData>,
      ),
      PullDeadLetterData,
      PrefetchHooks Function()
    >;
typedef $$PricingSettingsTableCreateCompanionBuilder =
    PricingSettingsCompanion Function({
      required String id,
      required double defaultRatePerKgUgx,
      required DateTime updatedAt,
      Value<String?> updatedBy,
      Value<int> deliveryFeeUgx,
      Value<int> expressSurchargeFlatUgx,
      Value<double> expressSurchargePct,
      Value<int> rowid,
    });
typedef $$PricingSettingsTableUpdateCompanionBuilder =
    PricingSettingsCompanion Function({
      Value<String> id,
      Value<double> defaultRatePerKgUgx,
      Value<DateTime> updatedAt,
      Value<String?> updatedBy,
      Value<int> deliveryFeeUgx,
      Value<int> expressSurchargeFlatUgx,
      Value<double> expressSurchargePct,
      Value<int> rowid,
    });

class $$PricingSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $PricingSettingsTable> {
  $$PricingSettingsTableFilterComposer({
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

  ColumnFilters<double> get defaultRatePerKgUgx => $composableBuilder(
    column: $table.defaultRatePerKgUgx,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deliveryFeeUgx => $composableBuilder(
    column: $table.deliveryFeeUgx,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expressSurchargeFlatUgx => $composableBuilder(
    column: $table.expressSurchargeFlatUgx,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get expressSurchargePct => $composableBuilder(
    column: $table.expressSurchargePct,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PricingSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $PricingSettingsTable> {
  $$PricingSettingsTableOrderingComposer({
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

  ColumnOrderings<double> get defaultRatePerKgUgx => $composableBuilder(
    column: $table.defaultRatePerKgUgx,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deliveryFeeUgx => $composableBuilder(
    column: $table.deliveryFeeUgx,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expressSurchargeFlatUgx => $composableBuilder(
    column: $table.expressSurchargeFlatUgx,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get expressSurchargePct => $composableBuilder(
    column: $table.expressSurchargePct,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PricingSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PricingSettingsTable> {
  $$PricingSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get defaultRatePerKgUgx => $composableBuilder(
    column: $table.defaultRatePerKgUgx,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumn<int> get deliveryFeeUgx => $composableBuilder(
    column: $table.deliveryFeeUgx,
    builder: (column) => column,
  );

  GeneratedColumn<int> get expressSurchargeFlatUgx => $composableBuilder(
    column: $table.expressSurchargeFlatUgx,
    builder: (column) => column,
  );

  GeneratedColumn<double> get expressSurchargePct => $composableBuilder(
    column: $table.expressSurchargePct,
    builder: (column) => column,
  );
}

class $$PricingSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PricingSettingsTable,
          PricingSetting,
          $$PricingSettingsTableFilterComposer,
          $$PricingSettingsTableOrderingComposer,
          $$PricingSettingsTableAnnotationComposer,
          $$PricingSettingsTableCreateCompanionBuilder,
          $$PricingSettingsTableUpdateCompanionBuilder,
          (
            PricingSetting,
            BaseReferences<
              _$AppDatabase,
              $PricingSettingsTable,
              PricingSetting
            >,
          ),
          PricingSetting,
          PrefetchHooks Function()
        > {
  $$PricingSettingsTableTableManager(
    _$AppDatabase db,
    $PricingSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PricingSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PricingSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PricingSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<double> defaultRatePerKgUgx = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> updatedBy = const Value.absent(),
                Value<int> deliveryFeeUgx = const Value.absent(),
                Value<int> expressSurchargeFlatUgx = const Value.absent(),
                Value<double> expressSurchargePct = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PricingSettingsCompanion(
                id: id,
                defaultRatePerKgUgx: defaultRatePerKgUgx,
                updatedAt: updatedAt,
                updatedBy: updatedBy,
                deliveryFeeUgx: deliveryFeeUgx,
                expressSurchargeFlatUgx: expressSurchargeFlatUgx,
                expressSurchargePct: expressSurchargePct,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required double defaultRatePerKgUgx,
                required DateTime updatedAt,
                Value<String?> updatedBy = const Value.absent(),
                Value<int> deliveryFeeUgx = const Value.absent(),
                Value<int> expressSurchargeFlatUgx = const Value.absent(),
                Value<double> expressSurchargePct = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PricingSettingsCompanion.insert(
                id: id,
                defaultRatePerKgUgx: defaultRatePerKgUgx,
                updatedAt: updatedAt,
                updatedBy: updatedBy,
                deliveryFeeUgx: deliveryFeeUgx,
                expressSurchargeFlatUgx: expressSurchargeFlatUgx,
                expressSurchargePct: expressSurchargePct,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PricingSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PricingSettingsTable,
      PricingSetting,
      $$PricingSettingsTableFilterComposer,
      $$PricingSettingsTableOrderingComposer,
      $$PricingSettingsTableAnnotationComposer,
      $$PricingSettingsTableCreateCompanionBuilder,
      $$PricingSettingsTableUpdateCompanionBuilder,
      (
        PricingSetting,
        BaseReferences<_$AppDatabase, $PricingSettingsTable, PricingSetting>,
      ),
      PricingSetting,
      PrefetchHooks Function()
    >;
typedef $$PricingCatalogItemsTableCreateCompanionBuilder =
    PricingCatalogItemsCompanion Function({
      required String id,
      required String name,
      required int amountUgx,
      Value<bool> active,
      Value<int> sortOrder,
      Value<String?> category,
      Value<int> rowid,
    });
typedef $$PricingCatalogItemsTableUpdateCompanionBuilder =
    PricingCatalogItemsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> amountUgx,
      Value<bool> active,
      Value<int> sortOrder,
      Value<String?> category,
      Value<int> rowid,
    });

class $$PricingCatalogItemsTableFilterComposer
    extends Composer<_$AppDatabase, $PricingCatalogItemsTable> {
  $$PricingCatalogItemsTableFilterComposer({
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

  ColumnFilters<int> get amountUgx => $composableBuilder(
    column: $table.amountUgx,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PricingCatalogItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $PricingCatalogItemsTable> {
  $$PricingCatalogItemsTableOrderingComposer({
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

  ColumnOrderings<int> get amountUgx => $composableBuilder(
    column: $table.amountUgx,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PricingCatalogItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PricingCatalogItemsTable> {
  $$PricingCatalogItemsTableAnnotationComposer({
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

  GeneratedColumn<int> get amountUgx =>
      $composableBuilder(column: $table.amountUgx, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);
}

class $$PricingCatalogItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PricingCatalogItemsTable,
          PricingCatalogItem,
          $$PricingCatalogItemsTableFilterComposer,
          $$PricingCatalogItemsTableOrderingComposer,
          $$PricingCatalogItemsTableAnnotationComposer,
          $$PricingCatalogItemsTableCreateCompanionBuilder,
          $$PricingCatalogItemsTableUpdateCompanionBuilder,
          (
            PricingCatalogItem,
            BaseReferences<
              _$AppDatabase,
              $PricingCatalogItemsTable,
              PricingCatalogItem
            >,
          ),
          PricingCatalogItem,
          PrefetchHooks Function()
        > {
  $$PricingCatalogItemsTableTableManager(
    _$AppDatabase db,
    $PricingCatalogItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PricingCatalogItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PricingCatalogItemsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PricingCatalogItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> amountUgx = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PricingCatalogItemsCompanion(
                id: id,
                name: name,
                amountUgx: amountUgx,
                active: active,
                sortOrder: sortOrder,
                category: category,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int amountUgx,
                Value<bool> active = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PricingCatalogItemsCompanion.insert(
                id: id,
                name: name,
                amountUgx: amountUgx,
                active: active,
                sortOrder: sortOrder,
                category: category,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PricingCatalogItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PricingCatalogItemsTable,
      PricingCatalogItem,
      $$PricingCatalogItemsTableFilterComposer,
      $$PricingCatalogItemsTableOrderingComposer,
      $$PricingCatalogItemsTableAnnotationComposer,
      $$PricingCatalogItemsTableCreateCompanionBuilder,
      $$PricingCatalogItemsTableUpdateCompanionBuilder,
      (
        PricingCatalogItem,
        BaseReferences<
          _$AppDatabase,
          $PricingCatalogItemsTable,
          PricingCatalogItem
        >,
      ),
      PricingCatalogItem,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$StaffTableTableManager get staff =>
      $$StaffTableTableManager(_db, _db.staff);
  $$CustomersTableTableManager get customers =>
      $$CustomersTableTableManager(_db, _db.customers);
  $$OrdersTableTableManager get orders =>
      $$OrdersTableTableManager(_db, _db.orders);
  $$OrderStatusEventsTableTableManager get orderStatusEvents =>
      $$OrderStatusEventsTableTableManager(_db, _db.orderStatusEvents);
  $$ProofEventsTableTableManager get proofEvents =>
      $$ProofEventsTableTableManager(_db, _db.proofEvents);
  $$ProofPhotosTableTableManager get proofPhotos =>
      $$ProofPhotosTableTableManager(_db, _db.proofPhotos);
  $$IssuesTableTableManager get issues =>
      $$IssuesTableTableManager(_db, _db.issues);
  $$ShiftsTableTableManager get shifts =>
      $$ShiftsTableTableManager(_db, _db.shifts);
  $$ValidTransitionsTableTableManager get validTransitions =>
      $$ValidTransitionsTableTableManager(_db, _db.validTransitions);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$SyncWatermarksTableTableManager get syncWatermarks =>
      $$SyncWatermarksTableTableManager(_db, _db.syncWatermarks);
  $$PullDeadLetterTableTableManager get pullDeadLetter =>
      $$PullDeadLetterTableTableManager(_db, _db.pullDeadLetter);
  $$PricingSettingsTableTableManager get pricingSettings =>
      $$PricingSettingsTableTableManager(_db, _db.pricingSettings);
  $$PricingCatalogItemsTableTableManager get pricingCatalogItems =>
      $$PricingCatalogItemsTableTableManager(_db, _db.pricingCatalogItems);
}
