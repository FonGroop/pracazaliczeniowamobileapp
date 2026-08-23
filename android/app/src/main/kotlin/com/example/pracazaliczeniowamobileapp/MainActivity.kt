package com.example.pracazaliczeniowamobileapp

import android.content.ActivityNotFoundException
import android.content.Intent
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "city_companion/attachments",
        ).setMethodCallHandler { call, result ->
            if (call.method != "open") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val path = call.argument<String>("path")
            if (path.isNullOrBlank()) {
                result.error("invalid_path", "No attachment path was provided.", null)
                return@setMethodCallHandler
            }
            openAttachment(path, result)
        }
    }

    private fun openAttachment(path: String, result: MethodChannel.Result) {
        val file = File(path)
        if (!file.exists()) {
            result.error("file_missing", "The attachment is no longer on this device.", null)
            return
        }

        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.attachment_provider",
            file,
        )
        val extension = file.extension.lowercase()
        val mimeType = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
            ?: "application/octet-stream"
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mimeType)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        try {
            startActivity(intent)
            result.success(null)
        } catch (_: ActivityNotFoundException) {
            result.error("viewer_unavailable", "No app can open this attachment type.", null)
        }
    }
}
