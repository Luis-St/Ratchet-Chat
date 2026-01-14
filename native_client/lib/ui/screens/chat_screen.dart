import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/contacts_provider.dart';
import '../../providers/messages_provider.dart';
import '../widgets/compose_area.dart';
import '../widgets/message_bubble.dart';

/// Chat screen for a specific conversation.
class ChatScreen extends ConsumerStatefulWidget {
  final String peerHandle;

  const ChatScreen({
    super.key,
    required this.peerHandle,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Set active conversation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeConversationProvider.notifier).state = widget.peerHandle;
    });

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Load more when scrolled near the bottom (older messages)
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(messagesProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesState = ref.watch(messagesProvider);
    final contactsState = ref.watch(contactsProvider);

    // Find contact
    final contact = contactsState.contacts
        .where((c) => c.handle == widget.peerHandle)
        .firstOrNull;

    final displayName = contact?.effectiveDisplayName ?? widget.peerHandle;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(displayName),
            if (contact != null && contact.handle != displayName)
              Text(
                contact.handle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
          ],
        ),
        actions: [
          // Contact info button
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              _showContactInfo(context, contact?.handle ?? widget.peerHandle);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _buildMessagesList(messagesState),
          ),

          // Compose area
          ComposeArea(
            enabled: !messagesState.isLoading,
            onSend: (text) {
              ref.read(messagesProvider.notifier).sendMessage(text);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(MessagesState state) {
    if (state.isLoading && state.messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (state.error != null && state.messages.isEmpty) {
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
              state.error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(messagesProvider.notifier).refresh();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.messages.isEmpty) {
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
              'No messages yet',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Send a message to start the conversation',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(messagesProvider.notifier).refresh(),
      child: ListView.builder(
        controller: _scrollController,
        reverse: true, // Newest at bottom
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.messages.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.messages.length) {
            // Loading indicator at the top
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          final message = state.messages[index];
          final previousMessage =
              index < state.messages.length - 1 ? state.messages[index + 1] : null;

          // Check if we need a date separator
          final showDateSeparator = previousMessage == null ||
              !_isSameDay(message.createdAt, previousMessage.createdAt);

          return Column(
            children: [
              MessageBubble(
                message: message,
                showTimestamp: true,
              ),
              if (showDateSeparator)
                DateSeparator(date: message.createdAt),
            ],
          );
        },
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showContactInfo(BuildContext context, String handle) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contact Info',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.alternate_email),
                  title: Text(handle),
                  subtitle: const Text('Handle'),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
