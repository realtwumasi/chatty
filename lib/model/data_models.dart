enum MessageStatus { sending, sent, delivered, read, failed }

class User {
  final String id;
  final String name;
  final String email;
  bool isOnline;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.isOnline = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      // API returns 'username', fallback to 'email' if missing
      name: json['username'] ?? json['email'] ?? 'Unknown',
      email: json['email'] ?? '',
      // API doesn't seem to have is_online in User schema, defaulting to false
      isOnline: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': name,
      'email': email,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is User && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class Message {
  final String id;
  final String senderId;
  final String senderName; // Added to handle UI needs
  final String text;
  final DateTime timestamp;
  final bool isMe;
  final bool isSystem;
  MessageStatus status;

  Message({
    this.id = '',
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    required this.isMe,
    this.isSystem = false,
    this.status = MessageStatus.sent,
  });

  factory Message.fromJson(Map<String, dynamic> json, String currentUserId) {
    // API returns 'sender' as a full User object
    final senderData = json['sender'] is Map ? json['sender'] : {};
    final senderId = senderData['id']?.toString() ?? '';
    final senderName = senderData['username'] ?? 'Unknown';

    return Message(
      id: json['id']?.toString() ?? '',
      senderId: senderId,
      senderName: senderName,
      text: json['content'] ?? '',
      timestamp: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      isMe: senderId == currentUserId,
      isSystem: false, // API doesn't specify system messages yet
      status: MessageStatus.sent, // Defaulting as API doesn't return status enum
    );
  }
}

class Chat {
  final String id;
  final String name;
  final bool isGroup;
  final List<Message> messages;
  final List<User> participants;
  int unreadCount;
  final List<String> eventLog;

  Chat({
    required this.id,
    required this.name,
    required this.isGroup,
    required this.messages,
    required this.participants,
    this.unreadCount = 0,
    this.eventLog = const [],
  });

  // Helper to create a Chat from a Group API response
  factory Chat.fromGroupJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Group Chat',
      isGroup: true,
      unreadCount: 0, // Not provided in group list directly
      messages: [], // Messages fetched separately
      participants: [], // Fetched via /groups/{id}/members/
    );
  }
}