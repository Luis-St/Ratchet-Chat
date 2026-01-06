import 'package:flutter/foundation.dart';

import 'contact.dart';

/// Represents the current state of the contacts list.
@immutable
class ContactsState {
  const ContactsState({
    this.contacts = const [],
    this.isLoading = false,
    this.error,
  });

  const ContactsState.initial() : this();

  const ContactsState.loading()
    : this(isLoading: true);

  /// List of contacts, sorted by display name.
  final List<Contact> contacts;

  /// Whether contacts are currently being loaded.
  final bool isLoading;

  /// Error message if loading failed.
  final String? error;

  /// Whether the contacts list is empty.
  bool get isEmpty => contacts.isEmpty;

  /// Number of contacts.
  int get count => contacts.length;

  /// Whether there is an error.
  bool get hasError => error != null;

  /// Finds a contact by handle (case-insensitive).
  Contact? findByHandle(String handle) {
    final normalized = handle.toLowerCase();
    try {
      return contacts.firstWhere(
        (c) => c.handle.toLowerCase() == normalized,
      );
    } catch (_) {
      return null;
    }
  }

  /// Creates a copy with the given fields replaced.
  ContactsState copyWith({
    List<Contact>? contacts,
    bool? isLoading,
    String? error,
  }) {
    return ContactsState(
      contacts: contacts ?? this.contacts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Creates a copy with contacts sorted by display name.
  ContactsState withSortedContacts() {
    final sorted = List<Contact>.from(contacts)
      ..sort((a, b) => a.effectiveDisplayName.toLowerCase().compareTo(
            b.effectiveDisplayName.toLowerCase(),
          ));
    return copyWith(contacts: sorted);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactsState &&
          runtimeType == other.runtimeType &&
          listEquals(contacts, other.contacts) &&
          isLoading == other.isLoading &&
          error == other.error;

  @override
  int get hashCode => Object.hash(contacts, isLoading, error);

  @override
  String toString() =>
      'ContactsState(count: ${contacts.length}, isLoading: $isLoading, error: $error)';
}
