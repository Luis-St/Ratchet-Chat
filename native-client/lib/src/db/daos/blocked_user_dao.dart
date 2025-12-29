// Blocked User Data Access Object.

import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../database.dart';

/// Represents a blocked user entry.
class BlockedUser {
  final int? id;
  final Uint8List encryptedUserId;

  BlockedUser({this.id, required this.encryptedUserId});

  factory BlockedUser.fromMap(Map<String, dynamic> map) {
    return BlockedUser(
      id: map['id'] as int?,
      encryptedUserId: map['encrypted_user_id'] as Uint8List,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'encrypted_user_id': encryptedUserId,
    };
  }
}

/// Data access object for blocked users.
///
/// User IDs are stored encrypted to maintain privacy even if the
/// database is compromised.
class BlockedUserDao {
  final AppDatabase _appDb;

  BlockedUserDao([AppDatabase? db]) : _appDb = db ?? AppDatabase();

  /// Get all blocked user entries.
  Future<List<BlockedUser>> getAllBlocked() async {
    final db = await _appDb.database;
    final results = await db.query('blocked_users');
    return results.map((row) => BlockedUser.fromMap(row)).toList();
  }

  /// Add a blocked user (encrypted user ID).
  Future<int> addBlocked(Uint8List encryptedUserId) async {
    final db = await _appDb.database;
    return await db.insert(
      'blocked_users',
      {'encrypted_user_id': encryptedUserId},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Remove a blocked user by encrypted user ID.
  Future<void> removeBlocked(Uint8List encryptedUserId) async {
    final db = await _appDb.database;
    await db.delete(
      'blocked_users',
      where: 'encrypted_user_id = ?',
      whereArgs: [encryptedUserId],
    );
  }

  /// Remove a blocked user by ID.
  Future<void> removeBlockedById(int id) async {
    final db = await _appDb.database;
    await db.delete(
      'blocked_users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Check if an encrypted user ID is in the blocked list.
  Future<bool> isBlocked(Uint8List encryptedUserId) async {
    final db = await _appDb.database;
    final results = await db.query(
      'blocked_users',
      where: 'encrypted_user_id = ?',
      whereArgs: [encryptedUserId],
    );
    return results.isNotEmpty;
  }

  /// Get blocked user count.
  Future<int> getBlockedCount() async {
    final db = await _appDb.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM blocked_users',
    );
    return result.first['count'] as int;
  }

  /// Clear all blocked users.
  Future<void> clearAll() async {
    final db = await _appDb.database;
    await db.delete('blocked_users');
  }
}
