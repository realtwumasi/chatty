import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../externals/mock_data.dart';
import '../new_message_page.dart';
import 'components/message_tile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MockService _service = MockService();

  @override
  void initState() {
    super.initState();
    _service.addListener(_refresh);
  }

  @override
  void dispose() {
    _service.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text("Logout", style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text("Are you sure you want to log out?", style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close drawer
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Logged out successfully")),
              );
            },
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Theme Colors
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final drawerColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      // Feature: Sidebar / Drawer for User Details & Settings
      drawer: Drawer(
        backgroundColor: drawerColor,
        child: Column(
          children: [
            // User Details Header
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF1A60FF),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  _service.currentUser.name[0],
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A60FF),
                  ),
                ),
              ),
              accountName: Text(
                _service.currentUser.name,
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(_service.currentUser.email),
            ),

            // Theme Toggle
            ListTile(
              leading: Icon(
                _service.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                color: textColor,
              ),
              title: Text("Dark Mode", style: TextStyle(color: textColor)),
              trailing: Switch(
                value: _service.isDarkMode,
                activeColor: const Color(0xFF1A60FF),
                onChanged: (val) {
                  _service.toggleTheme();
                },
              ),
            ),

            const Spacer(),
            Divider(color: isDark ? Colors.grey[800] : Colors.grey[300]),

            // Logout
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Logout", style: TextStyle(color: Colors.red)),
              onTap: _handleLogout,
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: AnimatedTextKit(
          key: ValueKey(isDark), // Forces rebuild when theme changes
          animatedTexts: [
            TypewriterAnimatedText(
              'Chatty',
              textStyle: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
                color: textColor, // Adaptive text color
              ),
              speed: const Duration(milliseconds: 350),
            ),
          ],
          totalRepeatCount: 1,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        elevation: 0,
        backgroundColor: const Color(0xFF1A60FF),
        shape: const CircleBorder(),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NewMessagePage(),
            ),
          );
        },
        child: const Icon(Icons.message, color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        child: _service.activeChats.isEmpty
            ? Center(child: Text("No chats yet", style: TextStyle(color: Colors.grey[400])))
            : ListView.builder(
          itemCount: _service.activeChats.length,
          itemBuilder: (context, index) {
            final chat = _service.activeChats[index];
            return MessageTile(
              chat: chat,
              onTap: _refresh,
            );
          },
        ),
      ),
    );
  }
}