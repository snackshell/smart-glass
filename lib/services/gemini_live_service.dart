import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class GeminiLiveService {
  // API Keys - Rotate through these
  static const List<String> _apiKeys = [
    "AIzaSyDJV_G2EgJvNkQwVqqtFe4XniezHbd3CoA",
    "AIzaSyBWtNidMrYzNuB3KuswxUvb1eVmw9EDwnw",
    "AIzaSyCDSx6Qfk1xKR3uKAjRm8cMzJbbvJ-DhT0",
    "AIzaSyDK-igv5zspBwzfSGKgoZ9jvo_hTK6g2fQ",
    "AIzaSyCNZbKQX_jmDrOw0B1d4DCzqHMhr5Uw_60",
  ];

  int _currentKeyIndex = 0;
  WebSocketChannel? _channel;
  bool _isConnected = false;
  
  // Callbacks
  Function(Uint8List)? onAudioReceived;
  Function(String)? onTextReceived;
  Function(bool)? onConnectionChanged;

  bool get isConnected => _isConnected;

  Future<void> connect() async {
    if (_isConnected) return;

    final apiKey = _apiKeys[_currentKeyIndex];
    final uri = Uri.parse(
      'wss://generativelanguage.googleapis.com/v1beta/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=$apiKey',
    );

    try {
      _channel = WebSocketChannel.connect(uri);
      
      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onDone: () {
          _isConnected = false;
          onConnectionChanged?.call(false);
          _rotateKey(); // Rotate key on disconnection/error
        },
        onError: (error) {
          print("Gemini WebSocket Error: $error");
          _isConnected = false;
          onConnectionChanged?.call(false);
          _rotateKey();
        },
      );

      _isConnected = true;
      onConnectionChanged?.call(true);

      // Send Setup Message
      _sendSetupMessage();

    } catch (e) {
      print("Failed to connect to Gemini: $e");
      _isConnected = false;
      onConnectionChanged?.call(false);
      _rotateKey();
    }
  }

  void _rotateKey() {
    _currentKeyIndex = (_currentKeyIndex + 1) % _apiKeys.length;
  }

  void _sendSetupMessage() {
    final setupMsg = {
      "setup": {
        "model": "models/gemini-2.5-flash-native-audio-preview-09-2025",
        "generation_config": {
          "response_modalities": ["AUDIO"],
          "speech_config": {
            "voice_config": {
              "prebuilt_voice_config": { "voice_name": "Zephyr" }
            }
          }
        }
      }
    };
    _channel?.sink.add(jsonEncode(setupMsg));
  }

  void sendAudioChunk(Uint8List audioData) {
    if (!_isConnected || _channel == null) return;

    final base64Audio = base64Encode(audioData);
    final msg = {
      "realtime_input": {
        "media_chunks": [
          {
            "mime_type": "audio/pcm",
            "data": base64Audio
          }
        ]
      }
    };
    _channel!.sink.add(jsonEncode(msg));
  }

  void _handleMessage(dynamic message) {
    if (message is String) {
      try {
        final data = jsonDecode(message);
        
        // Handle ServerContent (Model Turn)
        if (data.containsKey('serverContent')) {
          final serverContent = data['serverContent'];
          
          // Check for model turn
          if (serverContent.containsKey('modelTurn')) {
            final parts = serverContent['modelTurn']['parts'] as List;
            for (var part in parts) {
              // Handle Inline Audio
              if (part.containsKey('inlineData')) {
                final inlineData = part['inlineData'];
                if (inlineData['mimeType'].toString().startsWith('audio/')) {
                  final audioBase64 = inlineData['data'];
                  final audioBytes = base64Decode(audioBase64);
                  onAudioReceived?.call(audioBytes);
                }
              }
              // Handle Text (if any, for debug)
              if (part.containsKey('text')) {
                onTextReceived?.call(part['text']);
              }
            }
          }
        }
      } catch (e) {
        print("Error parsing Gemini message: $e");
      }
    }
  }

  void disconnect() {
    _channel?.sink.close(status.normalClosure);
    _isConnected = false;
    onConnectionChanged?.call(false);
    _channel = null;
  }
}
