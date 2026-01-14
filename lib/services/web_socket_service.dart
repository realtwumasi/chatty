import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class WebSocketService {
  WebSocketChannel? _channel;
// ... (lines 9-27 omitted for brevity in thought process, but tool needs exact match logic)
// I will target the imports and the connect method separately or together if close.
// They are far apart. I should use `multi_replace_file_content` or two `replace_file_content` calls.
// Since `replace_file_content` is "SINGLE CONTIGUOUS block", I must use `multi_replace_file_content` or two calls.
// Use multi_replace_file_content.
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  String? _lastToken;
  bool _isDisconnecting = false;

  // Expose a stream of decoded JSON events
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _eventController.stream;

  // Connection State
  final ValueNotifier<bool> isConnected = ValueNotifier(false);
  final ValueNotifier<String?> lastError = ValueNotifier(null);

  void connect(String token) {
    if (_channel != null) return;
    _lastToken = token;
    _isDisconnecting = false;

    // FIX: Updated to use the /ws endpoint as per documentation
    final uri = Uri.parse('wss://postumbonal-monatomic-cecelia.ngrok-free.dev/ws').replace(queryParameters: {
      'token': token,
    });

    try {
      if (kDebugMode) print('WS: Connecting to $uri');
      // FIX: Add Origin and User-Agent headers which are often required by backends
      _channel = IOWebSocketChannel.connect(
        uri, 
        headers: {
          'ngrok-skip-browser-warning': 'true',
          'Origin': 'https://postumbonal-monatomic-cecelia.ngrok-free.dev',
          'User-Agent': 'ChattyApp/1.0',
        },
        pingInterval: const Duration(seconds: 30),
      );
      isConnected.value = true;
      lastError.value = null;

      _subscription = _channel!.stream.listen(
            (message) {
          if (kDebugMode) {
            // print('WS Received: $message');
          }

          if (message is String) {
            final parts = message.split('\n');
            for (var part in parts) {
              if (part.trim().isEmpty) continue;
              try {
                final data = jsonDecode(part);
                _eventController.add(data);
              } catch (e) {
                print('WS Parse Error for part: $e\nData: $part');
              }
            }
          } else {
            try {
              final data = jsonDecode(message);
              _eventController.add(data);
            } catch (e) {
              print('WS Parse Error: $e');
            }
          }
        },
        onDone: () {
          final reason = 'Closed: ${_channel?.closeCode} ${_channel?.closeReason}';
          print('WS: $reason');
          lastError.value = reason;
          isConnected.value = false;
          _cleanup();
          _attemptReconnect();
        },
        onError: (error) {
          final reason = 'Error: $error';
          print('WS: $reason');
          lastError.value = reason;
          isConnected.value = false;
          _cleanup();
          _attemptReconnect();
        },
        cancelOnError: true,
      );

      // _startHeartbeat();
    } catch (e) {
      print('WS Connection Error: $e');
      isConnected.value = false;
      _attemptReconnect();
    }
  }

  void disconnect() {
    _isDisconnecting = true;
    _reconnectTimer?.cancel();
    if (_channel != null) {
      // Use normalClosure (1000) to avoid invalid code errors
      try {
        _channel!.sink.close(status.normalClosure);
      } catch (_) {}
      _cleanup();
    }
    isConnected.value = false;
  }

  void _cleanup() {
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void _startHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      send('ping', {});
    });
  }

  void _attemptReconnect() {
    if (_isDisconnecting || _lastToken == null) return;

    if (_reconnectTimer?.isActive ?? false) return;

    print('WS: Scheduling reconnect in 5s...');
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isDisconnecting && _lastToken != null) {
        print('WS: Attempting reconnect...');
        connect(_lastToken!);
      }
    });
  }

  void send(String type, Map<String, dynamic> data) {
    if (_channel != null) {
      try {
        final message = jsonEncode({
          'type': type,
          'data': data,
        });
        _channel!.sink.add(message);
      } catch (e) {
        print('WS Send Error: $e');
      }
    }
  }

  void subscribeToGroup(String groupId) {
    send('subscribe_group', {'group_id': groupId});
  }

  void unsubscribeFromGroup(String groupId) {
    send('unsubscribe_group', {'group_id': groupId});
  }

  void sendTyping(String? groupId, String? recipientId, bool isTyping) {
    send('typing_indicator', {
      if (groupId != null) 'group_id': groupId,
      if (recipientId != null) 'recipient_id': recipientId,
      'is_typing': isTyping,
    });
  }

  void sendMarkRead(String messageId) {
    send('mark_read', {
      'message_id': messageId,
    });
  }
}