import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../model/responsive_helper.dart';

class ChatInputArea extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final String hintText;
  final bool isDesktop;
  final bool isDark;

  const ChatInputArea({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.hintText,
    this.isDesktop = false,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final inputColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey[100];
    final textColor = Theme.of(context).colorScheme.onSurface;


    return Container(
      padding: EdgeInsets.all(isDesktop ? 20 : 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: inputColor,
                borderRadius: BorderRadius.circular(25),
              ),
              child: CallbackShortcuts(
                bindings: {
                   if (isDesktop)
                     const SingleActivator(LogicalKeyboardKey.enter): () => onSubmitted(),
                },
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: isDesktop,
                  onChanged: onChanged,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textInputAction: isDesktop ? TextInputAction.newline : TextInputAction.send,
                  style: TextStyle(color: textColor, fontSize: Responsive.fontSize(context, 16)),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: const TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onSubmitted: isDesktop ? null : (_) => onSubmitted(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: const Color(0xFF1A60FF),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: onSubmitted,
            ),
          ),
        ],
      ),
    );
  }
}
