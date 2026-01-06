import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
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
  final FocusNode _inputFocusNode = FocusNode();
  late String _chatId;
  Timer? _typingDebounce;
  late ChatRepository _repository;

  // Reply State
  Message? _replyingTo;

  // Scroll State
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    _chatId = widget.chat.id;
    _repository = ref.read(chatRepositoryProvider);

    // Defer state updates to avoid build collisions
    Future.microtask(() {
      _repository.enterChat(_chatId);
      _repository.fetchMessagesForChat(_chatId, true);
    });

    _scrollController.addListener(_scrollListener);
    SchedulerBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animated: false));
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final distanceToBottom = _scrollController.position.maxScrollExtent - _scrollController.offset;
      final show = distanceToBottom > 300;
      if (show != _showScrollToBottom) {
        setState(() {
          _showScrollToBottom = show;
        });
      }
    }
  }

  @override
  void didUpdateWidget(GroupChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chat.id != widget.chat.id) {
      Future.microtask(() {
        _repository.leaveChat();
        _chatId = widget.chat.id;
        _repository.enterChat(_chatId);
        _repository.fetchMessagesForChat(_chatId, true);
      });
      _messageController.clear();
      setState(() => _replyingTo = null);
    }
  }

  @override
  void dispose() {
    _repository.leaveChat();
    _typingDebounce?.cancel();
    _scrollController.removeListener(_scrollListener);
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    if (_typingDebounce?.isActive ?? false) _typingDebounce!.cancel();
    ref.read(chatRepositoryProvider).sendTyping(_chatId, true, true);
    _typingDebounce = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        ref.read(chatRepositoryProvider).sendTyping(_chatId, true, false);
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      final repo = ref.read(chatRepositoryProvider);
      final replyContext = _replyingTo;

      _messageController.clear();
      setState(() => _replyingTo = null);

      repo.sendMessage(
          _chatId,
          text,
          true, // isGroup
          replyTo: replyContext
      );

      repo.sendTyping(_chatId, true, false);
      _scrollToBottom();

      if (widget.isDesktop) {
        _inputFocusNode.requestFocus();
      }
    }
  }

  void _onSwipeReply(Message message) {
    HapticFeedback.lightImpact();
    setState(() {
      _replyingTo = message;
    });
    _inputFocusNode.requestFocus();
  }

  void _scrollToBottom({bool animated = true}) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        Future.delayed(const Duration(milliseconds: 50), () {
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
    });
  }

  void _showGroupInfo(String chatId) {
    if (Responsive.isDesktop(context)) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(child: _GroupInfoContent(chatId: chatId)),
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
          builder: (_, c) => SingleChildScrollView(controller: c, child: _GroupInfoContent(chatId: chatId)),
        ),
      );
    }
  }

  void _confirmDeleteGroup(BuildContext context, String groupId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Group"),
        content: const Text("Are you sure you want to permanently delete this group? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close chat page
              try {
                await ref.read(chatRepositoryProvider).deleteGroup(groupId);
              } catch (e) {
                if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to delete group: $e")));
                }
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final inputColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey[100];
    final isDesktop = widget.isDesktop;

    final chatList = ref.watch(chatListProvider);
    final currentChat = chatList.firstWhere((c) => c.id == _chatId, orElse: () => widget.chat);

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
          onTap: () => _showGroupInfo(_chatId),
          child: _GroupChatTitle(chat: currentChat, chatId: _chatId, textColor: textColor),
        ),
        actions: [
          PopupMenuButton<String>(

            icon: Icon(Icons.more_vert, color: textColor),
            onSelected: (value) {
              if (value == 'info') {
                _showGroupInfo(_chatId);
              } else if (value == 'delete') {
                _confirmDeleteGroup(context, _chatId);
              }
            },
            itemBuilder: (context) {
              final currentUserId = ref.read(userProvider)?.id;
              final isCreator = currentChat.creatorId == currentUserId;

              return [
                const PopupMenuItem(
                  value: 'info',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey),
                      SizedBox(width: 8),
                      Text("Group Info"),
                    ],
                  ),
                ),
                if (isCreator)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_forever, color: Colors.red),
                        SizedBox(width: 8),
                        Text("Delete Group", style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
              ];
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: isDesktop,
                  child: ListView.builder(
                    controller: _scrollController,
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                            child: Text(
                              message.text,
                              style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 12),
                                  color: isDark ? Colors.grey[300] : Colors.grey[800]
                              ),
                            ),
                          ),
                        );
                      }

                      bool showName = true;
                      bool showDate = false;

                      if (index > 0) {
                        final prevMessage = currentChat.messages[index - 1];
                        if (prevMessage.senderId == message.senderId && !prevMessage.isSystem) {
                          showName = false;
                        }
                        if (!_isSameDay(prevMessage.timestamp, message.timestamp)) {
                          showDate = true;
                          showName = true;
                        }
                      } else {
                        showDate = true;
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showDate) _DateHeader(date: message.timestamp, isDark: isDark),
                          GestureDetector(
                            onLongPress: () => _onSwipeReply(message),
                            child: Dismissible(
                              key: ValueKey(message.id),
                              direction: DismissDirection.startToEnd,
                              confirmDismiss: (_) async {
                                _onSwipeReply(message);
                                return false;
                              },
                              background: Container(
                                alignment: Alignment.centerLeft,
                                padding: EdgeInsets.only(left: 20),
                                child: Icon(Icons.reply, color: const Color(0xFF1A60FF)),
                              ),
                              child: _GroupMessageBubble(
                                message: message,
                                isDark: isDark,
                                onRetry: () => ref.read(chatRepositoryProvider).resendMessage(_chatId, message, true),
                                showName: showName,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                if (_showScrollToBottom)
                  Positioned(
                    bottom: 20.h,
                    right: 20.w,
                    child: FloatingActionButton.small(
                      onPressed: () => _scrollToBottom(animated: true),
                      backgroundColor: const Color(0xFF1A60FF),
                      child: const Icon(Icons.arrow_downward, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),

          if (_replyingTo != null)
            Container(
              padding: EdgeInsets.all(8),
              color: isDark ? Colors.grey[900] : Colors.grey[200],
              child: Row(
                children: [
                  Container(width: 4, height: 40, color: const Color(0xFF1A60FF)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            _replyingTo!.senderName,
                            style: TextStyle(
                                color: const Color(0xFF1A60FF),
                                fontWeight: FontWeight.bold,
                                fontSize: Responsive.fontSize(context, 14)
                            )
                        ),
                        Text(
                            _replyingTo!.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey, fontSize: Responsive.fontSize(context, 14))
                        ),
                      ],
                    ),
                  ),
                  IconButton(icon: Icon(Icons.close, color: Colors.grey), onPressed: () => setState(() => _replyingTo = null)),
                ],
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
                      focusNode: _inputFocusNode,
                      autofocus: isDesktop,
                      onChanged: _onTextChanged,
                      style: TextStyle(color: textColor, fontSize: Responsive.fontSize(context, 16)),
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
}

class _DateHeader extends StatelessWidget {
  final DateTime date;
  final bool isDark;

  const _DateHeader({required this.date, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    String text;
    if (dateOnly == today) {
      text = "Today";
    } else if (dateOnly == yesterday) {
      text = "Yesterday";
    } else {
      text = DateFormat('MMMM d, y').format(date);
    }

    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 12.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
              fontSize: Responsive.fontSize(context, 12),
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[300] : Colors.grey[600]
          ),
        ),
      ),
    );
  }
}

class _GroupChatTitle extends ConsumerWidget {
  final Chat chat;
  final String chatId;
  final Color textColor;

  const _GroupChatTitle({required this.chat, required this.chatId, required this.textColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typingMap = ref.watch(typingStatusProvider);
    final typingUsers = typingMap[chatId] ?? {};
    final typingText = typingUsers.isEmpty ? "" : "${typingUsers.join(', ')} typing...";

    return Row(
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
            Text(chat.name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: Responsive.fontSize(context, 16))),
            if (typingText.isNotEmpty)
              Text(typingText, style: TextStyle(color: const Color(0xFF1A60FF), fontSize: Responsive.fontSize(context, 12), fontStyle: FontStyle.italic))
            else
              Text(
                "${chat.participants.length} members",
                style: TextStyle(color: Colors.grey, fontSize: Responsive.fontSize(context, 12)),
              ),
          ],
        ),
      ],
    );
  }
}

class _GroupMessageBubble extends StatelessWidget {
  final Message message;
  final bool isDark;
  final VoidCallback onRetry;
  final bool showName;

  const _GroupMessageBubble({
    required this.message,
    required this.isDark,
    required this.onRetry,
    this.showName = true,
  });

  Color _getUserColor(String username) {
    final colors = [
      Colors.orange, Colors.purple, Colors.pink, Colors.teal,
      Colors.blue, Colors.green, Colors.redAccent, Colors.indigo
    ];
    return colors[username.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
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
              onPressed: onRetry,
            ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            child: Container(
              margin: EdgeInsets.symmetric(vertical: 4.h),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(showName && !isMe ? 0 : 12.r),
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
                  // Reply Context
                  if (message.replyToId != null)
                    Container(
                      margin: EdgeInsets.only(bottom: 6),
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: isMe ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(left: BorderSide(color: isMe ? Colors.white70 : senderColor, width: 3))
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              message.replyToSender ?? "Unknown",
                              style: TextStyle(color: isMe ? Colors.white70 : senderColor, fontWeight: FontWeight.bold, fontSize: Responsive.fontSize(context, 11))
                          ),
                          Text(
                              message.replyToContent ?? "...",
                              style: TextStyle(color: isMe ? Colors.white60 : (isDark ? Colors.grey[300] : Colors.black54), fontSize: Responsive.fontSize(context, 11), overflow: TextOverflow.ellipsis), maxLines: 1
                          ),
                        ],
                      ),
                    ),

                  if (!isMe && showName)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        message.senderName,
                        style: TextStyle(fontWeight: FontWeight.bold, color: senderColor, fontSize: Responsive.fontSize(context, 13)),
                      ),
                    ),
                  Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: 8,
                    children: [
                      Text(message.text, style: TextStyle(color: textColor, fontSize: Responsive.fontSize(context, 15))),
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}",
                              style: TextStyle(color: timeColor, fontSize: Responsive.fontSize(context, 10)),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              Icon(
                                message.status == MessageStatus.sending ? Icons.access_time :
                                (message.status == MessageStatus.read
                                    ? Icons.done_all
                                    : (message.status == MessageStatus.failed ? Icons.error : Icons.done)),
                                size: 12,
                                color: message.status == MessageStatus.read ? Colors.lightBlueAccent : timeColor,
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
  final String chatId;
  const _GroupInfoContent({required this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final repo = ref.read(chatRepositoryProvider);
    final currentUser = ref.watch(userProvider);
    final chatList = ref.watch(chatListProvider);

    // Find the chat object dynamically so UI updates when members change
    final chat = chatList.firstWhere((c) => c.id == chatId, orElse: () => Chat(id: chatId, name: 'Unknown', isGroup: true, messages: [], participants: []));

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Group Members", style: TextStyle(fontSize: Responsive.fontSize(context, 18), fontWeight: FontWeight.bold)),
              // Add Member button removed
            ],
          ),
          const Divider(),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: chat.participants.length,
            itemBuilder: (context, index) {
              final user = chat.participants[index];
              final isMe = user.id == currentUser?.id;
              return ListTile(
                leading: CircleAvatar(child: Text(user.name.isNotEmpty ? user.name[0] : '?')),
                title: Text(user.name + (isMe ? " (You)" : ""), style: TextStyle(fontSize: Responsive.fontSize(context, 16))),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'msg') {
                      Navigator.pop(context); // Close sheet
                      final privateChat = await repo.startPrivateChat(user);
                      if (context.mounted) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(chat: privateChat)));
                      }
                    } else if (value == 'remove') {
                      try {
                        await repo.removeMemberFromGroup(chat.id, user.id);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to remove: $e")));
                        }
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    if (!isMe) PopupMenuItem(value: 'msg', child: Text("Message", style: TextStyle(fontSize: Responsive.fontSize(context, 14)))),
                    if (!isMe) PopupMenuItem(value: 'remove', child: Text("Remove", style: TextStyle(color: Colors.red, fontSize: Responsive.fontSize(context, 14)))),
                  ],
                ),
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
            child: Text("Leave Group", style: TextStyle(fontSize: Responsive.fontSize(context, 14))),
          ),
        ],
      ),
    );
  }
}