import 'dart:async';
import 'dart:typed_data';
import 'package:sound_stream/sound_stream.dart';

class AudioService {
  final RecorderStream _recorder = RecorderStream();
  final PlayerStream _player = PlayerStream();

  StreamSubscription<Uint8List>? _micSubscription;
  
  // Callback to send audio data to Gemini
  Function(Uint8List)? onAudioData;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize recorder (16kHz mono for Gemini)
    await _recorder.initialize();
    
    // Initialize player (24kHz is typical for Gemini, but we can stick to 24k or 16k)
    // Gemini 2.5 Flash Native Audio usually returns 24kHz.
    await _player.initialize();

    _isInitialized = true;
  }

  Future<void> startRecording() async {
    if (!_isInitialized) await initialize();

    _micSubscription = _recorder.audioStream.listen((data) {
      onAudioData?.call(data);
    });

    await _recorder.start();
  }

  Future<void> stopRecording() async {
    await _micSubscription?.cancel();
    _micSubscription = null;
    await _recorder.stop();
  }

  Future<void> playAudioChunk(Uint8List audioData) async {
    if (!_isInitialized) await initialize();
    // Write directly to the player buffer
    await _player.writeChunk(audioData);
  }

  Future<void> dispose() async {
    await stopRecording();
    _recorder.dispose();
    _player.dispose();
  }
}
