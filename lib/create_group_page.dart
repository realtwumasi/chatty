import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'chat_page/chat_page.dart';
import 'externals/mock_data.dart';
import 'model/data_models.dart';

// PAGE: Dedicated page for creating a group
class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final TextEditingController _groupNameController = TextEditingController();
  final MockService _service = MockService();

  // Track selected users for the group
  final Set<User> _selectedUsers = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "New Group",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 18.sp),
        ),
        actions: [
          // 'Create' button
          TextButton(
            onPressed: () {
              if (_groupNameController.text.isNotEmpty && _selectedUsers.isNotEmpty) {
                // Create group via service
                final chat = _service.createGroup(
                    _groupNameController.text.trim(),
                    _selectedUsers.toList()
                );
                // Navigate to the newly created chat
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => ChatPage(chat: chat)),
                );
              }
            },
            child: Text(
              "Create",
              style: TextStyle(
                color: (_groupNameController.text.isNotEmpty && _selectedUsers.isNotEmpty)
                    ? const Color(0xFF1A60FF)
                    : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Group Name Input
          Padding(
            padding: EdgeInsets.all(16.w),
            child: TextField(
              controller: _groupNameController,
              onChanged: (val) => setState(() {}), // Rebuild to enable/disable button
              decoration: InputDecoration(
                labelText: "Group Name",
                prefixIcon: const Icon(Icons.group),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("Select Members", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: Colors.grey)),
            ),
          ),
          SizedBox(height: 10.h),

          // User Selection List
          Expanded(
            child: ListView.builder(
              itemCount: _service.allUsers.length,
              itemBuilder: (context, index) {
                final user = _service.allUsers[index];
                final isSelected = _selectedUsers.contains(user);

                return CheckboxListTile(
                  value: isSelected,
                  activeColor: const Color(0xFF1A60FF),
                  secondary: CircleAvatar(
                    backgroundColor: Colors.grey[300],
                    child: Text(user.name[0], style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(user.name, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500)),
                  subtitle: Text(user.email),
                  onChanged: (bool? selected) {
                    setState(() {
                      if (selected == true) {
                        _selectedUsers.add(user);
                      } else {
                        _selectedUsers.remove(user);
                      }
                    });
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