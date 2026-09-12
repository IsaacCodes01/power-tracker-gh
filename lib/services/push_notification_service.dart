import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../firebase_options.dart';
import '../screens/notifications/notifications_list_screen.dart';
import 'firestore_service.dart';

// Used so the service can navigate (e.g. when a notification is tapped)
// without needing a BuildContext of its own. Add this to MaterialApp's
// `navigatorKey:` in main.dart.
final navigatorKey = GlobalKey<NavigatorState>();

const _defaultChannel = AndroidNotificationChannel(
  'power_tracker_default',
  'General notifications',
  description:
      'Status changes, verifications, power restoration, '
      'maintenance notices, and announcements.',
  importance: Importance.high,
);

final _localNotifications = FlutterLocalNotificationsPlugin();

// FCM requires this to be a TOP-LEVEL (or static) function — it runs in
// its own isolate when a push arrives while the app is fully closed or
// backgrounded, so it can't rely on any state from the rest of the app.
// It just needs Firebase initialized; the OS handles showing the actual
// notification for background/terminated pushes on its own, so there's
// nothing else to do here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();

  factory PushNotificationService() => _instance;

  PushNotificationService._internal();

  final _messaging = FirebaseMessaging.instance;
  final _firestoreService = FirestoreService();
  bool _initialized = false;

  // Call once, right after main() / Firebase.initializeApp(), to set up
  // the notification channel and local-notification plugin. Doesn't need
  // a signed-in user yet.
  Future<void> setup() async {
    if (_initialized) return;
    _initialized = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
      onDidReceiveNotificationResponse: (response) {
        _openNotificationsList();
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_defaultChannel);

    // Foreground pushes don't show a system notification on their own —
    // FCM just hands the message to the app silently. This is what
    // actually pops the heads-up banner while the app is open.
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _defaultChannel.id,
            _defaultChannel.name,
            channelDescription: _defaultChannel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    });

    // App was backgrounded (not closed) and the user tapped the push.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _openNotificationsList();
    });
  }

  // Call once a user is signed in (e.g. from MainNavigationScreen's
  // initState) to actually request permission and register this device's
  // token against their account.
  Future<void> registerForUser(String uid) async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await _messaging.getToken();
    if (token != null) {
      await _firestoreService.saveFcmToken(uid, token);
    }

    // Token can change (app reinstall, token rotation) — keep it current.
    _messaging.onTokenRefresh.listen((newToken) {
      _firestoreService.saveFcmToken(uid, newToken);
    });

    // Cold start: app was fully closed and the user tapped a push to
    // open it. Handled separately from onMessageOpenedApp above because
    // the app wasn't already running for that listener to catch it.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _openNotificationsList();
    }
  }

  void _openNotificationsList() {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const NotificationsListScreen()),
    );
  }
}
