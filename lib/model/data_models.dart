// --- Data Models ---

// Represents a user in the system
class User {
  final String id;
  final String name;
  final String email;

  User({required this.id, required this.name, required this.email});
}

// Represents a single message
class Message {
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isMe; // Helper to determine if I sent it

  Message({
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.isMe,
  });
}

// Represents a conversation (Group or Private)
class Chat {
  final String id;
  final String name; // User name for private, Group name for groups
  final bool isGroup;
  final List<Message> messages;
  final List<User> participants;
  int unreadCount; // Tracks unread messages

  Chat({
    required this.id,
    required this.name,
    required this.isGroup,
    required this.messages,
    required this.participants,
    this.unreadCount = 0,
  });
}