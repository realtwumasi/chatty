import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../externals/mock_data.dart';
import '../model/data_models.dart';

// PAGE: The actual chat interface
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
    // Mark messages as read when opening chat
    widget.chat.unreadCount = 0;
  }

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      // Use service to update data
      _service.sendMessage(widget.chat.id, _messageController.text.trim());

      setState(() {
        _messageController.clear();
      });

      // Scroll to bottom after sending
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
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
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 16.sp,
                  ),
                ),
                if (widget.chat.isGroup)
                  Text(
                    "${widget.chat.participants.length} members",
                    style: TextStyle(color: Colors.grey, fontSize: 12.sp),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert, color: Colors.black),
          )
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: widget.chat.messages.isEmpty
                ? Center(
              child: Text(
                "No messages yet.\nSay hello!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400]),
              ),
            )
                : ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 10.h),
              itemCount: widget.chat.messages.length,
              itemBuilder: (context, index) {
                final message = widget.chat.messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),

          // Input Area
          Container(
            padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
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
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(25.r),
                    ),
                    child: TextField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
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

  Widget _buildMessageBubble(Message message) {
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: message.isMe ? const Color(0xFF1A60FF) : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16.r),
            topRight: Radius.circular(16.r),
            bottomLeft: message.isMe ? Radius.circular(16.r) : Radius.zero,
            bottomRight: message.isMe ? Radius.zero : Radius.circular(16.r),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: message.isMe ? Colors.white : Colors.black87,
                fontSize: 15.sp,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              "${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}",
              style: TextStyle(
                color: message.isMe ? Colors.white70 : Colors.grey[500],
                fontSize: 10.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}