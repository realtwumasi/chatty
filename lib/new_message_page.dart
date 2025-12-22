import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'chat_page/chat_page.dart';
import 'create_group_page.dart';
import 'externals/mock_data.dart';
import 'model/data_models.dart';

class NewMessagePage extends StatefulWidget {
  const NewMessagePage({super.key});

  @override
  State<NewMessagePage> createState() => _NewMessagePageState();
}

class _NewMessagePageState extends State<NewMessagePage> {
  final TextEditingController _searchController = TextEditingController();
  final MockService _service = MockService();
  List<User> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _filteredUsers = _service.allUsers;
  }

  void _filterUsers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _service.allUsers;
      } else {
        _filteredUsers = _service.allUsers
            .where((user) =>
        user.name.toLowerCase().contains(query.toLowerCase()) ||
            user.email.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Theme Colors
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey[100];
    final hintColor = isDark ? Colors.grey[400] : Colors.grey[500];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "New Message",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 18.sp,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterUsers,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: "Search users...",
                  hintStyle: TextStyle(color: hintColor, fontSize: 14.sp),
                  prefixIcon: Icon(Icons.search, color: hintColor, size: 20.sp),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                ),
              ),
            ),
          ),

          // 'Create New Group' Action Tile
          InkWell(
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const CreateGroupPage()),
              );
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Row(
                children: [
                  Container(
                    width: 50.w,
                    height: 50.h,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A60FF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.group_add, color: Colors.white, size: 24.sp),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    "Create New Group",
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: textColor),
                  ),
                ],
              ),
            ),
          ),

          Divider(height: 1, thickness: 0.5, color: isDark ? Colors.grey[800] : Colors.grey[300]),

          // User List
          Expanded(
            child: ListView.builder(
              itemCount: _filteredUsers.length,
              itemBuilder: (context, index) {
                final user = _filteredUsers[index];
                return ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                  leading: CircleAvatar(
                    backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                    radius: 25.r,
                    child: Text(
                      user.name[0].toUpperCase(),
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18.sp),
                    ),
                  ),
                  title: Text(
                    user.name,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.sp, color: textColor),
                  ),
                  subtitle: Text(user.email, style: TextStyle(color: hintColor)),
                  onTap: () {
                    final chat = _service.getOrCreatePrivateChat(user);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => ChatPage(chat: chat)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}