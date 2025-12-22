import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import '../externals/mock_data.dart';
import '../new_message_page.dart';
import 'components/message_tile.dart';


// PAGE: Main Home Screen
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MockService _service = MockService();

  // Refresh method to update list when returning from other pages
  void _refresh() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: AnimatedTextKit(
          animatedTexts: [
            TypewriterAnimatedText(
              'Chatty',
              textStyle: const TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              speed: const Duration(milliseconds: 350),
            ),
          ],
          totalRepeatCount: 1,
        ),
      ),
      // Floating Action Button to start new chats
      floatingActionButton: FloatingActionButton(
        elevation: 0,
        backgroundColor: const Color(0xFF1A60FF),
        shape: const CircleBorder(),
        onPressed: () async {
          // Wait for result to refresh list on return
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NewMessagePage(),
            ),
          );
          _refresh();
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
              onTap: _refresh, // Callback to refresh home when returning from chat
            );
          },
        ),
      ),
    );
  }
}