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

  // --- Startup / Auto Login ---

  Future<bool> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Load Theme
    _isDarkMode = prefs.getBool(_keyTheme) ?? false;

    // 2. Check tokens
    final hasToken = await _api.loadTokens();
    if (!hasToken) {
      notifyListeners();
      return false; // No token, go to login
    }

    // 3. Load Cached User (Fast UI)
    final userJson = prefs.getString(_keyUser);
    if (userJson != null) {
      try {
        _currentUser = User.fromJson(jsonDecode(userJson));
      } catch (_) {}
    }

    // 4. Fetch fresh data
    try {
      await fetchUsers(); // This effectively validates the token
      await fetchChats();
      notifyListeners();
      return true; // Success
    } catch (e) {
      // If token expired (401), clear and force login
      if (e.toString().contains('401')) {
        await logout();
        return false;
      }
      // If valid cache but no network, maybe allow entry?
      // For now, return true if we have a user object
      return _currentUser != null;
    }
  }

  // --- Auth Actions ---

  Future<void> login(String username, String password) async {
    _setLoading(true);
    try {
      final response = await _api.post('/auth/login/', {
        'identifier': username,
        'password': password,
      });

      final tokens = response['tokens'];
      await _api.setTokens(
          access: tokens['access'],
          refresh: tokens['refresh']
      );

      final userData = response['user'];
      _currentUser = User(
        id: userData['id']?.toString() ?? '',
        email: userData['email'] ?? '',
        name: username,
        isOnline: true,
      );

      // Persist User
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUser, jsonEncode(_currentUser!.toJson()));

      await fetchUsers();
      await fetchChats();

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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUser);

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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTheme, _isDarkMode);
    notifyListeners();
  }

  // --- Data Fetching ---

  Future<void> fetchUsers() async {
    try {
      final List data = await _api.get('/users/');
      _allUsers = data.map((e) => User.fromJson(e)).toList();
      _allUsers.removeWhere((u) => u.id == currentUser.id);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print("Fetch users error: $e");
      // Don't rethrow to avoid crashing UI on minor network blips
    }
  }

  Future<void> fetchChats() async {
    try {
      // 1. Fetch Groups
      final List groupData = await _api.get('/groups/');
      final groups = groupData.map((e) => Chat.fromGroupJson(e)).toList();

      // Update local state intelligently (merge instead of overwrite if possible)
      _chats = groups;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print("Fetch chats error: $e");
    }
  }

  Future<void> fetchMessagesForChat(String chatId, bool isGroup) async {
    try {
      final Map<String, String> params = isGroup
          ? {'group': chatId, 'message_type': 'group'}
          : {'recipient': chatId, 'message_type': 'private'};

      final List data = await _api.get('/messages/', params: params);

      final chatIndex = _chats.indexWhere((c) => isGroup ? c.id == chatId : c.participants.any((p) => p.id == chatId));

      if (chatIndex != -1) {
        final msgs = data.map((e) => Message.fromJson(e, currentUser.id)).toList();
        msgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        _chats[chatIndex].messages.clear();
        _chats[chatIndex].messages.addAll(msgs);
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print("Fetch messages error: $e");
    }
  }

  // --- Actions ---

  Future<void> sendMessage(String targetId, String content, bool isGroup) async {
    final endpoint = '/messages/';
    final body = {
      'content': content,
      'message_type': isGroup ? 'group' : 'private',
      if (isGroup) 'group': targetId else 'recipient_id': targetId,
    };

    final tempMsg = Message(
      senderId: currentUser.id,
      senderName: currentUser.name,
      text: content,
      timestamp: DateTime.now(),
      isMe: true,
      status: MessageStatus.sending,
    );

    // Optimistic Update logic can go here...

    try {
      await _api.post(endpoint, body);
      await fetchMessagesForChat(targetId, isGroup);
    } catch (e) {
      rethrow;
    }
  }

  Future<Chat> createGroup(String name, List<User> members) async {
    try {
      final response = await _api.post('/groups/', {
        'name': name,
        'description': 'Created via Chatty App'
      });

      final newChat = Chat.fromGroupJson(response);
      _chats.insert(0, newChat);
      notifyListeners();
      return newChat;
    } catch (e) {
      rethrow;
    }
  }

  // Bridge for UI
  List<User> get filteredUsers => _allUsers;

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  // Legacy mock methods no longer needed but kept empty/compatible if UI calls them directly
  // In a real refactor, you would remove these from UI calls.
  void leaveGroup(String chatId) {}
  Chat getOrCreatePrivateChat(User user) {
    // Basic mock-like implementation to prevent crash before full API private chat logic
    return Chat(id: user.id, name: user.name, isGroup: false, messages: [], participants: [currentUser, user]);
  }
}