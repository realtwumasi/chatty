import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../model/responsive_helper.dart';

class ChatFilterTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool isDark;

  const ChatFilterTabs({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);
    final hPadding = isDesktop ? 16.0 : 16.w;
    final vPadding = isDesktop ? 4.0 : 4.h;
    final gap = isDesktop ? 8.0 : 8.w;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: vPadding),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip(context, "All", 0, isDark, isDesktop),
            SizedBox(width: gap),
            _filterChip(context, "Private", 1, isDark, isDesktop),
            SizedBox(width: gap),
            _filterChip(context, "Groups", 2, isDark, isDesktop),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(BuildContext context, String label, int index, bool isDark, bool isDesktop) {
    final isSelected = selectedIndex == index;
    final hPad = isDesktop ? 16.0 : 16.w;
    final vPad = isDesktop ? 6.0 : 6.h;

    return InkWell(
      onTap: () => onSelect(index),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A60FF) : (isDark ? Colors.grey[800] : Colors.grey[200]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[700]),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: Responsive.fontSize(context, 13),
          ),
        ),
      ),
    );
  }
}
