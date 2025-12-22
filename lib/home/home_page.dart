import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
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
    // Listen to changes in the service (e.g., new group created)
    _service.addListener(_refresh);
  }

  @override
  void dispose() {
    // Clean up listener to prevent memory leaks
    _service.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
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
      floatingActionButton: FloatingActionButton(
        elevation: 0,
        backgroundColor: const Color(0xFF1A60FF),
        shape: const CircleBorder(),
        onPressed: () {
          // No longer need to await Navigator because we use a Listener now
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
              onTap: () {
                // Optional: force refresh just in case, though listener handles data
                _refresh();
              },
            );
          },
        ),
      ),
    );
  }
}