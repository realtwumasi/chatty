import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'chat_page/chat_page.dart';
import 'externals/mock_data.dart';
import 'model/data_models.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final TextEditingController _groupNameController = TextEditingController();
  final MockService _service = MockService();
  final Set<User> _selectedUsers = {};

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final inputFillColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey[100];
    // Fixed: Added ! to ensure these colors are treated as non-nullable Color objects
    final hintColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "New Group",
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 18.sp),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (_groupNameController.text.isNotEmpty && _selectedUsers.isNotEmpty) {
                final chat = _service.createGroup(
                    _groupNameController.text.trim(),
                    _selectedUsers.toList()
                );
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
              onChanged: (val) => setState(() {}),
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: "Group Name",
                labelStyle: TextStyle(color: hintColor),
                prefixIcon: Icon(Icons.group, color: hintColor),
                filled: true,
                fillColor: inputFillColor,
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
              child: Text("Select Members", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: hintColor)),
            ),
          ),
          SizedBox(height: 10.h),

          Expanded(
            child: ListView.builder(
              itemCount: _service.allUsers.length,
              itemBuilder: (context, index) {
                final user = _service.allUsers[index];
                final isSelected = _selectedUsers.contains(user);

                return CheckboxListTile(
                  value: isSelected,
                  activeColor: const Color(0xFF1A60FF),
                  checkColor: Colors.white,
                  side: BorderSide(color: hintColor),
                  secondary: CircleAvatar(
                    backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                    child: Text(user.name[0], style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(user.name, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500, color: textColor)),
                  subtitle: Text(user.email, style: TextStyle(color: hintColor)),
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