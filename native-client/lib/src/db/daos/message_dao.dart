// Message Data Access Object.

import 'package:sqflite/sqflite.dart';

import '../database.dart';
import '../models/message.dart';

/// Data access object for messages.
class MessageDao {
  final AppDatabase _appDb;

  MessageDao([AppDatabase? db]) : _appDb = db ?? AppDatabase();

  /// Get messages for a conversation.
  Future<List<Message>> getMessagesForConversation(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await _appDb.database;
    final results = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
    return results.map((row) => Message.fromMap(row)).toList();
  }

  /// Get a message by ID.
  Future<Message?> getMessageById(String id) async {
    final db = await _appDb.database;
    final results = await db.query(
      'messages',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) {
      return null;
    }

    return Message.fromMap(results.first);
  }

  /// Insert a new message.
  Future<void> insertMessage(Message message) async {
    final db = await _appDb.database;
    await db.insert(
      'messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert multiple messages.
  Future<void> insertMessages(List<Message> messages) async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      for (final message in messages) {
        await txn.insert(
          'messages',
          message.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Update message status.
  Future<void> updateMessageStatus(String id, MessageStatus status) async {
    final db = await _appDb.database;
    await db.update(
      'messages',
      {'status': status.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete a message.
  Future<void> deleteMessage(String id) async {
    final db = await _appDb.database;
    await db.delete(
      'messages',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete all messages for a conversation.
  Future<void> deleteMessagesForConversation(String conversationId) async {
    final db = await _appDb.database;
    await db.delete(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
  }

  /// Get the latest message for a conversation.
  Future<Message?> getLatestMessage(String conversationId) async {
    final db = await _appDb.database;
    final results = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'timestamp DESC',
      limit: 1,
    );

    if (results.isEmpty) {
      return null;
    }

    return Message.fromMap(results.first);
  }

  /// Get message count for a conversation.
  Future<int> getMessageCount(String conversationId) async {
    final db = await _appDb.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM messages WHERE conversation_id = ?',
      [conversationId],
    );
    return result.first['count'] as int;
  }

  /// Search messages by content.
  /// Note: This searches encrypted content, so it only works for metadata searches.
  Future<List<Message>> searchMessages(String query) async {
    final db = await _appDb.database;
    final results = await db.query(
      'messages',
      where: 'sender_handle LIKE ? OR recipient_handle LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'timestamp DESC',
      limit: 100,
    );
    return results.map((row) => Message.fromMap(row)).toList();
  }
}
