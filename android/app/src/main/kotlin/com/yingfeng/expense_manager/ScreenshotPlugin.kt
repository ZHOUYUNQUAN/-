package com.yingfeng.expense_manager

import android.content.Context
import android.database.ContentObserver
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class ScreenshotPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var observer: ContentObserver? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.yingfeng.expense/screenshot")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopListening()
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startListening" -> {
                startListening()
                result.success(null)
            }
            "stopListening" -> {
                stopListening()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startListening() {
        stopListening()
        observer = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                uri?.let {
                    // Check if the new media file is a screenshot
                    val projection = arrayOf(MediaStore.Images.Media.DISPLAY_NAME)
                    val cursor = context.contentResolver.query(it, projection, null, null, null)
                    cursor?.use { c ->
                        if (c.moveToFirst()) {
                            val name = c.getString(0) ?: ""
                            // Screenshot filenames typically contain "Screenshot" or "截图"
                            if (name.contains("Screenshot", ignoreCase = true) ||
                                name.contains("截图")) {
                                channel.invokeMethod("onScreenshotTaken", null)
                            }
                        }
                    }
                }
            }
        }

        context.contentResolver.registerContentObserver(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            true,
            observer!!
        )
    }

    private fun stopListening() {
        observer?.let {
            context.contentResolver.unregisterContentObserver(it)
        }
        observer = null
    }
}
