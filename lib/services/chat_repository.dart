import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/data_models.dart';
import 'api_service.dart';

class ChatRepository extends ChangeNotifier {
  static final ChatRepository _instance = ChatRepository._internal();
  factory ChatRepository() => _instance;
  ChatRepository._internal();

  final ApiService _api = ApiService();

  User? _currentUser;
  User get currentUser => _currentUser ?? User(id: '', name: 'Guest', email: '');

  List<Chat> _chats = [];
  List<Chat> get chats => _chats;

  List<User> _allUsers = [];
  List<User> get allUsers => _allUsers;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  static const String _keyUser = 'current_user';
  static const String _keyTheme = 'is_dark_mode';

  // --- Startup ---

  Future<bool> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(_keyTheme) ?? false;

      final userJson = prefs.getString(_keyUser);
      if (userJson != null) {
        try {
          _currentUser = User.fromJson(jsonDecode(userJson));
        } catch (_) {}
      }
    } catch (e) {
      if (kDebugMode) print("Storage Warning: Failed to init storage: $e");
    }

    final hasToken = await _api.loadTokens();

    if (!hasToken && _currentUser == null) {
      notifyListeners();
      return false;
    }

    try {
      // Optimization: Parallel fetch
      await Future.wait([
        fetchUsers(),
        fetchChats(),
      ]);
      notifyListeners();
      return true;
    } catch (e) {
      if (e.toString().contains('401')) {
        await logout();
        return false;
      }
      return _currentUser != null;
    }
  }

  // --- Auth ---

  Future<void> login(String username, String password) async {
    _setLoading(true);
    try {
      final response = await _api.post('/auth/login/', {
        'identifier': username,
        'password': password,
      });

      final tokens = response['tokens'];
      await _api.setTokens(access: tokens['access'], refresh: tokens['refresh']);

      final userData = response['user'];
      _currentUser = User(
        id: userData['id']?.toString() ?? '',
        email: userData['email'] ?? '',
        name: userData['username'] ?? username, // API uses username
        isOnline: true,
      );

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyUser, jsonEncode(_currentUser!.toJson()));
      } catch (_) {}

      await Future.wait([fetchUsers(), fetchChats()]);

      notifyListeners();
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    _chats = [];
    _allUsers = [];
    await _api.clearTokens();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUser);
    } catch (_) {}

    notifyListeners();
  }

  Future<void> register(String username, String email, String password) async {
    _setLoading(true);
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
      _setLoading(false);
    }
  }

  // --- Theme ---

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyTheme, _isDarkMode);
    } catch (_) {}
  }

  // --- Data ---

  Future<void> fetchUsers() async {
    try {
      // API returns PaginatedUserList: { count, next, previous, results: [] }
      final response = await _api.get('/users/');

      final List data = (response is Map && response.containsKey('results'))
          ? response['results']
          : [];

      final newUsers = data.map((e) => User.fromJson(e)).toList();

      if (_currentUser != null) {
        newUsers.removeWhere((u) => u.id == _currentUser!.id);
      }

      _allUsers = newUsers;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print("Fetch users error: $e");
    }
  }

  Future<void> fetchChats() async {
    try {
      // API returns PaginatedGroupList
      final response = await _api.get('/groups/');

      final List groupData = (response is Map && response.containsKey('results'))
          ? response['results']
          : [];

      _chats = groupData.map((e) => Chat.fromGroupJson(e)).toList();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print("Fetch chats error: $e");
    }
  }

  Future<void> fetchMessagesForChat(String chatId, bool isGroup) async {
    try {
      // API Parameters from YAML
      final Map<String, String> params = isGroup
          ? {'group': chatId, 'message_type': 'group'}
          : {'recipient': chatId, 'message_type': 'private'};

      // API returns PaginatedMessageList
      final response = await _api.get('/messages/', params: params);

      final List data = (response is Map && response.containsKey('results'))
          ? response['results']
          : [];

      // Find the chat in local state to update
      final chatIndex = _chats.indexWhere((c) => isGroup
          ? c.id == chatId
          : c.participants.any((p) => p.id == chatId && p.id != currentUser.id));

      if (chatIndex != -1) {
        final newMsgs = data.map((e) => Message.fromJson(e, currentUser.id)).toList();

        // Sort by timestamp (oldest first for ListView)
        newMsgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        // Optimization: Check if messages actually changed before notifying to reduce rebuilds
        final currentMsgs = _chats[chatIndex].messages;

        // Simple length check or last ID check for optimization
        if (currentMsgs.length != newMsgs.length ||
            (newMsgs.isNotEmpty && currentMsgs.isNotEmpty && newMsgs.last.id != currentMsgs.last.id)) {

          _chats[chatIndex].messages.clear();
          _chats[chatIndex].messages.addAll(newMsgs);
          notifyListeners();
        }
      }
    } catch (e) {
      if (kDebugMode) print("Fetch messages error: $e");
    }
  }

  // --- Actions ---

  Future<Chat> createPrivateChat(User otherUser) async {
    try {
      // Check if we already have a chat with this user
      return _chats.firstWhere((c) => !c.isGroup && c.participants.any((p) => p.id == otherUser.id));
    } catch (_) {
      // If not, create a temporary local chat object
      // Note: The API doesn't have an explicit "create private chat" endpoint.
      // Messages create the thread implicitly.
      final newChat = Chat(
        id: otherUser.id,
        name: otherUser.name,
        isGroup: false,
        messages: [],
        participants: [currentUser, otherUser],
      );

      // Add to local list immediately for UI responsiveness
      if (!_chats.any((c) => c.id == newChat.id)) {
        _chats.insert(0, newChat);
        notifyListeners();
      }
      return newChat;
    }
  }

  Future<void> sendMessage(String targetId, String content, bool isGroup) async {
    final endpoint = '/messages/';
    final body = {
      'content': content,
      'message_type': isGroup ? 'group' : 'private',
      // YAML Spec: use 'group' (uuid) for groups, 'recipient_id' (uuid) for private
      if (isGroup) 'group': targetId else 'recipient_id': targetId,
    };

    // Optimistic Update: Show message immediately before server confirms
    final chatIndex = _chats.indexWhere((c) => isGroup
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
      _chats[chatIndex].messages.add(tempMsg);
      notifyListeners();
    }

    try {
      await _api.post(endpoint, body);
      // Fetch latest to get the real ID and server timestamp
      await fetchMessagesForChat(targetId, isGroup);
    } catch (e) {
      if (chatIndex != -1) {
        // Mark last message as failed if needed, or remove it
        // For now, rethrowing allows the UI to handle the error
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

      // Optionally add members immediately if the API supports it in one go,
      // otherwise iterate through members to add them.
      // The provided YAML create_group only takes name/desc.
      // Members must be added via /groups/{id}/join/ or similar logic not fully detailed in single-call.

      _chats.insert(0, newChat);
      notifyListeners();
      return newChat;
    } catch (e) {
      rethrow;
    }
  }

  void leaveGroup(String chatId) {
    // Optimistic leave
    _chats.removeWhere((c) => c.id == chatId);
    notifyListeners();
    // Actual API call
    _api.post('/groups/$chatId/leave/', {});
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}