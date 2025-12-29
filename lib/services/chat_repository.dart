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

  // Optimization: Use separate map for quick lookup
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
        name: username,
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
      final List data = await _api.get('/users/');
      final newUsers = data.map((e) => User.fromJson(e)).toList();
      newUsers.removeWhere((u) => u.id == currentUser.id);

      _allUsers = newUsers;
      // Optimization: Only notify if absolutely necessary, but users list changes rarely
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print("Fetch users error: $e");
    }
  }

  Future<void> fetchChats() async {
    try {
      final List groupData = await _api.get('/groups/');
      _chats = groupData.map((e) => Chat.fromGroupJson(e)).toList();
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
        final newMsgs = data.map((e) => Message.fromJson(e, currentUser.id)).toList();
        newMsgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        // Optimization: Check if messages actually changed before notifying
        final currentMsgs = _chats[chatIndex].messages;
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
      return _chats.firstWhere((c) => !c.isGroup && c.participants.any((p) => p.id == otherUser.id));
    } catch (_) {
      final newChat = Chat(
        id: otherUser.id,
        name: otherUser.name,
        isGroup: false,
        messages: [],
        participants: [currentUser, otherUser],
      );

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
      if (isGroup) 'group': targetId else 'recipient_id': targetId,
    };

    // Optimistic Update
    final chatIndex = _chats.indexWhere((c) => isGroup ? c.id == targetId : c.participants.any((p) => p.id == targetId));
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
      // Revert or mark failed if implementing offline support
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
      _chats.insert(0, newChat);
      notifyListeners();
      return newChat;
    } catch (e) {
      rethrow;
    }
  }

  void leaveGroup(String chatId) {
    _chats.removeWhere((c) => c.id == chatId);
    notifyListeners();
  }

  List<User> get filteredUsers => _allUsers;

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}