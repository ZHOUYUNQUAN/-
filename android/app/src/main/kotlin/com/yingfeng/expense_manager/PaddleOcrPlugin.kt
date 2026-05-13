package com.yingfeng.expense_manager

import android.content.Context
import android.graphics.BitmapFactory
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File

/**
 * PaddleOCR Plugin for on-device Chinese text recognition.
 *
 * Uses PP-OCRv5 mobile model via Paddle Lite inference.
 *
 * Setup required:
 * 1. Download PP-OCRv5 models from:
 *    https://huggingface.co/PaddlePaddle/PaddleOCR/tree/main/ppocr_v5_mobile
 *    Place .nb files in: android/app/src/main/assets/models/
 * 2. Paddle Lite .so libraries are expected in jniLibs/
 *    (armeabi-v7a/ and arm64-v8a/)
 */
class PaddleOcrPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private var nativeReady = false

    companion object {
        private const val CHANNEL = "com.yingfeng.expense/paddleocr"
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)

        // Try to initialize PaddleOCR native library
        try {
            System.loadLibrary("paddle_ocr_native")
            nativeReady = NativeBridge.init(
                flutterPluginBinding.applicationContext,
                "models"
            )
        } catch (e: UnsatisfiedLinkError) {
            // Native library not available - PaddleOCR models not installed
            nativeReady = false
        }
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "recognize" -> {
                if (!nativeReady) {
                    result.error("NOT_READY", "PaddleOCR native lib not loaded", null)
                    return
                }
                val imagePath = call.argument<String>("imagePath")
                if (imagePath == null) {
                    result.error("INVALID_ARG", "imagePath is required", null)
                    return
                }
                recognize(imagePath, result)
            }
            else -> result.notImplemented()
        }
    }

    private fun recognize(imagePath: String, result: Result) {
        try {
            val file = File(imagePath)
            if (!file.exists()) {
                result.error("FILE_NOT_FOUND", "Image file not found: $imagePath", null)
                return
            }

            val bitmap = BitmapFactory.decodeFile(imagePath)
            if (bitmap == null) {
                result.error("DECODE_FAILED", "Failed to decode image", null)
                return
            }

            val text = NativeBridge.recognize(bitmap)
            bitmap.recycle()

            result.success(mapOf("text" to text))
        } catch (e: Exception) {
            result.error("OCR_FAILED", e.message, null)
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        if (nativeReady) {
            NativeBridge.release()
            nativeReady = false
        }
    }
}

/**
 * JNI bridge to native PaddleOCR C++ code.
 *
 * The native library (libpaddle_ocr_native.so) wraps:
 * - Paddle Lite prediction engine
 * - PP-OCRv5 text detection + recognition pipeline
 *
 * Build with CMakeLists.txt in android/app/
 */
object NativeBridge {
    external fun init(context: Context, modelDir: String): Boolean
    external fun recognize(bitmap: android.graphics.Bitmap): String
    external fun release()
}
