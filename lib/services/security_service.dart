// lib/services/security_service.dart

import 'dart:io' show Platform;
import 'package:flutter/services.dart';

class SecurityService {
  // This channel name MUST match the one in MainActivity.kt
  static const _channel = MethodChannel('com.example.basirah/screen_capture');

  /// Secures the app on a platform-by-platform basis.
  /// On Android, it invokes a method to add the FLAG_SECURE.
  /// On iOS, the native code handles this automatically, so this is a no-op.
  static Future<void> secureApp() async {
    // The iOS implementation is now fully automatic in AppDelegate and needs no calls.
    if (Platform.isAndroid) {
      try {
        // We only need to call this once when the app starts.
        await _channel.invokeMethod('preventScreenCapture');
        print("SecurityService: Android screen capture prevention enabled.");
      } on PlatformException catch (e) {
        print(
            "SecurityService: Failed to prevent screen capture: '${e.message}'.");
      }
    }
  }
}
