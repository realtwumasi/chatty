import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../chat_page/chat_page.dart';
import '../model/data_models.dart';
import '../model/responsive_helper.dart';
import '../new_message_page.dart';
import '../services/chat_repository.dart'; // Updated
import 'components/message_tile.dart';
import '../onboarding/sign_in_page.dart'; // For logout redirect

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ChatRepository _repository = ChatRepository();
  Chat? _selectedChat;

  @override
  void initState() {
    super.initState();
    _repository.addListener(_refresh);
    // Ensure we have latest data
    _repository.fetchChats();
  }

  @override
  void dispose() {
    _repository.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _onChatSelected(Chat chat) {
    if (Responsive.isDesktop(context)) {
      setState(() {
        _selectedChat = chat;
        chat.unreadCount = 0;
      });
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ChatPage(chat: chat)),
      ).then((_) => _refresh()); // Refresh on return to update read status/last msg
    }
  }

  void _handleLogout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text("Logout", style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text("Are you sure you want to log out?", style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _repository.logout();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const SignInPage()),
                      (route) => false,
                );
              }
            },
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return _buildDesktopLayout();
        }
        return _buildMobileLayout();
      },
    );
  }

  Widget _buildMobileLayout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: backgroundColor,
      drawer: _buildDrawer(isDark, textColor),
      appBar: _buildAppBar(textColor, isDark, isDesktop: false),
      floatingActionButton: _buildFAB(),
      body: _buildChatList(),
    );
  }

  Widget _buildDesktopLayout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Row(
        children: [
          SizedBox(
            width: 380,
            child: Column(
              children: [
                _buildAppBar(textColor, isDark, isDesktop: true),
                Expanded(child: _buildChatList()),
                Divider(height: 1, color: borderColor),
                _buildCompactUserProfile(isDark, textColor),
              ],
            ),
          ),
          VerticalDivider(width: 1, color: borderColor),
          Expanded(
            child: _selectedChat != null
                ? ChatPage(key: ValueKey(_selectedChat!.id), chat: _selectedChat!, isDesktop: true)
                : _buildEmptyDesktopState(isDark, textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDesktopState(bool isDark, Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: isDark ? Colors.grey[700] : Colors.grey[300]),
          const SizedBox(height: 20),
          Text(
            "Select a chat to start messaging",
            style: TextStyle(color: textColor.withOpacity(0.5), fontSize: Responsive.fontSize(context, 18)),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactUserProfile(bool isDark, Color textColor) {
    return ListTile(
      tileColor: isDark ? Colors.grey[900] : Colors.grey[50],
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: Responsive.isDesktop(context) ? 8 : 4.h),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF1A60FF),
        radius: Responsive.radius(context, 20),
        child: Text(
            _repository.currentUser.name.isNotEmpty ? _repository.currentUser.name[0] : '?',
            style: TextStyle(color: Colors.white, fontSize: Responsive.fontSize(context, 16))
        ),
      ),
      title: Text(
          _repository.currentUser.name,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: Responsive.fontSize(context, 14))
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(_repository.isDarkMode ? Icons.dark_mode : Icons.light_mode, color: textColor),
            iconSize: Responsive.fontSize(context, 24),
            onPressed: () => _repository.toggleTheme(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          SizedBox(width: 16.w),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            iconSize: Responsive.fontSize(context, 24),
            onPressed: _handleLogout,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    if (_repository.chats.isEmpty) {
      if (_repository.isLoading) return const Center(child: CircularProgressIndicator());
      return Center(child: Text("No chats yet", style: TextStyle(color: Colors.grey[400])));
    }
    return ListView.builder(
      itemCount: _repository.chats.length,
      itemBuilder: (context, index) {
        final chat = _repository.chats[index];
        return MessageTile(
          chat: chat,
          isSelected: _selectedChat?.id == chat.id,
          onTap: () => _onChatSelected(chat),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(Color textColor, bool isDark, {required bool isDesktop}) {
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
              tooltip: "New Chat",
            ),
          )
      ],
    );
  }

  FloatingActionButton _buildFAB() {
    return FloatingActionButton(
      elevation: 4,
      backgroundColor: const Color(0xFF1A60FF),
      shape: const CircleBorder(),
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const NewMessagePage()));
      },
      child: Icon(Icons.message, color: Colors.white, size: Responsive.fontSize(context, 24)),
    );
  }

  Widget _buildDrawer(bool isDark, Color textColor) {
    final drawerColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    return Drawer(
      backgroundColor: drawerColor,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF1A60FF)),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                _repository.currentUser.name.isNotEmpty ? _repository.currentUser.name[0] : '?',
                style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold, color: const Color(0xFF1A60FF)),
              ),
            ),
            accountName: Text(_repository.currentUser.name, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
            accountEmail: Text(_repository.currentUser.email),
          ),
          ListTile(
            leading: Icon(_repository.isDarkMode ? Icons.dark_mode : Icons.light_mode, color: textColor),
            title: Text("Dark Mode", style: TextStyle(color: textColor)),
            trailing: Switch(value: _repository.isDarkMode, activeColor: const Color(0xFF1A60FF), onChanged: (val) => _repository.toggleTheme()),
          ),
          const Spacer(),
          Divider(color: isDark ? Colors.grey[800] : Colors.grey[300]),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: _handleLogout,
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }
}