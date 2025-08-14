// lib/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'topbar/login_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // `addPostFrameCallback` ensures that the context is fully available before
    // we try to use it with Provider, which is a robust practice.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAppAndNavigate();
    });
  }

  Future<void> _initializeAppAndNavigate() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // --- ROBUST TIMING AND AUTHENTICATION ---
    // We run two futures in parallel:
    // 1. A timer for the minimum splash screen duration (your 4 seconds).
    // 2. The authentication check from our refactored AuthProvider.
    // `Future.wait` completes only after BOTH of these are finished.
    final List<dynamic> results = await Future.wait([
      Future.delayed(
          const Duration(seconds: 4)), // Your desired splash duration
      authProvider.tryAutoLogin(), // The authentication check
    ]);

    // The result of `tryAutoLogin` is the second item in the list.
    final bool isLoggedIn = results[1];

    // This check prevents a "setState called after dispose" error if the user
    // navigates away or closes the app while the futures are running.
    if (!mounted) return;

    // Now, navigate based on the definitive result of the auth check.
    if (isLoggedIn) {
      // Go to the main screen. Using a named route is clean.
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      // Go to the login page.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Your existing splash screen UI is perfect.
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/Basirah_splash.png"),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
