import 'dart:async';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../chat_page/chat_page.dart';
import '../chat_page/group_chat_page.dart'; // Import GroupChatPage
import '../model/data_models.dart';
import '../model/responsive_helper.dart';
import '../new_message_page.dart';
import '../services/chat_repository.dart';
import 'components/message_tile.dart';
import '../onboarding/sign_in_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  Chat? _selectedChat;
  Timer? _chatListPollingTimer;

  @override
  void initState() {
    super.initState();
    ref.read(chatRepositoryProvider).fetchChats();
    // Poll for new chats/groups
    _chatListPollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      ref.read(chatRepositoryProvider).fetchChats();
    });
  }

  @override
  void dispose() {
    _chatListPollingTimer?.cancel();
    super.dispose();
  }

  void _onChatSelected(Chat chat) {
    if (Responsive.isDesktop(context)) {
      setState(() {
        _selectedChat = chat;
        chat.unreadCount = 0;
      });
    } else {
      // Logic to choose correct page
      if (chat.isGroup) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => GroupChatPage(chat: chat)),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ChatPage(chat: chat)),
        );
      }
    }
  }

  void _handleLogout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(chatRepositoryProvider).logout();
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

    final chatList = ref.watch(chatListProvider);
    if (_selectedChat != null) {
      final updated = chatList.where((c) => c.id == _selectedChat!.id).firstOrNull;
      if (updated != null && updated != _selectedChat) {
        _selectedChat = updated;
      }
    }

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
                ? (_selectedChat!.isGroup
                ? GroupChatPage(key: ValueKey(_selectedChat!.id), chat: _selectedChat!, isDesktop: true)
                : ChatPage(key: ValueKey(_selectedChat!.id), chat: _selectedChat!, isDesktop: true))
                : _buildEmptyDesktopState(isDark, textColor),
          ),
        ],
      ),
    );
  }

  // ... (Rest of UI Helpers: _buildEmptyDesktopState, _buildCompactUserProfile, _buildChatList, _buildAppBar, _buildFAB, _buildDrawer remain largely same)
  // Re-implementing briefly to ensure file completeness for critical parts

  Widget _buildEmptyDesktopState(bool isDark, Color textColor) {
    return Center(child: Text("Select a chat", style: TextStyle(color: textColor, fontSize: 18)));
  }

  Widget _buildCompactUserProfile(bool isDark, Color textColor) {
    final currentUser = ref.watch(userProvider) ?? User(id: '', name: '?', email: '');
    final repo = ref.read(chatRepositoryProvider);
    return ListTile(
      tileColor: isDark ? Colors.grey[900] : Colors.grey[50],
      leading: CircleAvatar(child: Text(currentUser.name.isNotEmpty ? currentUser.name[0] : '?')),
      title: Text(currentUser.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: Icon(Icons.dark_mode), onPressed: () => repo.toggleTheme()),
          IconButton(icon: Icon(Icons.logout, color: Colors.red), onPressed: _handleLogout),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    final chats = ref.watch(chatListProvider);
    if (chats.isEmpty) return const Center(child: Text("No chats yet"));
    return ListView.builder(
      itemCount: chats.length,
      itemBuilder: (context, index) {
        final chat = chats[index];
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
      title: const Text("Chatty", style: TextStyle(fontWeight: FontWeight.bold)),
      actions: [
        if (isDesktop)
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NewMessagePage())),
            icon: const Icon(Icons.add_comment_outlined),
          )
      ],
    );
  }

  FloatingActionButton _buildFAB() {
    return FloatingActionButton(
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NewMessagePage())),
      child: const Icon(Icons.message, color: Colors.white),
    );
  }

  Widget _buildDrawer(bool isDark, Color textColor) {
    final currentUser = ref.watch(userProvider) ?? User(id: '', name: 'Guest', email: '');
    final repo = ref.read(chatRepositoryProvider);
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            currentAccountPicture: CircleAvatar(child: Text(currentUser.name.isNotEmpty ? currentUser.name[0] : '?')),
            accountName: Text(currentUser.name),
            accountEmail: Text(currentUser.email),
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text("Dark Mode"),
            trailing: Switch(value: ref.watch(themeProvider), onChanged: (val) => repo.toggleTheme()),
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: _handleLogout,
          ),
        ],
      ),
    );
  }
}