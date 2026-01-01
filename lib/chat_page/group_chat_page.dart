import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../model/data_models.dart';
import '../model/responsive_helper.dart';
import '../services/chat_repository.dart';
import 'chat_page.dart';

class GroupChatPage extends ConsumerStatefulWidget {
  final Chat chat;
  final bool isDesktop;

  const GroupChatPage({
    super.key,
    required this.chat,
    this.isDesktop = false,
  });

  @override
  ConsumerState<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends ConsumerState<GroupChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late String _chatId;
  Timer? _typingDebounce;

  @override
  void initState() {
    super.initState();
    _chatId = widget.chat.id;
    // Initial fetch, then rely on WS
    ref.read(chatRepositoryProvider).fetchMessagesForChat(_chatId, true);
    SchedulerBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animated: false));
  }

  @override
  void didUpdateWidget(GroupChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chat.id != widget.chat.id) {
      _chatId = widget.chat.id;
      ref.read(chatRepositoryProvider).fetchMessagesForChat(_chatId, true);
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
    ref.read(chatRepositoryProvider).sendTyping(_chatId, true, true);

    _typingDebounce = Timer(const Duration(seconds: 2), () {
      // Send "stop typing"
      ref.read(chatRepositoryProvider).sendTyping(_chatId, true, false);
    });
  }

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      ref.read(chatRepositoryProvider).sendMessage(
          _chatId,
          _messageController.text.trim(),
          true // isGroup
      );
      _messageController.clear();
      ref.read(chatRepositoryProvider).sendTyping(_chatId, true, false); // Stop typing immediately
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

  void _showGroupInfo(Chat currentChat) {
    if (Responsive.isDesktop(context)) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(child: _GroupInfoContent(chat: currentChat)),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, c) => SingleChildScrollView(controller: c, child: _GroupInfoContent(chat: currentChat)),
        ),
      );
    }
  }

  Color _getUserColor(String username) {
    final colors = [
      Colors.orange, Colors.purple, Colors.pink, Colors.teal,
      Colors.blue, Colors.green, Colors.redAccent, Colors.indigo
    ];
    return colors[username.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final inputColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey[100];
    final isDesktop = Responsive.isDesktop(context);

    final chatList = ref.watch(chatListProvider);
    final currentChat = chatList.firstWhere((c) => c.id == _chatId, orElse: () => widget.chat);

    // Listen for typing events
    final typingMap = ref.watch(typingStatusProvider);
    final typingUsers = typingMap[_chatId] ?? {};
    final typingText = typingUsers.isEmpty ? "" : "${typingUsers.join(', ')} typing...";

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
          onTap: () => _showGroupInfo(currentChat),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF1A60FF),
                radius: 20,
                child: const Icon(Icons.group, size: 24, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(currentChat.name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                  if (typingText.isNotEmpty)
                    Text(typingText, style: TextStyle(color: const Color(0xFF1A60FF), fontSize: 12, fontStyle: FontStyle.italic))
                  else
                    Text(
                      "${currentChat.participants.length} members",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(icon: Icon(Icons.more_vert, color: textColor), onPressed: () => _showGroupInfo(currentChat)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              itemCount: currentChat.messages.length,
              itemBuilder: (context, index) {
                final message = currentChat.messages[index];
                if (message.isSystem) {
                  return Center(
                    child: Container(
                      margin: EdgeInsets.symmetric(vertical: 8.h),
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(message.text, style: TextStyle(fontSize: 12.sp, color: isDark ? Colors.grey[300] : Colors.grey[800])),
                    ),
                  );
                }
                return _buildGroupMessageBubble(message, isDark);
              },
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
                      onChanged: _onTextChanged,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: "Message ${currentChat.name}...",
                        hintStyle: const TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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

  Widget _buildGroupMessageBubble(Message message, bool isDark) {
    final isMe = message.isMe;
    final bubbleColor = isMe
        ? (message.status == MessageStatus.failed ? Colors.red.shade700 : const Color(0xFF1A60FF))
        : (isDark ? const Color(0xFF2C2C2C) : Colors.white);
    final textColor = isMe ? Colors.white : (isDark ? Colors.white : Colors.black87);
    final timeColor = isMe ? Colors.white70 : Colors.grey;
    final senderColor = _getUserColor(message.senderName);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isMe && message.status == MessageStatus.failed)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.red),
              onPressed: () => ref.read(chatRepositoryProvider).resendMessage(_chatId, message, true),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            child: Container(
              margin: EdgeInsets.symmetric(vertical: 4.h),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12.r),
                  topRight: Radius.circular(12.r),
                  bottomLeft: isMe ? Radius.circular(12.r) : Radius.zero,
                  bottomRight: isMe ? Radius.zero : Radius.circular(12.r),
                ),
                boxShadow: [
                  if (!isDark && !isMe) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        message.senderName,
                        style: TextStyle(fontWeight: FontWeight.bold, color: senderColor, fontSize: 13.sp),
                      ),
                    ),
                  Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: 8,
                    children: [
                      Text(message.text, style: TextStyle(color: textColor, fontSize: 15.sp)),
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}",
                              style: TextStyle(color: timeColor, fontSize: 10.sp),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              Icon(
                                message.status == MessageStatus.sending ? Icons.access_time :
                                message.status == MessageStatus.failed ? Icons.error : Icons.done_all,
                                size: 12,
                                color: timeColor,
                              ),
                            ]
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupInfoContent extends ConsumerWidget {
  final Chat chat;
  const _GroupInfoContent({required this.chat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final repo = ref.read(chatRepositoryProvider);
    final currentUser = ref.watch(userProvider);

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Group Members", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: chat.participants.length,
            itemBuilder: (context, index) {
              final user = chat.participants[index];
              final isMe = user.id == currentUser?.id;
              return ListTile(
                leading: CircleAvatar(child: Text(user.name[0])),
                title: Text(user.name + (isMe ? " (You)" : "")),
                trailing: !isMe ? IconButton(
                  icon: const Icon(Icons.message, color: Color(0xFF1A60FF)),
                  onPressed: () async {
                    Navigator.pop(context); // Close sheet
                    final privateChat = await repo.startPrivateChat(user);
                    if (context.mounted) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(chat: privateChat)));
                    }
                  },
                ) : null,
              );
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[50], foregroundColor: Colors.red),
            onPressed: () {
              repo.leaveGroup(chat.id);
              Navigator.pop(context); // Close sheet
              Navigator.pop(context); // Close page
            },
            child: const Text("Leave Group"),
          ),
        ],
      ),
    );
  }
}