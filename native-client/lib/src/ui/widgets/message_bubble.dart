// Message bubble widget for chat display.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/theme.dart';

/// Message status for display.
enum MessageDisplayStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

class MessageBubble extends StatelessWidget {
  final String content;
  final DateTime timestamp;
  final bool isOutgoing;
  final MessageDisplayStatus status;
  final bool showTail;
  final VoidCallback? onRetry;

  const MessageBubble({
    super.key,
    required this.content,
    required this.timestamp,
    this.isOutgoing = true,
    this.status = MessageDisplayStatus.sent,
    this.showTail = true,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bubbleColor = isOutgoing
        ? (isDark ? AppColors.sentBubbleDark : AppColors.sentBubble)
        : (isDark ? AppColors.receivedBubbleDark : AppColors.receivedBubble);

    final textColor = isOutgoing
        ? Colors.white
        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary);

    return Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: EdgeInsets.only(
          left: isOutgoing ? 48 : 8,
          right: isOutgoing ? 8 : 48,
          top: 2,
          bottom: 2,
        ),
        child: Column(
          crossAxisAlignment:
              isOutgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isOutgoing || !showTail ? 18 : 4),
                  bottomRight: Radius.circular(isOutgoing && showTail ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content,
                    style: AppTypography.bodyMedium.copyWith(
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat.jm().format(timestamp),
                  style: AppTypography.labelSmall.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5),
                  ),
                ),
                if (isOutgoing) ...[
                  const SizedBox(width: 4),
                  _buildStatusIcon(context),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(BuildContext context) {
    switch (status) {
      case MessageDisplayStatus.sending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation(
              Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        );
      case MessageDisplayStatus.sent:
        return Icon(
          Icons.check,
          size: 14,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
        );
      case MessageDisplayStatus.delivered:
        return Icon(
          Icons.done_all,
          size: 14,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
        );
      case MessageDisplayStatus.read:
        return const Icon(
          Icons.done_all,
          size: 14,
          color: AppColors.primary,
        );
      case MessageDisplayStatus.failed:
        return GestureDetector(
          onTap: onRetry,
          child: const Icon(
            Icons.error_outline,
            size: 14,
            color: AppColors.error,
          ),
        );
    }
  }
}
