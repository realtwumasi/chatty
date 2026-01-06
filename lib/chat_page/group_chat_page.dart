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
import 'components/chat_date_header.dart';
import 'components/chat_input_area.dart';
import 'components/message_bubble.dart';

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


    
    // OPTIMIZATION: Only rebuild if THIS chat changes.
    final currentChat = ref.watch(chatListProvider.select(
      (chats) => chats.firstWhere((c) => c.id == _chatId, orElse: () => widget.chat)
    ));

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
                          if (showDate) ChatDateHeader(date: message.timestamp, isDark: isDark),
                          GestureDetector(
                            onLongPress: () => _onSwipeReply(message),
                            onSecondaryTapUp: (details) {
                              // Desktop Right-Click Menu
                              final position = RelativeRect.fromRect(
                                details.globalPosition & Size.zero, 
                                Offset.zero & MediaQuery.of(context).size
                              );
                              showMenu(
                                context: context,
                                position: position,
                                items: [
                                  PopupMenuItem(
                                    value: 'reply',
                                    child: Row(children: [const Icon(Icons.reply, size: 20), const SizedBox(width: 8), const Text("Reply")]),
                                  ),
                                  PopupMenuItem(
                                    value: 'copy',
                                    child: Row(children: [const Icon(Icons.copy, size: 20), const SizedBox(width: 8), const Text("Copy Text")]),
                                  ),
                                ],
                              ).then((value) {
                                if (value == 'reply') {
                                  _onSwipeReply(message);
                                } else if (value == 'copy') {
                                  Clipboard.setData(ClipboardData(text: message.text));
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied to clipboard"), duration: Duration(seconds: 1)));
                                }
                              });
                            },
                            child: Dismissible(
                              key: ValueKey(message.id),
                              direction: DismissDirection.startToEnd,
                              confirmDismiss: (_) async {
                                _onSwipeReply(message);
                                return false;
                              },
                              background: Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 20),
                                child: const Icon(Icons.reply, color: Color(0xFF1A60FF)),
                              ),
                              child: MessageBubble(
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

          ChatInputArea(
            controller: _messageController,
            focusNode: _inputFocusNode,
            onChanged: _onTextChanged,
            onSubmitted: _sendMessage,
            hintText: "Message ${currentChat.name}...",
            isDesktop: isDesktop,
            isDark: isDark,
          ),
        ],
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