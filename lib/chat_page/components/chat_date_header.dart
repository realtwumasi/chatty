import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../model/responsive_helper.dart';

class ChatDateHeader extends StatelessWidget {
  final DateTime date;
  final bool isDark;

  const ChatDateHeader({
    super.key, 
    required this.date, 
    required this.isDark
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    String text;
    if (dateOnly == today) {
      text = "Today";
    } else if (dateOnly == yesterday) {
      text = "Yesterday";
    } else {
      text = DateFormat('MMMM d, y').format(date);
    }

    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 12.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
              fontSize: Responsive.fontSize(context, 12),
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[300] : Colors.grey[600]
          ),
        ),
      ),
    );
  }
}
