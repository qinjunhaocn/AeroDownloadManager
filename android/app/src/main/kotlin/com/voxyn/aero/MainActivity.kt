package com.voxyn.aero

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Hosts the Flutter engine plus two small Android-only integrations:
 *  - a foreground service that keeps the process alive while downloads run;
 *  - share / open-with intents (text links, magnet links, .torrent files).
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pendingPayload: List<String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        AeroDownloadService.start(this)
                        result.success(true)
                    }
                    "stopService" -> {
                        AeroDownloadService.stop(this)
                        result.success(true)
                    }
                    "getInitialShared" -> result.success(intentPayload(intent))
                    "consumePendingShared" -> {
                        val payload = pendingPayload ?: emptyList()
                        pendingPayload = null
                        result.success(payload)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val payload = intentPayload(intent)
        if (payload.isNotEmpty()) {
            pendingPayload = payload
            channel?.invokeMethod("shared", payload)
        }
    }

    /** Extracts useful strings from ACTION_SEND / ACTION_VIEW intents. */
    private fun intentPayload(intent: Intent?): List<String> {
        if (intent == null) return emptyList()
        val payload = mutableListOf<String>()
        when (intent.action) {
            Intent.ACTION_SEND -> {
                intent.getStringExtra(Intent.EXTRA_TEXT)?.let { payload.add(it) }
                val stream = if (Build.VERSION.SDK_INT >= 33) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_STREAM)
                }
                stream?.let { uri -> payload.addAll(copyStreamToCache(uri)) }
            }
            Intent.ACTION_VIEW -> {
                intent.data?.let { uri -> payload.addAll(copyStreamToCache(uri)) }
            }
        }
        return payload.filter { it.isNotBlank() }
    }

    /**
     * http(s) / magnet / file URIs are returned directly. Content URIs
     * (e.g. a shared .torrent from a file manager) are copied into the cache so
     * Dart can parse them with a plain file path.
     */
    private fun copyStreamToCache(uri: Uri): List<String> {
        val scheme = uri.scheme ?: return emptyList()
        if (scheme == "http" || scheme == "https" || scheme == "magnet") {
            return listOf(uri.toString())
        }
        if (scheme == "file") {
            return listOf(uri.path ?: return emptyList())
        }
        if (scheme != "content") return emptyList()

        val name = displayName(uri) ?: "shared_${System.currentTimeMillis()}.torrent"
        val target = File(cacheDir, name.replace('/', '_'))
        return try {
            contentResolver.openInputStream(uri)?.use { input ->
                target.outputStream().use { output -> input.copyTo(output) }
            }
            listOf(target.absolutePath)
        } catch (_: Throwable) {
            emptyList()
        }
    }

    private fun displayName(uri: Uri): String? {
        return try {
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (idx >= 0 && cursor.moveToFirst()) cursor.getString(idx) else null
            }
        } catch (_: Throwable) {
            null
        }
    }

    companion object {
        const val CHANNEL = "com.voxyn.aero/native"
    }
}
