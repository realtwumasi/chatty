import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'services/chat_repository.dart';
import 'chat_page/chat_page.dart';
import 'model/data_models.dart';
import 'model/responsive_helper.dart';

class CreateGroupPage extends ConsumerStatefulWidget {
  const CreateGroupPage({super.key});

  @override
  ConsumerState<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends ConsumerState<CreateGroupPage> {
  final TextEditingController _groupNameController = TextEditingController();
  final Set<User> _selectedUsers = {};

  @override
  void initState() {
    super.initState();
    // Fetch users when the page loads so we have a list to choose from
    ref.read(chatRepositoryProvider).fetchUsers();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final inputFillColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey[100];
    final hintColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    // Watch the list of all users from Riverpod state
    final allUsers = ref.watch(allUsersProvider);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: Responsive.isDesktop(context),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "New Group",
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: Responsive.fontSize(context, 18)),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (_groupNameController.text.isNotEmpty) {
                // Call createGroup from the repository
                final chat = await ref.read(chatRepositoryProvider).createGroup(
                    _groupNameController.text.trim(),
                    _selectedUsers.toList()
                );

                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => ChatPage(chat: chat)),
                  );
                }
              }
            },
            child: Text(
              "Create",
              style: TextStyle(
                color: (_groupNameController.text.isNotEmpty)
                    ? const Color(0xFF1A60FF)
                    : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: Responsive.fontSize(context, 16),
              ),
            ),
          ),
        ],
      ),
      body: ResponsiveContainer(
        maxWidth: 700,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16.w),
              child: TextField(
                controller: _groupNameController,
                onChanged: (val) => setState(() {}),
                style: TextStyle(color: textColor, fontSize: Responsive.fontSize(context, 16)),
                decoration: InputDecoration(
                  labelText: "Group Name",
                  labelStyle: TextStyle(color: hintColor, fontSize: Responsive.fontSize(context, 14)),
                  prefixIcon: Icon(Icons.group, color: hintColor, size: Responsive.fontSize(context, 20)),
                  filled: true,
                  fillColor: inputFillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("Select Members (Optional)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: Responsive.fontSize(context, 14), color: hintColor)),
              ),
            ),
            SizedBox(height: 10.h),

            Expanded(
              child: ListView.builder(
                itemCount: allUsers.length,
                itemBuilder: (context, index) {
                  final user = allUsers[index];
                  final isSelected = _selectedUsers.contains(user);

                  return CheckboxListTile(
                    value: isSelected,
                    activeColor: const Color(0xFF1A60FF),
                    checkColor: Colors.white,
                    side: BorderSide(color: hintColor),
                    secondary: CircleAvatar(
                      backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                      radius: Responsive.radius(context, 20),
                      child: Text(
                          user.name.isNotEmpty ? user.name[0] : '?',
                          style: TextStyle(color: Colors.white, fontSize: Responsive.fontSize(context, 16))
                      ),
                    ),
                    title: Text(user.name, style: TextStyle(fontSize: Responsive.fontSize(context, 16), fontWeight: FontWeight.w500, color: textColor)),
                    subtitle: Text(user.email, style: TextStyle(color: hintColor, fontSize: Responsive.fontSize(context, 14))),
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
      ),
    );
  }
}