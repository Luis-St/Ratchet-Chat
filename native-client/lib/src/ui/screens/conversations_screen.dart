// Conversations list screen.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/theme.dart';
import '../widgets/widgets.dart';

/// Conversation data for display.
class ConversationItem {
  final String id;
  final String participantHandle;
  final String? displayName;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isOnline;

  const ConversationItem({
    required this.id,
    required this.participantHandle,
    this.displayName,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = false,
  });

  String get name => displayName ?? participantHandle;
}

class ConversationsScreen extends StatelessWidget {
  final List<ConversationItem> conversations;
  final bool isLoading;
  final VoidCallback? onRefresh;
  final void Function(ConversationItem)? onConversationTap;
  final VoidCallback? onNewChatTap;
  final VoidCallback? onSettingsTap;

  const ConversationsScreen({
    super.key,
    this.conversations = const [],
    this.isLoading = false,
    this.onRefresh,
    this.onConversationTap,
    this.onNewChatTap,
    this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: onSettingsTap,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => onRefresh?.call(),
        child: _buildBody(context),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: onNewChatTap,
        child: const Icon(Icons.edit_outlined),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (isLoading && conversations.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (conversations.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: conversations.length,
      separatorBuilder: (context, index) => const Divider(height: 1, indent: 80),
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        return ConversationTile(
          name: conversation.name,
          lastMessage: conversation.lastMessage ?? 'No messages yet',
          time: conversation.lastMessageTime,
          unreadCount: conversation.unreadCount,
          isOnline: conversation.isOnline,
          onTap: () => onConversationTap?.call(conversation),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No conversations yet',
              style: AppTypography.headingSmall.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a new chat to begin messaging securely',
              style: AppTypography.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onNewChatTap,
              icon: const Icon(Icons.add),
              label: const Text('Start New Chat'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual conversation tile widget.
class ConversationTile extends StatelessWidget {
  final String name;
  final String lastMessage;
  final DateTime? time;
  final int unreadCount;
  final bool isOnline;
  final VoidCallback? onTap;

  const ConversationTile({
    super.key,
    required this.name,
    required this.lastMessage,
    this.time,
    this.unreadCount = 0,
    this.isOnline = false,
    this.onTap,
  });

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays == 0) {
      return DateFormat.jm().format(time);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat.E().format(time);
    } else {
      return DateFormat.MMMd().format(time);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Stack(
        children: [
          Avatar(name: name, size: 52),
          if (isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.online,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: AppTypography.labelLarge.copyWith(
                fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (time != null)
            Text(
              _formatTime(time!),
              style: AppTypography.labelSmall.copyWith(
                color: unreadCount > 0
                    ? AppColors.primary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              lastMessage,
              style: AppTypography.bodyMedium.copyWith(
                color: unreadCount > 0
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: AppTypography.labelSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
