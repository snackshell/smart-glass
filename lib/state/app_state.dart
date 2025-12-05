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

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString('esp_ip') ?? "10.112.131.205";
    _espCameraService.setIpAddress(ip);
    _keepActiveInBackground = prefs.getBool('background_mode') ?? false;
    
    // Initialize background service state if needed
    if (_keepActiveInBackground) {
       final service = FlutterBackgroundService();
       await service.startService();
    }
    
    notifyListeners();
  }

  Future<void> saveSettings(String ip, bool backgroundMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('esp_ip', ip);
    await prefs.setBool('background_mode', backgroundMode);
    
    _espCameraService.setIpAddress(ip);
    _keepActiveInBackground = backgroundMode;
    
    // Handle Background Service
    final service = FlutterBackgroundService();
    if (backgroundMode) {
      await service.startService();
    } else {
      service.invoke("stopService");
    }
    
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

  // Camera Control
  Future<void> setResolution(int framesize) async {
    try {
      final uri = Uri.parse("http://${espIp}/control?var=framesize&val=$framesize");
      await http.get(uri);
      _log("Set Resolution to $framesize");
    } catch (e) {
      _log("Failed to set resolution: $e");
    }
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
    
    // Start polling for physical button if connected to glass
    if (_isGlassConnected) {
      _pollButtonStatus();
    }
  }

  bool _isPolling = false;
  Future<void> _pollButtonStatus() async {
    if (_isPolling) return;
    _isPolling = true;

    while (_isListening && _isGlassConnected) {
      try {
        final uri = Uri.parse("http://${espIp}/wait_for_button");
        final response = await http.get(uri).timeout(const Duration(seconds: 32));
        
        if (response.statusCode == 200 && response.body == "PRESSED") {
          await _handleButtonPress();
        }
      } catch (e) {
        // Timeout or error, just retry
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    _isPolling = false;
  }

  Future<void> _handleButtonPress() async {
    _log("Physical Button Pressed!");
    
    // 1. Capture Image
    try {
      final uri = Uri.parse("http://${espIp}/capture");
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final imageBytes = response.bodyBytes;
        _log("Image captured (${imageBytes.length} bytes)");
        
        // 2. Send to Gemini
        if (_geminiService.isConnected) {
           _geminiService.sendImageFrame(imageBytes);
           _geminiService.sendText("Explain this image to a blind person to help them walk safely. Mention any obstacles or hazards.");
           _log("Sent image to Gemini (Navigation Mode)");
        }
      }
    } catch (e) {
      _log("Failed to capture image: $e");
    }
  }

  Future<void> stopListening() async {
    _isListening = false;
    _isThinking = true; 
    await _audioService.stopRecording();
    
    // Signal Gemini that user is done speaking (PTT release)
    if (_geminiService.isConnected) {
      _geminiService.sendEndTurn();
      _log("Sent EndTurn signal");
    }
    
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
