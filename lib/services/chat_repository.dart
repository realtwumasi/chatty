import 'dart:async';
import 'dart:convert';
import 'package:chatty/services/web_socket_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/data_models.dart';
import 'api_service.dart';


// --- Providers ---

final chatRepositoryProvider = Provider((ref) => ChatRepository(ref));

final userProvider = StateProvider<User?>((ref) => null);
final chatListProvider = StateProvider<List<Chat>>((ref) => []);
final allUsersProvider = StateProvider<List<User>>((ref) => []);
final isLoadingProvider = StateProvider<bool>((ref) => false);
final themeProvider = StateProvider<bool>((ref) => false);
final wsConnectionProvider = StateProvider<bool>((ref) => false);

final typingStatusProvider = StateProvider<Map<String, Set<String>>>((ref) => <String, Set<String>>{});

// --- Repository Logic ---

class ChatRepository {
  final Ref _ref;
  final ApiService _api = ApiService();
  final WebSocketService _ws = WebSocketService();

  final Map<String, Timer> _typingTimers = {};
  String? _activeChatId;

  ChatRepository(this._ref) {
    _ws.isConnected.addListener(() {
      _ref.read(wsConnectionProvider.notifier).state = _ws.isConnected.value;
      if (kDebugMode) print("WS Status Changed: ${_ws.isConnected.value}");
    });
  }

  static const String _keyUser = 'current_user';
  static const String _keyTheme = 'is_dark_mode';
  static const String _keyChats = 'local_chats';

  // --- Startup ---

  Future<bool> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final isDark = prefs.getBool(_keyTheme) ?? false;
      _ref.read(themeProvider.notifier).state = isDark;

      final userJson = prefs.getString(_keyUser);
      if (userJson != null) {
        try {
          final user = User.fromJson(jsonDecode(userJson));
          _ref.read(userProvider.notifier).state = user;
        } catch (_) {}
      }

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

    if (hasToken) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token != null) {
        _initWebSocket(token);
      }
    }

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

  // --- Active Chat Management ---
  void enterChat(String chatId) {
    _activeChatId = chatId;
    final chats = _ref.read(chatListProvider);
    final index = chats.indexWhere((c) => c.id == chatId);
    if (index != -1 && chats[index].unreadCount > 0) {
      final updatedChat = Chat(
        id: chats[index].id,
        name: chats[index].name,
        isGroup: chats[index].isGroup,
        participants: chats[index].participants,
        messages: chats[index].messages,
        unreadCount: 0,
        eventLog: chats[index].eventLog,
      );
      final newChatList = List<Chat>.from(chats);
      newChatList[index] = updatedChat;
      _ref.read(chatListProvider.notifier).state = newChatList;
      _saveChatsToLocal();

      _sendReadReceipt(chats[index]);
    }
  }

  void leaveChat() {
    _activeChatId = null;
  }

  void _sendReadReceipt(Chat chat) {
    if (chat.isGroup) {
      _ws.sendMarkRead(chat.id, null);
    } else {
      final currentUser = _ref.read(userProvider);
      final otherUser = chat.participants.firstWhere((u) => u.id != currentUser?.id, orElse: () => User(id: '', name: '', email: ''));
      if (otherUser.id.isNotEmpty) {
        _ws.sendMarkRead(null, otherUser.id);
      }
    }
  }

  // --- WebSocket Logic ---

  void _initWebSocket(String token) {
    _ws.connect(token);
    _ws.events.listen(_handleWebSocketEvent);
  }

  void _handleWebSocketEvent(Map<String, dynamic> event) {
    // ... same as before
    final type = event['type'];
    final data = event['data'];
    final payload = (data is Map<String, dynamic>) ? data : event;

    switch (type) {
      case 'connected':
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

      case 'user_removed':
        _handleUserRemoved(payload);
        break;

      case 'typing_indicator':
        _handleTypingIndicator(payload);
        break;
    }
  }

  void _handleNewMessage(Map<String, dynamic> payload, bool isGroup) {
    // ... same logic but wrap state updates
    final currentUser = _ref.read(userProvider);
    if (currentUser == null) return;

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
      final senderId = payload['sender_id']?.toString();
      final recipientId = payload['recipient_id']?.toString();
      final otherId = (senderId == currentUser.id) ? recipientId : senderId;
      chatIndex = chats.indexWhere((c) => !c.isGroup && c.participants.any((p) => p.id == otherId));

      if (chatIndex == -1 && otherId != null) {
        final otherUser = User(
            id: otherId,
            name: newMessage.isMe ? (payload['recipient_username'] ?? '?') : newMessage.senderName,
            email: ''
        );
        final newChat = Chat(
          id: otherId,
          name: otherUser.name,
          isGroup: false,
          messages: [newMessage],
          participants: [currentUser, otherUser],
          unreadCount: 1,
        );

        // Use microtask to avoid build conflicts
        Future.microtask(() {
          _ref.read(chatListProvider.notifier).state = [newChat, ...chats];
          _saveChatsToLocal();
        });
        return;
      }
    }

    if (chatIndex != -1) {
      final currentChat = chats[chatIndex];
      if (currentChat.messages.any((m) => m.id == newMessage.id)) return;

      final filteredMessages = currentChat.messages.where((m) {
        if (m.isMe && m.status == MessageStatus.sending && m.text == newMessage.text) {
          return false;
        }
        return true;
      }).toList();

      final updatedMessages = [...filteredMessages, newMessage];
      updatedMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      final bool isActive = _activeChatId == currentChat.id;
      final int newUnreadCount = isActive
          ? 0
          : currentChat.unreadCount + (newMessage.isMe ? 0 : 1);

      if (isActive && !newMessage.isMe) {
        _sendReadReceipt(currentChat);
      }

      final updatedChat = Chat(
        id: currentChat.id,
        name: currentChat.name,
        isGroup: currentChat.isGroup,
        participants: currentChat.participants,
        messages: updatedMessages,
        unreadCount: newUnreadCount,
        eventLog: currentChat.eventLog,
      );

      final newChatList = List<Chat>.from(chats);
      newChatList.removeAt(chatIndex);
      newChatList.insert(0, updatedChat);

      Future.microtask(() {
        _ref.read(chatListProvider.notifier).state = newChatList;
        _saveChatsToLocal();
      });
    }
  }

  void _handleTypingIndicator(Map<String, dynamic> payload) {
    // ... same as before
    final isTyping = payload['is_typing'] == true;
    final username = payload['username'] ?? 'Someone';
    final currentUser = _ref.read(userProvider);

    if (payload['user_id'].toString() == currentUser?.id) return;

    String? chatId;
    if (payload['group_id'] != null) {
      chatId = payload['group_id'].toString();
    } else if (payload['recipient_id'] != null) {
      chatId = payload['user_id'].toString();
    }

    if (chatId == null) return;

    final currentMap = _ref.read(typingStatusProvider);
    final newMap = Map<String, Set<String>>.from(currentMap);

    final currentSet = newMap[chatId] ?? <String>{};
    final newSet = Set<String>.from(currentSet);

    if (isTyping) {
      newSet.add(username);
      _typingTimers[chatId]?.cancel();
      _typingTimers[chatId] = Timer(const Duration(milliseconds: 3500), () {
        _clearTyping(chatId!, username);
      });
    } else {
      newSet.remove(username);
    }

    newMap[chatId] = newSet;
    Future.microtask(() {
      _ref.read(typingStatusProvider.notifier).state = newMap;
    });
  }

  void _clearTyping(String chatId, String username) {
    final currentMap = _ref.read(typingStatusProvider);
    if (currentMap.containsKey(chatId) && currentMap[chatId]!.contains(username)) {
      final newMap = Map<String, Set<String>>.from(currentMap);

      final newSet = Set<String>.from(newMap[chatId]!);
      newSet.remove(username);
      newMap[chatId] = newSet;

      _ref.read(typingStatusProvider.notifier).state = newMap;
    }
  }

  void sendTyping(String chatId, bool isGroup, bool isTyping) {
    if (isGroup) {
      _ws.sendTyping(chatId, null, isTyping);
    } else {
      _ws.sendTyping(null, chatId, isTyping);
    }
  }

  // --- Handlers for Join/Leave ---
  // ... (handleUserJoined, Left, Removed etc. basically same logic)
  void _handleUserJoined(Map<String, dynamic> payload) {
    _updateGroupMembership(payload, true);
  }

  void _handleUserLeft(Map<String, dynamic> payload) {
    _updateGroupMembership(payload, false);
  }

  void _handleUserRemoved(Map<String, dynamic> payload) {
    final groupId = payload['group_id']?.toString();
    final userId = payload['user_id']?.toString();
    final username = payload['username'];

    if (groupId == null || userId == null) return;

    final chats = _ref.read(chatListProvider);
    final chatIndex = chats.indexWhere((c) => c.id == groupId);

    if (chatIndex != -1) {
      final currentChat = chats[chatIndex];
      final sysMsg = _createSystemMessage("$username was removed from the group");

      List<User> newParticipants = List<User>.from(currentChat.participants);
      newParticipants.removeWhere((u) => u.id == userId);

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
      Future.microtask(() {
        _ref.read(chatListProvider.notifier).state = newChatList;
        _saveChatsToLocal();
      });
    }
  }

  void _updateGroupMembership(Map<String, dynamic> payload, bool isJoin) {
    final groupId = payload['group_id']?.toString();
    final userId = payload['user_id']?.toString();
    final username = payload['username'];

    if (groupId == null || userId == null) return;

    final chats = _ref.read(chatListProvider);
    final chatIndex = chats.indexWhere((c) => c.id == groupId);

    if (chatIndex != -1) {
      final currentChat = chats[chatIndex];
      final sysMsg = _createSystemMessage("$username ${isJoin ? 'joined' : 'left'} the group");

      List<User> newParticipants = List<User>.from(currentChat.participants);
      if (isJoin) {
        if (!newParticipants.any((u) => u.id == userId)) {
          newParticipants.add(User(id: userId, name: username, email: ''));
        }
      } else {
        newParticipants.removeWhere((u) => u.id == userId);
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
      Future.microtask(() {
        _ref.read(chatListProvider.notifier).state = newChatList;
        _saveChatsToLocal();
      });
    }
  }

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

  // --- Actions ---
  // ... (login, logout, etc remain mostly same, just added microtask where update happens)

  Future<void> login(String username, String password) async {
    _ref.read(isLoadingProvider.notifier).state = true;
    try {
      final response = await _api.post('/auth/login/', {'identifier': username, 'password': password});
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
    _ws.disconnect();
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
      await _api.post('/users/', {'username': username, 'email': email, 'password': password});
      await login(username, password);
    } catch (e) {
      rethrow;
    } finally {
      _ref.read(isLoadingProvider.notifier).state = false;
    }
  }

  Future<void> toggleTheme() async {
    final current = _ref.read(themeProvider);
    _ref.read(themeProvider.notifier).state = !current;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyTheme, !current);
    } catch (_) {}
  }

  Future<void> fetchUsers() async {
    try {
      final response = await _api.get('/users/');
      final List data = (response is Map && response.containsKey('results')) ? response['results'] : [];
      final newUsers = data.map((e) => User.fromJson(e)).toList();
      final currentUser = _ref.read(userProvider);
      if (currentUser != null) newUsers.removeWhere((u) => u.id == currentUser.id);
      _ref.read(allUsersProvider.notifier).state = newUsers;
    } catch (e) {
      if (kDebugMode) print("Fetch users error: $e");
    }
  }

  Future<void> fetchChats() async {
    try {
      final response = await _api.get('/groups/');
      final List groupData = (response is Map && response.containsKey('results')) ? response['results'] : [];
      final fetchedGroups = groupData.map((e) => Chat.fromGroupJson(e)).toList();

      final privateChats = await _fetchPrivateChatsFromHistory();

      final currentChats = _ref.read(chatListProvider);
      final mergedMap = <String, Chat>{};

      for (var chat in privateChats) {
        mergedMap[chat.id] = chat;
      }

      for (var group in fetchedGroups) {
        final local = currentChats.where((c) => c.id == group.id).firstOrNull;
        if (local != null) {
          mergedMap[group.id] = Chat(
            id: group.id,
            name: group.name,
            isGroup: group.isGroup,
            messages: local.messages,
            participants: local.participants.isEmpty ? group.participants : local.participants,
            unreadCount: local.unreadCount,
            eventLog: local.eventLog,
          );
        } else {
          mergedMap[group.id] = group;
        }
        if (_ws.isConnected.value) _ws.subscribeToGroup(group.id);
      }

      for (var local in currentChats) {
        if (!mergedMap.containsKey(local.id)) {
          mergedMap[local.id] = local;
        }
      }

      _ref.read(chatListProvider.notifier).state = mergedMap.values.toList();
      _saveChatsToLocal();
    } catch (e) {
      if (kDebugMode) print("Fetch chats error: $e");
    }
  }

  Future<List<Chat>> _fetchPrivateChatsFromHistory() async {
    try {
      final response = await _api.get('/messages/', params: {
        'message_type': 'private',
        'page_size': '100'
      });

      final List data = (response is Map && response.containsKey('results')) ? response['results'] : [];
      final currentUser = _ref.read(userProvider);
      if (currentUser == null) return [];

      final Map<String, List<Message>> msgsByPartner = {};
      final Map<String, User> partners = {};

      for (var msgJson in data) {
        final msg = Message.fromJson(msgJson, currentUser.id);

        final senderData = msgJson['sender'];
        final recipientData = msgJson['recipient'];

        String partnerId;
        User partnerUser;

        if (senderData['id'].toString() == currentUser.id) {
          partnerId = recipientData['id'].toString();
          partnerUser = User.fromJson(recipientData);
        } else {
          partnerId = senderData['id'].toString();
          partnerUser = User.fromJson(senderData);
        }

        if (!msgsByPartner.containsKey(partnerId)) {
          msgsByPartner[partnerId] = [];
          partners[partnerId] = partnerUser;
        }
        msgsByPartner[partnerId]!.add(msg);
      }

      final List<Chat> restoredChats = [];
      msgsByPartner.forEach((pid, msgs) {
        msgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        restoredChats.add(Chat(
          id: pid,
          name: partners[pid]!.name,
          isGroup: false,
          participants: [currentUser, partners[pid]!],
          messages: msgs,
          unreadCount: 0,
        ));
      });

      return restoredChats;
    } catch (e) {
      if (kDebugMode) print("Private chat restore error: $e");
      return [];
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
      final List data = (response is Map && response.containsKey('results')) ? response['results'] : [];

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
        final localOnlyMessages = currentMessages.where((m) =>
        m.status == MessageStatus.sending || m.status == MessageStatus.failed || m.isSystem
        ).toList();

        final finalMessages = [...newMsgs];
        for (var local in localOnlyMessages) {
          if (!finalMessages.any((m) => m.id == local.id)) {
            finalMessages.add(local);
          }
        }
        finalMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        final updatedChat = Chat(
          id: chats[chatIndex].id,
          name: chats[chatIndex].name,
          isGroup: chats[chatIndex].isGroup,
          participants: chats[chatIndex].participants,
          unreadCount: 0,
          eventLog: chats[chatIndex].eventLog,
          messages: finalMessages,
        );

        final newChatList = List<Chat>.from(chats);
        newChatList[chatIndex] = updatedChat;

        Future.microtask(() {
          _ref.read(chatListProvider.notifier).state = newChatList;
          _saveChatsToLocal();
        });
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
        Future.microtask(() {
          _ref.read(chatListProvider.notifier).state = newChatList;
          _saveChatsToLocal();
        });
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
      newChatList.removeAt(chatIndex);
      newChatList.insert(0, updatedChat);
      _ref.read(chatListProvider.notifier).state = newChatList;
      _saveChatsToLocal();
    }

    try {
      await _api.post(endpoint, body);
    } catch (e) {
      if (chatIndex != -1) {
        final currentChats = _ref.read(chatListProvider);
        final currentIndex = currentChats.indexWhere((c) => c.id == (isGroup ? targetId : chats[chatIndex].id));
        if (currentIndex != -1) {
          final msgs = List<Message>.from(currentChats[currentIndex].messages);
          if (msgs.isNotEmpty && msgs.last.status == MessageStatus.sending) {
            msgs.last.status = MessageStatus.failed;

            final failedChat = Chat(
              id: currentChats[currentIndex].id,
              name: currentChats[currentIndex].name,
              isGroup: currentChats[currentIndex].isGroup,
              participants: currentChats[currentIndex].participants,
              messages: msgs,
              unreadCount: currentChats[currentIndex].unreadCount,
              eventLog: currentChats[currentIndex].eventLog,
            );
            final newChatList = List<Chat>.from(currentChats);
            newChatList[currentIndex] = failedChat;
            _ref.read(chatListProvider.notifier).state = newChatList;
            _saveChatsToLocal();
          }
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
      if (currentUser != null) newChat.participants.add(currentUser);

      final currentChats = _ref.read(chatListProvider);
      _ref.read(chatListProvider.notifier).state = [newChat, ...currentChats];
      _saveChatsToLocal();
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

  // --- Add/Remove Members ---

  Future<void> addMemberToGroup(String groupId, String userId) async {
    try {
      await _api.post('/groups/$groupId/add_member/', {'user_id': userId});
      fetchGroupMembers(groupId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeMemberFromGroup(String groupId, String userId) async {
    try {
      await _api.post('/groups/$groupId/remove_member/', {'user_id': userId});
    } catch (e) {
      rethrow;
    }
  }
}