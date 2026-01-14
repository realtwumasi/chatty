import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../model/responsive_helper.dart';

class ChattySearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;
  final Color inputColor;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onFocusRequest;

  const ChattySearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.inputColor,
    required this.onChanged,
    required this.onClear,
    required this.onFocusRequest,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);
    final hPadding = isDesktop ? 16.0 : 16.w;
    final vPadding = isDesktop ? 8.0 : 8.h;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: vPadding),
      child: Container(
        decoration: BoxDecoration(
          color: inputColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
             BoxShadow(
               color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
               blurRadius: 10,
               offset: const Offset(0, 4),
             )
          ],
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          style: TextStyle(fontSize: Responsive.fontSize(context, 14)),
          decoration: InputDecoration(
              hintText: "Search conversations...",
              hintStyle: TextStyle(color: const Color(0xFF9E9E9E), fontSize: Responsive.fontSize(context, 14)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF9E9E9E)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: isDesktop ? 12 : 12.h),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () {
                controller.clear();
                onClear();
                onFocusRequest();
              })
                  : null
          ),
        ),
      ),
    );
  }
}
