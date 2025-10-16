package com.example.basirah

import io.flutter.embedding.android.FlutterActivity
import android.view.WindowManager.LayoutParams
import android.os.Bundle

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(LayoutParams.FLAG_SECURE)
    }
}