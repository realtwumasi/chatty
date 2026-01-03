import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../model/data_models.dart';
import '../../model/responsive_helper.dart';
import '../../services/chat_repository.dart';

class MessageTile extends ConsumerWidget {
  final Chat chat;
  final VoidCallback onTap;
  final bool isSelected;

  const MessageTile({
    super.key,
    required this.chat,
    required this.onTap,
    this.isSelected = false,
  });

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(time.year, time.month, time.day);

    if (dateOnly == today) {
      return DateFormat('h:mm a').format(time);
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d').format(time);
    }
  }

  Color _getAvatarColor(String name) {
    final colors = [
      Colors.orange, Colors.purple, Colors.pink, Colors.teal,
      Colors.blue, Colors.green, Colors.redAccent, Colors.indigo,
      Colors.brown, Colors.deepOrange,
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final bool isDesktop = Responsive.isDesktop(context);

    // Watch typing status for this specific chat
    final typingMap = ref.watch(typingStatusProvider);
    final typingUsers = typingMap[chat.id] ?? {};
    final isTyping = typingUsers.isNotEmpty;

    final tileColor = isSelected
        ? (isDark ? Colors.white.withOpacity(0.1) : const Color(0xFF1A60FF).withOpacity(0.1))
        : null;

    final String lastMessage = chat.lastMessagePreview;
    final String time = chat.messages.isNotEmpty ? _formatTime(chat.messages.last.timestamp) : "";

    // Check status of last message if it's mine
    final lastMsg = chat.messages.isNotEmpty ? chat.messages.last : null;
    final isMyLastMsg = lastMsg?.isMe ?? false;

    // Sizing
    final double avatarRadius = isDesktop ? 24 : 28.r;
    final double titleSize = Responsive.fontSize(context, 16);
    final double subtitleSize = Responsive.fontSize(context, 14);
    final double timeSize = Responsive.fontSize(context, 12);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(
              vertical: isDesktop ? 12 : 12.h,
              horizontal: 8.w
          ),
          child: Row(
            children: [
              CircleAvatar(
                // Use deterministic color for private chats, grey for groups (or generate there too)
                backgroundColor: chat.isGroup
                    ? (isDark ? Colors.grey[800] : Colors.grey[300])
                    : _getAvatarColor(chat.name),
                radius: avatarRadius,
                child: chat.isGroup
                    ? Icon(Icons.group, color: isDark ? Colors.white70 : Colors.grey[700], size: avatarRadius * 1.2)
                    : Text(
                  chat.name.isNotEmpty ? chat.name[0].toUpperCase() : "?",
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 20),
                    fontWeight: FontWeight.bold,
                    color: Colors.white, // White text on colored background
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            chat.name,
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (time.isNotEmpty)
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: timeSize,
                              color: chat.unreadCount > 0
                                  ? const Color(0xFF1A60FF) // Blue if unread
                                  : secondaryTextColor,
                              fontWeight: chat.unreadCount > 0
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Expanded(
                          child: isTyping
                              ? Text(
                            "Typing...",
                            style: TextStyle(
                              fontSize: subtitleSize,
                              color: const Color(0xFF1A60FF),
                              fontWeight: FontWeight.bold,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                              : Row(
                            children: [
                              if (isMyLastMsg && lastMsg != null)
                                Padding(
                                  padding: EdgeInsets.only(right: 4.w),
                                  child: Icon(
                                    lastMsg.status == MessageStatus.sending ? Icons.access_time :
                                    (lastMsg.status == MessageStatus.read
                                        ? Icons.done_all
                                        : (lastMsg.status == MessageStatus.failed ? Icons.error_outline : Icons.done)),
                                    size: 14.sp,
                                    color: lastMsg.status == MessageStatus.read
                                        ? Colors.lightBlueAccent
                                        : (lastMsg.status == MessageStatus.failed ? Colors.red : secondaryTextColor),
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  lastMessage,
                                  style: TextStyle(
                                    fontSize: subtitleSize,
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
                            ],
                          ),
                        ),
                        if (chat.unreadCount > 0)
                          Container(
                            margin: EdgeInsets.only(left: 8.w),
                            padding: const EdgeInsets.all(6),
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
      ),
    );
  }
}