// lib/screen_capture_blocker.dart
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';

class ScreenCaptureBlocker {
  // IMPORTANT: This identifier MUST match the one used in native code (Android & iOS)
  static const String _channelIdentifierBase = "com.example.basirah";

  static const MethodChannel _methodChannel =
      MethodChannel('$_channelIdentifierBase/screen_capture');
  static const EventChannel _eventChannel =
      EventChannel('$_channelIdentifierBase/screen_capture_event');

  static Stream<bool>? _screenRecordingStatusStream;

  // For Android: Call this to prevent screen capture (globally for the window)
  static Future<void> preventScreenCapture() async {
    if (Platform.isAndroid) {
      try {
        await _methodChannel.invokeMethod('preventScreenCapture');
        print(
            '[ScreenCaptureBlocker] Screen capture prevention enabled (Android)');
      } on PlatformException catch (e) {
        print(
            "[ScreenCaptureBlocker] Failed to prevent screen capture: '${e.message}'.");
      }
    }
  }

  // For Android: Call this to allow screen capture again (globally for the window)
  // Use with caution, usually not needed if you want blanket protection.
  static Future<void> allowScreenCapture() async {
    if (Platform.isAndroid) {
      try {
        await _methodChannel.invokeMethod('allowScreenCapture');
        print('[ScreenCaptureBlocker] Screen capture allowed (Android)');
      } on PlatformException catch (e) {
        print(
            "[ScreenCaptureBlocker] Failed to allow screen capture: '${e.message}'.");
      }
    }
  }

  // For iOS: Listen to this stream to get updates on screen recording status
  // Emits true if recording, false otherwise.
  static Stream<bool> get screenRecordingStatusStream {
    if (Platform.isIOS) {
      _screenRecordingStatusStream ??=
          _eventChannel.receiveBroadcastStream().cast<bool>();
      return _screenRecordingStatusStream!;
    }
    // For other platforms or as a default, return a stream that emits false.
    return Stream.value(false);
  }

  // For iOS: A one-time check if the screen is currently being recorded.
  static Future<bool> isScreenBeingRecorded() async {
    if (Platform.isIOS) {
      try {
        final bool isRecording =
            await _methodChannel.invokeMethod('isScreenBeingRecorded');
        return isRecording;
      } on PlatformException catch (e) {
        print(
            "[ScreenCaptureBlocker] Failed to check iOS screen recording status: '${e.message}'.");
        return false;
      }
    }
    return false; // Not applicable or error
  }
}
