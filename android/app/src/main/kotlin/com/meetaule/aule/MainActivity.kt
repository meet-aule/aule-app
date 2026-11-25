package com.meetaule.aule

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The recent-apps screen shows no snapshot of the app, so notices,
        // summaries and memories about a child never appear there. Screenshots
        // the parent takes on purpose still work. Android 13 and later.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(false)
        }
    }
}
