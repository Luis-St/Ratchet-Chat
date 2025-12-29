// Contacts state management.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../api/api.dart';
import '../db/db.dart';

/// Contacts provider for managing user contacts.
class ContactsProvider extends ChangeNotifier {
  final DirectoryApi _directoryApi;
  final ContactDao _contactDao;

  List<Contact> _contacts = [];
  bool _isLoading = false;
  String? _error;

  ContactsProvider({
    required DirectoryApi directoryApi,
    ContactDao? contactDao,
  })  : _directoryApi = directoryApi,
        _contactDao = contactDao ?? ContactDao();

  /// All contacts.
  List<Contact> get contacts => List.unmodifiable(_contacts);

  /// Loading state.
  bool get isLoading => _isLoading;

  /// Last error.
  String? get error => _error;

  // ============== State Management ==============

  void _setLoading(bool loading) {
    _isLoading = loading;
    _error = null;
    notifyListeners();
  }

  void _setError(String error) {
    _isLoading = false;
    _error = error;
    notifyListeners();
  }

  // ============== Initialization ==============

  /// Load contacts from local database.
  Future<void> loadContacts() async {
    _setLoading(true);

    try {
      _contacts = await _contactDao.getAllContacts();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _setError('Failed to load contacts: $e');
    }
  }

  // ============== Contact Lookup ==============

  /// Lookup a user by handle and add as contact.
  Future<Contact?> lookupAndAddContact(String handle) async {
    _setLoading(true);

    try {
      // Check if already a contact
      final existing = await _contactDao.getContactByHandle(handle);
      if (existing != null) {
        _isLoading = false;
        notifyListeners();
        return existing;
      }

      // Lookup in directory
      final lookup = await _directoryApi.lookupUser(handle);

      // Create contact
      final contact = Contact(
        id: lookup.userId,
        handle: lookup.handle,
        identityPublicKey: base64Decode(lookup.identityPublicKey),
        transportPublicKey: base64Decode(lookup.transportPublicKey),
      );

      // Save to database
      await _contactDao.insertContact(contact);

      // Reload contacts
      await loadContacts();

      return contact;
    } catch (e) {
      _setError('Failed to lookup contact: $e');
      return null;
    }
  }

  /// Get a contact by handle (from local cache or database).
  Future<Contact?> getContactByHandle(String handle) async {
    // Check cache first
    final cached = _contacts.where((c) => c.handle == handle).firstOrNull;
    if (cached != null) return cached;

    // Check database
    return await _contactDao.getContactByHandle(handle);
  }

  /// Get a contact by ID.
  Future<Contact?> getContactById(String id) async {
    // Check cache first
    final cached = _contacts.where((c) => c.id == id).firstOrNull;
    if (cached != null) return cached;

    // Check database
    return await _contactDao.getContactById(id);
  }

  // ============== Contact Management ==============

  /// Add a contact manually.
  Future<void> addContact(Contact contact) async {
    try {
      await _contactDao.insertContact(contact);
      await loadContacts();
    } catch (e) {
      _setError('Failed to add contact: $e');
    }
  }

  /// Update a contact's display name.
  Future<void> updateContactDisplayName(String handle, String displayName) async {
    try {
      final contact = await _contactDao.getContactByHandle(handle);
      if (contact == null) {
        _setError('Contact not found');
        return;
      }

      final updated = contact.copyWith(displayName: displayName);
      await _contactDao.updateContact(updated);
      await loadContacts();
    } catch (e) {
      _setError('Failed to update contact: $e');
    }
  }

  /// Remove a contact.
  Future<void> removeContact(String handle) async {
    try {
      await _contactDao.deleteContactByHandle(handle);
      await loadContacts();
    } catch (e) {
      _setError('Failed to remove contact: $e');
    }
  }

  // ============== Search ==============

  /// Search contacts by name or handle.
  Future<List<Contact>> searchContacts(String query) async {
    if (query.isEmpty) return _contacts;
    return await _contactDao.searchContacts(query);
  }

  /// Refresh contact's keys from server.
  Future<void> refreshContactKeys(String handle) async {
    try {
      final lookup = await _directoryApi.lookupUser(handle);
      final contact = await _contactDao.getContactByHandle(handle);

      if (contact == null) return;

      final updated = contact.copyWith(
        identityPublicKey: base64Decode(lookup.identityPublicKey),
        transportPublicKey: base64Decode(lookup.transportPublicKey),
      );

      await _contactDao.updateContact(updated);
      await loadContacts();
    } catch (e) {
      _setError('Failed to refresh contact keys: $e');
    }
  }
}
