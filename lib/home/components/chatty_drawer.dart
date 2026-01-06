import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../services/chat_repository.dart';
import '../../model/data_models.dart';
import '../../model/responsive_helper.dart';
import '../../onboarding/sign_in_page.dart';

class ChattyDrawer extends ConsumerWidget {
  const ChattyDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final drawerColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = Theme.of(context).colorScheme.onSurface;
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
            onTap: () => _handleLogout(context, ref),
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }

  void _handleLogout(BuildContext context, WidgetRef ref) {
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
              if (context.mounted) {
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
}
