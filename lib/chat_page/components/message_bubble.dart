import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../model/data_models.dart';
import '../../model/responsive_helper.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isDark;
  final VoidCallback onRetry;
  final bool showName;
  final bool isFirstInSequence;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isDark,
    required this.onRetry,
    this.showName = false,
    this.isFirstInSequence = true,
  });

  Color _getUserColor(String username) {
    final colors = [
      Colors.orange, Colors.purple, Colors.pink, Colors.teal,
      Colors.blue, Colors.green, Colors.redAccent, Colors.indigo
    ];
    return colors[username.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;

    // Premium Styling
    final bubbleDecoration = BoxDecoration(
      gradient: isMe
          ? (message.status == MessageStatus.failed
              ? LinearGradient(colors: [Colors.red.shade700, Colors.red.shade900])
              : const LinearGradient(
                  colors: [Color(0xFF1A60FF), Color(0xFF0040DD)], // Blue gradient
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ))
          : null,
      color: isMe ? null : (isDark ? const Color(0xFF2C2C2C) : Colors.white),
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular((!isMe && !isFirstInSequence) ? 4.r : 18.r),
        topRight: Radius.circular((isMe && !isFirstInSequence) ? 4.r : 18.r),
        bottomLeft: isMe ? Radius.circular(18.r) : Radius.circular(4.r), // "Tail" effect
        bottomRight: isMe ? Radius.circular(4.r) : Radius.circular(18.r),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
          blurRadius: 4,
          offset: const Offset(0, 2),
        )
      ],
    );

    final textColor = isMe ? Colors.white : (isDark ? Colors.white : Colors.black87);
    final timeColor = isMe ? Colors.white70 : Colors.grey;
    final senderColor = _getUserColor(message.senderName);

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
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            child: Container(
              margin: EdgeInsets.symmetric(vertical: 4.h),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: bubbleDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Reply Context (Premium Look)
                  if (message.replyToId != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.black.withOpacity(0.1) : (isDark ? Colors.black.withOpacity(0.2) : Colors.grey[100]),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(left: BorderSide(color: isMe ? Colors.white70 : (showName ? senderColor : const Color(0xFF1A60FF)), width: 3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.replyToSender ?? "Unknown",
                            style: TextStyle(
                              color: isMe ? Colors.white70 : (showName ? senderColor : const Color(0xFF1A60FF)),
                              fontWeight: FontWeight.bold,
                              fontSize: Responsive.fontSize(context, 11),
                            ),
                          ),
                          Text(
                            message.replyToContent ?? "...",
                            style: TextStyle(
                              color: isMe ? Colors.white60 : (isDark ? Colors.grey[400] : Colors.black54),
                              fontSize: Responsive.fontSize(context, 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),

                  // Sender Name (Group Only)
                  if (!isMe && showName)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        message.senderName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: senderColor,
                          fontSize: Responsive.fontSize(context, 13),
                        ),
                      ),
                    ),

                  // Message Text & Time
                  Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: 8,
                    children: [
                      Text(
                        message.text,
                        style: TextStyle(
                          color: textColor,
                          fontSize: Responsive.fontSize(context, 15),
                          height: 1.4, // Better readability
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0), // Slight nudge down
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}",
                              style: TextStyle(color: timeColor, fontSize: Responsive.fontSize(context, 10)),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              Icon(
                                message.status == MessageStatus.sending
                                    ? Icons.access_time
                                    : (message.status == MessageStatus.read
                                        ? Icons.done_all
                                        : (message.status == MessageStatus.failed ? Icons.error : Icons.done)),
                                size: 14,
                                color: message.status == MessageStatus.read ? Colors.lightBlueAccent : timeColor,
                              ),
                            ]
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
