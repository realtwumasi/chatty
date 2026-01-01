import 'dart:async';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../chat_page/chat_page.dart';
import '../chat_page/group_chat_page.dart';
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
  Timer? _backgroundSyncTimer;

  @override
  void initState() {
    super.initState();
    ref.read(chatRepositoryProvider).fetchChats();
    // Background sync every 30 seconds as fallback
    _backgroundSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.read(chatRepositoryProvider).fetchChats();
    });
  }

  @override
  void dispose() {
    _backgroundSyncTimer?.cancel();
    super.dispose();
  }

  void _onChatSelected(Chat chat) {
    if (Responsive.isDesktop(context)) {
      setState(() {
        _selectedChat = chat;
        chat.unreadCount = 0; // Mark read visually
      });
    } else {
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

  Future<void> _handleRefresh() async {
    await ref.read(chatRepositoryProvider).fetchChats();
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
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: _buildChatList(),
      ),
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

  // ... (UI Helpers below remain same but ensuring no timer logic is hidden inside)

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
    final currentUser = ref.watch(userProvider) ?? User(id: '', name: '?', email: '');
    final repo = ref.read(chatRepositoryProvider);
    return ListTile(
      tileColor: isDark ? Colors.grey[900] : Colors.grey[50],
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: Responsive.isDesktop(context) ? 8 : 4.h),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF1A60FF),
        radius: Responsive.radius(context, 20),
        child: Text(
            currentUser.name.isNotEmpty ? currentUser.name[0] : '?',
            style: TextStyle(color: Colors.white, fontSize: Responsive.fontSize(context, 16))
        ),
      ),
      title: Text(
          currentUser.name,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: Responsive.fontSize(context, 14))
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(ref.watch(themeProvider) ? Icons.dark_mode : Icons.light_mode, color: textColor),
            iconSize: Responsive.fontSize(context, 24),
            onPressed: () => repo.toggleTheme(),
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
    final chats = ref.watch(chatListProvider);
    final isLoading = ref.watch(isLoadingProvider);

    if (chats.isEmpty) {
      if (isLoading) return const Center(child: CircularProgressIndicator());
      return Center(child: Text("No chats yet", style: TextStyle(color: Colors.grey[400])));
    }
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
    final currentUser = ref.watch(userProvider) ?? User(id: '', name: 'Guest', email: '');
    final repo = ref.read(chatRepositoryProvider);

    return Drawer(
      backgroundColor: drawerColor,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF1A60FF)),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                currentUser.name.isNotEmpty ? currentUser.name[0] : '?',
                style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold, color: const Color(0xFF1A60FF)),
              ),
            ),
            accountName: Text(currentUser.name, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
            accountEmail: Text(currentUser.email),
          ),
          ListTile(
            leading: Icon(ref.watch(themeProvider) ? Icons.dark_mode : Icons.light_mode, color: textColor),
            title: Text("Dark Mode", style: TextStyle(color: textColor)),
            trailing: Switch(
                value: ref.watch(themeProvider),
                activeColor: const Color(0xFF1A60FF),
                onChanged: (val) => repo.toggleTheme()
            ),
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