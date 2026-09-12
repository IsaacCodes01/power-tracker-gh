import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Wrapped defensively: if push-notification setup fails or hangs on a
  // particular device (permission quirks, a plugin channel issue, etc.),
  // the whole app must not get stuck before runApp() ever fires. Worst
  // case with this in place is "push notifications don't work on this
  // device" — not "the app never opens at all."
  try {
    // Must be registered before runApp() — this is what lets a push wake
    // the app up (or run a background isolate) while it's closed.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    // A hard timeout as well as a try/catch: a catch alone doesn't help
    // if setup() hangs rather than throwing — this guarantees main()
    // always reaches runApp() one way or another.
    await PushNotificationService().setup().timeout(
      const Duration(seconds: 10),
    );
  } catch (e, stackTrace) {
    debugPrint('Push notification setup failed, continuing anyway: $e');
    debugPrint('$stackTrace');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseScheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Power Tracker GH',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: baseScheme,
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const SplashScreen(),
    );
  }
}