package com.ravvapps.surveilpro

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.media.MediaScannerConnection
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.surveilpro.app/media_scanner"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        // Register method channel for media scanner
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scanFile" -> {
                        val path = call.argument<String>("path")
                        if (path != null) {
                            scanFile(path, result)
                        } else {
                            result.error("INVALID_PATH", "Path cannot be null", null)
                        }
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }

    private fun scanFile(path: String, result: MethodChannel.Result) {
        try {
            MediaScannerConnection.scanFile(
                context,
                arrayOf(path),
                null
            ) { _, uri ->
                // Scanning complete callback
                runOnUiThread {
                    result.success(true)
                }
            }
        } catch (e: Exception) {
            runOnUiThread {
                result.error("SCAN_ERROR", e.message, null)
            }
        }
    }
}