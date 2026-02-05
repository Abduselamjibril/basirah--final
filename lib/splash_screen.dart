// lib/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import 'providers/auth_provider.dart';
import 'topbar/login_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final VideoPlayerController _videoController;
  late final Future<void> _initializeVideoFuture;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset('assets/splash_vid.mp4');
    _initializeVideoFuture = _videoController.initialize().then((_) {
      _videoController
        ..setLooping(true)
        ..play();
      if (mounted) {
        setState(() {});
      }
    }).catchError((_) {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAppAndNavigate();
    });
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _initializeAppAndNavigate() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final results = await Future.wait([
      Future.delayed(const Duration(seconds: 7)),
      authProvider.tryAutoLogin(),
      _safeWaitForVideo(),
    ]);

    final bool isLoggedIn = results[1] as bool;

    if (!mounted) {
      return;
    }

    if (isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    }
  }

  Future<void> _safeWaitForVideo() async {
    try {
      await _initializeVideoFuture;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<void>(
            future: _initializeVideoFuture,
            builder: (context, snapshot) {
              final initialized =
                  snapshot.connectionState == ConnectionState.done &&
                      _videoController.value.isInitialized;
              if (initialized) {
                final size = _videoController.value.size;
                return FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: VideoPlayer(_videoController),
                  ),
                );
              }
              return Container(color: Colors.black);
            },
          ),
          // No overlay so the video shows unobstructed.
          Container(color: Colors.transparent),
          FutureBuilder<void>(
            future: _initializeVideoFuture,
            builder: (context, snapshot) {
              final stillLoading = snapshot.connectionState != ConnectionState.done;
              if (stillLoading) {
                return const Center(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF009B77)),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}
