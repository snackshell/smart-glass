import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import '../state/app_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Ra'yee",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Camera Feed Area
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              clipBehavior: Clip.antiAlias,
              child: appState.isGlassConnected
                  ? Mjpeg(
                      isLive: true,
                      stream: appState.cameraStreamUrl,
                      error: (context, error, stack) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 40),
                              const SizedBox(height: 8),
                              Text("Stream Error", style: TextStyle(color: Colors.white54)),
                            ],
                          ),
                        );
                      },
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF2962FF)),
                          SizedBox(height: 16),
                          Text(
                            "Connecting to Glass...",
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
            ),
          ),

          // Bottom Controls Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Use minimum space needed
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Status Text
                Text(
                  appState.isListening
                      ? "Listening..."
                      : appState.isThinking
                          ? "Thinking..."
                          : appState.isGlassConnected
                              ? "Connected to Glass"
                              : "Connecting...",
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),

                // Waveform / Visualizer (Simple Animation Placeholder)
                if (appState.isThinking)
                  SizedBox(
                    height: 60,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return Container(
                          width: 6,
                          height: 30 + (index % 3) * 10.0,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2962FF),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  )
                else
                  const SizedBox(height: 60), // Spacer

                const SizedBox(height: 24),

                // Mic Button
                GestureDetector(
                  onTapDown: (_) => appState.startListening(),
                  onTapUp: (_) => appState.stopListening(),
                  onTapCancel: () => appState.stopListening(),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: appState.isListening
                          ? const Color(0xFF2962FF)
                          : const Color(0xFF1E1E1E),
                      shape: BoxShape.circle,
                      boxShadow: appState.isListening
                          ? [
                              BoxShadow(
                                color: const Color(0xFF2962FF).withOpacity(0.5),
                                blurRadius: 20,
                                spreadRadius: 5,
                              )
                            ]
                          : [],
                      border: Border.all(
                        color: appState.isListening
                            ? Colors.transparent
                            : Colors.white24,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.mic,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Hold to Speak",
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
