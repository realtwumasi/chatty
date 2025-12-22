import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../model/data_models.dart';

// Service now extends ChangeNotifier for reactive updates
class MockService extends ChangeNotifier {
  static final MockService _instance = MockService._internal();
  factory MockService() => _instance;

  // Feature: Fault detection timer
  Timer? _heartbeatTimer;

  MockService._internal() {
    // Feature: Start Heartbeat to detect active members
    _startHeartbeat();
  }

  final User currentUser = User(id: 'me', name: 'Me', email: 'me@example.com', isOnline: true);

  final List<User> allUsers = [
    User(id: '1', name: 'John Doe', email: 'john@example.com', isOnline: true),
    User(id: '2', name: 'Jane Smith', email: 'jane@example.com', isOnline: false),
    User(id: '3', name: 'Mike Johnson', email: 'mike@example.com', isOnline: true),
    User(id: '4', name: 'Sarah Williams', email: 'sarah@example.com', isOnline: false),
    User(id: '5', name: 'Tom Brown', email: 'tom@example.com', isOnline: true),
  ];

  List<Chat> activeChats = [
    Chat(
      id: 'c1',
      name: 'John Doe',
      isGroup: false,
      participants: [],
      unreadCount: 2,
      messages: [
        Message(senderId: '1', text: 'Hey there!', timestamp: DateTime.now().subtract(const Duration(minutes: 5)), isMe: false),
        Message(senderId: 'me', text: 'Hello! How are you?', timestamp: DateTime.now().subtract(const Duration(minutes: 4)), isMe: true),
      ],
    ),
  ];

  // --- Reliability Features ---

  // Feature: Fault detection (Heartbeat checks)
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (kDebugMode) print("Heartbeat: System Active. Checking user status...");
      // Simulate changing online status for demo purposes
      for (var user in allUsers) {
        if (Random().nextInt(10) > 7) { // 30% chance to toggle
          user.isOnline = !user.isOnline;
        }
      }
      notifyListeners();
    });
  }

  // --- Group Management Features ---

  // Feature: Leave a group
  void leaveGroup(String chatId) {
    final chat = activeChats.firstWhere((c) => c.id == chatId);
    if (chat.isGroup) {
      // Remove current user
      chat.participants.removeWhere((u) => u.id == currentUser.id);

      // Feature: Detect when member leaves (Log it)
      _addSystemMessage(chat, "${currentUser.name} left the group");

      // In a real app, we might archive this chat.
      // For now, we update the UI to reflect they are no longer a participant.
      notifyListeners();
    }
  }

  // Helper for System Logs
  void _addSystemMessage(Chat chat, String text) {
    chat.messages.add(Message(
      senderId: 'system',
      text: text,
      timestamp: DateTime.now(),
      isMe: false,
      isSystem: true,
    ));
    // Feature: Keep a simple log
    chat.eventLog.add("[${DateTime.now()}] SYSTEM: $text");
  }

  Chat getOrCreatePrivateChat(User otherUser) {
    try {
      return activeChats.firstWhere((chat) =>
      !chat.isGroup && chat.name == otherUser.name);
    } catch (e) {
      final newChat = Chat(
        id: DateTime.now().toIso8601String(),
        name: otherUser.name,
        isGroup: false,
        participants: [currentUser, otherUser],
        messages: [],
        unreadCount: 0,
      );
      activeChats.insert(0, newChat);
      notifyListeners();
      return newChat;
    }
  }

  Chat createGroup(String groupName, List<User> members) {
    // Feature: System keeps track of active members (participants list)
    final allMembers = [currentUser, ...members];

    final newChat = Chat(
      id: DateTime.now().toIso8601String(),
      name: groupName,
      isGroup: true,
      participants: allMembers,
      messages: [
        Message(
          senderId: 'system',
          text: 'Group "$groupName" created with ${allMembers.length} members',
          timestamp: DateTime.now(),
          isMe: false,
          isSystem: true,
        )
      ],
      unreadCount: 0,
    );
    activeChats.insert(0, newChat);
    notifyListeners();
    return newChat;
  }

  // Feature: Retry message delivery if recipient unreachable (Simulated)
  Future<void> sendMessage(String chatId, String text) async {
    final chat = activeChats.firstWhere((c) => c.id == chatId);

    // 1. Create message with 'sending' status
    final newMessage = Message(
      senderId: currentUser.id,
      text: text,
      timestamp: DateTime.now(),
      isMe: true,
      status: MessageStatus.sending,
    );

    chat.messages.add(newMessage);
    notifyListeners();

    // 2. Simulate Network Delay
    await Future.delayed(const Duration(milliseconds: 600));

    // 3. Simulate Random Failure (Reliability Test)
    bool simulatedFailure = Random().nextDouble() < 0.15; // 15% fail rate

    if (simulatedFailure) {
      newMessage.status = MessageStatus.failed;
      notifyListeners();

      // Feature: Retry logic
      if (kDebugMode) print("Message failed. Retrying...");
      await Future.delayed(const Duration(seconds: 1));
      newMessage.status = MessageStatus.delivered;
      if (kDebugMode) print("Retry successful.");
    } else {
      newMessage.status = MessageStatus.delivered;
    }

    // Feature: Log message
    chat.eventLog.add("[${DateTime.now()}] MSG: $text");

    // Move to top
    activeChats.remove(chat);
    activeChats.insert(0, chat);
    notifyListeners();
  }
}