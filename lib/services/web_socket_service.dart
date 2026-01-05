import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class WebSocketService {
  WebSocketChannel? _channel;
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

  void connect(String token) {
    if (_channel != null) return;
    _lastToken = token;
    _isDisconnecting = false;

    final uri = Uri.parse('wss://postumbonal-monatomic-cecelia.ngrok-free.dev/ws?token=$token');

    try {
      if (kDebugMode) print('WS: Connecting...');
      _channel = WebSocketChannel.connect(uri);
      isConnected.value = true;

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
          print('WS: Closed by server');
          isConnected.value = false;
          _cleanup();
          _attemptReconnect();
        },
        onError: (error) {
          print('WS Error: $error');
          isConnected.value = false;
          _cleanup();
          _attemptReconnect();
        },
      );

      _startHeartbeat();
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
      _channel!.sink.close(status.normalClosure);
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

  // Updated to match documentation: Expects message_id
  void sendMarkRead(String messageId) {
    send('mark_read', {
      'message_id': messageId,
    });
  }
}