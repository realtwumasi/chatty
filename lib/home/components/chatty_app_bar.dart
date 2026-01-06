import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import '../../model/responsive_helper.dart';
import '../../new_message_page.dart';

class ChattyAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isDesktop;
  final bool isDark;
  final Color textColor;

  const ChattyAppBar({
    super.key,
    required this.isDesktop,
    required this.isDark,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: !isDesktop,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: textColor),
      centerTitle: false,
      title: AnimatedTextKit(
        key: ValueKey(isDark),
        animatedTexts: [
          TypewriterAnimatedText(
            'Chatty',
            textStyle: TextStyle(fontSize: Responsive.fontSize(context, 24), fontWeight: FontWeight.bold, color: textColor),
            speed: const Duration(milliseconds: 350),
          ),
        ],
        totalRepeatCount: 1,
      ),
      actions: [
        if (isDesktop)
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const NewMessagePage()));
              },
              icon: const Icon(Icons.add_comment_outlined, color: Color(0xFF1A60FF), size: 28),
              tooltip: "New Chat (Ctrl+N)",
            ),
          )
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
