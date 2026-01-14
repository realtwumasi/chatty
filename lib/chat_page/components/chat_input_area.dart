import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      padding: EdgeInsets.all(isDesktop ? 20 : 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, isDark ? 0.3 : 0.05),
            offset: const Offset(0, -2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: inputColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? Colors.transparent : Colors.grey.shade200,
                ),
              ),
              child: CallbackShortcuts(
                bindings: {
                  if (isDesktop)
                    const SingleActivator(LogicalKeyboardKey.enter): () =>
                        onSubmitted(),
                },
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: isDesktop,
                  onChanged: onChanged,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textInputAction: isDesktop
                      ? TextInputAction.newline
                      : TextInputAction.send,
                  style: TextStyle(
                    color: textColor,
                    fontSize: Responsive.fontSize(context, 16),
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: isDesktop ? null : (_) => onSubmitted(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF1A60FF), Color(0xFF0040DD)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
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
