import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../services/audio_service.dart';
import '../services/gemini_live_service.dart';
import '../services/esp_camera_service.dart';
import '../services/background_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class AppState extends ChangeNotifier {
  final AudioService _audioService = AudioService();
  final GeminiLiveService _geminiService = GeminiLiveService();
  final EspCameraService _espCameraService = EspCameraService();

  // State Variables
  bool _isGlassConnected = false;
  bool _isListening = false;
  bool _isThinking = false;
  bool _keepActiveInBackground = false;
  bool _debugEnabled = false;
  List<String> _debugLogs = [];

  // Getters
  bool get isGlassConnected => _isGlassConnected;
  bool get isGeminiConnected => _geminiService.isConnected;
  bool get isListening => _isListening;
  bool get isThinking => _isThinking;
  bool get keepActiveInBackground => _keepActiveInBackground;
  bool get debugEnabled => _debugEnabled;
  List<String> get debugLogs => _debugLogs;
  String get cameraStreamUrl => _espCameraService.streamUrl;
    _geminiService.onAudioReceived = (audioData) {
      _audioService.playAudioChunk(audioData);
      if (_isThinking) {
        _isThinking = false; // Playing audio now
        notifyListeners();
      }
    };

    _geminiService.onError = (error) {
      _log("Gemini Error: $error");
    };

    _geminiService.onTextReceived = (text) {
      _log("Gemini: $text");
    };

    _audioService.onAudioData = (data) {
      if (_isListening && _geminiService.isConnected) {
        _geminiService.sendAudioChunk(data);
      }
    };
  }

  // ... (existing methods) ...

  Future<void> stopListening() async {
    if (_debugLogs.length > 50) _debugLogs.removeLast();
    notifyListeners();
  }
}
