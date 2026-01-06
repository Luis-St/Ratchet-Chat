import 'package:flutter/material.dart';

import '../../data/models/contact.dart';

/// A list tile widget for displaying a contact.
class ContactListTile extends StatelessWidget {
  const ContactListTile({
    super.key,
    required this.contact,
    this.collapsed = false,
    this.onTap,
    this.onDelete,
  });

  /// The contact to display.
  final Contact contact;

  /// Whether to show collapsed (icon-only) mode.
  final bool collapsed;

  /// Callback when the tile is tapped.
  final VoidCallback? onTap;

  /// Callback when delete is requested.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (collapsed) {
      return _buildCollapsedTile(context, theme);
    }

    return _buildExpandedTile(context, theme);
  }

  Widget _buildCollapsedTile(BuildContext context, ThemeData theme) {
    return Tooltip(
      message: '${contact.effectiveDisplayName}\n${contact.handle}',
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _showContextMenu(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          child: _buildAvatar(theme, 20),
        ),
      ),
    );
  }

  Widget _buildExpandedTile(BuildContext context, ThemeData theme) {
    return Dismissible(
      key: Key(contact.handle),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete?.call();
        return false; // Don't auto-dismiss, let the dialog handle it
      },
      background: Container(
        color: theme.colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Icon(
          Icons.delete,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      child: ListTile(
        leading: _buildAvatar(theme, 20),
        title: Text(
          contact.effectiveDisplayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge,
        ),
        subtitle: Text(
          contact.handle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          onSelected: (value) {
            if (value == 'delete') {
              onDelete?.call();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(
                    Icons.delete,
                    size: 20,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Remove',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
              ),
            ),
          ],
        ),
        onTap: onTap,
        onLongPress: () => _showContextMenu(context),
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme, double radius) {
    final initials = _getInitials();

    return CircleAvatar(
      radius: radius,
      backgroundColor: _getAvatarColor(theme),
      child: Text(
        initials,
        style: TextStyle(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }

  String _getInitials() {
    final name = contact.effectiveDisplayName;
    if (name.isEmpty) return '?';

    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Color _getAvatarColor(ThemeData theme) {
    // Generate a consistent color based on the handle
    final hash = contact.handle.hashCode;
    final colors = [
      theme.colorScheme.primaryContainer,
      theme.colorScheme.secondaryContainer,
      theme.colorScheme.tertiaryContainer,
      Colors.blue.shade100,
      Colors.green.shade100,
      Colors.orange.shade100,
      Colors.purple.shade100,
      Colors.teal.shade100,
    ];
    return colors[hash.abs() % colors.length];
  }

  void _showContextMenu(BuildContext context) {
    final theme = Theme.of(context);
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + renderBox.size.width,
        position.dy + renderBox.size.height,
      ),
      items: [
        PopupMenuItem(
          onTap: onDelete,
          child: Row(
            children: [
              Icon(Icons.delete, size: 20, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              Text('Remove', style: TextStyle(color: theme.colorScheme.error)),
            ],
          ),
        ),
      ],
    );
  }
}
