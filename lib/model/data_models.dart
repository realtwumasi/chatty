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
      // API Spec: 'username' is the display name. Fallback to email.
      name: json['username'] ?? json['email'] ?? 'Unknown',
      email: json['email'] ?? '',
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
  final String senderName;
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
    // API Spec: 'sender' is a full User object reference
    final senderData = json['sender'] is Map ? json['sender'] : {};
    final senderId = senderData['id']?.toString() ?? '';
    final senderName = senderData['username'] ?? 'Unknown';

    return Message(
      id: json['id']?.toString() ?? '',
      senderId: senderId,
      senderName: senderName,
      text: json['content'] ?? '',
      // API Spec: 'created_at'
      timestamp: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      isMe: senderId == currentUserId,
      status: MessageStatus.sent,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Message &&
              runtimeType == other.runtimeType &&
              id == other.id &&
              status == other.status;

  @override
  int get hashCode => id.hashCode ^ status.hashCode;
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

  factory Chat.fromGroupJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Group Chat',
      isGroup: true,
      unreadCount: 0,
      messages: [],
      participants: [],
    );
  }

  // Optimization: Cached-like getters for UI
  String get lastMessagePreview {
    if (messages.isEmpty) return "No messages yet";
    return messages.last.text;
  }

  String get lastMessageTime {
    if (messages.isEmpty) return "";
    final last = messages.last.timestamp;
    return "${last.hour}:${last.minute.toString().padLeft(2, '0')}";
  }

  // Optimization: Equality check to prevent unnecessary rebuilds
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Chat &&
              runtimeType == other.runtimeType &&
              id == other.id &&
              unreadCount == other.unreadCount &&
              messages.length == other.messages.length &&
              (messages.isEmpty || messages.last == other.messages.last);

  @override
  int get hashCode => id.hashCode ^ unreadCount.hashCode ^ messages.length.hashCode;
}