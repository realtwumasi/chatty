// --- Data Models ---

enum MessageStatus { sending, sent, delivered, read, failed }

// Represents a user in the system
class User {
  final String id;
  final String name;
  final String email;
  bool isOnline; // Feature: Presence detection

  User({
    required this.id,
    required this.name,
    required this.email,
    this.isOnline = false, // Default to offline
  });

  // Feature: Equality overrides for set operations in Group Creation
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is User && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// Represents a single message
class Message {
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isMe;
  final bool isSystem; // Feature: For Join/Leave logs
  MessageStatus status; // Feature: Reliability (Retry/Status)

  Message({
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.isMe,
    this.isSystem = false,
    this.status = MessageStatus.sent,
  });
}

// Represents a conversation (Group or Private)
class Chat {
  final String id;
  final String name;
  final bool isGroup;
  final List<Message> messages;
  final List<User> participants;
  int unreadCount;
  final List<String> eventLog; // Feature: Simple log of messages/events

  Chat({
    required this.id,
    required this.name,
    required this.isGroup,
    required this.messages,
    required this.participants,
    this.unreadCount = 0,
    this.eventLog = const [],
  });
}