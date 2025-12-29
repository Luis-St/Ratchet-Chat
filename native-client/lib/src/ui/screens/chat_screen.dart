// Chat screen for individual conversations.

import 'package:flutter/material.dart';

import '../theme/theme.dart';
import '../widgets/widgets.dart';

/// Message data for display.
class MessageItem {
  final String id;
  final String content;
  final DateTime timestamp;
  final bool isOutgoing;
  final MessageDisplayStatus status;

  const MessageItem({
    required this.id,
    required this.content,
    required this.timestamp,
    required this.isOutgoing,
    this.status = MessageDisplayStatus.sent,
  });
}

class ChatScreen extends StatefulWidget {
  final String participantHandle;
  final String? participantName;
  final bool isOnline;
  final List<MessageItem> messages;
  final bool isLoading;
  final bool isTyping;
  final Future<bool> Function(String content)? onSendMessage;
  final VoidCallback? onCallTap;
  final VoidCallback? onVideoCallTap;
  final VoidCallback? onInfoTap;
  final VoidCallback? onBackTap;

  const ChatScreen({
    super.key,
    required this.participantHandle,
    this.participantName,
    this.isOnline = false,
    this.messages = const [],
    this.isLoading = false,
    this.isTyping = false,
    this.onSendMessage,
    this.onCallTap,
    this.onVideoCallTap,
    this.onInfoTap,
    this.onBackTap,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleSend() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    _messageController.clear();

    try {
      await widget.onSendMessage?.call(content);
      _scrollToBottom();
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.participantName ?? widget.participantHandle;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBackTap ?? () => Navigator.of(context).pop(),
        ),
        title: GestureDetector(
          onTap: widget.onInfoTap,
          child: Row(
            children: [
              Avatar(name: name, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTypography.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: widget.isOnline
                                ? AppColors.online
                                : AppColors.offline,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.isOnline ? 'Online' : 'Offline',
                          style: AppTypography.labelSmall.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined),
            onPressed: widget.onCallTap,
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            onPressed: widget.onVideoCallTap,
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _buildMessagesList(),
          ),
          // Typing indicator
          if (widget.isTyping)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: TypingIndicator(),
            ),
          // Input bar
          _buildInputBar(context),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (widget.isLoading && widget.messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (widget.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No messages yet',
                style: AppTypography.bodyLarge.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start the conversation!',
                style: AppTypography.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      itemCount: widget.messages.length,
      itemBuilder: (context, index) {
        final message = widget.messages[index];
        final showTail = index == 0 ||
            widget.messages[index - 1].isOutgoing != message.isOutgoing;

        return MessageBubble(
          content: message.content,
          timestamp: message.timestamp,
          isOutgoing: message.isOutgoing,
          status: message.status,
          showTail: showTail,
        );
      },
    );
  }

  Widget _buildInputBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.border,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Attachment button
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            onPressed: () {
              // TODO: Implement attachments
            },
          ),
          // Text field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceVariantDark
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Message',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                style: AppTypography.bodyMedium,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _handleSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
              color: Colors.white,
              onPressed: _isSending ? null : _handleSend,
            ),
          ),
        ],
      ),
    );
  }
}
