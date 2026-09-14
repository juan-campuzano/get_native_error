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
            "peekPendingCrash" -> result.success(readPending(delete = false))
            "takePendingCrash" -> result.success(readPending(delete = true))
            "crashNative" -> {
                ensureNativeLoaded()
                nativeCrash()
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
            file.writeText(payload.toString())
        } catch (_: Throwable) {
            // Best-effort: the process is already dying.
        }
    }

    private fun readPending(delete: Boolean): String? {
        val file = crashFile() ?: return null
        if (!file.exists()) {
            return null
        }
        return try {
            val text = file.readText()
            if (delete) {
                file.delete()
            }
            text.ifEmpty { null }
        } catch (_: Throwable) {
            null
        }
    }

    private external fun nativeInstall(path: String)

    private external fun nativeCrash()

    companion object {
        private val javaHandlerInstalled = AtomicBoolean(false)
        private val nativeLoaded = AtomicBoolean(false)
    }
}
