import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // Keep for .h/.w context
import '../../model/data_models.dart';
import '../../model/responsive_helper.dart';

class MessageTile extends StatelessWidget {
  final Chat chat;
  final VoidCallback onTap;
  final bool isSelected;

  const MessageTile({
    super.key,
    required this.chat,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final bool isDesktop = Responsive.isDesktop(context);

    final tileColor = isSelected
        ? (isDark ? Colors.white.withOpacity(0.1) : Colors.blue.withOpacity(0.1))
        : null;

    final String lastMessage = chat.messages.isNotEmpty
        ? chat.messages.last.text
        : "No messages yet";

    final String time = chat.messages.isNotEmpty
        ? "${chat.messages.last.timestamp.hour}:${chat.messages.last.timestamp.minute.toString().padLeft(2, '0')}"
        : "";

    // Sizing Logic:
    // On Mobile: Use .r, .sp, .w for scaling.
    // On Desktop: Use fixed values to prevent elements from becoming huge.
    final double avatarRadius = isDesktop ? 24 : 28.r;
    final double titleSize = Responsive.fontSize(context, 16);
    final double subtitleSize = Responsive.fontSize(context, 14);
    final double timeSize = Responsive.fontSize(context, 12);
    final double iconSize = isDesktop ? 24 : 28.sp;

    // Fix: Use fixed logical pixels for spacing on Desktop
    final double gapSize = isDesktop ? 12 : 15.w;
    final double badgePadding = isDesktop ? 6 : 6.w;
    final double badgeMargin = isDesktop ? 8 : 8.w;

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
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                radius: avatarRadius,
                child: chat.isGroup
                    ? Icon(Icons.group, color: isDark ? Colors.white70 : Colors.grey[700], size: iconSize)
                    : Text(
                  chat.name.isNotEmpty ? chat.name[0].toUpperCase() : "?",
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 20),
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.grey[700],
                  ),
                ),
              ),
              // Fix: Adjusted gap size to be tighter on desktop
              SizedBox(width: gapSize),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          chat.name,
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: timeSize,
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
                    Row(
                      children: [
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
                        if (chat.unreadCount > 0)
                          Container(
                            // Fix: Adjusted margin and padding for badge
                            margin: EdgeInsets.only(left: badgeMargin),
                            padding: EdgeInsets.all(badgePadding),
                            decoration: const BoxDecoration(
                              color: Color(0xFF1A60FF),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              chat.unreadCount.toString(),
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, 10),
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