import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../model/data_models.dart';
import '../model/responsive_helper.dart';
import '../services/chat_repository.dart';

// Strictly for Private Chats
class ChatPage extends ConsumerStatefulWidget {
  final Chat chat;
  final bool isDesktop;

  const ChatPage({
    super.key,
    required this.chat,
    this.isDesktop = false,
  });

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late String _chatId;
  Timer? _typingDebounce;

  @override
  void initState() {
    super.initState();
    _chatId = widget.chat.id;
    // Initial fetch, then rely on WS
    ref.read(chatRepositoryProvider).fetchMessagesForChat(_chatId, false);
    SchedulerBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animated: false));
  }

  @override
  void didUpdateWidget(ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chat.id != widget.chat.id) {
      _chatId = widget.chat.id;
      ref.read(chatRepositoryProvider).fetchMessagesForChat(_chatId, false);
      _messageController.clear();
    }
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    if (_typingDebounce?.isActive ?? false) _typingDebounce!.cancel();

    // Send "is typing"
    ref.read(chatRepositoryProvider).sendTyping(_chatId, false, true);

    _typingDebounce = Timer(const Duration(seconds: 2), () {
      // Send "stop typing"
      ref.read(chatRepositoryProvider).sendTyping(_chatId, false, false);
    });
  }

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      ref.read(chatRepositoryProvider).sendMessage(
          _chatId,
          _messageController.text.trim(),
          false // isGroup = false
      );
      _messageController.clear();
      ref.read(chatRepositoryProvider).sendTyping(_chatId, false, false); // Stop typing immediately
      _scrollToBottom();
    }
  }

  void _scrollToBottom({bool animated = true}) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (animated) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      }
    });
  }

  void _showPrivateChatDetails(Chat currentChat) {
    if (Responsive.isDesktop(context)) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(child: _PrivateChatInfoContent(chat: currentChat)),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        builder: (context) => _PrivateChatInfoContent(chat: currentChat),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final inputColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey[100];
    // Optimization: Use isDesktop from widget
    final isDesktop = widget.isDesktop;

    final chatList = ref.watch(chatListProvider);
    final currentChat = chatList.firstWhere((c) => c.id == _chatId, orElse: () => widget.chat);

    // Listen for typing events
    final typingMap = ref.watch(typingStatusProvider);
    final typingUsers = typingMap[_chatId] ?? {};
    final isTyping = typingUsers.isNotEmpty;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 1,
        leading: isDesktop ? null : IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: InkWell(
          onTap: () => _showPrivateChatDetails(currentChat),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF1A60FF),
                radius: 18,
                child: Text(currentChat.name.isNotEmpty ? currentChat.name[0] : '?', style: const TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(currentChat.name, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 16)),
                  if (isTyping)
                    Text("typing...", style: TextStyle(color: const Color(0xFF1A60FF), fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(icon: Icon(Icons.more_vert, color: textColor), onPressed: () => _showPrivateChatDetails(currentChat)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Scrollbar(
              // Optimization: Scrollbar for desktop
              controller: _scrollController,
              thumbVisibility: isDesktop,
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                itemCount: currentChat.messages.length,
                itemBuilder: (context, index) {
                  return _buildMessageBubble(currentChat.messages[index], isDark);
                },
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(isDesktop ? 20 : 10),
            decoration: BoxDecoration(
              color: backgroundColor,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: inputColor,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: _messageController,
                      // Optimization: Autofocus for desktop usage
                      autofocus: isDesktop,
                      onChanged: _onTextChanged,
                      style: TextStyle(color: textColor),
                      decoration: const InputDecoration(
                        hintText: "Type a message...",
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF1A60FF),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isDark) {
    final isMe = message.isMe;
    final bubbleColor = isMe
        ? (message.status == MessageStatus.failed ? Colors.red.shade700 : const Color(0xFF1A60FF))
        : (isDark ? const Color(0xFF2C2C2C) : Colors.grey[200]);
    final textColor = isMe ? Colors.white : (isDark ? Colors.white : Colors.black87);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMe && message.status == MessageStatus.failed)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.red),
              onPressed: () => ref.read(chatRepositoryProvider).resendMessage(_chatId, message, false),
            ),
          Container(
            margin: EdgeInsets.symmetric(vertical: 4.h),
            padding: const EdgeInsets.all(12),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(message.text, style: TextStyle(color: textColor, fontSize: 15)),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}",
                      style: TextStyle(color: isMe ? Colors.white70 : Colors.grey, fontSize: 10),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                          message.status == MessageStatus.sending ? Icons.access_time :
                          message.status == MessageStatus.failed ? Icons.error : Icons.done,
                          size: 12, color: Colors.white70
                      )
                    ]
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivateChatInfoContent extends ConsumerWidget {
  final Chat chat;
  const _PrivateChatInfoContent({required this.chat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(userProvider);
    final otherUser = chat.participants.firstWhere((u) => u.id != currentUser?.id, orElse: () => User(id: '?', name: chat.name, email: 'unknown'));
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 40, backgroundColor: Colors.grey[300], child: Text(otherUser.name[0], style: const TextStyle(fontSize: 32))),
          const SizedBox(height: 15),
          Text(otherUser.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
          Text(otherUser.email, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          ListTile(
            leading: const Icon(Icons.block, color: Colors.red),
            title: const Text("Block User", style: TextStyle(color: Colors.red)),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}