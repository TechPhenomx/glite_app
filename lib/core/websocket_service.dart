import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocket? _socket;

  Future<void> connect() async {
    if (_socket != null && _socket!.readyState == WebSocket.open) {
      return; // Already connected
    }

    try {
      print("🔌 Connecting WebSocket...");
      _socket = await WebSocket.connect("wss://cs.marsoakgroups.in/cs");
      print("✅ WebSocket connected");

      _socket!.listen(
            (data) => print("📥 Received: $data"),
        onDone: () => print("❌ WebSocket closed"),
        onError: (e) => print("❌ WebSocket error: $e"),
      );
    } catch (e) {
      print("❌ WebSocket connection failed: $e");
    }
  }

  void send(Map<String, dynamic> data) {
    if (_socket?.readyState == WebSocket.open) {
      _socket!.add(jsonEncode(data));
      print("📤 Sent via WebSocket: $data");
    } else {
      print("❌ WebSocket not connected. Cannot send.");
    }
  }

  bool get isConnected => _socket?.readyState == WebSocket.open;

  void disconnect() {
    _socket?.close();
    _socket = null;
    print("🔌 WebSocket disconnected");
  }
}
