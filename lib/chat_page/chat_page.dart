import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../model/data_models.dart';
import '../model/responsive_helper.dart';
import '../services/chat_repository.dart';

class ChatPage extends StatefulWidget {
  final Chat chat;
  final bool isDesktop;

  const ChatPage({
    super.key,
    required this.chat,
    this.isDesktop = false,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatRepository _repository = ChatRepository();

  late Chat _currentChat;

  @override
  void initState() {
    super.initState();
    _currentChat = widget.chat;
    _repository.addListener(_updateUI);
    // Fetch latest messages from API
    _repository.fetchMessagesForChat(_currentChat.id, _currentChat.isGroup);

    // Optimization: Scroll to bottom after frame
    SchedulerBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animated: false));
  }

  @override
  void didUpdateWidget(ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chat.id != widget.chat.id) {
      _currentChat = widget.chat;
      _repository.fetchMessagesForChat(_currentChat.id, _currentChat.isGroup);
      _messageController.clear();
    }
  }

  @override
  void dispose() {
    _repository.removeListener(_updateUI);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateUI() {
    if (!mounted) return;
    try {
      final updatedChat = _repository.chats.firstWhere((c) => c.id == widget.chat.id);

      // Optimization: Only setState if content actually changed
      if (updatedChat.messages.length != _currentChat.messages.length) {
        setState(() {
          _currentChat = updatedChat;
        });
        _scrollToBottom();
      }
    } catch (_) {}
  }

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      _repository.sendMessage(
          _currentChat.id,
          _messageController.text.trim(),
          _currentChat.isGroup
      );
      _messageController.clear();
      _scrollToBottom();
    }
  }

  void _scrollToBottom({bool animated = true}) {
    // Optimization: Use scheduler to ensure layout is ready
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

  void _showResponsiveModal({required Widget child}) {
    if (Responsive.isDesktop(context)) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(child: child),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) => SingleChildScrollView(
            controller: controller,
            child: child,
          ),
        ),
      );
    }
  }

  // ... rest of the helper methods (_showGroupInfo, etc) remain effectively the same
  // but we can optimize the build method below

  void _showGroupInfo() {
    _showResponsiveModal(
      child: _GroupInfoContent(chat: _currentChat, repository: _repository),
    );
  }

  void _showPrivateChatDetails() {
    _showResponsiveModal(
      child: _PrivateChatInfoContent(chat: _currentChat, repository: _repository),
    );
  }

  void _handleCall() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        contentPadding: EdgeInsets.all(20.w),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: Responsive.radius(context, 30),
              backgroundColor: const Color(0xFF1A60FF),
              child: Icon(Icons.person, color: Colors.white, size: Responsive.fontSize(context, 30)),
            ),
            SizedBox(height: 15.h),
            Text("Calling...", style: TextStyle(color: Colors.grey, fontSize: Responsive.fontSize(context, 14))),
            SizedBox(height: 5.h),
            Text(_currentChat.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: Responsive.fontSize(context, 18), color: Theme.of(context).colorScheme.onSurface)),
            SizedBox(height: 20.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton(
                  backgroundColor: Colors.red,
                  elevation: 0,
                  mini: true,
                  onPressed: () => Navigator.pop(context),
                  child: const Icon(Icons.call_end, color: Colors.white),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final inputColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey[100];
    final bool isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 1,
        titleSpacing: widget.isDesktop ? 20 : 0,
        leading: widget.isDesktop
            ? null
            : IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: InkWell(
          onTap: () {
            _currentChat.isGroup ? _showGroupInfo() : _showPrivateChatDetails();
          },
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF1A60FF),
                radius: Responsive.radius(context, 18),
                child: _currentChat.isGroup
                    ? Icon(Icons.group, size: Responsive.fontSize(context, 20), color: Colors.white)
                    : Text(_currentChat.name.isNotEmpty ? _currentChat.name[0] : '?', style: TextStyle(color: Colors.white, fontSize: Responsive.fontSize(context, 18))),
              ),
              SizedBox(width: 10.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentChat.name,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: Responsive.fontSize(context, 16)),
                  ),
                  if (_currentChat.isGroup)
                    Text(
                      "Tap for info",
                      style: TextStyle(color: Colors.grey, fontSize: Responsive.fontSize(context, 12)),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: _handleCall,
            icon: Icon(Icons.phone, color: textColor),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: textColor),
            color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
            onSelected: (value) {
              if (value == 'details') {
                _currentChat.isGroup ? _showGroupInfo() : _showPrivateChatDetails();
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem(value: 'details', child: Text('Details', style: TextStyle(color: textColor))),
                if (!_currentChat.isGroup)
                  const PopupMenuItem(value: 'block', child: Text('Block', style: TextStyle(color: Colors.red))),
              ];
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 10.h),
              // Optimization: cacheExtent for smoother scrolling
              cacheExtent: 500,
              itemCount: _currentChat.messages.length,
              itemBuilder: (context, index) {
                final message = _currentChat.messages[index];
                if (message.isSystem) {
                  return Center(
                    child: Container(
                      margin: EdgeInsets.symmetric(vertical: 8.h),
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                      decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12)
                      ),
                      child: Text(message.text, style: TextStyle(fontSize: Responsive.fontSize(context, 12), color: isDark ? Colors.grey[300] : Colors.grey[800])),
                    ),
                  );
                }
                return _buildMessageBubble(message, isDark);
              },
            ),
          ),

          // Message Input
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 20 : 15.w,
                vertical: isDesktop ? 20 : 10.h
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
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
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(color: textColor, fontSize: Responsive.fontSize(context, 16)),
                      decoration: InputDecoration(
                        hintText: "Type a message...",
                        hintStyle: TextStyle(color: Colors.grey[500], fontSize: Responsive.fontSize(context, 14)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 20 : 20.w,
                            vertical: isDesktop ? 16 : 12.h
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isDesktop ? 12 : 10.w),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: EdgeInsets.all(isDesktop ? 10 : 12.w),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A60FF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.send, color: Colors.white, size: Responsive.fontSize(context, 20)),
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
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            constraints: BoxConstraints(
              maxWidth: widget.isDesktop
                  ? 400
                  : MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: message.isMe
                  ? const Color(0xFF1A60FF)
                  : (isDark ? const Color(0xFF2C2C2C) : Colors.grey[200]),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.r),
                topRight: Radius.circular(16.r),
                bottomLeft: message.isMe ? Radius.circular(16.r) : Radius.zero,
                bottomRight: message.isMe ? Radius.zero : Radius.circular(16.r),
              ),
            ),
            child: Text(
              message.text,
              style: TextStyle(
                color: message.isMe
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black87),
                fontSize: Responsive.fontSize(context, 15),
              ),
            ),
          ),
          SizedBox(height: 4.h),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}",
                style: TextStyle(color: Colors.grey[500], fontSize: Responsive.fontSize(context, 10)),
              ),
              if (message.isMe) ...[
                SizedBox(width: 4.w),
                Icon(
                  message.status == MessageStatus.failed ? Icons.error_outline :
                  message.status == MessageStatus.sending ? Icons.access_time :
                  message.status == MessageStatus.delivered ? Icons.done_all : Icons.done,
                  size: Responsive.fontSize(context, 12),
                  color: message.status == MessageStatus.failed ? Colors.red : Colors.grey[500],
                ),
              ]
            ],
          ),
          SizedBox(height: 10.h),
        ],
      ),
    );
  }
}

// Extracted Content Widgets updated with Repository
class _GroupInfoContent extends StatelessWidget {
  final Chat chat;
  final ChatRepository repository;
  const _GroupInfoContent({required this.chat, required this.repository});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final isDesktop = Responsive.isDesktop(context);

    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Group Info", style: TextStyle(fontSize: Responsive.fontSize(context, 18), fontWeight: FontWeight.bold, color: textColor)),
              IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, color: textColor)),
            ],
          ),
          Divider(color: Colors.grey[300]),
          Text("Members (${chat.participants.length})", style: TextStyle(color: Colors.grey, fontSize: Responsive.fontSize(context, 14))),
          SizedBox(height: 10.h),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: chat.participants.length,
              itemBuilder: (context, index) {
                final user = chat.participants[index];
                final isMe = user.id == repository.currentUser.id;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Stack(
                    children: [
                      CircleAvatar(radius: Responsive.radius(context, 20), child: Text(user.name.isNotEmpty ? user.name[0] : '?')),
                      if (user.isOnline)
                        Positioned(right: 0, bottom: 0, child: Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
                    ],
                  ),
                  title: Text(user.name + (isMe ? " (You)" : ""), style: TextStyle(color: textColor, fontSize: Responsive.fontSize(context, 16))),
                  subtitle: Text(user.isOnline ? "Online" : "Offline", style: TextStyle(color: user.isOnline ? Colors.green : Colors.grey, fontSize: Responsive.fontSize(context, 12))),
                );
              },
            ),
          ),
          SizedBox(height: 20.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[50],
                  foregroundColor: Colors.red,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(vertical: isDesktop ? 16 : 12.h)
              ),
              onPressed: () {
                repository.leaveGroup(chat.id);
                Navigator.pop(context);
              },
              child: const Text("Leave Group"),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivateChatInfoContent extends StatelessWidget {
  final Chat chat;
  final ChatRepository repository;
  const _PrivateChatInfoContent({required this.chat, required this.repository});

  @override
  Widget build(BuildContext context) {
    final otherUser = chat.participants.firstWhere(
          (u) => u.id != repository.currentUser.id,
      orElse: () => User(id: '?', name: chat.name, email: 'unknown'),
    );
    final textColor = Theme.of(context).colorScheme.onSurface;
    final isDesktop = Responsive.isDesktop(context);

    return Container(
      padding: EdgeInsets.all(isDesktop ? 32 : 20.w),
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: isDesktop ? 50 : 40.r,
            backgroundColor: Colors.grey[200],
            child: Text(otherUser.name.isNotEmpty ? otherUser.name[0] : '?', style: TextStyle(fontSize: Responsive.fontSize(context, 32), color: Colors.grey[800])),
          ),
          SizedBox(height: isDesktop ? 20 : 15.h),
          Text(otherUser.name, style: TextStyle(fontSize: Responsive.fontSize(context, 22), fontWeight: FontWeight.bold, color: textColor)),
          Text(otherUser.email, style: TextStyle(color: Colors.grey, fontSize: Responsive.fontSize(context, 14))),
          SizedBox(height: 5.h),
          Text(otherUser.isOnline ? "• Online" : "• Offline",
              style: TextStyle(color: otherUser.isOnline ? Colors.green : Colors.grey, fontWeight: FontWeight.w500)),
          SizedBox(height: isDesktop ? 40 : 30.h),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8.r)),
              child: const Icon(Icons.block, color: Colors.red),
            ),
            title: const Text("Block User", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}