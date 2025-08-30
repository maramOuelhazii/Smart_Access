import 'package:firebase_messaging/firebase_messaging.dart';
Future<void> handleBackgroundMessage(RemoteMessage message) async {
  print('🔵 Background: ${message.notification?.title}');
  print('🟡 Data: ${message.data}');
}

class FirebaseApi {
  final _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initNotification() async {
    await _firebaseMessaging.requestPermission();

    final fCMToken = await _firebaseMessaging.getToken();
    print('✅ FCM Token: $fCMToken');

    // Foreground message
    FirebaseMessaging.onMessage.listen((message) {
      print('🟢 Foreground: ${message.notification?.title}');
      print('🟡 Data: ${message.data}');
    });

    // When the app is opened from terminated state via notification
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        print('🟠 Terminated state: ${message.notification?.title}');
      }
    });

    // When the app is in background and user taps the notification
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      print('🟣 Background tap: ${message.notification?.title}');
    });
  }
}
