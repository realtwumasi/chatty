import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'chat_page/chat_page.dart';
import 'create_group_page.dart';
import 'externals/mock_data.dart';
import 'model/data_models.dart';

// PAGE: Select a user or create a group
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

  // Filter users logic
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "New Message",
          style: TextStyle(
            color: Colors.black,
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
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterUsers,
                decoration: InputDecoration(
                  hintText: "Search users...",
                  hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14.sp),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: 20.sp),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                ),
              ),
            ),
          ),

          // 'Create New Group' Action Tile
          InkWell(
            onTap: () {
              // Navigate to the new Create Group PAGE (not popup)
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
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1, thickness: 0.5),

          // User List
          Expanded(
            child: ListView.builder(
              itemCount: _filteredUsers.length,
              itemBuilder: (context, index) {
                final user = _filteredUsers[index];
                return ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey[300],
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
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.sp),
                  ),
                  subtitle: Text(user.email),
                  onTap: () {
                    // Start logic for private chat
                    final chat = _service.getOrCreatePrivateChat(user);
                    // Replace this page with the chat page
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