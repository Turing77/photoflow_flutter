package com.turingai.photoflow_flutter

import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.photoflow_flutter/storage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getStorageInfo" -> {
                    try {
                        val stat = android.os.StatFs(android.os.Environment.getDataDirectory().path)
                        val totalBytes = stat.totalBytes
                        val freeBytes = stat.availableBytes
                        val usedBytes = totalBytes - freeBytes

                        val storageInfo = HashMap<String, Long>()
                        storageInfo["total"] = totalBytes
                        storageInfo["free"] = freeBytes
                        storageInfo["used"] = usedBytes

                        result.success(storageInfo)
                    } catch (e: Exception) {
                        result.error("STORAGE_ERROR", "Failed to get storage info: ${e.message}", null)
                    }
                }
                "getFileSize" -> {
                    try {
                        val uri = call.argument<String>("uri")
                        if (uri != null) {
                            val assetUri = Uri.parse(uri)
                            val cursor = contentResolver.query(assetUri, arrayOf(android.provider.MediaStore.MediaColumns.SIZE), null, null, null)
                            if (cursor != null && cursor.moveToFirst()) {
                                val sizeIndex = cursor.getColumnIndex(android.provider.MediaStore.MediaColumns.SIZE)
                                val size = if (sizeIndex >= 0) cursor.getLong(sizeIndex) else 0L
                                cursor.close()
                                result.success(size)
                            } else {
                                cursor?.close()
                                result.success(0L)
                            }
                        } else {
                            result.success(0L)
                        }
                    } catch (e: Exception) {
                        result.success(0L)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
