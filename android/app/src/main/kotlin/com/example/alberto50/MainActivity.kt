package com.example.alberto50

import android.content.pm.PackageManager
import android.content.res.Configuration
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "alberto50/platform")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAndroidTvHints" -> {
                        val uiMode = resources.configuration.uiMode and Configuration.UI_MODE_TYPE_MASK
                        val pm = packageManager
                        result.success(
                            mapOf(
                                "uiModeTelevision" to (uiMode == Configuration.UI_MODE_TYPE_TELEVISION),
                                "leanbackLauncher" to pm.hasSystemFeature(PackageManager.FEATURE_LEANBACK),
                                "hasTouchscreen" to pm.hasSystemFeature(PackageManager.FEATURE_TOUCHSCREEN),
                            ),
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        // TV remotes must reach Flutter. Do not let the Android window
        // swallow DPAD / OK / Back before the engine sees them.
        return super.dispatchKeyEvent(event)
    }

    override fun onResume() {
        super.onResume()
        window.decorView.isFocusable = true
        window.decorView.isFocusableInTouchMode = true
        window.decorView.requestFocus()
    }
}
