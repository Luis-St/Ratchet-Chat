import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/auth_exceptions.dart';
import '../data/models/contact.dart';
import '../data/models/contacts_state.dart';
import '../data/repositories/contacts_repository.dart';
import 'service_providers.dart';

/// Notifier for managing contacts state.
class ContactsNotifier extends Notifier<ContactsState> {
  late final ContactsRepository _contactsRepository;

  @override
  ContactsState build() {
    _contactsRepository = ref.watch(contactsRepositoryProvider);
    ref.onDispose(() {
      stopBackgroundSync();
    });
    return const ContactsState.initial();
  }

  /// The master key used for encryption (must be set before operations).
  Uint8List? _masterKey;

  /// Timer for periodic background sync.
  Timer? _syncTimer;

  /// Sets the master key for encryption operations.
  void setMasterKey(Uint8List? key) {
    _masterKey = key;
  }

  /// Starts periodic background sync (every 60 seconds).
  void startBackgroundSync() {
    stopBackgroundSync(); // Cancel any existing timer
    _syncTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_masterKey != null) {
        loadContacts();
      }
    });
  }

  /// Stops the background sync timer.
  void stopBackgroundSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Loads contacts from the server.
  ///
  /// Must call [setMasterKey] first.
  Future<void> loadContacts() async {
    if (_masterKey == null) {
      debugPrint('ContactsNotifier: Cannot load contacts - master key is null');
      state = state.copyWith(error: 'Not authenticated');
      return;
    }

    debugPrint('ContactsNotifier: Loading contacts...');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final contacts = await _contactsRepository.fetchContacts(_masterKey!);
      debugPrint('ContactsNotifier: Loaded ${contacts.length} contacts');
      state = ContactsState(contacts: contacts);
    } on SessionExpiredException {
      debugPrint('ContactsNotifier: Session expired while loading contacts');
      state = state.copyWith(isLoading: false, error: 'Session expired');
      rethrow;
    } catch (e) {
      debugPrint('ContactsNotifier: Error loading contacts: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Adds a contact by handle.
  ///
  /// Looks up the user in the directory and adds them to the contact list.
  /// Must call [setMasterKey] first.
  Future<void> addContactByHandle(String handle) async {
    if (_masterKey == null) {
      throw const SessionExpiredException('Not authenticated');
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final updatedContacts = await _contactsRepository.addContactByHandle(
        handle: handle,
        masterKey: _masterKey!,
        existingContacts: state.contacts,
      );
      state = ContactsState(contacts: updatedContacts);
    } on ContactAlreadyExistsException {
      state = state.copyWith(isLoading: false);
      rethrow;
    } on ContactNotFoundException {
      state = state.copyWith(isLoading: false);
      rethrow;
    } on InvalidHandleException {
      state = state.copyWith(isLoading: false);
      rethrow;
    } on SessionExpiredException {
      state = state.copyWith(isLoading: false, error: 'Session expired');
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Removes a contact by handle.
  ///
  /// Must call [setMasterKey] first.
  Future<void> removeContact(String handle) async {
    if (_masterKey == null) {
      throw const SessionExpiredException('Not authenticated');
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final updatedContacts = await _contactsRepository.removeContact(
        handle: handle,
        masterKey: _masterKey!,
        existingContacts: state.contacts,
      );
      state = ContactsState(contacts: updatedContacts);
    } on SessionExpiredException {
      state = state.copyWith(isLoading: false, error: 'Session expired');
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Updates a contact's nickname.
  ///
  /// Must call [setMasterKey] first.
  Future<void> updateContactNickname(String handle, String? nickname) async {
    if (_masterKey == null) {
      throw const SessionExpiredException('Not authenticated');
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final updatedContacts = await _contactsRepository.updateContactNickname(
        handle: handle,
        nickname: nickname,
        masterKey: _masterKey!,
        existingContacts: state.contacts,
      );
      state = ContactsState(contacts: updatedContacts);
    } on SessionExpiredException {
      state = state.copyWith(isLoading: false, error: 'Session expired');
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Refreshes contacts from the server.
  Future<void> refreshContacts() async {
    await loadContacts();
  }

  /// Finds a contact by handle.
  Contact? findContact(String handle) {
    return state.findByHandle(handle);
  }

  /// Clears contacts state (called on logout).
  Future<void> clear() async {
    stopBackgroundSync();
    _masterKey = null;
    state = const ContactsState.initial();
    await _contactsRepository.clearCache();
  }
}

/// Provider for the contacts notifier.
final contactsProvider = NotifierProvider<ContactsNotifier, ContactsState>(
  ContactsNotifier.new,
);
