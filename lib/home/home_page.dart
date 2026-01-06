import 'dart:async';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'components/available_group_tile.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  Chat? _selectedChat;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _listFocusNode = FocusNode();

  String _searchQuery = "";
  int _selectedFilterIndex = 0; // 0: All, 1: Private, 2: Group

  @override
  void initState() {
    super.initState();
    ref.read(chatRepositoryProvider).fetchChats();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    _listFocusNode.dispose();
    super.dispose();
  }

  void _onChatSelected(Chat chat) {
    if (Responsive.isDesktop(context)) {
      setState(() {
        _selectedChat = chat;
        chat.unreadCount = 0;
      });
      _listFocusNode.requestFocus();
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
        title: Text("Logout", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: Responsive.fontSize(context, 18))),
        content: Text("Are you sure you want to log out?", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: Responsive.fontSize(context, 14))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: TextStyle(fontSize: Responsive.fontSize(context, 14)))),
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
            child: Text("Logout", style: TextStyle(color: Colors.red, fontSize: Responsive.fontSize(context, 14))),
          ),
        ],
      ),
    );
  }

  void _handleKeyNavigation(RawKeyEvent event, List<Chat> displayChats) {
    if (event is! RawKeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveSelection(displayChats, 1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveSelection(displayChats, -1);
    }
  }

  void _moveSelection(List<Chat> chats, int direction) {
    if (chats.isEmpty) return;
    int currentIndex = -1;
    if (_selectedChat != null) {
      currentIndex = chats.indexWhere((c) => c.id == _selectedChat!.id);
    }
    int newIndex = currentIndex + direction;
    if (newIndex < 0) newIndex = 0;
    if (newIndex >= chats.length) newIndex = chats.length - 1;
    if (newIndex != currentIndex) {
      _onChatSelected(chats[newIndex]);
      _scrollToIndex(newIndex);
    }
  }

  void _scrollToIndex(int index) {
    const itemHeight = 72.0;
    final targetOffset = index * itemHeight;
    if (_scrollController.hasClients) {
      if (targetOffset < _scrollController.offset) {
        _scrollController.animateTo(targetOffset, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      } else if (targetOffset > _scrollController.offset + _scrollController.position.viewportDimension - itemHeight) {
        _scrollController.animateTo(targetOffset - _scrollController.position.viewportDimension + itemHeight + 20, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = ref.watch(wsConnectionProvider);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () => _searchFocusNode.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NewMessagePage())),
        const SingleActivator(LogicalKeyboardKey.escape): () {
          FocusScope.of(context).unfocus();
          _listFocusNode.requestFocus();
        },
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final content = _buildMobileLayout(isConnected);
            if (constraints.maxWidth >= 900) {
              return _buildDesktopLayout(isConnected);
            }
            return content;
          },
        ),
      ),
    );
  }

  Widget _buildConnectionBanner(bool isConnected) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: isConnected
          ? const SizedBox(width: double.infinity)
          : Container(
        width: double.infinity,
        color: Colors.redAccent.shade700,
        padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 16.w),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, color: Colors.white, size: Responsive.fontSize(context, 14)),
            SizedBox(width: 8.w),
            Flexible(
              child: Text(
                "Waiting for connection...",
                style: TextStyle(color: Colors.white, fontSize: Responsive.fontSize(context, 12), fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, Color inputColor) {
    final bool isDesktop = Responsive.isDesktop(context);
    final hPadding = isDesktop ? 16.0 : 16.w;
    final vPadding = isDesktop ? 8.0 : 8.h;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: vPadding),
      child: Container(
        decoration: BoxDecoration(color: inputColor, borderRadius: BorderRadius.circular(12)),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          onChanged: (value) => setState(() => _searchQuery = value),
          style: TextStyle(fontSize: Responsive.fontSize(context, 14)),
          decoration: InputDecoration(
              hintText: "Search (Ctrl+F)...",
              hintStyle: TextStyle(color: Colors.grey, fontSize: Responsive.fontSize(context, 14)),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: isDesktop ? 12 : 12.h),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = "");
                _listFocusNode.requestFocus();
              })
                  : null
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTabs(bool isDark) {
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
            _filterChip("All", 0, isDark, isDesktop),
            SizedBox(width: gap),
            _filterChip("Private", 1, isDark, isDesktop),
            SizedBox(width: gap),
            _filterChip("Groups", 2, isDark, isDesktop),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, int index, bool isDark, bool isDesktop) {
    final isSelected = _selectedFilterIndex == index;
    final hPad = isDesktop ? 16.0 : 16.w;
    final vPad = isDesktop ? 6.0 : 6.h;

    return InkWell(
      onTap: () => setState(() => _selectedFilterIndex = index),
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

  Widget _buildMobileLayout(bool isConnected) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final inputColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey[100];

    return Scaffold(
      backgroundColor: backgroundColor,
      drawer: _buildDrawer(isDark, textColor),
      appBar: _buildAppBar(textColor, isDark, isDesktop: false),
      floatingActionButton: _buildFAB(),
      body: Column(
        children: [
          _buildConnectionBanner(isConnected),
          _buildSearchBar(isDark, inputColor!),
          _buildFilterTabs(isDark),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              child: _buildChatList(isDesktop: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(bool isConnected) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final inputColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey[100];

    final chatList = ref.watch(chatListProvider);
    if (_selectedChat != null) {
      final updated = chatList.where((c) => c.id == _selectedChat!.id).firstOrNull;
      if (updated != null && updated != _selectedChat) {
        _selectedChat = updated;
      }
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          _buildConnectionBanner(isConnected),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 380,
                  child: Column(
                    children: [
                      _buildAppBar(textColor, isDark, isDesktop: true),
                      _buildSearchBar(isDark, inputColor!),
                      _buildFilterTabs(isDark),
                      Expanded(child: _buildChatList(isDesktop: true)),
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
          Text("Select a chat to start messaging", style: TextStyle(color: textColor.withOpacity(0.5), fontSize: Responsive.fontSize(context, 18))),
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
        child: Text(currentUser.name.isNotEmpty ? currentUser.name[0] : '?', style: TextStyle(color: Colors.white, fontSize: Responsive.fontSize(context, 16))),
      ),
      title: Text(currentUser.name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: Responsive.fontSize(context, 14))),
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

  Widget _buildChatList({required bool isDesktop}) {
    final chats = ref.watch(chatListProvider);
    final isLoading = ref.watch(isLoadingProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    var filteredChats = chats;
    if (_searchQuery.isNotEmpty) {
      filteredChats = chats.where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    // Split logic
    final joinedGroups = filteredChats.where((c) => c.isGroup && c.isMember).toList();
    final availableGroups = filteredChats.where((c) => c.isGroup && !c.isMember).toList();
    final privateChats = filteredChats.where((c) => !c.isGroup).toList();

    List<Widget> listItems = [];

    if (_selectedFilterIndex == 0) { // All
      listItems.addAll(privateChats.map((c) => MessageTile(
          chat: c,
          isSelected: _selectedChat?.id == c.id,
          onTap: () => _onChatSelected(c)
      )));
      listItems.addAll(joinedGroups.map((c) => MessageTile(
          chat: c,
          isSelected: _selectedChat?.id == c.id,
          onTap: () => _onChatSelected(c)
      )));

      if (availableGroups.isNotEmpty) {
        listItems.add(Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: Row(
            children: [
              Expanded(child: Divider(color: Colors.grey[400])),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                child: Text("Available groups to join", style: TextStyle(color: Colors.grey, fontSize: Responsive.fontSize(context, 12), fontWeight: FontWeight.bold)),
              ),
              Expanded(child: Divider(color: Colors.grey[400])),
            ],
          ),
        ));
        listItems.addAll(availableGroups.map((c) => AvailableGroupTile(chat: c)));
      }
    } else if (_selectedFilterIndex == 1) { // Private
      listItems.addAll(privateChats.map((c) => MessageTile(
          chat: c,
          isSelected: _selectedChat?.id == c.id,
          onTap: () => _onChatSelected(c)
      )));
    } else if (_selectedFilterIndex == 2) { // Groups
      listItems.addAll(joinedGroups.map((c) => MessageTile(
          chat: c,
          isSelected: _selectedChat?.id == c.id,
          onTap: () => _onChatSelected(c)
      )));
      if (availableGroups.isNotEmpty) {
        listItems.add(Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: Divider(color: Colors.grey),
        ));
        listItems.addAll(availableGroups.map((c) => AvailableGroupTile(chat: c)));
      }
    }

    if (listItems.isEmpty) {
      if (isLoading && chats.isEmpty) return const Center(child: CircularProgressIndicator());
      return Center(child: Text("No chats yet", style: TextStyle(color: Colors.grey[400], fontSize: Responsive.fontSize(context, 16))));
    }

    return RawKeyboardListener(
      focusNode: _listFocusNode,
      onKey: (event) => _handleKeyNavigation(event, chats), // Note: navigation might need adjustment for mixed lists
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: isDesktop,
        child: ListView(
          controller: _scrollController,
          children: listItems,
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Chat chat, Offset position) {
    // ... same as before
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    showMenu(
      context: context,
      position: RelativeRect.fromRect(position & const Size(40, 40), Offset.zero & overlay.size),
      items: [
        if (chat.isGroup)
          PopupMenuItem(
            child: Text('Leave Group', style: TextStyle(color: Colors.red, fontSize: Responsive.fontSize(context, 14))),
            onTap: () {
              ref.read(chatRepositoryProvider).leaveGroup(chat.id);
              if (_selectedChat?.id == chat.id) {
                setState(() => _selectedChat = null);
              }
            },
          ),
        PopupMenuItem(
          value: 'read',
          child: Text('Mark as Read', style: TextStyle(fontSize: Responsive.fontSize(context, 14))),
        ),
      ],
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
              tooltip: "New Chat (Ctrl+N)",
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
    // ... same as before
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
            accountName: Text(currentUser.name, style: TextStyle(fontSize: Responsive.fontSize(context, 18), fontWeight: FontWeight.bold)),
            accountEmail: Text(currentUser.email, style: TextStyle(fontSize: Responsive.fontSize(context, 14))),
          ),
          ListTile(
            leading: Icon(ref.watch(themeProvider) ? Icons.dark_mode : Icons.light_mode, color: textColor),
            title: Text("Dark Mode", style: TextStyle(color: textColor, fontSize: Responsive.fontSize(context, 14))),
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
            title: Text("Logout", style: TextStyle(color: Colors.red, fontSize: Responsive.fontSize(context, 14))),
            onTap: _handleLogout,
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }
}