import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/auth_exceptions.dart';
import '../data/models/contact.dart';
import '../data/models/contacts_state.dart';
import '../data/repositories/contacts_repository.dart';
import 'service_providers.dart';

/// Notifier for managing contacts state.
class ContactsNotifier extends StateNotifier<ContactsState> {
  ContactsNotifier(this._contactsRepository) : super(const ContactsState.initial());

  final ContactsRepository _contactsRepository;

  /// The master key used for encryption (must be set before operations).
  Uint8List? _masterKey;

  /// Sets the master key for encryption operations.
  void setMasterKey(Uint8List? key) {
    _masterKey = key;
  }

  /// Loads contacts from the server.
  ///
  /// Must call [setMasterKey] first.
  Future<void> loadContacts() async {
    if (_masterKey == null) {
      state = state.copyWith(error: 'Not authenticated');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final contacts = await _contactsRepository.fetchContacts(_masterKey!);
      state = ContactsState(contacts: contacts);
    } on SessionExpiredException {
      state = state.copyWith(isLoading: false, error: 'Session expired');
      rethrow;
    } catch (e) {
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
    _masterKey = null;
    state = const ContactsState.initial();
    await _contactsRepository.clearCache();
  }
}

/// Provider for the contacts notifier.
final contactsProvider = StateNotifierProvider<ContactsNotifier, ContactsState>(
  (ref) {
    return ContactsNotifier(ref.watch(contactsRepositoryProvider));
  },
);
