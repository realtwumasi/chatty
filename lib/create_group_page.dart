import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'services/chat_repository.dart';
import 'chat_page/group_chat_page.dart';
import 'model/data_models.dart';
import 'model/responsive_helper.dart';

class CreateGroupPage extends ConsumerStatefulWidget {
  const CreateGroupPage({super.key});

  @override
  ConsumerState<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends ConsumerState<CreateGroupPage> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final Set<User> _selectedUsers = {};
  String _searchQuery = "";
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    ref.read(chatRepositoryProvider).fetchUsers();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Color _getUserColor(String username) {
    final colors = [
      Colors.orange, Colors.purple, Colors.pink, Colors.teal,
      Colors.blue, Colors.green, Colors.redAccent, Colors.indigo
    ];
    return colors[username.hashCode.abs() % colors.length];
  }

  Future<void> _createGroup() async {
    if (_groupNameController.text.trim().isEmpty) return;

    setState(() => _isCreating = true);

    try {
      final chat = await ref.read(chatRepositoryProvider).createGroup(
          _groupNameController.text.trim(),
          _selectedUsers.toList()
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => GroupChatPage(chat: chat)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to create group: $e"), backgroundColor: Colors.red),
        );
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final inputFillColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey[100];
    // Fix: Force non-nullable Color for use in BorderSide
    final Color hintColor = isDark ? Colors.grey[400]! : Colors.grey[500]!;
    final isDesktop = Responsive.isDesktop(context);

    final allUsers = ref.watch(allUsersProvider);
    final filteredUsers = _searchQuery.isEmpty
        ? allUsers
        : allUsers.where((u) =>
    u.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        u.email.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: isDesktop,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "New Group",
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: Responsive.fontSize(context, 18)),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16.w),
            child: TextButton(
              onPressed: (_isCreating || _groupNameController.text.trim().isEmpty) ? null : _createGroup,
              child: _isCreating
                  ? SizedBox(width: 16.w, height: 16.w, child: CircularProgressIndicator(strokeWidth: 2, color: const Color(0xFF1A60FF)))
                  : Text(
                "Create",
                style: TextStyle(
                  color: (_groupNameController.text.trim().isNotEmpty)
                      ? const Color(0xFF1A60FF)
                      : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: Responsive.fontSize(context, 16),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ResponsiveContainer(
        maxWidth: 700,
        child: Column(
          children: [
            // Group Name Input
            Padding(
              padding: EdgeInsets.all(16.w),
              child: TextField(
                controller: _groupNameController,
                autofocus: isDesktop, // Focus on load for desktop
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

            // Search Members
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: TextStyle(color: textColor, fontSize: Responsive.fontSize(context, 14)),
                decoration: InputDecoration(
                  hintText: "Search members...",
                  hintStyle: TextStyle(color: hintColor),
                  prefixIcon: Icon(Icons.search, color: hintColor, size: Responsive.fontSize(context, 18)),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    "Select Members (${_selectedUsers.length})",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: Responsive.fontSize(context, 14), color: hintColor)
                ),
              ),
            ),

            Divider(height: 1, thickness: 0.5, color: isDark ? Colors.grey[800] : Colors.grey[300]),

            Expanded(
              child: filteredUsers.isEmpty
                  ? Center(child: Text("No users found", style: TextStyle(color: hintColor)))
                  : Scrollbar(
                thumbVisibility: isDesktop,
                child: ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    final isSelected = _selectedUsers.contains(user);

                    return CheckboxListTile(
                      value: isSelected,
                      activeColor: const Color(0xFF1A60FF),
                      checkColor: Colors.white,
                      side: BorderSide(color: hintColor),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                      secondary: CircleAvatar(
                        backgroundColor: _getUserColor(user.name),
                        radius: Responsive.radius(context, 20),
                        child: Text(
                            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                            style: TextStyle(color: Colors.white, fontSize: Responsive.fontSize(context, 16), fontWeight: FontWeight.bold)
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
            ),
          ],
        ),
      ),
    );
  }
}