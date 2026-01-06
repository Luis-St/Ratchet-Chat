import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/auth_exceptions.dart';
import '../../providers/contacts_provider.dart';

/// Dialog for adding a new contact by handle.
class AddContactDialog extends ConsumerStatefulWidget {
  const AddContactDialog({super.key});

  @override
  ConsumerState<AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends ConsumerState<AddContactDialog> {
  final _formKey = GlobalKey<FormState>();
  final _handleController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _handleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Add Contact'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the handle of the person you want to add.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _handleController,
              decoration: InputDecoration(
                labelText: 'Handle',
                hintText: 'username@server.com',
                prefixIcon: const Icon(Icons.alternate_email),
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              enabled: !_isLoading,
              autofocus: true,
              validator: _validateHandle,
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Looking up user...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }

  String? _validateHandle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a handle';
    }

    final handle = value.trim();

    // Basic format validation
    // Handle can be just a username (for same server) or username@host
    if (handle.contains('@')) {
      final parts = handle.split('@');
      if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
        return 'Invalid handle format';
      }
      // Validate host format
      final hostPattern = RegExp(r'^[a-zA-Z0-9.-]+(?::\d+)?$');
      if (!hostPattern.hasMatch(parts[1])) {
        return 'Invalid server address';
      }
    }

    return null;
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final handle = _handleController.text.trim();

    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(contactsProvider.notifier).addContactByHandle(handle);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact added successfully')),
        );
      }
    } on ContactAlreadyExistsException {
      setState(() {
        _isLoading = false;
        _error = 'This contact already exists';
      });
    } on ContactNotFoundException {
      setState(() {
        _isLoading = false;
        _error = 'User not found';
      });
    } on InvalidHandleException {
      setState(() {
        _isLoading = false;
        _error = 'Invalid handle format';
      });
    } on NetworkException {
      setState(() {
        _isLoading = false;
        _error = 'Network error. Please check your connection.';
      });
    } on SessionExpiredException {
      setState(() {
        _isLoading = false;
        _error = 'Session expired. Please log in again.';
      });
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to add contact: ${e.toString()}';
      });
    }
  }
}
