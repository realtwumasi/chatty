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

  // Reply fields
  final String? replyToId;
  final String? replyToSender;
  final String? replyToContent;

  Message({
    this.id = '',
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    required this.isMe,
    this.isSystem = false,
    this.status = MessageStatus.sent,
    this.replyToId,
    this.replyToSender,
    this.replyToContent,
  });

  factory Message.fromJson(Map<String, dynamic> json, String currentUserId) {
    final senderData = json['sender'] is Map ? json['sender'] : {};
    final senderId = senderData['id']?.toString() ?? json['sender_id']?.toString() ?? '';
    final senderName = senderData['username'] ?? json['sender_username'] ?? 'Unknown';

    // Handle reply data from API (assuming flattening or nested object)
    // If backend returns 'reply_to' object:
    final replyData = json['reply_to'] as Map<String, dynamic>?;

    return Message(
      id: json['id']?.toString() ?? json['message_id']?.toString() ?? '',
      senderId: senderId,
      senderName: senderName,
      text: json['content'] ?? '',
      timestamp: DateTime.tryParse(json['created_at'] ?? json['timestamp'] ?? '') ?? DateTime.now(),
      isMe: senderId == currentUserId,
      status: MessageStatus.sent, // Default to sent if not provided
      isSystem: json['is_system'] ?? false,
      replyToId: replyData?['id']?.toString() ?? json['reply_to_id']?.toString(),
      replyToSender: replyData?['sender_username'] ?? json['reply_to_sender']?.toString(),
      replyToContent: replyData?['content'] ?? json['reply_to_content']?.toString(),
    );
  }

  // For Local Storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'isMe': isMe,
      'isSystem': isSystem,
      'status': status.index,
      'replyToId': replyToId,
      'replyToSender': replyToSender,
      'replyToContent': replyToContent,
    };
  }

  factory Message.fromLocalJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      senderId: json['senderId'],
      senderName: json['senderName'],
      text: json['text'],
      timestamp: DateTime.parse(json['timestamp']),
      isMe: json['isMe'],
      isSystem: json['isSystem'] ?? false,
      status: MessageStatus.values[json['status'] ?? 1],
      replyToId: json['replyToId'],
      replyToSender: json['replyToSender'],
      replyToContent: json['replyToContent'],
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

  // For Local Storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isGroup': isGroup,
      'messages': messages.map((m) => m.toJson()).toList(),
      'participants': participants.map((u) => u.toJson()).toList(),
      'unreadCount': unreadCount,
    };
  }

  factory Chat.fromLocalJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'],
      name: json['name'],
      isGroup: json['isGroup'],
      messages: (json['messages'] as List?)
          ?.map((m) => Message.fromLocalJson(m))
          .toList() ??
          [],
      participants: (json['participants'] as List?)
          ?.map((u) => User.fromJson(u))
          .toList() ??
          [],
      unreadCount: json['unreadCount'] ?? 0,
    );
  }

  String get lastMessagePreview {
    if (messages.isEmpty) return "No messages yet";
    return messages.last.text;
  }

  String get lastMessageTime {
    if (messages.isEmpty) return "";
    final last = messages.last.timestamp;
    return "${last.hour}:${last.minute.toString().padLeft(2, '0')}";
  }

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