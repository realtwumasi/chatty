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
    widget.chat.unreadCount = 0;
    // Listen for status updates (e.g. message delivered, user online)
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
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
            Text(
              "Calling...",
              style: TextStyle(color: Colors.grey, fontSize: 14.sp),
            ),
            SizedBox(height: 5.h),
            Text(
              widget.chat.name,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.sp),
            ),
            SizedBox(height: 20.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.mic_off, color: Colors.grey),
                ),
                SizedBox(width: 20.w),
                FloatingActionButton(
                  backgroundColor: Colors.red,
                  elevation: 0,
                  mini: true,
                  onPressed: () => Navigator.pop(context),
                  child: const Icon(Icons.call_end, color: Colors.white),
                ),
                SizedBox(width: 20.w),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.volume_up, color: Colors.grey),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // Feature: Simulate Blocking
  void _handleBlock() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Block ${widget.chat.name}?"),
        content: const Text("You will no longer receive messages or calls from this contact."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("${widget.chat.name} has been blocked")),
              );
            },
            child: const Text("Block", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Feature: Private Chat Details
  void _showPrivateChatDetails() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (context) {
        // Attempt to find the 'other' user in the chat
        final otherUser = widget.chat.participants.firstWhere(
              (u) => u.id != _service.currentUser.id,
          orElse: () => User(id: '?', name: widget.chat.name, email: 'unknown'),
        );

        return Container(
          padding: EdgeInsets.all(20.w),
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.w, height: 4.h,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              SizedBox(height: 20.h),
              CircleAvatar(
                radius: 40.r,
                backgroundColor: Colors.grey[200],
                child: Text(otherUser.name[0], style: TextStyle(fontSize: 32.sp, color: Colors.grey[800])),
              ),
              SizedBox(height: 15.h),
              Text(otherUser.name, style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold)),
              Text(otherUser.email, style: TextStyle(color: Colors.grey, fontSize: 14.sp)),
              SizedBox(height: 5.h),
              Text(otherUser.isOnline ? "• Online" : "• Offline",
                  style: TextStyle(color: otherUser.isOnline ? Colors.green : Colors.grey, fontWeight: FontWeight.w500)),

              SizedBox(height: 30.h),
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
                  _handleBlock();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Feature: Group Info Modal (Members, Private Message, Leave)
  void _showGroupInfo() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Group Info", style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(),
              Text("Members (${widget.chat.participants.length})", style: TextStyle(color: Colors.grey, fontSize: 14.sp)),
              SizedBox(height: 10.h),

              // Feature: Active Member Tracking & Private Messaging
              Expanded(
                child: ListView.builder(
                  itemCount: widget.chat.participants.length,
                  itemBuilder: (context, index) {
                    final user = widget.chat.participants[index];
                    final isMe = user.id == _service.currentUser.id;

                    return ListTile(
                      leading: Stack(
                        children: [
                          CircleAvatar(child: Text(user.name[0])),
                          // Online Status Indicator
                          if (user.isOnline)
                            Positioned(
                              right: 0, bottom: 0,
                              child: Container(
                                width: 10, height: 10,
                                decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white)),
                              ),
                            ),
                        ],
                      ),
                      title: Text(user.name + (isMe ? " (You)" : "")),
                      subtitle: Text(user.isOnline ? "Online" : "Offline", style: TextStyle(color: user.isOnline ? Colors.green : Colors.grey, fontSize: 12.sp)),
                      trailing: !isMe ? IconButton(
                        icon: const Icon(Icons.message, color: Color(0xFF1A60FF)),
                        onPressed: () {
                          // Feature: Private Messaging from Group
                          Navigator.pop(context); // Close modal
                          final privateChat = _service.getOrCreatePrivateChat(user);
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => ChatPage(chat: privateChat)),
                          );
                        },
                      ) : null,
                    );
                  },
                ),
              ),

              // Feature: Leave Group
              if (widget.chat.isGroup)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[50],
                      foregroundColor: Colors.red,
                      elevation: 0,
                    ),
                    onPressed: () {
                      _service.leaveGroup(widget.chat.id);
                      Navigator.pop(context); // Close modal
                      Navigator.pop(context); // Return to home
                    },
                    child: const Text("Leave Group"),
                  ),
                ),
            ],
          ),
        );
      },
    );
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
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 16.sp),
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
          // Call Button
          IconButton(
            onPressed: _handleCall,
            icon: const Icon(Icons.phone, color: Colors.black),
          ),
          // More Menu (Details, Block)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            color: Colors.white,
            onSelected: (value) {
              if (value == 'details') {
                widget.chat.isGroup ? _showGroupInfo() : _showPrivateChatDetails();
              } else if (value == 'block') {
                _handleBlock();
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem(
                  value: 'details',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.black54, size: 20),
                      SizedBox(width: 10),
                      Text('Details'),
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
          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 10.h),
              itemCount: widget.chat.messages.length,
              itemBuilder: (context, index) {
                final message = widget.chat.messages[index];

                // Feature: System Messages (Join/Leave)
                if (message.isSystem) {
                  return Center(
                    child: Container(
                      margin: EdgeInsets.symmetric(vertical: 8.h),
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                      child: Text(message.text, style: TextStyle(fontSize: 12.sp, color: Colors.grey[800])),
                    ),
                  );
                }

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
      child: Column(
        crossAxisAlignment: message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
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
            child: Text(
              message.text,
              style: TextStyle(
                color: message.isMe ? Colors.white : Colors.black87,
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
                // Feature: Retry/Status Indicator
                Icon(
                  message.status == MessageStatus.failed ? Icons.error_outline :
                  message.status == MessageStatus.sending ? Icons.access_time :
                  message.status == MessageStatus.delivered ? Icons.done_all : Icons.done,
                  size: 12.sp,
                  color: message.status == MessageStatus.failed ? Colors.red : Colors.grey[500],
                ),
                if (message.status == MessageStatus.failed)
                  Text(" Failed", style: TextStyle(color: Colors.red, fontSize: 10.sp))
              ]
            ],
          ),
          SizedBox(height: 10.h),
        ],
      ),
    );
  }
}