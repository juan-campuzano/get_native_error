package com.getnativeerror.get_native_error

import android.content.Context
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.json.JSONObject
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

/** GetNativeErrorPlugin */
class GetNativeErrorPlugin :
    FlutterPlugin,
    MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var appContext: Context? = null
    private var previousJavaHandler: Thread.UncaughtExceptionHandler? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        appContext = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "get_native_error")
        channel.setMethodCallHandler(this)
        installInternal()
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "install" -> {
                installInternal()
                result.success(null)
            }
            "peekPendingCrash" -> result.success(readOldest(delete = false))
            "takePendingCrash" -> result.success(readOldest(delete = true))
            "peekPendingCrashes" -> result.success(readAll())
            "takePendingCrashes" -> {
                val crashes = readAll()
                clearAll()
                result.success(crashes)
            }
            "deletePendingCrash" -> {
                deleteAt(call.arguments as? Int ?: -1)
                result.success(null)
            }
            "markHealthyExit" -> {
                sessionFile()?.delete()
                result.success(null)
            }
            "crashNative" -> {
                ensureNativeLoaded()
                nativeCrash()
                result.success(null)
            }
            "crashUncaughtException", "throwJavaException" -> {
                Log.w(TAG, "crashUncaughtException requested: test crash will follow")
                Thread {
                    throw RuntimeException("Native crash reporter test")
                }.start()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        appContext = null
    }

    private fun crashFile(): File? {
        val context = appContext ?: return null
        val dir = File(context.filesDir, "native_crashes")
        dir.mkdirs()
        return File(dir, "pending.json")
    }

    private fun sessionFile(): File? {
        val context = appContext ?: return null
        val dir = File(context.filesDir, "native_crashes")
        dir.mkdirs()
        return File(dir, "session.marker")
    }

    private fun ensureNativeLoaded() {
        if (nativeLoaded.compareAndSet(false, true)) {
            System.loadLibrary("get_native_error")
        }
    }

    private fun installInternal() {
        val file = crashFile() ?: return
        ensureNativeLoaded()
        nativeInstall(file.absolutePath)
        installJavaHandler(file)
        detectAbnormalTermination(file)
    }

    // Heuristic for deaths that run no handler (kill -9, system OOM, device
    // shutdown). A leftover session marker with no crash on disk means the
    // previous session died silently, so a synthetic record is written. When a
    // crash is present, that death is already explained and no record is added.
    private fun detectAbnormalTermination(file: File) {
        if (abnormalTerminationChecked.compareAndSet(false, true).not()) {
            return
        }
        val marker = sessionFile() ?: return
        val hadCrash = file.exists() && file.length() > 0
        if (marker.exists() && !hadCrash) {
            writeAbnormalTermination(file)
        }
        try {
            marker.parentFile?.mkdirs()
            marker.writeText(System.currentTimeMillis().toString())
        } catch (_: Throwable) {
            // Best-effort: without the marker we simply skip the next check.
        }
    }

    private fun writeAbnormalTermination(file: File) {
        try {
            val payload =
                JSONObject()
                    .put("kind", "abnormalTermination")
                    .put(
                        "diagnosis",
                        "The previous session ended without running any handler, " +
                            "for example kill -9 or a system OOM.",
                    )
                    .put("platform", "android")
                    .put("arch", Build.SUPPORTED_ABIS.firstOrNull() ?: "")
                    .put("timestampMs", System.currentTimeMillis())
            file.parentFile?.mkdirs()
            file.appendText(payload.toString() + "\n")
        } catch (_: Throwable) {
            // Best-effort only.
        }
    }

    private fun installJavaHandler(file: File) {
        if (!javaHandlerInstalled.compareAndSet(false, true)) {
            return
        }
        previousJavaHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            writeJavaCrash(file, thread, error)
            val previous = previousJavaHandler
            if (previous != null) {
                previous.uncaughtException(thread, error)
            }
        }
    }

    private fun writeJavaCrash(
        file: File,
        thread: Thread,
        error: Throwable
    ) {
        try {
            val payload =
                JSONObject()
                    .put("kind", "java")
                    .put("exceptionType", error.javaClass.name)
                    .put("exceptionMessage", error.message ?: "")
                    .put("stackTrace", Log.getStackTraceString(error))
                    .put("threadName", thread.name)
                    .put("platform", "android")
                    .put("arch", Build.SUPPORTED_ABIS.firstOrNull() ?: "")
                    .put("timestampMs", System.currentTimeMillis())
            file.parentFile?.mkdirs()
            // JSON Lines: append one line per record so several crashes from
            // the same session are all preserved. toString() has no real line
            // breaks because the stack trace is JSON-escaped.
            file.appendText(payload.toString() + "\n")
        } catch (_: Throwable) {
            // Best-effort: the process is already dying.
        }
    }

    private fun readAll(): List<String> {
        val file = crashFile() ?: return emptyList()
        if (!file.exists()) {
            return emptyList()
        }
        return try {
            file.readLines().map { it.trim() }.filter { it.isNotEmpty() }
        } catch (_: Throwable) {
            emptyList()
        }
    }

    private fun readOldest(delete: Boolean): String? {
        val crashes = readAll()
        if (crashes.isEmpty()) {
            return null
        }
        if (delete) {
            deleteAt(0)
        }
        return crashes.first()
    }

    private fun deleteAt(index: Int) {
        val crashes = readAll().toMutableList()
        if (index !in crashes.indices) {
            return
        }
        crashes.removeAt(index)
        writeAll(crashes)
    }

    private fun clearAll() {
        crashFile()?.delete()
    }

    private fun writeAll(crashes: List<String>) {
        val file = crashFile() ?: return
        if (crashes.isEmpty()) {
            file.delete()
            return
        }
        file.writeText(crashes.joinToString("\n") + "\n")
    }

    private external fun nativeInstall(path: String)

    private external fun nativeCrash()

    companion object {
        private const val TAG = "GetNativeError"
        private val javaHandlerInstalled = AtomicBoolean(false)
        private val nativeLoaded = AtomicBoolean(false)
        private val abnormalTerminationChecked = AtomicBoolean(false)
    }
}
