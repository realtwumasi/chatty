import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../model/data_models.dart';
import '../../model/responsive_helper.dart';
import '../../services/chat_repository.dart';

class AvailableGroupTile extends ConsumerStatefulWidget {
  final Chat chat;

  const AvailableGroupTile({
    super.key,
    required this.chat,
  });

  @override
  ConsumerState<AvailableGroupTile> createState() => _AvailableGroupTileState();
}

class _AvailableGroupTileState extends ConsumerState<AvailableGroupTile> {
  bool _isJoining = false;

  Color _getAvatarColor(String name) {
    final colors = [
      Colors.orange, Colors.purple, Colors.pink, Colors.teal,
      Colors.blue, Colors.green, Colors.redAccent, Colors.indigo,
      Colors.brown, Colors.deepOrange,
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  Future<void> _handleJoin() async {
    setState(() => _isJoining = true);
    try {
      await ref.read(chatRepositoryProvider).joinGroup(widget.chat.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Joined ${widget.chat.name} successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to join group"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final bool isDesktop = Responsive.isDesktop(context);

    // Sizing - Matching MessageTile
    final double avatarRadius = isDesktop ? 24 : 28.r;
    final double titleSize = Responsive.fontSize(context, 16);
    final double subtitleSize = Responsive.fontSize(context, 14);

    // Margins/Padding - Matching MessageTile
    final hMargin = isDesktop ? 8.0 : 8.w;
    final vMargin = isDesktop ? 2.0 : 2.h;
    final vPadding = isDesktop ? 12.0 : 12.h;
    final hPadding = isDesktop ? 8.0 : 8.w;
    final contentGap = isDesktop ? 12.0 : 12.w;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: hMargin, vertical: vMargin),
      decoration: BoxDecoration(
        // Transparent/Hover effect style instead of card style
        color: isDark ? Colors.transparent : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        // Optional: Add hover effect logic here if needed, or keep transparent
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: vPadding, horizontal: hPadding),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: _getAvatarColor(widget.chat.name),
              radius: avatarRadius,
              child: Icon(Icons.group_add, color: Colors.white, size: avatarRadius * 1.2),
            ),
            SizedBox(width: contentGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chat.name,
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    "Join to start chatting",
                    style: TextStyle(
                      fontSize: subtitleSize,
                      color: secondaryTextColor,
                      fontWeight: FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            SizedBox(
              height: 32.h,
              child: ElevatedButton(
                onPressed: _isJoining ? null : _handleJoin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A60FF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: _isJoining
                    ? SizedBox(width: 14.w, height: 14.w, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text("Join", style: TextStyle(fontSize: Responsive.fontSize(context, 12), fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}