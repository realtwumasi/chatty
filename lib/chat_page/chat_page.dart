import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart'; // Added for HapticFeedback
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart'; // Added for DateFormat
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
  final FocusNode _inputFocusNode = FocusNode(); // Added FocusNode
  late String _chatId;
  Timer? _typingDebounce;
  late ChatRepository _repository;

  // Reply State
  Message? _replyingTo;

  // Scroll State
  bool _showScrollToBottom = false; // Added Scroll State

  @override
  void initState() {
    super.initState();
    _chatId = widget.chat.id;
    _repository = ref.read(chatRepositoryProvider);

    Future.microtask(() {
      _repository.enterChat(_chatId);
      _repository.fetchMessagesForChat(_chatId, false);
    });

    _scrollController.addListener(_scrollListener); // Added listener
    SchedulerBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animated: false));
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      // Show button if we are more than 300 pixels from the bottom
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
  void didUpdateWidget(ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chat.id != widget.chat.id) {
      Future.microtask(() {
        _repository.leaveChat();
        _chatId = widget.chat.id;
        _repository.enterChat(_chatId);
        _repository.fetchMessagesForChat(_chatId, false);
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

    ref.read(chatRepositoryProvider).sendTyping(_chatId, false, true);

    _typingDebounce = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        ref.read(chatRepositoryProvider).sendTyping(_chatId, false, false);
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      final repo = ref.read(chatRepositoryProvider);
      final replyContext = _replyingTo;

      _messageController.clear();
      if (mounted) {
        setState(() => _replyingTo = null);
      }

      repo.sendMessage(
          _chatId,
          text,
          false, // isGroup = false
          replyTo: replyContext
      );

      repo.sendTyping(_chatId, false, false);
      _scrollToBottom();

      // Keep focus on desktop for rapid messaging
      if (widget.isDesktop) {
        _inputFocusNode.requestFocus();
      }
    }
  }

  void _onSwipeReply(Message message) {
    HapticFeedback.lightImpact(); // Added Haptic
    setState(() {
      _replyingTo = message;
    });
    _inputFocusNode.requestFocus(); // Focus input
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

    // Extracted typing logic to _PrivateChatTitle widget to prevent full rebuilds

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 1,
        leading: isDesktop ? null : IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        // Optimization: Extracted title
        title: InkWell(
          onTap: () => _showPrivateChatDetails(currentChat),
          child: _PrivateChatTitle(chat: currentChat, chatId: _chatId, textColor: textColor),
        ),
        actions: [
          IconButton(icon: Icon(Icons.more_vert, color: textColor), onPressed: () => _showPrivateChatDetails(currentChat)),
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
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, // Added
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                    itemCount: currentChat.messages.length,
                    itemBuilder: (context, index) {
                      final msg = currentChat.messages[index];

                      // Handling System Messages
                      if (msg.isSystem) {
                        return Center(
                          child: Container(
                            margin: EdgeInsets.symmetric(vertical: 8.h),
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[800] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                                msg.text,
                                style: TextStyle(
                                    fontSize: 12.sp,
                                    color: isDark ? Colors.grey[300] : Colors.grey[800]
                                )
                            ),
                          ),
                        );
                      }

                      // Optimization: Date Headers & Message Grouping
                      bool showDate = false;
                      bool isFirstInSequence = true;

                      if (index > 0) {
                        final prevMessage = currentChat.messages[index - 1];
                        // If previous message is same sender and not system, this is a continuation
                        if (prevMessage.senderId == msg.senderId && !prevMessage.isSystem) {
                          isFirstInSequence = false;
                        }

                        // Check date boundary
                        if (!_isSameDay(prevMessage.timestamp, msg.timestamp)) {
                          showDate = true;
                          isFirstInSequence = true; // Reset grouping on new day
                        }
                      } else {
                        showDate = true;
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showDate) _DateHeader(date: msg.timestamp, isDark: isDark),
                          GestureDetector(
                            onLongPress: () => _onSwipeReply(msg),
                            child: Dismissible(
                              key: ValueKey(msg.id),
                              direction: DismissDirection.startToEnd,
                              confirmDismiss: (direction) async {
                                _onSwipeReply(msg);
                                return false;
                              },
                              background: Container(
                                alignment: Alignment.centerLeft,
                                padding: EdgeInsets.only(left: 20),
                                child: Icon(Icons.reply, color: const Color(0xFF1A60FF)),
                              ),
                              child: _PrivateMessageBubble(
                                message: msg,
                                isDark: isDark,
                                isFirstInSequence: isFirstInSequence,
                                onRetry: () => ref.read(chatRepositoryProvider).resendMessage(_chatId, msg, false),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                // Jump to Bottom FAB
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
                        Text(_replyingTo!.senderName, style: TextStyle(color: const Color(0xFF1A60FF), fontWeight: FontWeight.bold)),
                        Text(_replyingTo!.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey)),
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
                      focusNode: _inputFocusNode, // Added focus node
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
}

// Extracted for performance
class _PrivateChatTitle extends ConsumerWidget {
  final Chat chat;
  final String chatId;
  final Color textColor;

  const _PrivateChatTitle({required this.chat, required this.chatId, required this.textColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typingMap = ref.watch(typingStatusProvider);
    final typingUsers = typingMap[chatId] ?? {};
    final isTyping = typingUsers.isNotEmpty;

    return Row(
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xFF1A60FF),
          radius: 18,
          child: Text(chat.name.isNotEmpty ? chat.name[0] : '?', style: const TextStyle(color: Colors.white)),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(chat.name, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 16)),
            if (isTyping)
              Text("typing...", style: TextStyle(color: const Color(0xFF1A60FF), fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
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
          style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: isDark ? Colors.grey[300] : Colors.grey[600]),
        ),
      ),
    );
  }
}

class _PrivateMessageBubble extends StatelessWidget {
  final Message message;
  final bool isDark;
  final bool isFirstInSequence;
  final VoidCallback onRetry;

  const _PrivateMessageBubble({
    required this.message,
    required this.isDark,
    required this.onRetry,
    this.isFirstInSequence = true,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    final bubbleColor = isMe
        ? (message.status == MessageStatus.failed ? Colors.red.shade700 : const Color(0xFF1A60FF))
        : (isDark ? const Color(0xFF2C2C2C) : Colors.white); // Changed to White for consistency
    final textColor = isMe ? Colors.white : (isDark ? Colors.white : Colors.black87);
    final timeColor = isMe ? Colors.white70 : Colors.grey;

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
          Container(
            margin: EdgeInsets.only(top: 2.h, bottom: 2.h), // Consistent spacing
            padding: const EdgeInsets.all(10),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                // Grouping visual logic: if NOT first in sequence, reduce the corner radius to look merged
                topLeft: Radius.circular((!isMe && !isFirstInSequence) ? 2.r : 16.r),
                topRight: Radius.circular((isMe && !isFirstInSequence) ? 2.r : 16.r),
                bottomLeft: isMe ? Radius.circular(16.r) : Radius.zero,
                bottomRight: isMe ? Radius.zero : Radius.circular(16.r),
              ),
              boxShadow: [
                if (!isDark && !isMe) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.replyToId != null)
                  Container(
                    margin: EdgeInsets.only(bottom: 6),
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: isMe ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(left: BorderSide(color: isMe ? Colors.white70 : const Color(0xFF1A60FF), width: 3))
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(message.replyToSender ?? "Unknown", style: TextStyle(color: isMe ? Colors.white70 : const Color(0xFF1A60FF), fontWeight: FontWeight.bold, fontSize: 11)),
                        Text(message.replyToContent ?? "...", style: TextStyle(color: isMe ? Colors.white60 : (isDark ? Colors.grey[300] : Colors.black54), fontSize: 11, overflow: TextOverflow.ellipsis), maxLines: 1),
                      ],
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
                                (message.status == MessageStatus.read
                                    ? Icons.done_all
                                    : (message.status == MessageStatus.failed ? Icons.error : Icons.done)),
                                size: 12,
                                color: message.status == MessageStatus.read ? Colors.lightBlueAccent : timeColor
                            )
                          ]
                        ],
                      ),
                    ),
                  ],
                ),
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
          CircleAvatar(radius: 40, backgroundColor: Colors.grey[300], child: Text(otherUser.name.isNotEmpty ? otherUser.name[0] : '?', style: const TextStyle(fontSize: 32))),
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