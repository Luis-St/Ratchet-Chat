import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../core/errors/auth_exceptions.dart';
import '../models/contact.dart';
import '../models/user_session.dart';
import '../services/api_service.dart';
import '../services/crypto_service.dart';
import '../services/directory_service.dart';
import '../services/secure_storage_service.dart';

/// Repository for contact operations.
class ContactsRepository {
  ContactsRepository({
    required ApiService apiService,
    required CryptoService cryptoService,
    required SecureStorageService storageService,
    required DirectoryService directoryService,
  }) : _apiService = apiService,
       _cryptoService = cryptoService,
       _storageService = storageService,
       _directoryService = directoryService;

  final ApiService _apiService;
  final CryptoService _cryptoService;
  final SecureStorageService _storageService;
  final DirectoryService _directoryService;

  /// Fetches contacts from the server and decrypts them.
  ///
  /// Returns an empty list if no contacts are stored.
  Future<List<Contact>> fetchContacts(Uint8List masterKey) async {
    try {
      final response = await _apiService.get('/auth/contacts');

      final ciphertext = response['ciphertext'] as String?;
      final iv = response['iv'] as String?;

      // No contacts stored yet
      if (ciphertext == null || iv == null) {
        return [];
      }

      // Decrypt the contacts payload
      final payload = EncryptedPayload(ciphertext: ciphertext, iv: iv);
      final decrypted = _cryptoService.decrypt(payload, masterKey);
      final json = jsonDecode(utf8.decode(decrypted)) as Map<String, dynamic>;

      final contactsJson = json['contacts'] as List<dynamic>? ?? [];
      final contacts = contactsJson
          .map((c) => Contact.fromJson(c as Map<String, dynamic>))
          .toList();

      // Sort by display name
      contacts.sort((a, b) => a.effectiveDisplayName.toLowerCase().compareTo(
            b.effectiveDisplayName.toLowerCase(),
          ));

      // Cache locally
      await _cacheContacts(contacts, masterKey);

      return contacts;
    } on SessionExpiredException {
      rethrow;
    } on NetworkException catch (e) {
      // Try to load from cache if network fails
      debugPrint('ContactsRepository: Network error fetching contacts: $e');
      return _loadCachedContacts(masterKey);
    } catch (e, stackTrace) {
      // Try to load from cache on error
      debugPrint('ContactsRepository: Error fetching contacts: $e');
      debugPrint('ContactsRepository: Stack trace: $stackTrace');
      return _loadCachedContacts(masterKey);
    }
  }

  /// Looks up a user by handle and creates a Contact.
  ///
  /// Throws [ContactNotFoundException] if user not found.
  /// Throws [InvalidHandleException] if handle format is invalid.
  Future<Contact> lookupContact(String handle) async {
    final result = await _directoryService.lookupHandle(handle);

    final parsed = DirectoryService.parseHandle(result.handle);
    if (parsed == null) {
      throw const InvalidHandleException();
    }

    return Contact(
      handle: result.handle,
      username: parsed.username,
      host: parsed.host,
      publicIdentityKey: result.publicIdentityKey,
      publicTransportKey: result.publicTransportKey,
      displayName: result.displayName,
      avatarFilename: result.avatarFilename,
      createdAt: DateTime.now(),
    );
  }

  /// Adds a contact by handle.
  ///
  /// Looks up the user in the directory, creates the contact,
  /// and syncs to the server.
  ///
  /// Returns the list of all contacts after adding.
  Future<List<Contact>> addContactByHandle({
    required String handle,
    required Uint8List masterKey,
    required List<Contact> existingContacts,
  }) async {
    // Check if contact already exists
    final normalizedHandle = handle.trim().toLowerCase();
    final exists = existingContacts.any(
      (c) => c.handle.toLowerCase() == normalizedHandle ||
             (normalizedHandle.contains('@') == false &&
              c.username.toLowerCase() == normalizedHandle),
    );
    if (exists) {
      throw const ContactAlreadyExistsException();
    }

    // Look up the contact
    final contact = await lookupContact(handle);

    // Check again with the resolved handle
    final resolvedExists = existingContacts.any(
      (c) => c.handle.toLowerCase() == contact.handle.toLowerCase(),
    );
    if (resolvedExists) {
      throw const ContactAlreadyExistsException();
    }

    // Add to list
    final updatedContacts = [...existingContacts, contact];

    // Sync to server
    await _syncToServer(updatedContacts, masterKey);

    // Sort and return
    updatedContacts.sort((a, b) => a.effectiveDisplayName.toLowerCase().compareTo(
          b.effectiveDisplayName.toLowerCase(),
        ));

    return updatedContacts;
  }

  /// Removes a contact by handle.
  ///
  /// Returns the list of all contacts after removal.
  Future<List<Contact>> removeContact({
    required String handle,
    required Uint8List masterKey,
    required List<Contact> existingContacts,
  }) async {
    final normalizedHandle = handle.trim().toLowerCase();

    final updatedContacts = existingContacts
        .where((c) => c.handle.toLowerCase() != normalizedHandle)
        .toList();

    // Sync to server
    await _syncToServer(updatedContacts, masterKey);

    return updatedContacts;
  }

  /// Updates a contact's nickname.
  ///
  /// Returns the list of all contacts after update.
  Future<List<Contact>> updateContactNickname({
    required String handle,
    required String? nickname,
    required Uint8List masterKey,
    required List<Contact> existingContacts,
  }) async {
    final normalizedHandle = handle.trim().toLowerCase();

    final updatedContacts = existingContacts.map((c) {
      if (c.handle.toLowerCase() == normalizedHandle) {
        return c.copyWith(nickname: nickname);
      }
      return c;
    }).toList();

    // Sync to server
    await _syncToServer(updatedContacts, masterKey);

    // Sort and return
    updatedContacts.sort((a, b) => a.effectiveDisplayName.toLowerCase().compareTo(
          b.effectiveDisplayName.toLowerCase(),
        ));

    return updatedContacts;
  }

  /// Syncs contacts to the server.
  Future<void> _syncToServer(
    List<Contact> contacts,
    Uint8List masterKey,
  ) async {
    // Serialize contacts
    final payload = {
      'contacts': contacts.map((c) => c.toJson()).toList(),
    };
    final plaintext = utf8.encode(jsonEncode(payload));

    // Encrypt
    final encrypted = _cryptoService.encrypt(
      Uint8List.fromList(plaintext),
      masterKey,
    );

    // Upload to server
    await _apiService.put('/auth/contacts', {
      'ciphertext': encrypted.ciphertext,
      'iv': encrypted.iv,
    });

    // Update local cache
    await _cacheContacts(contacts, masterKey);
  }

  /// Caches contacts locally.
  Future<void> _cacheContacts(
    List<Contact> contacts,
    Uint8List masterKey,
  ) async {
    final payload = {
      'contacts': contacts.map((c) => c.toJson()).toList(),
    };
    final plaintext = utf8.encode(jsonEncode(payload));

    final encrypted = _cryptoService.encrypt(
      Uint8List.fromList(plaintext),
      masterKey,
    );

    await _storageService.saveEncryptedContacts(
      encrypted.ciphertext,
      encrypted.iv,
    );
  }

  /// Loads contacts from local cache.
  Future<List<Contact>> _loadCachedContacts(Uint8List masterKey) async {
    try {
      final cached = await _storageService.getEncryptedContacts();
      if (cached == null) {
        return [];
      }

      final decrypted = _cryptoService.decrypt(cached, masterKey);
      final json = jsonDecode(utf8.decode(decrypted)) as Map<String, dynamic>;

      final contactsJson = json['contacts'] as List<dynamic>? ?? [];
      final contacts = contactsJson
          .map((c) => Contact.fromJson(c as Map<String, dynamic>))
          .toList();

      contacts.sort((a, b) => a.effectiveDisplayName.toLowerCase().compareTo(
            b.effectiveDisplayName.toLowerCase(),
          ));

      return contacts;
    } catch (_) {
      return [];
    }
  }

  /// Clears cached contacts (called on logout).
  Future<void> clearCache() async {
    await _storageService.clearEncryptedContacts();
  }
}
