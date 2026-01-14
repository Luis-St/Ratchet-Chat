// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MessagesTable extends Messages with TableInfo<$MessagesTable, Message> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderIdMeta = const VerificationMeta(
    'senderId',
  );
  @override
  late final GeneratedColumn<String> senderId = GeneratedColumn<String>(
    'sender_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _peerHandleMeta = const VerificationMeta(
    'peerHandle',
  );
  @override
  late final GeneratedColumn<String> peerHandle = GeneratedColumn<String>(
    'peer_handle',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _encryptedContentMeta = const VerificationMeta(
    'encryptedContent',
  );
  @override
  late final GeneratedColumn<String> encryptedContent = GeneratedColumn<String>(
    'encrypted_content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
    'direction',
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
    requiredDuringInsert: false,
    defaultValue: const Constant('message'),
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
  static const VerificationMeta _isReadMeta = const VerificationMeta('isRead');
  @override
  late final GeneratedColumn<bool> isRead = GeneratedColumn<bool>(
    'is_read',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_read" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _vaultSyncedMeta = const VerificationMeta(
    'vaultSynced',
  );
  @override
  late final GeneratedColumn<bool> vaultSynced = GeneratedColumn<bool>(
    'vault_synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("vault_synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _verifiedMeta = const VerificationMeta(
    'verified',
  );
  @override
  late final GeneratedColumn<bool> verified = GeneratedColumn<bool>(
    'verified',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("verified" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _referencedMessageIdMeta =
      const VerificationMeta('referencedMessageId');
  @override
  late final GeneratedColumn<String> referencedMessageId =
      GeneratedColumn<String>(
        'referenced_message_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _serverMessageIdMeta = const VerificationMeta(
    'serverMessageId',
  );
  @override
  late final GeneratedColumn<String> serverMessageId = GeneratedColumn<String>(
    'server_message_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerId,
    senderId,
    peerHandle,
    encryptedContent,
    direction,
    type,
    createdAt,
    isRead,
    vaultSynced,
    verified,
    referencedMessageId,
    serverMessageId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<Message> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('sender_id')) {
      context.handle(
        _senderIdMeta,
        senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_senderIdMeta);
    }
    if (data.containsKey('peer_handle')) {
      context.handle(
        _peerHandleMeta,
        peerHandle.isAcceptableOrUnknown(data['peer_handle']!, _peerHandleMeta),
      );
    } else if (isInserting) {
      context.missing(_peerHandleMeta);
    }
    if (data.containsKey('encrypted_content')) {
      context.handle(
        _encryptedContentMeta,
        encryptedContent.isAcceptableOrUnknown(
          data['encrypted_content']!,
          _encryptedContentMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedContentMeta);
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
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
    if (data.containsKey('is_read')) {
      context.handle(
        _isReadMeta,
        isRead.isAcceptableOrUnknown(data['is_read']!, _isReadMeta),
      );
    }
    if (data.containsKey('vault_synced')) {
      context.handle(
        _vaultSyncedMeta,
        vaultSynced.isAcceptableOrUnknown(
          data['vault_synced']!,
          _vaultSyncedMeta,
        ),
      );
    }
    if (data.containsKey('verified')) {
      context.handle(
        _verifiedMeta,
        verified.isAcceptableOrUnknown(data['verified']!, _verifiedMeta),
      );
    }
    if (data.containsKey('referenced_message_id')) {
      context.handle(
        _referencedMessageIdMeta,
        referencedMessageId.isAcceptableOrUnknown(
          data['referenced_message_id']!,
          _referencedMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('server_message_id')) {
      context.handle(
        _serverMessageIdMeta,
        serverMessageId.isAcceptableOrUnknown(
          data['server_message_id']!,
          _serverMessageIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      senderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_id'],
      )!,
      peerHandle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_handle'],
      )!,
      encryptedContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_content'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direction'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      isRead: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_read'],
      )!,
      vaultSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}vault_synced'],
      )!,
      verified: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}verified'],
      )!,
      referencedMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}referenced_message_id'],
      ),
      serverMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_message_id'],
      ),
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class Message extends DataClass implements Insertable<Message> {
  /// Unique message ID (UUID)
  final String id;

  /// Owner's user ID (for multi-account support)
  final String ownerId;

  /// Sender's handle (e.g., "user@server.com")
  final String senderId;

  /// The other participant's handle (peer in conversation)
  final String peerHandle;

  /// Encrypted content as JSON: { "encrypted_blob": "...", "iv": "..." }
  final String encryptedContent;

  /// Message direction: "in" or "out"
  final String direction;

  /// Message type: "message", "edit", "delete", "reaction", "receipt", "unsupported"
  final String type;

  /// When the message was created
  final DateTime createdAt;

  /// Whether the message has been read
  final bool isRead;

  /// Whether the message has been synced to the vault
  final bool vaultSynced;

  /// Whether the signature was verified
  final bool verified;

  /// Reference to original message (for edits, deletes, reactions)
  final String? referencedMessageId;

  /// Server-provided message ID (for vault sync tracking)
  final String? serverMessageId;
  const Message({
    required this.id,
    required this.ownerId,
    required this.senderId,
    required this.peerHandle,
    required this.encryptedContent,
    required this.direction,
    required this.type,
    required this.createdAt,
    required this.isRead,
    required this.vaultSynced,
    required this.verified,
    this.referencedMessageId,
    this.serverMessageId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['sender_id'] = Variable<String>(senderId);
    map['peer_handle'] = Variable<String>(peerHandle);
    map['encrypted_content'] = Variable<String>(encryptedContent);
    map['direction'] = Variable<String>(direction);
    map['type'] = Variable<String>(type);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['is_read'] = Variable<bool>(isRead);
    map['vault_synced'] = Variable<bool>(vaultSynced);
    map['verified'] = Variable<bool>(verified);
    if (!nullToAbsent || referencedMessageId != null) {
      map['referenced_message_id'] = Variable<String>(referencedMessageId);
    }
    if (!nullToAbsent || serverMessageId != null) {
      map['server_message_id'] = Variable<String>(serverMessageId);
    }
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      ownerId: Value(ownerId),
      senderId: Value(senderId),
      peerHandle: Value(peerHandle),
      encryptedContent: Value(encryptedContent),
      direction: Value(direction),
      type: Value(type),
      createdAt: Value(createdAt),
      isRead: Value(isRead),
      vaultSynced: Value(vaultSynced),
      verified: Value(verified),
      referencedMessageId: referencedMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(referencedMessageId),
      serverMessageId: serverMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverMessageId),
    );
  }

  factory Message.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      senderId: serializer.fromJson<String>(json['senderId']),
      peerHandle: serializer.fromJson<String>(json['peerHandle']),
      encryptedContent: serializer.fromJson<String>(json['encryptedContent']),
      direction: serializer.fromJson<String>(json['direction']),
      type: serializer.fromJson<String>(json['type']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      isRead: serializer.fromJson<bool>(json['isRead']),
      vaultSynced: serializer.fromJson<bool>(json['vaultSynced']),
      verified: serializer.fromJson<bool>(json['verified']),
      referencedMessageId: serializer.fromJson<String?>(
        json['referencedMessageId'],
      ),
      serverMessageId: serializer.fromJson<String?>(json['serverMessageId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'senderId': serializer.toJson<String>(senderId),
      'peerHandle': serializer.toJson<String>(peerHandle),
      'encryptedContent': serializer.toJson<String>(encryptedContent),
      'direction': serializer.toJson<String>(direction),
      'type': serializer.toJson<String>(type),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'isRead': serializer.toJson<bool>(isRead),
      'vaultSynced': serializer.toJson<bool>(vaultSynced),
      'verified': serializer.toJson<bool>(verified),
      'referencedMessageId': serializer.toJson<String?>(referencedMessageId),
      'serverMessageId': serializer.toJson<String?>(serverMessageId),
    };
  }

  Message copyWith({
    String? id,
    String? ownerId,
    String? senderId,
    String? peerHandle,
    String? encryptedContent,
    String? direction,
    String? type,
    DateTime? createdAt,
    bool? isRead,
    bool? vaultSynced,
    bool? verified,
    Value<String?> referencedMessageId = const Value.absent(),
    Value<String?> serverMessageId = const Value.absent(),
  }) => Message(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    senderId: senderId ?? this.senderId,
    peerHandle: peerHandle ?? this.peerHandle,
    encryptedContent: encryptedContent ?? this.encryptedContent,
    direction: direction ?? this.direction,
    type: type ?? this.type,
    createdAt: createdAt ?? this.createdAt,
    isRead: isRead ?? this.isRead,
    vaultSynced: vaultSynced ?? this.vaultSynced,
    verified: verified ?? this.verified,
    referencedMessageId: referencedMessageId.present
        ? referencedMessageId.value
        : this.referencedMessageId,
    serverMessageId: serverMessageId.present
        ? serverMessageId.value
        : this.serverMessageId,
  );
  Message copyWithCompanion(MessagesCompanion data) {
    return Message(
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      peerHandle: data.peerHandle.present
          ? data.peerHandle.value
          : this.peerHandle,
      encryptedContent: data.encryptedContent.present
          ? data.encryptedContent.value
          : this.encryptedContent,
      direction: data.direction.present ? data.direction.value : this.direction,
      type: data.type.present ? data.type.value : this.type,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      isRead: data.isRead.present ? data.isRead.value : this.isRead,
      vaultSynced: data.vaultSynced.present
          ? data.vaultSynced.value
          : this.vaultSynced,
      verified: data.verified.present ? data.verified.value : this.verified,
      referencedMessageId: data.referencedMessageId.present
          ? data.referencedMessageId.value
          : this.referencedMessageId,
      serverMessageId: data.serverMessageId.present
          ? data.serverMessageId.value
          : this.serverMessageId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Message(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('senderId: $senderId, ')
          ..write('peerHandle: $peerHandle, ')
          ..write('encryptedContent: $encryptedContent, ')
          ..write('direction: $direction, ')
          ..write('type: $type, ')
          ..write('createdAt: $createdAt, ')
          ..write('isRead: $isRead, ')
          ..write('vaultSynced: $vaultSynced, ')
          ..write('verified: $verified, ')
          ..write('referencedMessageId: $referencedMessageId, ')
          ..write('serverMessageId: $serverMessageId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerId,
    senderId,
    peerHandle,
    encryptedContent,
    direction,
    type,
    createdAt,
    isRead,
    vaultSynced,
    verified,
    referencedMessageId,
    serverMessageId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.senderId == this.senderId &&
          other.peerHandle == this.peerHandle &&
          other.encryptedContent == this.encryptedContent &&
          other.direction == this.direction &&
          other.type == this.type &&
          other.createdAt == this.createdAt &&
          other.isRead == this.isRead &&
          other.vaultSynced == this.vaultSynced &&
          other.verified == this.verified &&
          other.referencedMessageId == this.referencedMessageId &&
          other.serverMessageId == this.serverMessageId);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<String> id;
  final Value<String> ownerId;
  final Value<String> senderId;
  final Value<String> peerHandle;
  final Value<String> encryptedContent;
  final Value<String> direction;
  final Value<String> type;
  final Value<DateTime> createdAt;
  final Value<bool> isRead;
  final Value<bool> vaultSynced;
  final Value<bool> verified;
  final Value<String?> referencedMessageId;
  final Value<String?> serverMessageId;
  final Value<int> rowid;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.senderId = const Value.absent(),
    this.peerHandle = const Value.absent(),
    this.encryptedContent = const Value.absent(),
    this.direction = const Value.absent(),
    this.type = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isRead = const Value.absent(),
    this.vaultSynced = const Value.absent(),
    this.verified = const Value.absent(),
    this.referencedMessageId = const Value.absent(),
    this.serverMessageId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String id,
    required String ownerId,
    required String senderId,
    required String peerHandle,
    required String encryptedContent,
    required String direction,
    this.type = const Value.absent(),
    required DateTime createdAt,
    this.isRead = const Value.absent(),
    this.vaultSynced = const Value.absent(),
    this.verified = const Value.absent(),
    this.referencedMessageId = const Value.absent(),
    this.serverMessageId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ownerId = Value(ownerId),
       senderId = Value(senderId),
       peerHandle = Value(peerHandle),
       encryptedContent = Value(encryptedContent),
       direction = Value(direction),
       createdAt = Value(createdAt);
  static Insertable<Message> custom({
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<String>? senderId,
    Expression<String>? peerHandle,
    Expression<String>? encryptedContent,
    Expression<String>? direction,
    Expression<String>? type,
    Expression<DateTime>? createdAt,
    Expression<bool>? isRead,
    Expression<bool>? vaultSynced,
    Expression<bool>? verified,
    Expression<String>? referencedMessageId,
    Expression<String>? serverMessageId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (senderId != null) 'sender_id': senderId,
      if (peerHandle != null) 'peer_handle': peerHandle,
      if (encryptedContent != null) 'encrypted_content': encryptedContent,
      if (direction != null) 'direction': direction,
      if (type != null) 'type': type,
      if (createdAt != null) 'created_at': createdAt,
      if (isRead != null) 'is_read': isRead,
      if (vaultSynced != null) 'vault_synced': vaultSynced,
      if (verified != null) 'verified': verified,
      if (referencedMessageId != null)
        'referenced_message_id': referencedMessageId,
      if (serverMessageId != null) 'server_message_id': serverMessageId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerId,
    Value<String>? senderId,
    Value<String>? peerHandle,
    Value<String>? encryptedContent,
    Value<String>? direction,
    Value<String>? type,
    Value<DateTime>? createdAt,
    Value<bool>? isRead,
    Value<bool>? vaultSynced,
    Value<bool>? verified,
    Value<String?>? referencedMessageId,
    Value<String?>? serverMessageId,
    Value<int>? rowid,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      senderId: senderId ?? this.senderId,
      peerHandle: peerHandle ?? this.peerHandle,
      encryptedContent: encryptedContent ?? this.encryptedContent,
      direction: direction ?? this.direction,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      vaultSynced: vaultSynced ?? this.vaultSynced,
      verified: verified ?? this.verified,
      referencedMessageId: referencedMessageId ?? this.referencedMessageId,
      serverMessageId: serverMessageId ?? this.serverMessageId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<String>(senderId.value);
    }
    if (peerHandle.present) {
      map['peer_handle'] = Variable<String>(peerHandle.value);
    }
    if (encryptedContent.present) {
      map['encrypted_content'] = Variable<String>(encryptedContent.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (isRead.present) {
      map['is_read'] = Variable<bool>(isRead.value);
    }
    if (vaultSynced.present) {
      map['vault_synced'] = Variable<bool>(vaultSynced.value);
    }
    if (verified.present) {
      map['verified'] = Variable<bool>(verified.value);
    }
    if (referencedMessageId.present) {
      map['referenced_message_id'] = Variable<String>(
        referencedMessageId.value,
      );
    }
    if (serverMessageId.present) {
      map['server_message_id'] = Variable<String>(serverMessageId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('senderId: $senderId, ')
          ..write('peerHandle: $peerHandle, ')
          ..write('encryptedContent: $encryptedContent, ')
          ..write('direction: $direction, ')
          ..write('type: $type, ')
          ..write('createdAt: $createdAt, ')
          ..write('isRead: $isRead, ')
          ..write('vaultSynced: $vaultSynced, ')
          ..write('verified: $verified, ')
          ..write('referencedMessageId: $referencedMessageId, ')
          ..write('serverMessageId: $serverMessageId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cursorTypeMeta = const VerificationMeta(
    'cursorType',
  );
  @override
  late final GeneratedColumn<String> cursorType = GeneratedColumn<String>(
    'cursor_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cursorValueMeta = const VerificationMeta(
    'cursorValue',
  );
  @override
  late final GeneratedColumn<String> cursorValue = GeneratedColumn<String>(
    'cursor_value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSyncAtMeta = const VerificationMeta(
    'lastSyncAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncAt = GeneratedColumn<DateTime>(
    'last_sync_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerId,
    cursorType,
    cursorValue,
    lastSyncAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('cursor_type')) {
      context.handle(
        _cursorTypeMeta,
        cursorType.isAcceptableOrUnknown(data['cursor_type']!, _cursorTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_cursorTypeMeta);
    }
    if (data.containsKey('cursor_value')) {
      context.handle(
        _cursorValueMeta,
        cursorValue.isAcceptableOrUnknown(
          data['cursor_value']!,
          _cursorValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_cursorValueMeta);
    }
    if (data.containsKey('last_sync_at')) {
      context.handle(
        _lastSyncAtMeta,
        lastSyncAt.isAcceptableOrUnknown(
          data['last_sync_at']!,
          _lastSyncAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSyncAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId, cursorType};
  @override
  SyncStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateData(
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      cursorType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cursor_type'],
      )!,
      cursorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cursor_value'],
      )!,
      lastSyncAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_sync_at'],
      )!,
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateData extends DataClass implements Insertable<SyncStateData> {
  /// Owner's user ID
  final String ownerId;

  /// Sync cursor type (e.g., "vault_cursor")
  final String cursorType;

  /// Current cursor value
  final String cursorValue;

  /// Last sync timestamp
  final DateTime lastSyncAt;
  const SyncStateData({
    required this.ownerId,
    required this.cursorType,
    required this.cursorValue,
    required this.lastSyncAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_id'] = Variable<String>(ownerId);
    map['cursor_type'] = Variable<String>(cursorType);
    map['cursor_value'] = Variable<String>(cursorValue);
    map['last_sync_at'] = Variable<DateTime>(lastSyncAt);
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(
      ownerId: Value(ownerId),
      cursorType: Value(cursorType),
      cursorValue: Value(cursorValue),
      lastSyncAt: Value(lastSyncAt),
    );
  }

  factory SyncStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateData(
      ownerId: serializer.fromJson<String>(json['ownerId']),
      cursorType: serializer.fromJson<String>(json['cursorType']),
      cursorValue: serializer.fromJson<String>(json['cursorValue']),
      lastSyncAt: serializer.fromJson<DateTime>(json['lastSyncAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerId': serializer.toJson<String>(ownerId),
      'cursorType': serializer.toJson<String>(cursorType),
      'cursorValue': serializer.toJson<String>(cursorValue),
      'lastSyncAt': serializer.toJson<DateTime>(lastSyncAt),
    };
  }

  SyncStateData copyWith({
    String? ownerId,
    String? cursorType,
    String? cursorValue,
    DateTime? lastSyncAt,
  }) => SyncStateData(
    ownerId: ownerId ?? this.ownerId,
    cursorType: cursorType ?? this.cursorType,
    cursorValue: cursorValue ?? this.cursorValue,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
  );
  SyncStateData copyWithCompanion(SyncStateCompanion data) {
    return SyncStateData(
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      cursorType: data.cursorType.present
          ? data.cursorType.value
          : this.cursorType,
      cursorValue: data.cursorValue.present
          ? data.cursorValue.value
          : this.cursorValue,
      lastSyncAt: data.lastSyncAt.present
          ? data.lastSyncAt.value
          : this.lastSyncAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateData(')
          ..write('ownerId: $ownerId, ')
          ..write('cursorType: $cursorType, ')
          ..write('cursorValue: $cursorValue, ')
          ..write('lastSyncAt: $lastSyncAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(ownerId, cursorType, cursorValue, lastSyncAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateData &&
          other.ownerId == this.ownerId &&
          other.cursorType == this.cursorType &&
          other.cursorValue == this.cursorValue &&
          other.lastSyncAt == this.lastSyncAt);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateData> {
  final Value<String> ownerId;
  final Value<String> cursorType;
  final Value<String> cursorValue;
  final Value<DateTime> lastSyncAt;
  final Value<int> rowid;
  const SyncStateCompanion({
    this.ownerId = const Value.absent(),
    this.cursorType = const Value.absent(),
    this.cursorValue = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStateCompanion.insert({
    required String ownerId,
    required String cursorType,
    required String cursorValue,
    required DateTime lastSyncAt,
    this.rowid = const Value.absent(),
  }) : ownerId = Value(ownerId),
       cursorType = Value(cursorType),
       cursorValue = Value(cursorValue),
       lastSyncAt = Value(lastSyncAt);
  static Insertable<SyncStateData> custom({
    Expression<String>? ownerId,
    Expression<String>? cursorType,
    Expression<String>? cursorValue,
    Expression<DateTime>? lastSyncAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerId != null) 'owner_id': ownerId,
      if (cursorType != null) 'cursor_type': cursorType,
      if (cursorValue != null) 'cursor_value': cursorValue,
      if (lastSyncAt != null) 'last_sync_at': lastSyncAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStateCompanion copyWith({
    Value<String>? ownerId,
    Value<String>? cursorType,
    Value<String>? cursorValue,
    Value<DateTime>? lastSyncAt,
    Value<int>? rowid,
  }) {
    return SyncStateCompanion(
      ownerId: ownerId ?? this.ownerId,
      cursorType: cursorType ?? this.cursorType,
      cursorValue: cursorValue ?? this.cursorValue,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (cursorType.present) {
      map['cursor_type'] = Variable<String>(cursorType.value);
    }
    if (cursorValue.present) {
      map['cursor_value'] = Variable<String>(cursorValue.value);
    }
    if (lastSyncAt.present) {
      map['last_sync_at'] = Variable<DateTime>(lastSyncAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('ownerId: $ownerId, ')
          ..write('cursorType: $cursorType, ')
          ..write('cursorValue: $cursorValue, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [messages, syncState];
}

typedef $$MessagesTableCreateCompanionBuilder =
    MessagesCompanion Function({
      required String id,
      required String ownerId,
      required String senderId,
      required String peerHandle,
      required String encryptedContent,
      required String direction,
      Value<String> type,
      required DateTime createdAt,
      Value<bool> isRead,
      Value<bool> vaultSynced,
      Value<bool> verified,
      Value<String?> referencedMessageId,
      Value<String?> serverMessageId,
      Value<int> rowid,
    });
typedef $$MessagesTableUpdateCompanionBuilder =
    MessagesCompanion Function({
      Value<String> id,
      Value<String> ownerId,
      Value<String> senderId,
      Value<String> peerHandle,
      Value<String> encryptedContent,
      Value<String> direction,
      Value<String> type,
      Value<DateTime> createdAt,
      Value<bool> isRead,
      Value<bool> vaultSynced,
      Value<bool> verified,
      Value<String?> referencedMessageId,
      Value<String?> serverMessageId,
      Value<int> rowid,
    });

class $$MessagesTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
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

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get peerHandle => $composableBuilder(
    column: $table.peerHandle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedContent => $composableBuilder(
    column: $table.encryptedContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRead => $composableBuilder(
    column: $table.isRead,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get vaultSynced => $composableBuilder(
    column: $table.vaultSynced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get verified => $composableBuilder(
    column: $table.verified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get referencedMessageId => $composableBuilder(
    column: $table.referencedMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverMessageId => $composableBuilder(
    column: $table.serverMessageId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
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

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get peerHandle => $composableBuilder(
    column: $table.peerHandle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedContent => $composableBuilder(
    column: $table.encryptedContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRead => $composableBuilder(
    column: $table.isRead,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get vaultSynced => $composableBuilder(
    column: $table.vaultSynced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get verified => $composableBuilder(
    column: $table.verified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get referencedMessageId => $composableBuilder(
    column: $table.referencedMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverMessageId => $composableBuilder(
    column: $table.serverMessageId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<String> get peerHandle => $composableBuilder(
    column: $table.peerHandle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get encryptedContent => $composableBuilder(
    column: $table.encryptedContent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get isRead =>
      $composableBuilder(column: $table.isRead, builder: (column) => column);

  GeneratedColumn<bool> get vaultSynced => $composableBuilder(
    column: $table.vaultSynced,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get verified =>
      $composableBuilder(column: $table.verified, builder: (column) => column);

  GeneratedColumn<String> get referencedMessageId => $composableBuilder(
    column: $table.referencedMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverMessageId => $composableBuilder(
    column: $table.serverMessageId,
    builder: (column) => column,
  );
}

class $$MessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessagesTable,
          Message,
          $$MessagesTableFilterComposer,
          $$MessagesTableOrderingComposer,
          $$MessagesTableAnnotationComposer,
          $$MessagesTableCreateCompanionBuilder,
          $$MessagesTableUpdateCompanionBuilder,
          (Message, BaseReferences<_$AppDatabase, $MessagesTable, Message>),
          Message,
          PrefetchHooks Function()
        > {
  $$MessagesTableTableManager(_$AppDatabase db, $MessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String> senderId = const Value.absent(),
                Value<String> peerHandle = const Value.absent(),
                Value<String> encryptedContent = const Value.absent(),
                Value<String> direction = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> isRead = const Value.absent(),
                Value<bool> vaultSynced = const Value.absent(),
                Value<bool> verified = const Value.absent(),
                Value<String?> referencedMessageId = const Value.absent(),
                Value<String?> serverMessageId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                ownerId: ownerId,
                senderId: senderId,
                peerHandle: peerHandle,
                encryptedContent: encryptedContent,
                direction: direction,
                type: type,
                createdAt: createdAt,
                isRead: isRead,
                vaultSynced: vaultSynced,
                verified: verified,
                referencedMessageId: referencedMessageId,
                serverMessageId: serverMessageId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ownerId,
                required String senderId,
                required String peerHandle,
                required String encryptedContent,
                required String direction,
                Value<String> type = const Value.absent(),
                required DateTime createdAt,
                Value<bool> isRead = const Value.absent(),
                Value<bool> vaultSynced = const Value.absent(),
                Value<bool> verified = const Value.absent(),
                Value<String?> referencedMessageId = const Value.absent(),
                Value<String?> serverMessageId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion.insert(
                id: id,
                ownerId: ownerId,
                senderId: senderId,
                peerHandle: peerHandle,
                encryptedContent: encryptedContent,
                direction: direction,
                type: type,
                createdAt: createdAt,
                isRead: isRead,
                vaultSynced: vaultSynced,
                verified: verified,
                referencedMessageId: referencedMessageId,
                serverMessageId: serverMessageId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessagesTable,
      Message,
      $$MessagesTableFilterComposer,
      $$MessagesTableOrderingComposer,
      $$MessagesTableAnnotationComposer,
      $$MessagesTableCreateCompanionBuilder,
      $$MessagesTableUpdateCompanionBuilder,
      (Message, BaseReferences<_$AppDatabase, $MessagesTable, Message>),
      Message,
      PrefetchHooks Function()
    >;
typedef $$SyncStateTableCreateCompanionBuilder =
    SyncStateCompanion Function({
      required String ownerId,
      required String cursorType,
      required String cursorValue,
      required DateTime lastSyncAt,
      Value<int> rowid,
    });
typedef $$SyncStateTableUpdateCompanionBuilder =
    SyncStateCompanion Function({
      Value<String> ownerId,
      Value<String> cursorType,
      Value<String> cursorValue,
      Value<DateTime> lastSyncAt,
      Value<int> rowid,
    });

class $$SyncStateTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cursorType => $composableBuilder(
    column: $table.cursorType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cursorValue => $composableBuilder(
    column: $table.cursorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cursorType => $composableBuilder(
    column: $table.cursorType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cursorValue => $composableBuilder(
    column: $table.cursorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get cursorType => $composableBuilder(
    column: $table.cursorType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cursorValue => $composableBuilder(
    column: $table.cursorValue,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => column,
  );
}

class $$SyncStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStateTable,
          SyncStateData,
          $$SyncStateTableFilterComposer,
          $$SyncStateTableOrderingComposer,
          $$SyncStateTableAnnotationComposer,
          $$SyncStateTableCreateCompanionBuilder,
          $$SyncStateTableUpdateCompanionBuilder,
          (
            SyncStateData,
            BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateData>,
          ),
          SyncStateData,
          PrefetchHooks Function()
        > {
  $$SyncStateTableTableManager(_$AppDatabase db, $SyncStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ownerId = const Value.absent(),
                Value<String> cursorType = const Value.absent(),
                Value<String> cursorValue = const Value.absent(),
                Value<DateTime> lastSyncAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStateCompanion(
                ownerId: ownerId,
                cursorType: cursorType,
                cursorValue: cursorValue,
                lastSyncAt: lastSyncAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerId,
                required String cursorType,
                required String cursorValue,
                required DateTime lastSyncAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncStateCompanion.insert(
                ownerId: ownerId,
                cursorType: cursorType,
                cursorValue: cursorValue,
                lastSyncAt: lastSyncAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStateTable,
      SyncStateData,
      $$SyncStateTableFilterComposer,
      $$SyncStateTableOrderingComposer,
      $$SyncStateTableAnnotationComposer,
      $$SyncStateTableCreateCompanionBuilder,
      $$SyncStateTableUpdateCompanionBuilder,
      (
        SyncStateData,
        BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateData>,
      ),
      SyncStateData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
}
