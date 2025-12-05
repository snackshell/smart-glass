import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class BackgroundService {
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'my_foreground', // id
      'Ra\'yee Background Service', // title
      description: 'This channel is used for important notifications.', // description
      importance: Importance.low, 
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false, // User toggles it
        isForegroundMode: true,
        notificationChannelId: 'my_foreground',
        initialNotificationTitle: 'Ra\'yee is active',
        initialNotificationContent: 'Listening for Smart Glass commands...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Keep alive timer
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          // Update notification if needed
          // service.setForegroundNotificationInfo(
          //   title: "Ra'yee Active",
          //   content: "Monitoring...",
          // );
        }
      }
      
      // Here we could technically poll, but since we want to share state 
      // with the main app, we are using this service primarily to keep 
      // the Main Isolate alive (by virtue of being a foreground service 
      // in the same process on some configs, or just preventing OS kill).
      // 
      // Note: In a production app, we would move the Gemini/ESP logic 
      // entirely here or use IsolateNameServer to communicate.
      // For this prototype, the Foreground Service notification 
      // significantly reduces the chance of the OS killing the UI isolate.
    });
  }
}
