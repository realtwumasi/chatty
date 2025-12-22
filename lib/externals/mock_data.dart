import 'package:flutter/foundation.dart';
import '../model/data_models.dart';

// Service now extends ChangeNotifier for reactive updates
class MockService extends ChangeNotifier {
  static final MockService _instance = MockService._internal();
  factory MockService() => _instance;
  MockService._internal();

  final User currentUser = User(id: 'me', name: 'Me', email: 'me@example.com');

  final List<User> allUsers = [
    User(id: '1', name: 'John Doe', email: 'john@example.com'),
    User(id: '2', name: 'Jane Smith', email: 'jane@example.com'),
    User(id: '3', name: 'Mike Johnson', email: 'mike@example.com'),
    User(id: '4', name: 'Sarah Williams', email: 'sarah@example.com'),
    User(id: '5', name: 'Tom Brown', email: 'tom@example.com'),
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
        Message(senderId: '1', text: 'I am good, just coding.', timestamp: DateTime.now().subtract(const Duration(minutes: 1)), isMe: false),
      ],
    ),
  ];

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
      notifyListeners(); // Notify UI to update
      return newChat;
    }
  }

  Chat createGroup(String groupName, List<User> members) {
    final newChat = Chat(
      id: DateTime.now().toIso8601String(),
      name: groupName,
      isGroup: true,
      participants: [currentUser, ...members],
      messages: [
        Message(
            senderId: 'system',
            text: 'Group "$groupName" created',
            timestamp: DateTime.now(),
            isMe: false
        )
      ],
      unreadCount: 0,
    );
    activeChats.insert(0, newChat);
    notifyListeners(); // Notify UI to update immediately
    return newChat;
  }

  void sendMessage(String chatId, String text) {
    final chat = activeChats.firstWhere((c) => c.id == chatId);
    chat.messages.add(
        Message(
          senderId: currentUser.id,
          text: text,
          timestamp: DateTime.now(),
          isMe: true,
        )
    );

    // Move to top and notify
    activeChats.remove(chat);
    activeChats.insert(0, chat);
    notifyListeners(); // Notify UI to update
  }
}