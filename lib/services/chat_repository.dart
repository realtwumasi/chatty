import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/data_models.dart';
import 'api_service.dart';
import 'package:chatty/services/web_socket_service.dart';
// --- Providers ---

final chatRepositoryProvider = Provider((ref) => ChatRepository(ref));

final userProvider = StateProvider<User?>((ref) => null);
final chatListProvider = StateProvider<List<Chat>>((ref) => []);
final allUsersProvider = StateProvider<List<User>>((ref) => []);
final isLoadingProvider = StateProvider<bool>((ref) => false);
final themeProvider = StateProvider<bool>((ref) => false);

// --- Repository Logic ---

class ChatRepository {
  final Ref _ref;
  final ApiService _api = ApiService();
  final WebSocketService _ws = WebSocketService();

  ChatRepository(this._ref);

  static const String _keyUser = 'current_user';
  static const String _keyTheme = 'is_dark_mode';
  static const String _keyChats = 'local_chats';

  // --- Startup ---

  Future<bool> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load Theme
      final isDark = prefs.getBool(_keyTheme) ?? false;
      _ref.read(themeProvider.notifier).state = isDark;

      // Load User
      final userJson = prefs.getString(_keyUser);
      if (userJson != null) {
        try {
          final user = User.fromJson(jsonDecode(userJson));
          _ref.read(userProvider.notifier).state = user;
        } catch (_) {}
      }

      // Load Local Chats (Offline Access)
      final chatsJson = prefs.getString(_keyChats);
      if (chatsJson != null) {
        try {
          final List<dynamic> decoded = jsonDecode(chatsJson);
          final localChats = decoded.map((e) => Chat.fromLocalJson(e)).toList();
          _ref.read(chatListProvider.notifier).state = localChats;
        } catch (e) {
          if (kDebugMode) print("Error loading local chats: $e");
        }
      }

    } catch (e) {
      if (kDebugMode) print("Storage Warning: Failed to init storage: $e");
    }

    final hasToken = await _api.loadTokens();
    final currentUser = _ref.read(userProvider);

    if (!hasToken && currentUser == null) {
      return false;
    }

    // Initialize WS if we have a token (even if offline initially, we try)
    if (hasToken) {
      // We need the raw token string which is stored in ApiService or SharedPreferences
      // Ideally ApiService exposes it, or we re-fetch from prefs.
      // For simplicity, we re-fetch from prefs here or assume ApiService has it.
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token != null) {
        _initWebSocket(token);
      }
    }

    // Attempt to sync online data
    try {
      await Future.wait([
        fetchUsers(),
        fetchChats(),
      ]);
      return true;
    } catch (e) {
      if (e.toString().contains('401')) {
        await logout();
        return false;
      }
      return currentUser != null;
    }
  }

  // --- WebSocket Logic ---

  void _initWebSocket(String token) {
    _ws.connect(token);
    _ws.events.listen(_handleWebSocketEvent);
  }

  void _handleWebSocketEvent(Map<String, dynamic> event) {
    final type = event['type'];
    final data = event['data']; // Data is usually a map inside the event

    // The doc says: "Events Received ... { 'type': 'group_message', ... }"
    // But the payload structure usually is { type: "...", ...data_fields }
    // OR { type: "...", data: { ... } }.
    // Based on the doc "Data Structure" column, it implies the fields are top level or in a data object.
    // Standard practice with this stack implies data is usually the payload.
    // Let's assume `event` contains the type and the fields are either top-level or in `data`.
    // We will handle the case where `data` might be the event itself or a field.
    final payload = (data is Map<String, dynamic>) ? data : event;

    switch (type) {
      case 'connected':
      // Once connected, subscribe to all known groups
        final chats = _ref.read(chatListProvider);
        for (var chat in chats) {
          if (chat.isGroup) {
            _ws.subscribeToGroup(chat.id);
          }
        }
        break;

      case 'group_message':
      case 'private_message':
        _handleNewMessage(payload, type == 'group_message');
        break;

      case 'user_joined':
        _handleUserJoined(payload);
        break;

      case 'user_left':
        _handleUserLeft(payload);
        break;
    }
  }

  void _handleNewMessage(Map<String, dynamic> payload, bool isGroup) {
    // Map WS payload to Message model
    // Payload: {message_id, sender_id, sender_username, content, group_id, group_name, timestamp}
    final currentUser = _ref.read(userProvider);
    if (currentUser == null) return;

    // Avoid duplicating own messages if we handled them optimistically
    // Ideally, we replace the temp message with the real one.
    if (payload['sender_id'] == currentUser.id) {
      // We could confirm the message here, but simpler to just let the fetch sync happen or ignore
      // For now, we will add it, duplicate check handles if ID matches
    }

    final newMessage = Message(
      id: payload['message_id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: payload['sender_id']?.toString() ?? '',
      senderName: payload['sender_username'] ?? 'Unknown',
      text: payload['content'] ?? '',
      timestamp: DateTime.tryParse(payload['timestamp'] ?? '') ?? DateTime.now(),
      isMe: payload['sender_id'].toString() == currentUser.id,
      status: MessageStatus.delivered,
    );

    final chats = _ref.read(chatListProvider);
    int chatIndex = -1;

    if (isGroup) {
      final groupId = payload['group_id']?.toString();
      chatIndex = chats.indexWhere((c) => c.id == groupId);
    } else {
      // Private message
      final senderId = payload['sender_id']?.toString();
      final recipientId = payload['recipient_id']?.toString();
      final otherId = (senderId == currentUser.id) ? recipientId : senderId;

      chatIndex = chats.indexWhere((c) => !c.isGroup && c.participants.any((p) => p.id == otherId));

      // If private chat doesn't exist yet (new incoming DM), create it
      if (chatIndex == -1 && otherId != null) {
        // We might need to fetch user details or create a basic user object
        final otherUser = User(id: otherId, name: isGroup ? '?' : (newMessage.isMe ? payload['recipient_username'] : newMessage.senderName), email: '');
        // Create locally
        final newChat = Chat(
          id: otherId,
          name: otherUser.name,
          isGroup: false,
          messages: [newMessage],
          participants: [currentUser, otherUser],
          unreadCount: 1,
        );
        _ref.read(chatListProvider.notifier).state = [newChat, ...chats];
        _saveChatsToLocal();
        return;
      }
    }

    if (chatIndex != -1) {
      final currentChat = chats[chatIndex];
      // Check deduplication
      if (currentChat.messages.any((m) => m.id == newMessage.id)) return;

      final updatedMessages = [...currentChat.messages, newMessage];
      // Sort
      updatedMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      final updatedChat = Chat(
        id: currentChat.id,
        name: currentChat.name,
        isGroup: currentChat.isGroup,
        participants: currentChat.participants,
        messages: updatedMessages,
        unreadCount: currentChat.unreadCount + 1, // Increment unread
        eventLog: currentChat.eventLog,
      );

      final newChatList = List<Chat>.from(chats);
      newChatList[chatIndex] = updatedChat;
      _ref.read(chatListProvider.notifier).state = newChatList;
      _saveChatsToLocal();
    }
  }

  void _handleUserJoined(Map<String, dynamic> payload) {
    final groupId = payload['group_id']?.toString();
    final userId = payload['user_id']?.toString();
    final username = payload['username'];

    if (groupId == null || userId == null) return;

    final chats = _ref.read(chatListProvider);
    final chatIndex = chats.indexWhere((c) => c.id == groupId);

    if (chatIndex != -1) {
      final currentChat = chats[chatIndex];

      // Add System Message
      final sysMsg = _createSystemMessage("$username joined the group");

      // Add User to participants if not exists
      final newParticipants = List<User>.from(currentChat.participants);
      if (!newParticipants.any((u) => u.id == userId)) {
        newParticipants.add(User(id: userId, name: username, email: ''));
      }

      final updatedChat = Chat(
        id: currentChat.id,
        name: currentChat.name,
        isGroup: currentChat.isGroup,
        participants: newParticipants,
        messages: [...currentChat.messages, sysMsg],
        unreadCount: currentChat.unreadCount,
        eventLog: currentChat.eventLog,
      );

      final newChatList = List<Chat>.from(chats);
      newChatList[chatIndex] = updatedChat;
      _ref.read(chatListProvider.notifier).state = newChatList;
      _saveChatsToLocal();
    }
  }

  void _handleUserLeft(Map<String, dynamic> payload) {
    final groupId = payload['group_id']?.toString();
    final userId = payload['user_id']?.toString();
    final username = payload['username'];

    if (groupId == null || userId == null) return;

    final chats = _ref.read(chatListProvider);
    final chatIndex = chats.indexWhere((c) => c.id == groupId);

    if (chatIndex != -1) {
      final currentChat = chats[chatIndex];

      // Add System Message
      final sysMsg = _createSystemMessage("$username left the group");

      // Remove User
      final newParticipants = currentChat.participants.where((u) => u.id != userId).toList();

      final updatedChat = Chat(
        id: currentChat.id,
        name: currentChat.name,
        isGroup: currentChat.isGroup,
        participants: newParticipants,
        messages: [...currentChat.messages, sysMsg],
        unreadCount: currentChat.unreadCount,
        eventLog: currentChat.eventLog,
      );

      final newChatList = List<Chat>.from(chats);
      newChatList[chatIndex] = updatedChat;
      _ref.read(chatListProvider.notifier).state = newChatList;
      _saveChatsToLocal();
    }
  }

  // --- Helper: Save to Local Storage ---
  void _saveChatsToLocal() {
    final chats = _ref.read(chatListProvider);
    SharedPreferences.getInstance().then((prefs) {
      try {
        final jsonStr = jsonEncode(chats.map((c) => c.toJson()).toList());
        prefs.setString(_keyChats, jsonStr);
      } catch (e) {
        if (kDebugMode) print("Error saving local chats: $e");
      }
    });
  }

  // --- Auth ---

  Future<void> login(String username, String password) async {
    _ref.read(isLoadingProvider.notifier).state = true;
    try {
      final response = await _api.post('/auth/login/', {
        'identifier': username,
        'password': password,
      });

      final tokens = response['tokens'];
      final accessToken = tokens['access'];
      await _api.setTokens(access: accessToken, refresh: tokens['refresh']);

      final userData = response['user'];
      final user = User(
        id: userData['id']?.toString() ?? '',
        email: userData['email'] ?? '',
        name: userData['username'] ?? username,
        isOnline: true,
      );

      _ref.read(userProvider.notifier).state = user;

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyUser, jsonEncode(user.toJson()));
      } catch (_) {}

      // Connect WebSocket
      _initWebSocket(accessToken);

      await Future.wait([fetchUsers(), fetchChats()]);

    } catch (e) {
      rethrow;
    } finally {
      _ref.read(isLoadingProvider.notifier).state = false;
    }
  }

  Future<void> logout() async {
    _ref.read(userProvider.notifier).state = null;
    _ref.read(chatListProvider.notifier).state = [];
    _ref.read(allUsersProvider.notifier).state = [];
    _ws.disconnect(); // Disconnect WS
    await _api.clearTokens();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUser);
      await prefs.remove(_keyChats);
    } catch (_) {}
  }

  Future<void> register(String username, String email, String password) async {
    _ref.read(isLoadingProvider.notifier).state = true;
    try {
      await _api.post('/users/', {
        'username': username,
        'email': email,
        'password': password,
      });
      await login(username, password);
    } catch (e) {
      rethrow;
    } finally {
      _ref.read(isLoadingProvider.notifier).state = false;
    }
  }

  // --- Theme ---

  Future<void> toggleTheme() async {
    final current = _ref.read(themeProvider);
    _ref.read(themeProvider.notifier).state = !current;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyTheme, !current);
    } catch (_) {}
  }

  // --- Data ---

  Future<void> fetchUsers() async {
    try {
      final response = await _api.get('/users/');
      final List data = (response is Map && response.containsKey('results'))
          ? response['results']
          : [];

      final newUsers = data.map((e) => User.fromJson(e)).toList();
      final currentUser = _ref.read(userProvider);

      if (currentUser != null) {
        newUsers.removeWhere((u) => u.id == currentUser.id);
      }

      _ref.read(allUsersProvider.notifier).state = newUsers;
    } catch (e) {
      if (kDebugMode) print("Fetch users error: $e");
    }
  }

  Future<void> fetchChats() async {
    try {
      final response = await _api.get('/groups/');
      final List groupData = (response is Map && response.containsKey('results'))
          ? response['results']
          : [];

      final fetchedChats = groupData.map((e) => Chat.fromGroupJson(e)).toList();

      final currentChats = _ref.read(chatListProvider);
      final mergedChats = <Chat>[];

      for (var fetched in fetchedChats) {
        final existing = currentChats.where((c) => c.id == fetched.id).firstOrNull;
        if (existing != null) {
          mergedChats.add(Chat(
            id: fetched.id,
            name: fetched.name,
            isGroup: fetched.isGroup,
            messages: existing.messages,
            participants: existing.participants.isEmpty ? fetched.participants : existing.participants,
            unreadCount: existing.unreadCount,
            eventLog: existing.eventLog,
          ));

          // Re-subscribe if we just fetched and are connected
          if (_ws.isConnected) _ws.subscribeToGroup(fetched.id);
        } else {
          mergedChats.add(fetched);
          if (_ws.isConnected) _ws.subscribeToGroup(fetched.id);
        }
      }

      for (var local in currentChats) {
        if (!local.isGroup && !mergedChats.any((c) => c.id == local.id)) {
          mergedChats.add(local);
        }
      }

      _ref.read(chatListProvider.notifier).state = mergedChats;
      _saveChatsToLocal();
    } catch (e) {
      if (kDebugMode) print("Fetch chats error: $e");
    }
  }

  Future<void> fetchMessagesForChat(String chatId, bool isGroup) async {
    try {
      if (isGroup) {
        fetchGroupMembers(chatId).catchError((e){});
      }

      final Map<String, String> params = isGroup
          ? {'group': chatId, 'message_type': 'group'}
          : {'recipient': chatId, 'message_type': 'private'};

      final response = await _api.get('/messages/', params: params);

      final List data = (response is Map && response.containsKey('results'))
          ? response['results']
          : [];

      final currentUser = _ref.read(userProvider);
      if (currentUser == null) return;

      final chats = _ref.read(chatListProvider);
      final chatIndex = chats.indexWhere((c) => isGroup
          ? c.id == chatId
          : c.participants.any((p) => p.id == chatId && p.id != currentUser.id));

      if (chatIndex != -1) {
        final newMsgs = data.map((e) => Message.fromJson(e, currentUser.id)).toList();
        newMsgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        final currentMessages = chats[chatIndex].messages;
        final unsyncedMessages = currentMessages.where((m) =>
        m.status == MessageStatus.sending || m.status == MessageStatus.failed
        ).toList();

        final finalMessages = [...newMsgs];
        for (var m in unsyncedMessages) {
          if (!finalMessages.any((fm) => fm.text == m.text && fm.timestamp.difference(m.timestamp).inSeconds.abs() < 2)) {
            finalMessages.add(m);
          }
        }

        final systemMessages = currentMessages.where((m) => m.isSystem).toList();
        for (var sysMsg in systemMessages) {
          if (!finalMessages.any((m) => m.id == sysMsg.id)) {
            finalMessages.add(sysMsg);
          }
        }
        finalMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        final updatedChat = Chat(
          id: chats[chatIndex].id,
          name: chats[chatIndex].name,
          isGroup: chats[chatIndex].isGroup,
          participants: chats[chatIndex].participants,
          unreadCount: chats[chatIndex].unreadCount,
          eventLog: chats[chatIndex].eventLog,
          messages: finalMessages,
        );

        final newChatList = List<Chat>.from(chats);
        newChatList[chatIndex] = updatedChat;
        _ref.read(chatListProvider.notifier).state = newChatList;
        _saveChatsToLocal();
      }
    } catch (e) {
      if (kDebugMode) print("Fetch messages error: $e");
    }
  }

  Future<void> fetchGroupMembers(String chatId) async {
    try {
      final response = await _api.get('/groups/$chatId/members/');
      final List data = (response is Map && response.containsKey('members')) ? response['members'] : [];
      final newMembers = data.map((m) => User.fromJson(m['user'])).toList();

      final chats = _ref.read(chatListProvider);
      final chatIndex = chats.indexWhere((c) => c.id == chatId && c.isGroup);

      if (chatIndex != -1) {
        final currentChat = chats[chatIndex];
        // We now rely on WS for real-time join/leave events,
        // but this fetch is good for initial sync or reconciliation.
        // We won't generate system messages here to avoid duplication with WS events.

        final updatedChat = Chat(
          id: currentChat.id,
          name: currentChat.name,
          isGroup: currentChat.isGroup,
          messages: currentChat.messages,
          participants: newMembers,
          unreadCount: currentChat.unreadCount,
          eventLog: currentChat.eventLog,
        );

        final newChatList = List<Chat>.from(chats);
        newChatList[chatIndex] = updatedChat;
        _ref.read(chatListProvider.notifier).state = newChatList;
        _saveChatsToLocal();
      }
    } catch (e) {
      if (kDebugMode) print("Fetch group members error: $e");
    }
  }

  Message _createSystemMessage(String text) {
    return Message(
        id: 'sys_${DateTime.now().millisecondsSinceEpoch}_${text.hashCode}',
        senderId: 'system',
        senderName: 'System',
        text: text,
        timestamp: DateTime.now(),
        isMe: false,
        isSystem: true,
        status: MessageStatus.delivered
    );
  }

  // --- Actions ---

  Future<Chat> startPrivateChat(User otherUser) async {
    final chats = _ref.read(chatListProvider);
    final currentUser = _ref.read(userProvider);
    if (currentUser == null) throw Exception("User not logged in");

    try {
      return chats.firstWhere((c) => !c.isGroup && c.participants.any((p) => p.id == otherUser.id));
    } catch (_) {
      final newChat = Chat(
        id: otherUser.id,
        name: otherUser.name,
        isGroup: false,
        messages: [],
        participants: [currentUser, otherUser],
      );

      _ref.read(chatListProvider.notifier).state = [newChat, ...chats];
      _saveChatsToLocal();
      return newChat;
    }
  }

  Future<void> resendMessage(String chatId, Message message, bool isGroup) async {
    final chats = _ref.read(chatListProvider);
    final chatIndex = chats.indexWhere((c) => isGroup ? c.id == chatId : c.participants.any((p) => p.id == chatId));

    if (chatIndex != -1) {
      final updatedMsgs = chats[chatIndex].messages.where((m) => m.id != message.id).toList();
      final updatedChat = Chat(
        id: chats[chatIndex].id,
        name: chats[chatIndex].name,
        isGroup: chats[chatIndex].isGroup,
        participants: chats[chatIndex].participants,
        messages: updatedMsgs,
        unreadCount: chats[chatIndex].unreadCount,
        eventLog: chats[chatIndex].eventLog,
      );
      final newChatList = List<Chat>.from(chats);
      newChatList[chatIndex] = updatedChat;
      _ref.read(chatListProvider.notifier).state = newChatList;
      _saveChatsToLocal();
    }

    await sendMessage(chatId, message.text, isGroup);
  }

  Future<void> sendMessage(String targetId, String content, bool isGroup) async {
    final currentUser = _ref.read(userProvider);
    if (currentUser == null) return;

    final endpoint = '/messages/';
    final body = {
      'content': content,
      'message_type': isGroup ? 'group' : 'private',
      if (isGroup) 'group': targetId else 'recipient_id': targetId,
    };

    final chats = _ref.read(chatListProvider);
    final chatIndex = chats.indexWhere((c) => isGroup
        ? c.id == targetId
        : c.participants.any((p) => p.id == targetId));

    if (chatIndex != -1) {
      final tempMsg = Message(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        senderId: currentUser.id,
        senderName: currentUser.name,
        text: content,
        timestamp: DateTime.now(),
        isMe: true,
        status: MessageStatus.sending,
      );

      final updatedChat = Chat(
        id: chats[chatIndex].id,
        name: chats[chatIndex].name,
        isGroup: chats[chatIndex].isGroup,
        participants: chats[chatIndex].participants,
        unreadCount: chats[chatIndex].unreadCount,
        eventLog: chats[chatIndex].eventLog,
        messages: [...chats[chatIndex].messages, tempMsg],
      );

      final newChatList = List<Chat>.from(chats);
      newChatList[chatIndex] = updatedChat;
      _ref.read(chatListProvider.notifier).state = newChatList;
      _saveChatsToLocal();
    }

    try {
      await _api.post(endpoint, body);
      // We don't fetch messages here anymore, we rely on the WebSocket to deliver the confirmed message
      // However, we might want to refresh to get the real ID if WS is slow or to confirm sent status
      // For responsiveness, trust WS.
    } catch (e) {
      if (chatIndex != -1) {
        final currentChats = _ref.read(chatListProvider);
        final msgs = List<Message>.from(currentChats[chatIndex].messages);
        if (msgs.isNotEmpty && msgs.last.status == MessageStatus.sending) {
          msgs.last.status = MessageStatus.failed;

          final failedChat = Chat(
            id: currentChats[chatIndex].id,
            name: currentChats[chatIndex].name,
            isGroup: currentChats[chatIndex].isGroup,
            participants: currentChats[chatIndex].participants,
            messages: msgs,
            unreadCount: currentChats[chatIndex].unreadCount,
            eventLog: currentChats[chatIndex].eventLog,
          );
          final newChatList = List<Chat>.from(currentChats);
          newChatList[chatIndex] = failedChat;
          _ref.read(chatListProvider.notifier).state = newChatList;
          _saveChatsToLocal();
        }
      }
      rethrow;
    }
  }

  Future<Chat> createGroup(String name, List<User> members) async {
    try {
      final response = await _api.post('/groups/', {
        'name': name,
        'description': 'Created via Chatty'
      });
      final newChat = Chat.fromGroupJson(response);

      final currentUser = _ref.read(userProvider);
      if (currentUser != null) {
        newChat.participants.add(currentUser);
      }

      final currentChats = _ref.read(chatListProvider);
      _ref.read(chatListProvider.notifier).state = [newChat, ...currentChats];
      _saveChatsToLocal();

      // Subscribe to new group
      _ws.subscribeToGroup(newChat.id);

      return newChat;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> joinGroup(String chatId) async {
    try {
      await _api.post('/groups/$chatId/join/', {});
      await fetchGroupMembers(chatId);
      await fetchChats();
      _ws.subscribeToGroup(chatId);
    } catch (e) {
      rethrow;
    }
  }

  void leaveGroup(String chatId) {
    final chats = _ref.read(chatListProvider);
    final newChats = chats.where((c) => c.id != chatId).toList();
    _ref.read(chatListProvider.notifier).state = newChats;
    _saveChatsToLocal();
    _ws.unsubscribeFromGroup(chatId);
    _api.post('/groups/$chatId/leave/', {});
  }
}