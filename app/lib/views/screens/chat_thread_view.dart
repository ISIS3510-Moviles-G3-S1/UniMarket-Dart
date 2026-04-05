import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../core/chat_store.dart';
import '../../models/chat_message.dart';

class ChatThreadView extends StatefulWidget {
  final String conversationId;

  const ChatThreadView({
    super.key,
    required this.conversationId,
  });

  @override
  State<ChatThreadView> createState() => _ChatThreadViewState();
}

class _ChatThreadViewState extends State<ChatThreadView> {
  late final TextEditingController _messageController;
  late final ScrollController _scrollController;
  ChatMessage? _replyingTo;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatStore>().markConversationAsRead(widget.conversationId);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;

    try {
      await context.read<ChatStore>().sendMessage(
        conversationId: widget.conversationId,
        text: text,
      );
      _messageController.clear();
      _replyingTo = null;

      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final msgDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (msgDate == today) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (msgDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  List<String> _getStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return ['⏱️', ''];
      case MessageStatus.sent:
        return ['✓', ''];
      case MessageStatus.read:
        return ['✓✓', ''];
      case MessageStatus.failed:
        return ['❌', ' (failed)'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Consumer<ChatStore>(
          builder: (context, chatStore, _) {
            final conversation = chatStore.getConversation(widget.conversationId);
            return Text(conversation?.sellerId ?? 'Chat');
          },
        ),
        backgroundColor: AppTheme.background,
        elevation: 0,
        foregroundColor: AppTheme.foreground,
      ),
      body: Consumer<ChatStore>(
        builder: (context, chatStore, _) {
          final conversation =
              chatStore.getConversation(widget.conversationId);

          if (conversation == null) {
            return const Center(child: Text('Conversation not found'));
          }

          return Column(
            children: [
              // Message list
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: conversation.messages.length,
                  itemBuilder: (context, index) {
                    final message = conversation.messages[index];
                    final isCurrentUser =
                        message.senderId == chatStore.currentUserId;

                    return Column(
                      crossAxisAlignment: isCurrentUser
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if (message.replyTo != null)
                          _buildReplyQuote(message.replyTo!),
                        _MessageBubble(
                          message: message,
                          isCurrentUser: isCurrentUser,
                          statusIcon: _getStatusIcon(message.status),
                          time: _formatTime(message.sentAt),
                          onReply: () {
                            setState(() => _replyingTo = message);
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  },
                ),
              ),
              // Reply preview
              if (_replyingTo != null) _buildReplyPreview(),
              // Message composer
              _buildMessageComposer(_sendMessage),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReplyQuote(ReplyTo replyTo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: AppTheme.accent,
            width: 3,
          ),
        ),
        color: AppTheme.accent.withOpacity(0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            replyTo.senderId,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.accent,
            ),
          ),
          Text(
            replyTo.textPreview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.1),
        border: Border(
          top: BorderSide(
            color: AppTheme.accent.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${_replyingTo?.senderId}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.accent,
                  ),
                ),
                Text(
                  _replyingTo?.text ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageComposer(VoidCallback onSend) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border(
          top: BorderSide(color: AppTheme.gray.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Write a message…',
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.muted,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: AppTheme.gray.withOpacity(0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: AppTheme.gray.withOpacity(0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppTheme.accent),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSend,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: AppTheme.accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send,
                color: AppTheme.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isCurrentUser;
  final List<String> statusIcon;
  final String time;
  final VoidCallback onReply;

  const _MessageBubble({
    required this.message,
    required this.isCurrentUser,
    required this.statusIcon,
    required this.time,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onReply,
      child: Align(
        alignment:
            isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: isCurrentUser ? AppTheme.accent : AppTheme.white,
            border: isCurrentUser
                ? null
                : Border.all(color: AppTheme.gray.withOpacity(0.1)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.imageURLs.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  height: 200,
                  width: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      message.imageURLs.first,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppTheme.gray.withOpacity(0.2),
                          child: const Icon(Icons.image_not_supported),
                        );
                      },
                    ),
                  ),
                ),
              if (message.text.isNotEmpty)
                Text(
                  message.text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isCurrentUser ? AppTheme.white : AppTheme.foreground,
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isCurrentUser
                          ? AppTheme.white.withOpacity(0.7)
                          : AppTheme.muted,
                    ),
                  ),
                  if (isCurrentUser) ...[
                    const SizedBox(width: 4),
                    Text(
                      statusIcon[0],
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
