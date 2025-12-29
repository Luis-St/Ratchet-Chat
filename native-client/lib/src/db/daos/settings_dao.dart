// Settings Data Access Object.

import 'package:sqflite/sqflite.dart';

import '../database.dart';

/// Data access object for settings (key-value store).
class SettingsDao {
  final AppDatabase _appDb;

  SettingsDao([AppDatabase? db]) : _appDb = db ?? AppDatabase();

  /// Get a setting value.
  Future<String?> get(String key) async {
    final db = await _appDb.database;
    final results = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );

    if (results.isEmpty) {
      return null;
    }

    return results.first['value'] as String?;
  }

  /// Set a setting value.
  Future<void> set(String key, String value) async {
    final db = await _appDb.database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Delete a setting.
  Future<void> delete(String key) async {
    final db = await _appDb.database;
    await db.delete(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  /// Get all settings.
  Future<Map<String, String>> getAll() async {
    final db = await _appDb.database;
    final results = await db.query('settings');

    final settings = <String, String>{};
    for (final row in results) {
      final key = row['key'] as String;
      final value = row['value'] as String?;
      if (value != null) {
        settings[key] = value;
      }
    }
    return settings;
  }

  /// Clear all settings.
  Future<void> clear() async {
    final db = await _appDb.database;
    await db.delete('settings');
  }

  // ============== Convenience methods for common settings ==============

  /// Get theme mode (light, dark, system).
  Future<String> getThemeMode() async {
    return await get('theme_mode') ?? 'system';
  }

  /// Set theme mode.
  Future<void> setThemeMode(String mode) async {
    await set('theme_mode', mode);
  }

  /// Get notification enabled state.
  Future<bool> getNotificationsEnabled() async {
    final value = await get('notifications_enabled');
    return value != 'false'; // Default true
  }

  /// Set notification enabled state.
  Future<void> setNotificationsEnabled(bool enabled) async {
    await set('notifications_enabled', enabled.toString());
  }

  /// Get sound enabled state.
  Future<bool> getSoundEnabled() async {
    final value = await get('sound_enabled');
    return value != 'false'; // Default true
  }

  /// Set sound enabled state.
  Future<void> setSoundEnabled(bool enabled) async {
    await set('sound_enabled', enabled.toString());
  }

  /// Get vibration enabled state.
  Future<bool> getVibrationEnabled() async {
    final value = await get('vibration_enabled');
    return value != 'false'; // Default true
  }

  /// Set vibration enabled state.
  Future<void> setVibrationEnabled(bool enabled) async {
    await set('vibration_enabled', enabled.toString());
  }

  /// Get last sync timestamp.
  Future<DateTime?> getLastSyncTime() async {
    final value = await get('last_sync_time');
    if (value == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(int.parse(value));
  }

  /// Set last sync timestamp.
  Future<void> setLastSyncTime(DateTime time) async {
    await set('last_sync_time', time.millisecondsSinceEpoch.toString());
  }
}
