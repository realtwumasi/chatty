import 'dart:convert';
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

// --- Repository Logic ---

class ChatRepository {
  final Ref _ref;
  final ApiService _api = ApiService();

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
      // Return true if we have a user (offline mode enabled)
      return currentUser != null;
    }
  }

  // --- Helper: Save to Local Storage ---
  void _saveChatsToLocal() {
    final chats = _ref.read(chatListProvider);
    // Debounce or run in background could be optimization, for now run directly
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
      await _api.setTokens(access: tokens['access'], refresh: tokens['refresh']);

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
    await _api.clearTokens();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUser);
      await prefs.remove(_keyChats); // Clear chats on logout
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

      // Merge with local data to preserve messages and participants we might have cached
      final currentChats = _ref.read(chatListProvider);
      final mergedChats = <Chat>[];

      for (var fetched in fetchedChats) {
        final existing = currentChats.where((c) => c.id == fetched.id).firstOrNull;
        if (existing != null) {
          // Keep messages and participants from local if available
          mergedChats.add(Chat(
            id: fetched.id,
            name: fetched.name, // Name might have changed on server
            isGroup: fetched.isGroup,
            messages: existing.messages,
            participants: existing.participants.isEmpty ? fetched.participants : existing.participants,
            unreadCount: existing.unreadCount,
            eventLog: existing.eventLog,
          ));
        } else {
          mergedChats.add(fetched);
        }
      }

      // Also keep private chats that might not be in the /groups/ endpoint if it only returns groups
      // (Depending on API, usually private chats are implicit. If /groups/ returns only groups,
      // we need to keep our local private chats)
      for (var local in currentChats) {
        if (!local.isGroup && !mergedChats.any((c) => c.id == local.id)) {
          mergedChats.add(local);
        }
      }

      _ref.read(chatListProvider.notifier).state = mergedChats;
      _saveChatsToLocal(); // Save
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

        // Preserve temporary/failed messages
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
        _saveChatsToLocal(); // Save after messages update
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

        final oldMemberIds = currentChat.participants.map((u) => u.id).toSet();
        final newMemberIds = newMembers.map((u) => u.id).toSet();
        final List<Message> newSystemMessages = [];

        if (oldMemberIds.isNotEmpty) {
          for (var user in newMembers) {
            if (!oldMemberIds.contains(user.id)) {
              newSystemMessages.add(_createSystemMessage("${user.name} joined the group"));
            }
          }
          for (var user in currentChat.participants) {
            if (!newMemberIds.contains(user.id)) {
              newSystemMessages.add(_createSystemMessage("${user.name} left the group"));
            }
          }
        }

        if (oldMemberIds.length != newMemberIds.length || newSystemMessages.isNotEmpty) {
          final updatedMessages = List<Message>.from(currentChat.messages)..addAll(newSystemMessages);
          updatedMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp)); // Ensure order

          final updatedChat = Chat(
            id: currentChat.id,
            name: currentChat.name,
            isGroup: currentChat.isGroup,
            messages: updatedMessages,
            participants: newMembers,
            unreadCount: currentChat.unreadCount,
            eventLog: currentChat.eventLog,
          );

          final newChatList = List<Chat>.from(chats);
          newChatList[chatIndex] = updatedChat;
          _ref.read(chatListProvider.notifier).state = newChatList;
          _saveChatsToLocal(); // Save after members update
        }
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
      _saveChatsToLocal(); // Save new chat
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
      _saveChatsToLocal(); // Save removal
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
      _saveChatsToLocal(); // Save optimistic message
    }

    try {
      await _api.post(endpoint, body);
      await fetchMessagesForChat(targetId, isGroup);
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
          _saveChatsToLocal(); // Save failed status
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
      _saveChatsToLocal(); // Save new group

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
    } catch (e) {
      rethrow;
    }
  }

  void leaveGroup(String chatId) {
    final chats = _ref.read(chatListProvider);
    final newChats = chats.where((c) => c.id != chatId).toList();
    _ref.read(chatListProvider.notifier).state = newChats;
    _saveChatsToLocal(); // Save state after leaving
    _api.post('/groups/$chatId/leave/', {});
  }
}