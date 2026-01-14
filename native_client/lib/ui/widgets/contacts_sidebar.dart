import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/contacts_state.dart';
import '../../providers/contacts_provider.dart';
import '../../routing/app_router.dart';
import 'add_contact_dialog.dart';
import 'contact_list_tile.dart';

/// Sidebar widget displaying the contacts list.
class ContactsSidebar extends ConsumerWidget {
  const ContactsSidebar({
    super.key,
    this.collapsed = false,
    this.showHeader = true,
    this.onToggleCollapse,
  });

  /// Whether the sidebar is collapsed (icon-only mode).
  final bool collapsed;

  /// Whether to show the header with title and add button.
  final bool showHeader;

  /// Callback when collapse toggle is pressed.
  final VoidCallback? onToggleCollapse;

  /// Width threshold below which we show collapsed layout.
  static const double _collapseThreshold = 150;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsState = ref.watch(contactsProvider);
    final theme = Theme.of(context);

    // Use LayoutBuilder to determine layout based on actual width,
    // not the collapsed boolean. This prevents overflow during animation.
    return LayoutBuilder(
      builder: (context, constraints) {
        final isEffectivelyCollapsed = constraints.maxWidth < _collapseThreshold;

        return Container(
          color: theme.colorScheme.surfaceContainerLow,
          child: Column(
            children: [
              // Header
              if (showHeader)
                _buildHeader(context, ref, theme, isEffectivelyCollapsed),
              // Contacts list
              Expanded(
                child: _buildContactsList(
                  context,
                  ref,
                  contactsState,
                  theme,
                  isEffectivelyCollapsed,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    bool isCollapsed,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 4 : 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: isCollapsed
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onToggleCollapse != null)
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Expand',
                    onPressed: onToggleCollapse,
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.person_add),
                  tooltip: 'Add contact',
                  onPressed: () => _showAddContactDialog(context, ref),
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                if (onToggleCollapse != null)
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Collapse',
                    onPressed: onToggleCollapse,
                    iconSize: 20,
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Contacts',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.person_add),
                  tooltip: 'Add contact',
                  onPressed: () => _showAddContactDialog(context, ref),
                  iconSize: 20,
                ),
              ],
            ),
    );
  }

  Widget _buildContactsList(
    BuildContext context,
    WidgetRef ref,
    ContactsState contactsState,
    ThemeData theme,
    bool isCollapsed,
  ) {
    if (contactsState.isLoading && contactsState.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (contactsState.hasError && contactsState.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load contacts',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  ref.read(contactsProvider.notifier).refreshContacts();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (contactsState.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(isCollapsed ? 8 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.people_outline,
                size: isCollapsed ? 32 : 48,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              if (!isCollapsed) ...[
                const SizedBox(height: 16),
                Text(
                  'No contacts yet',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Add someone to start chatting',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(contactsProvider.notifier).refreshContacts(),
      child: ListView.builder(
        itemCount: contactsState.contacts.length,
        itemBuilder: (context, index) {
          final contact = contactsState.contacts[index];
          return ContactListTile(
            contact: contact,
            collapsed: isCollapsed,
            onTap: () {
              context.go(AppRoutes.chatPath(contact.handle));
            },
            onDelete: () => _confirmDeleteContact(context, ref, contact.handle),
          );
        },
      ),
    );
  }

  void _showAddContactDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const AddContactDialog(),
    );
  }

  void _confirmDeleteContact(
    BuildContext context,
    WidgetRef ref,
    String handle,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove contact'),
        content: Text('Are you sure you want to remove $handle from your contacts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await ref.read(contactsProvider.notifier).removeContact(handle);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contact removed')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to remove contact: $e')),
                  );
                }
              }
            },
            child: Text(
              'Remove',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
