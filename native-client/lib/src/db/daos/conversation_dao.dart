// Conversation Data Access Object.

import 'package:sqflite/sqflite.dart';

import '../database.dart';
import '../models/conversation.dart';

/// Data access object for conversations.
class ConversationDao {
  final AppDatabase _appDb;

  ConversationDao([AppDatabase? db]) : _appDb = db ?? AppDatabase();

  /// Get all conversations ordered by last message time.
  Future<List<Conversation>> getAllConversations() async {
    final db = await _appDb.database;
    final results = await db.query(
      'conversations',
      orderBy: 'last_message_time DESC',
    );
    return results.map((row) => Conversation.fromMap(row)).toList();
  }

  /// Get a conversation by ID.
  Future<Conversation?> getConversationById(String id) async {
    final db = await _appDb.database;
    final results = await db.query(
      'conversations',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) {
      return null;
    }

    return Conversation.fromMap(results.first);
  }

  /// Get conversation by participant handle.
  Future<Conversation?> getConversationByParticipant(String handle) async {
    final db = await _appDb.database;
    final results = await db.query(
      'conversations',
      where: 'participant_handle = ?',
      whereArgs: [handle],
    );

    if (results.isEmpty) {
      return null;
    }

    return Conversation.fromMap(results.first);
  }

  /// Insert or update a conversation.
  Future<void> upsertConversation(Conversation conversation) async {
    final db = await _appDb.database;
    await db.insert(
      'conversations',
      conversation.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update conversation with new message info.
  Future<void> updateLastMessage({
    required String conversationId,
    required String messageId,
    required String preview,
    required DateTime time,
  }) async {
    final db = await _appDb.database;
    await db.update(
      'conversations',
      {
        'last_message_id': messageId,
        'last_message_preview': preview,
        'last_message_time': time.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  /// Increment unread count for a conversation.
  Future<void> incrementUnreadCount(String conversationId) async {
    final db = await _appDb.database;
    await db.rawUpdate(
      'UPDATE conversations SET unread_count = unread_count + 1 WHERE id = ?',
      [conversationId],
    );
  }

  /// Mark all messages in a conversation as read.
  Future<void> markAsRead(String conversationId) async {
    final db = await _appDb.database;
    await db.update(
      'conversations',
      {'unread_count': 0},
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  /// Delete a conversation.
  Future<void> deleteConversation(String id) async {
    final db = await _appDb.database;
    // Messages are deleted via CASCADE
    await db.delete(
      'conversations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get total unread count across all conversations.
  Future<int> getTotalUnreadCount() async {
    final db = await _appDb.database;
    final result = await db.rawQuery(
      'SELECT SUM(unread_count) as total FROM conversations',
    );
    return (result.first['total'] as int?) ?? 0;
  }

  /// Get conversation count.
  Future<int> getConversationCount() async {
    final db = await _appDb.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM conversations',
    );
    return result.first['count'] as int;
  }

  /// Get or create a conversation for a participant.
  Future<Conversation> getOrCreateConversation(String participantHandle) async {
    var conversation = await getConversationByParticipant(participantHandle);
    if (conversation != null) {
      return conversation;
    }

    // Create new conversation
    conversation = Conversation(
      id: participantHandle, // Use handle as ID for simplicity
      participantHandle: participantHandle,
    );
    await upsertConversation(conversation);
    return conversation;
  }
}
