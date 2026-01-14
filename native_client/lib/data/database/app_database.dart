import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

/// Messages table - stores all encrypted messages locally
class Messages extends Table {
  /// Unique message ID (UUID)
  TextColumn get id => text()();

  /// Owner's user ID (for multi-account support)
  TextColumn get ownerId => text()();

  /// Sender's handle (e.g., "user@server.com")
  TextColumn get senderId => text()();

  /// The other participant's handle (peer in conversation)
  TextColumn get peerHandle => text()();

  /// Encrypted content as JSON: { "encrypted_blob": "...", "iv": "..." }
  TextColumn get encryptedContent => text()();

  /// Message direction: "in" or "out"
  TextColumn get direction => text()();

  /// Message type: "message", "edit", "delete", "reaction", "receipt", "unsupported"
  TextColumn get type => text().withDefault(const Constant('message'))();

  /// When the message was created
  DateTimeColumn get createdAt => dateTime()();

  /// Whether the message has been read
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();

  /// Whether the message has been synced to the vault
  BoolColumn get vaultSynced => boolean().withDefault(const Constant(false))();

  /// Whether the signature was verified
  BoolColumn get verified => boolean().withDefault(const Constant(true))();

  /// Reference to original message (for edits, deletes, reactions)
  TextColumn get referencedMessageId => text().nullable()();

  /// Server-provided message ID (for vault sync tracking)
  TextColumn get serverMessageId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Sync state table - tracks vault sync cursors
class SyncState extends Table {
  /// Owner's user ID
  TextColumn get ownerId => text()();

  /// Sync cursor type (e.g., "vault_cursor")
  TextColumn get cursorType => text()();

  /// Current cursor value
  TextColumn get cursorValue => text()();

  /// Last sync timestamp
  DateTimeColumn get lastSyncAt => dateTime()();

  @override
  Set<Column> get primaryKey => {ownerId, cursorType};
}

/// Database class with all tables
@DriftDatabase(tables: [Messages, SyncState])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // ============ Message Operations ============

  /// Insert or update a message
  Future<void> upsertMessage(MessagesCompanion message) async {
    await into(messages).insertOnConflictUpdate(message);
  }

  /// Get messages for a conversation with pagination
  Future<List<Message>> getConversationMessages(
    String ownerId,
    String peerHandle, {
    int limit = 50,
    int offset = 0,
  }) async {
    return (select(messages)
          ..where((m) => m.ownerId.equals(ownerId) & m.peerHandle.equals(peerHandle))
          ..where((m) => m.type.equals('message') | m.type.equals('unsupported'))
          ..orderBy([(m) => OrderingTerm.desc(m.createdAt)])
          ..limit(limit, offset: offset))
        .get();
  }

  /// Get all conversations with last message for an owner
  Future<List<ConversationSummary>> getConversations(String ownerId) async {
    // Get latest message per peer
    final query = customSelect(
      '''
      SELECT m.*
      FROM messages m
      INNER JOIN (
        SELECT peer_handle, MAX(created_at) as max_created
        FROM messages
        WHERE owner_id = ? AND (type = 'message' OR type = 'unsupported')
        GROUP BY peer_handle
      ) latest ON m.peer_handle = latest.peer_handle AND m.created_at = latest.max_created
      WHERE m.owner_id = ? AND (m.type = 'message' OR m.type = 'unsupported')
      ORDER BY m.created_at DESC
      ''',
      variables: [Variable.withString(ownerId), Variable.withString(ownerId)],
      readsFrom: {messages},
    );

    final rows = await query.get();
    final summaries = <ConversationSummary>[];

    for (final row in rows) {
      final peerHandle = row.read<String>('peer_handle');
      final unreadCount = await _getUnreadCount(ownerId, peerHandle);

      summaries.add(ConversationSummary(
        peerHandle: peerHandle,
        lastMessageId: row.read<String>('id'),
        lastMessageEncryptedContent: row.read<String>('encrypted_content'),
        lastMessageDirection: row.read<String>('direction'),
        lastMessageCreatedAt: row.read<DateTime>('created_at'),
        unreadCount: unreadCount,
      ));
    }

    return summaries;
  }

  Future<int> _getUnreadCount(String ownerId, String peerHandle) async {
    final count = await (selectOnly(messages)
          ..addColumns([messages.id.count()])
          ..where(messages.ownerId.equals(ownerId) &
              messages.peerHandle.equals(peerHandle) &
              messages.direction.equals('in') &
              messages.isRead.equals(false) &
              (messages.type.equals('message') | messages.type.equals('unsupported'))))
        .getSingle();
    return count.read<int>(messages.id.count()) ?? 0;
  }

  /// Mark all messages from a peer as read
  Future<void> markAsRead(String ownerId, String peerHandle) async {
    await (update(messages)
          ..where((m) =>
              m.ownerId.equals(ownerId) &
              m.peerHandle.equals(peerHandle) &
              m.direction.equals('in') &
              m.isRead.equals(false)))
        .write(const MessagesCompanion(isRead: Value(true)));
  }

  /// Get unread count for a peer
  Future<int> getUnreadCount(String ownerId, String peerHandle) async {
    return _getUnreadCount(ownerId, peerHandle);
  }

  /// Get total unread count for all conversations
  Future<int> getTotalUnreadCount(String ownerId) async {
    final count = await (selectOnly(messages)
          ..addColumns([messages.id.count()])
          ..where(messages.ownerId.equals(ownerId) &
              messages.direction.equals('in') &
              messages.isRead.equals(false) &
              (messages.type.equals('message') | messages.type.equals('unsupported'))))
        .getSingle();
    return count.read<int>(messages.id.count()) ?? 0;
  }

  /// Delete a message by ID
  Future<void> deleteMessage(String id) async {
    await (delete(messages)..where((m) => m.id.equals(id))).go();
  }

  /// Update vault synced status
  Future<void> updateVaultSynced(String id, bool synced) async {
    await (update(messages)..where((m) => m.id.equals(id)))
        .write(MessagesCompanion(vaultSynced: Value(synced)));
  }

  /// Get messages not yet synced to vault
  Future<List<Message>> getUnsyncedMessages(String ownerId) async {
    return (select(messages)
          ..where((m) => m.ownerId.equals(ownerId) & m.vaultSynced.equals(false))
          ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
        .get();
  }

  /// Get a message by ID
  Future<Message?> getMessageById(String id) async {
    return (select(messages)..where((m) => m.id.equals(id))).getSingleOrNull();
  }

  /// Check if a message exists
  Future<bool> messageExists(String id) async {
    final msg = await getMessageById(id);
    return msg != null;
  }

  // ============ Sync State Operations ============

  /// Get sync cursor
  Future<String?> getSyncCursor(String ownerId, String cursorType) async {
    final result = await (select(syncState)
          ..where((s) => s.ownerId.equals(ownerId) & s.cursorType.equals(cursorType)))
        .getSingleOrNull();
    return result?.cursorValue;
  }

  /// Update sync cursor
  Future<void> updateSyncCursor(String ownerId, String cursorType, String value) async {
    await into(syncState).insertOnConflictUpdate(SyncStateCompanion(
      ownerId: Value(ownerId),
      cursorType: Value(cursorType),
      cursorValue: Value(value),
      lastSyncAt: Value(DateTime.now()),
    ));
  }

  // ============ Cleanup Operations ============

  /// Delete all data for an owner (on logout)
  Future<void> clearOwnerData(String ownerId) async {
    await (delete(messages)..where((m) => m.ownerId.equals(ownerId))).go();
    await (delete(syncState)..where((s) => s.ownerId.equals(ownerId))).go();
  }

  /// Delete all data (full reset)
  Future<void> clearAllData() async {
    await delete(messages).go();
    await delete(syncState).go();
  }
}

/// Summary of a conversation for list display
class ConversationSummary {
  final String peerHandle;
  final String lastMessageId;
  final String lastMessageEncryptedContent;
  final String lastMessageDirection;
  final DateTime lastMessageCreatedAt;
  final int unreadCount;

  ConversationSummary({
    required this.peerHandle,
    required this.lastMessageId,
    required this.lastMessageEncryptedContent,
    required this.lastMessageDirection,
    required this.lastMessageCreatedAt,
    required this.unreadCount,
  });
}

/// Opens a connection to the database
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'ratchet_chat.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
