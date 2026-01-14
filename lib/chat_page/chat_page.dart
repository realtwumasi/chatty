import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../model/data_models.dart';
import '../model/responsive_helper.dart';
import '../services/chat_repository.dart';
import 'components/chat_date_header.dart';
import 'components/chat_input_area.dart';
import 'components/message_bubble.dart';

// Strictly for Private Chats
class ChatPage extends ConsumerStatefulWidget {
  final Chat chat;
  final bool isDesktop;

  const ChatPage({super.key, required this.chat, this.isDesktop = false});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
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
      _repository.fetchMessagesForChat(_chatId, false);
    });

    _scrollController.addListener(_scrollListener);
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => _scrollToBottom(animated: false),
    );
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final distanceToBottom =
          _scrollController.position.maxScrollExtent - _scrollController.offset;
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
      if (widget.isDesktop) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _inputFocusNode.requestFocus();
        });
      }
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
        replyTo: replyContext,
      );

      repo.sendTyping(_chatId, false, false);
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
        // Small delay to ensure layout calculates new content size
        Future.delayed(const Duration(milliseconds: 50), () {
          if (_scrollController.hasClients) {
            if (animated) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            } else {
              _scrollController.jumpTo(
                _scrollController.position.maxScrollExtent,
              );
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
            child: SingleChildScrollView(
              child: _PrivateChatInfoContent(chat: currentChat),
            ),
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

  void _confirmDeleteGroup(BuildContext context, String groupId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Group"),
        content: const Text(
          "Are you sure you want to permanently delete this group? This action cannot be undone.",
        ),
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
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Failed to delete group: $e")),
                );
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: isDark ? Colors.grey[800] : Colors.grey[200],
          ),
          SizedBox(height: 16.h),
          Text(
            "No messages yet",
            style: TextStyle(color: Colors.grey, fontSize: 16.sp),
          ),
          Text(
            "Start the conversation!",
            style: TextStyle(color: Colors.grey, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final inputColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey[100];
    final isDesktop = widget.isDesktop;

    // OPTIMIZATION: Only rebuild if THIS chat changes.
    final currentChat = ref.watch(
      chatListProvider.select(
        (chats) =>
            chats.firstWhere((c) => c.id == _chatId, orElse: () => widget.chat),
      ),
    );

    // Extracted typing logic to _PrivateChatTitle widget to prevent full rebuilds

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 1,
        leading: isDesktop
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back, color: textColor),
                onPressed: () => Navigator.pop(context),
              ),
        title: InkWell(
          onTap: () => _showPrivateChatDetails(currentChat),
          child: _PrivateChatTitle(
            chat: currentChat,
            chatId: _chatId,
            textColor: textColor,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: textColor),
            onPressed: () {
              final isCreator =
                  currentChat.isGroup &&
                  currentChat.creatorId == ref.read(userProvider)?.id;

              if (isCreator) {
                showModalBottomSheet(
                  context: context,
                  builder: (ctx) => SafeArea(
                    child: Wrap(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.info_outline),
                          title: const Text('Chat Details'),
                          onTap: () {
                            Navigator.pop(ctx);
                            _showPrivateChatDetails(currentChat);
                          },
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.delete_forever,
                            color: Colors.red,
                          ),
                          title: const Text(
                            'Delete Group',
                            style: TextStyle(color: Colors.red),
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _confirmDeleteGroup(context, currentChat.id);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                _showPrivateChatDetails(currentChat);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: currentChat.messages.isEmpty
                ? _buildEmptyState(isDark)
                : Stack(
                    children: [
                      Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: isDesktop,
                        child: ListView.builder(
                          controller: _scrollController,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 10.h,
                          ),
                          itemCount: currentChat.messages.length,
                          itemBuilder: (context, index) {
                            final msg = currentChat.messages[index];

                            if (msg.isSystem) {
                              return Center(
                                child: Container(
                                  margin: EdgeInsets.symmetric(vertical: 8.h),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12.w,
                                    vertical: 4.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.grey[800]
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    msg.text,
                                    style: TextStyle(
                                      fontSize: Responsive.fontSize(
                                        context,
                                        12,
                                      ),
                                      color: isDark
                                          ? Colors.grey[300]
                                          : Colors.grey[800],
                                    ),
                                  ),
                                ),
                              );
                            }

                            bool showDate = false;
                            bool isFirstInSequence = true;

                            if (index > 0) {
                              final prevMessage =
                                  currentChat.messages[index - 1];
                              if (prevMessage.senderId == msg.senderId &&
                                  !prevMessage.isSystem) {
                                isFirstInSequence = false;
                              }

                              if (!_isSameDay(
                                prevMessage.timestamp,
                                msg.timestamp,
                              )) {
                                showDate = true;
                                isFirstInSequence = true;
                              }
                            } else {
                              showDate = true;
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (showDate)
                                  ChatDateHeader(
                                    date: msg.timestamp,
                                    isDark: isDark,
                                  ),
                                GestureDetector(
                                  onLongPress: () => _onSwipeReply(msg),
                                  onSecondaryTapUp: (details) {
                                    // Desktop Right-Click Menu
                                    final position = RelativeRect.fromRect(
                                      details.globalPosition & Size.zero,
                                      Offset.zero & MediaQuery.of(context).size,
                                    );
                                    showMenu(
                                      context: context,
                                      position: position,
                                      items: [
                                        PopupMenuItem(
                                          value: 'reply',
                                          child: Row(
                                            children: [
                                              const Icon(Icons.reply, size: 20),
                                              const SizedBox(width: 8),
                                              const Text("Reply"),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'copy',
                                          child: Row(
                                            children: [
                                              const Icon(Icons.copy, size: 20),
                                              const SizedBox(width: 8),
                                              const Text("Copy Text"),
                                            ],
                                          ),
                                        ),
                                        // Can add Delete here later
                                      ],
                                    ).then((value) {
                                      if (value == 'reply') {
                                        _onSwipeReply(msg);
                                      } else if (value == 'copy') {
                                        Clipboard.setData(
                                          ClipboardData(text: msg.text),
                                        );
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Copied to clipboard",
                                            ),
                                            duration: Duration(seconds: 1),
                                          ),
                                        );
                                      }
                                    });
                                  },
                                  child: Dismissible(
                                    key: ValueKey(msg.id),
                                    direction: DismissDirection.startToEnd,
                                    confirmDismiss: (direction) async {
                                      _onSwipeReply(msg);
                                      return false;
                                    },
                                    background: Container(
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.only(left: 20),
                                      child: const Icon(
                                        Icons.reply,
                                        color: Color(0xFF1A60FF),
                                      ),
                                    ),
                                    child: MessageBubble(
                                      message: msg,
                                      isDark: isDark,
                                      isFirstInSequence: isFirstInSequence,
                                      onRetry: () => ref
                                          .read(chatRepositoryProvider)
                                          .resendMessage(_chatId, msg, false),
                                      showName: false,
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
                            child: const Icon(
                              Icons.arrow_downward,
                              color: Colors.white,
                            ),
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
                  Container(
                    width: 4,
                    height: 40,
                    color: const Color(0xFF1A60FF),
                  ),
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
                            fontSize: Responsive.fontSize(context, 14),
                          ),
                        ),
                        Text(
                          _replyingTo!.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: Responsive.fontSize(context, 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey),
                    onPressed: () => setState(() => _replyingTo = null),
                  ),
                ],
              ),
            ),

          ChatInputArea(
            controller: _messageController,
            focusNode: _inputFocusNode,
            onChanged: _onTextChanged,
            onSubmitted: _sendMessage,
            hintText:
                "Message ${currentChat.isGroup ? currentChat.name : (currentChat.name)}...",
            isDesktop: isDesktop,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _PrivateChatTitle extends ConsumerWidget {
  final Chat chat;
  final String chatId;
  final Color textColor;

  const _PrivateChatTitle({
    required this.chat,
    required this.chatId,
    required this.textColor,
  });

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
          child: Text(
            chat.name.isNotEmpty ? chat.name[0] : '?',
            style: TextStyle(
              color: Colors.white,
              fontSize: Responsive.fontSize(context, 18),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chat.name,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: Responsive.fontSize(context, 16),
              ),
            ),
            if (isTyping)
              Text(
                "typing...",
                style: TextStyle(
                  color: const Color(0xFF1A60FF),
                  fontSize: Responsive.fontSize(context, 12),
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PrivateChatInfoContent extends ConsumerWidget {
  final Chat chat;
  const _PrivateChatInfoContent({required this.chat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(userProvider);
    final otherUser = chat.participants.firstWhere(
      (u) => u.id != currentUser?.id,
      orElse: () => User(id: '?', name: chat.name, email: 'unknown'),
    );
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.grey[300],
            child: Text(
              otherUser.name.isNotEmpty ? otherUser.name[0] : '?',
              style: TextStyle(fontSize: Responsive.fontSize(context, 32)),
            ),
          ),
          const SizedBox(height: 15),
          Text(
            otherUser.name,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 22),
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          Text(otherUser.email, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          ListTile(
            leading: const Icon(Icons.block, color: Colors.red),
            title: Text(
              "Block User",
              style: TextStyle(
                color: Colors.red,
                fontSize: Responsive.fontSize(context, 16),
              ),
            ),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
