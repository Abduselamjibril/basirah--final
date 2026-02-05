package com.basirahtv.app

import android.os.Bundle
import android.view.WindowManager.LayoutParams
import com.ryanheise.audioservice.AudioServiceActivity

// Use AudioServiceActivity to supply the correct FlutterEngine for audio_service background/notification controls.
class MainActivity : AudioServiceActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(LayoutParams.FLAG_SECURE) // temporarily disabled
    }
}