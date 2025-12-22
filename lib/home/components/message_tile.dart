import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../chat_page/chat_page.dart';
import '../../model/data_models.dart';


// COMPONENT: Display a single chat row in the home list
class MessageTile extends StatelessWidget {
  final Chat chat;
  final VoidCallback onTap;

  const MessageTile({
    super.key,
    required this.chat,
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    // Theme Awareness
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    // Get last message for preview
    final String lastMessage = chat.messages.isNotEmpty
        ? chat.messages.last.text
        : "No messages yet";

    final String time = chat.messages.isNotEmpty
        ? "${chat.messages.last.timestamp.hour}:${chat.messages.last.timestamp.minute.toString().padLeft(2, '0')}"
        : "";

    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ChatPage(chat: chat)),
        );
        onTap();
      },
      splashColor: const Color(0xFF1A60FF).withOpacity(0.1),
      borderRadius: BorderRadius.circular(12.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
        child: Row(
          children: [
            // Profile Image / Group Icon
            CircleAvatar(
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
              radius: 28.r,
              child: chat.isGroup
                  ? Icon(Icons.group, color: isDark ? Colors.white70 : Colors.grey[700], size: 28.sp)
                  : Text(
                chat.name.isNotEmpty ? chat.name[0].toUpperCase() : "?",
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.grey[700],
                ),
              ),
            ),
            SizedBox(width: 15.w),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and Time row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        chat.name,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: textColor, // Adaptive Color
                        ),
                      ),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: chat.unreadCount > 0
                              ? const Color(0xFF1A60FF)
                              : secondaryTextColor,
                          fontWeight: chat.unreadCount > 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),

                  // Message Preview and Badge row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: chat.unreadCount > 0
                                ? textColor
                                : secondaryTextColor,
                            fontWeight: chat.unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),

                      // Unread Badge
                      if (chat.unreadCount > 0)
                        Container(
                          margin: EdgeInsets.only(left: 8.w),
                          padding: EdgeInsets.all(6.w),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1A60FF),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            chat.unreadCount.toString(),
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}