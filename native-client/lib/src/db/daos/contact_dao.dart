// Contact Data Access Object.

import 'package:sqflite/sqflite.dart';

import '../database.dart';
import '../models/contact.dart';

/// Data access object for contacts.
class ContactDao {
  final AppDatabase _appDb;

  ContactDao([AppDatabase? db]) : _appDb = db ?? AppDatabase();

  /// Get all contacts.
  Future<List<Contact>> getAllContacts() async {
    final db = await _appDb.database;
    final results = await db.query(
      'contacts',
      orderBy: 'display_name ASC, handle ASC',
    );
    return results.map((row) => Contact.fromMap(row)).toList();
  }

  /// Get contact by ID.
  Future<Contact?> getContactById(String id) async {
    final db = await _appDb.database;
    final results = await db.query(
      'contacts',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) {
      return null;
    }

    return Contact.fromMap(results.first);
  }

  /// Get contact by handle.
  Future<Contact?> getContactByHandle(String handle) async {
    final db = await _appDb.database;
    final results = await db.query(
      'contacts',
      where: 'handle = ?',
      whereArgs: [handle],
    );

    if (results.isEmpty) {
      return null;
    }

    return Contact.fromMap(results.first);
  }

  /// Insert a new contact.
  Future<void> insertContact(Contact contact) async {
    final db = await _appDb.database;
    await db.insert(
      'contacts',
      contact.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update an existing contact.
  Future<void> updateContact(Contact contact) async {
    final db = await _appDb.database;
    await db.update(
      'contacts',
      contact.toMap(),
      where: 'id = ?',
      whereArgs: [contact.id],
    );
  }

  /// Delete a contact.
  Future<void> deleteContact(String id) async {
    final db = await _appDb.database;
    await db.delete(
      'contacts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete a contact by handle.
  Future<void> deleteContactByHandle(String handle) async {
    final db = await _appDb.database;
    await db.delete(
      'contacts',
      where: 'handle = ?',
      whereArgs: [handle],
    );
  }

  /// Search contacts by name or handle.
  Future<List<Contact>> searchContacts(String query) async {
    final db = await _appDb.database;
    final results = await db.query(
      'contacts',
      where: 'handle LIKE ? OR display_name LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'display_name ASC, handle ASC',
    );
    return results.map((row) => Contact.fromMap(row)).toList();
  }

  /// Get contact count.
  Future<int> getContactCount() async {
    final db = await _appDb.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM contacts');
    return result.first['count'] as int;
  }
}
