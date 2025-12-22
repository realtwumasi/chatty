import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../externals/mock_data.dart';
import '../model/data_models.dart';

class ChatPage extends StatefulWidget {
  final Chat chat;
  const ChatPage({super.key, required this.chat});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final MockService _service = MockService();

  @override
  void initState() {
    super.initState();
    widget.chat.unreadCount = 0;
    _service.addListener(_updateUI);
  }

  @override
  void dispose() {
    _service.removeListener(_updateUI);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateUI() {
    if (mounted) setState(() {});
  }

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      _service.sendMessage(widget.chat.id, _messageController.text.trim());
      _messageController.clear();
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Feature: Simulate a Call
  void _handleCall() {
    // Basic dialog setup... (Code simplified for brevity as logic remains same)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        contentPadding: EdgeInsets.all(20.w),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 30.r,
              backgroundColor: const Color(0xFF1A60FF),
              child: Icon(Icons.person, color: Colors.white, size: 30.sp),
            ),
            SizedBox(height: 15.h),
            Text("Calling...", style: TextStyle(color: Colors.grey, fontSize: 14.sp)),
            SizedBox(height: 5.h),
            Text(widget.chat.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.sp, color: Theme.of(context).colorScheme.onSurface)),
            // ... buttons ...
          ],
        ),
      ),
    );
  }

  void _handleBlock() { /* Block logic remains same */ }
  void _showPrivateChatDetails() { /* Details logic remains same */ }
  void _showGroupInfo() { /* Group Info logic remains same */ }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final inputColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey[100];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 1,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: InkWell(
          onTap: () {
            widget.chat.isGroup ? _showGroupInfo() : _showPrivateChatDetails();
          },
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF1A60FF),
                radius: 18.r,
                child: widget.chat.isGroup
                    ? const Icon(Icons.group, size: 20, color: Colors.white)
                    : Text(widget.chat.name[0], style: const TextStyle(color: Colors.white)),
              ),
              SizedBox(width: 10.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chat.name,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 16.sp),
                  ),
                  if (widget.chat.isGroup)
                    Text(
                      "Tap for group info",
                      style: TextStyle(color: Colors.grey, fontSize: 12.sp),
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
                widget.chat.isGroup ? _showGroupInfo() : _showPrivateChatDetails();
              } else if (value == 'block') {
                _handleBlock();
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem(
                  value: 'details',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: textColor.withOpacity(0.7), size: 20),
                      const SizedBox(width: 10),
                      Text('Details', style: TextStyle(color: textColor)),
                    ],
                  ),
                ),
                if (!widget.chat.isGroup)
                  const PopupMenuItem(
                    value: 'block',
                    child: Row(
                      children: [
                        Icon(Icons.block, color: Colors.red, size: 20),
                        SizedBox(width: 10),
                        Text('Block', style: TextStyle(color: Colors.red)),
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
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 10.h),
              itemCount: widget.chat.messages.length,
              itemBuilder: (context, index) {
                final message = widget.chat.messages[index];
                if (message.isSystem) {
                  return Center(
                    child: Container(
                      margin: EdgeInsets.symmetric(vertical: 8.h),
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                      decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12)
                      ),
                      child: Text(message.text, style: TextStyle(fontSize: 12.sp, color: isDark ? Colors.grey[300] : Colors.grey[800])),
                    ),
                  );
                }
                return _buildMessageBubble(message, isDark);
              },
            ),
          ),

          Container(
            padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 10.h),
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
                      borderRadius: BorderRadius.circular(25.r),
                    ),
                    child: TextField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: "Type a message...",
                        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14.sp),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A60FF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.send, color: Colors.white, size: 20.sp),
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
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: message.isMe
                  ? const Color(0xFF1A60FF)
                  : (isDark ? const Color(0xFF2C2C2C) : Colors.grey[200]), // Adaptive Background
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
                    : (isDark ? Colors.white : Colors.black87), // Adaptive Text
                fontSize: 15.sp,
              ),
            ),
          ),
          SizedBox(height: 4.h),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}",
                style: TextStyle(color: Colors.grey[500], fontSize: 10.sp),
              ),
              if (message.isMe) ...[
                SizedBox(width: 4.w),
                Icon(
                  message.status == MessageStatus.failed ? Icons.error_outline :
                  message.status == MessageStatus.sending ? Icons.access_time :
                  message.status == MessageStatus.delivered ? Icons.done_all : Icons.done,
                  size: 12.sp,
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