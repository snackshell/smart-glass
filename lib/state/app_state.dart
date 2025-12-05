import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/audio_service.dart';
import '../services/gemini_live_service.dart';
import '../services/esp_camera_service.dart';

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
  String get espIp => _espCameraService.baseUrl.replaceAll('http://', '');

  AppState() {
    _init();
  }

  Future<void> _init() async {
    await _loadSettings();
    
    // Setup Service Callbacks
    _geminiService.onConnectionChanged = (connected) {
      notifyListeners();
      _log(connected ? "Gemini Connected" : "Gemini Disconnected");
    };

    _geminiService.onAudioReceived = (audioData) {
      _audioService.playAudioChunk(audioData);
      if (_isThinking) {
        _isThinking = false; // Playing audio now
        notifyListeners();
      }
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

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString('esp_ip') ?? "10.110.64.205";
    _espCameraService.setIpAddress(ip);
    _keepActiveInBackground = prefs.getBool('background_mode') ?? false;
    notifyListeners();
  }

  Future<void> saveSettings(String ip, bool backgroundMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('esp_ip', ip);
    await prefs.setBool('background_mode', backgroundMode);
    
    _espCameraService.setIpAddress(ip);
    _keepActiveInBackground = backgroundMode;
    
    // Simulate reconnection to glass
    _isGlassConnected = false;
    notifyListeners();
    
    // Simple check (in real app, ping the IP)
    await Future.delayed(Duration(seconds: 1));
    _isGlassConnected = true;
    _log("Connected to Glass at $ip");
    notifyListeners();
  }

  void toggleDebug() {
    _debugEnabled = !_debugEnabled;
    notifyListeners();
  }

  Future<void> connectGemini() async {
    _log("Connecting to Gemini...");
    await _geminiService.connect();
  }

  Future<void> disconnectGemini() async {
    _geminiService.disconnect();
  }

  Future<void> startListening() async {
    if (!_geminiService.isConnected) {
      await connectGemini();
    }
    _isListening = true;
    _isThinking = false;
    await _audioService.startRecording();
    notifyListeners();
    _log("Listening...");
  }

  Future<void> stopListening() async {
    _isListening = false;
    _isThinking = true; // Assume thinking after listening stops
    await _audioService.stopRecording();
    notifyListeners();
    _log("Thinking...");
  }

  void _log(String message) {
    final timestamp = DateTime.now().toString().split(' ')[1].substring(0, 8);
    _debugLogs.insert(0, "[$timestamp] $message");
    if (_debugLogs.length > 50) _debugLogs.removeLast();
    notifyListeners();
  }
}
