// SQLite database setup with migrations.

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Database version for migrations.
const int _databaseVersion = 1;

/// Database name.
const String _databaseName = 'ratchet_chat.db';

/// Singleton database instance.
class AppDatabase {
  static Database? _database;
  static final AppDatabase _instance = AppDatabase._internal();

  factory AppDatabase() => _instance;

  AppDatabase._internal();

  /// Get the database instance, creating it if necessary.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the database.
  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  /// Configure database settings.
  Future<void> _onConfigure(Database db) async {
    // Enable foreign keys
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Create database tables.
  Future<void> _onCreate(Database db, int version) async {
    // Auth state table (singleton)
    await db.execute('''
      CREATE TABLE auth (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        user_id TEXT,
        handle TEXT,
        session_token TEXT,
        identity_public_key BLOB,
        transport_public_key BLOB,
        passkey_credential_id TEXT,
        logged_in INTEGER DEFAULT 0
      )
    ''');

    // Initialize with empty row
    await db.execute('''
      INSERT INTO auth (id, logged_in) VALUES (1, 0)
    ''');

    // Contacts table
    await db.execute('''
      CREATE TABLE contacts (
        id TEXT PRIMARY KEY,
        handle TEXT NOT NULL UNIQUE,
        display_name TEXT,
        identity_public_key BLOB,
        transport_public_key BLOB,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Create index for handle lookups
    await db.execute('''
      CREATE INDEX idx_contacts_handle ON contacts(handle)
    ''');

    // Conversations table
    await db.execute('''
      CREATE TABLE conversations (
        id TEXT PRIMARY KEY,
        participant_handle TEXT NOT NULL,
        last_message_id TEXT,
        last_message_preview TEXT,
        last_message_time INTEGER,
        unread_count INTEGER DEFAULT 0
      )
    ''');

    // Create index for participant lookups
    await db.execute('''
      CREATE INDEX idx_conversations_participant ON conversations(participant_handle)
    ''');

    // Messages table
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        sender_handle TEXT NOT NULL,
        recipient_handle TEXT NOT NULL,
        encrypted_content BLOB NOT NULL,
        timestamp INTEGER NOT NULL,
        status TEXT DEFAULT 'sent',
        FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for message queries
    await db.execute('''
      CREATE INDEX idx_messages_conversation ON messages(conversation_id, timestamp DESC)
    ''');
    await db.execute('''
      CREATE INDEX idx_messages_sender ON messages(sender_handle)
    ''');

    // Blocked users table (encrypted user IDs)
    await db.execute('''
      CREATE TABLE blocked_users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        encrypted_user_id BLOB NOT NULL UNIQUE
      )
    ''');

    // Settings table (key-value store)
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  /// Handle database upgrades.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Add migration logic here for future versions
    // Example:
    // if (oldVersion < 2) {
    //   await db.execute('ALTER TABLE users ADD COLUMN new_column TEXT');
    // }
  }

  /// Close the database.
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Delete the database (for logout/account deletion).
  Future<void> deleteDatabase() async {
    await close();
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    await databaseFactory.deleteDatabase(path);
  }

  /// Reset database to initial state (keeps structure, clears data).
  Future<void> reset() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('messages');
      await txn.delete('conversations');
      await txn.delete('contacts');
      await txn.delete('blocked_users');
      await txn.delete('settings');
      await txn.update('auth', {
        'user_id': null,
        'handle': null,
        'session_token': null,
        'identity_public_key': null,
        'transport_public_key': null,
        'passkey_credential_id': null,
        'logged_in': 0,
      });
    });
  }
}
