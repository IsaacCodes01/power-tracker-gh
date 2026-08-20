import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // FIXED: The old Future.delayed timer has been completely deleted from here!
  // This prevents the countdown from starting on a blank screen.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF673AB7),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/animations/bolt_animation.json',
              width: 250,
              repeat: false,
              // FIXED: The timer now starts ONLY after the phone successfully finishes decoding
              // and loading the lightning bolt asset in short-term memory!
              onLoaded: (composition) {
                Future.delayed(composition.duration, () {
                  if (!context.mounted) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AppGatekeeper(),
                    ),
                  );
                });
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'POWER TRACKER GH',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
