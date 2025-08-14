// android/app/src/main/kotlin/com/example/basirah/MainActivity.kt

package com.example.basirah

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.view.WindowManager
import androidx.annotation.NonNull

class MainActivity: FlutterActivity() {
    // This channel name MUST match the one in security_service.dart
    private val SCREEN_CAPTURE_CHANNEL_NAME = "com.example.basirah/screen_capture"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_CAPTURE_CHANNEL_NAME).setMethodCallHandler {
            call, result ->
            if (call.method == "preventScreenCapture") {
                // This is the only command we need. It blocks screenshots,
                // screen recording, and the app preview in the app switcher.
                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }
}