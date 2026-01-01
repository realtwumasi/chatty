import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;

  // Expose a stream of decoded JSON events
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _eventController.stream;

  bool get isConnected => _channel != null;

  void connect(String token) {
    if (_channel != null) return;

    final uri = Uri.parse('wss://postumbonal-monatomic-cecelia.ngrok-free.dev/ws?token=$token');

    try {
      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
            (message) {
          if (kDebugMode) {
            print('WS Received: $message');
          }
          try {
            final data = jsonDecode(message);
            _eventController.add(data);
          } catch (e) {
            print('WS Parse Error: $e');
          }
        },
        onDone: () {
          print('WS Closed');
          _cleanup();
          // Optional: Implement reconnection logic here
        },
        onError: (error) {
          print('WS Error: $error');
          _cleanup();
        },
      );

      _startHeartbeat();
    } catch (e) {
      print('WS Connection Error: $e');
    }
  }

  void disconnect() {
    if (_channel != null) {
      _channel!.sink.close(status.goingAway);
      _cleanup();
    }
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
    // Send ping every 30 seconds to keep connection alive
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      send('ping', {});
    });
  }

  void send(String type, Map<String, dynamic> data) {
    if (_channel != null) {
      final message = jsonEncode({
        'type': type,
        'data': data,
      });
      _channel!.sink.add(message);
      if (kDebugMode && type != 'ping') {
        print('WS Sent: $message');
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
}