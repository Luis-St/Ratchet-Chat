import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/conversation.dart';
import '../../data/models/message.dart';
import '../../providers/messages_provider.dart';

/// A list of conversations.
class ConversationList extends ConsumerWidget {
  final Function(String peerHandle) onConversationTap;
  final String? selectedPeerHandle;

  const ConversationList({
    super.key,
    required this.onConversationTap,
    this.selectedPeerHandle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsState = ref.watch(conversationsProvider);

    if (conversationsState.isLoading && conversationsState.conversations.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (conversationsState.error != null && conversationsState.conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              conversationsState.error!,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(conversationsProvider.notifier).refreshConversations();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (conversationsState.conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No conversations yet',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a conversation with a contact',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(conversationsProvider.notifier).refreshConversations(),
      child: ListView.builder(
        itemCount: conversationsState.conversations.length,
        itemBuilder: (context, index) {
          final conversation = conversationsState.conversations[index];
          final isSelected = conversation.contact.handle == selectedPeerHandle;

          return ConversationTile(
            conversation: conversation,
            isSelected: isSelected,
            onTap: () => onConversationTap(conversation.contact.handle),
          );
        },
      ),
    );
  }
}

/// A single conversation tile.
class ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final bool isSelected;
  final VoidCallback onTap;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      selected: isSelected,
      selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
      leading: CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
        child: Text(
          conversation.displayName.isNotEmpty
              ? conversation.displayName[0].toUpperCase()
              : '?',
          style: TextStyle(
            color: colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              conversation.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight:
                    conversation.hasUnread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (conversation.lastActivityAt != null) ...[
            const SizedBox(width: 8),
            Text(
              conversation.formatLastActivity(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: conversation.hasUnread
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      subtitle: Row(
        children: [
          if (conversation.lastMessage?.direction == MessageDirection.outgoing)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                conversation.lastMessage?.vaultSynced ?? false
                    ? Icons.done_all
                    : Icons.done,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          Expanded(
            child: Text(
              conversation.lastMessagePreview.isEmpty
                  ? 'No messages'
                  : conversation.lastMessagePreview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight:
                    conversation.hasUnread ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
      trailing: conversation.hasUnread
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                conversation.unreadCount > 99
                    ? '99+'
                    : conversation.unreadCount.toString(),
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      onTap: onTap,
    );
  }
}
