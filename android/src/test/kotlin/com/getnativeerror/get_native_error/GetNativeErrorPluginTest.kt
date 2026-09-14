package com.getnativeerror.get_native_error

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test

internal class GetNativeErrorPluginTest {
    @Test
    fun onMethodCall_peekPendingCrash_withoutEngine_returnsNull() {
        val plugin = GetNativeErrorPlugin()
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)

        plugin.onMethodCall(MethodCall("peekPendingCrash", null), mockResult)

        Mockito.verify(mockResult).success(null)
    }

    @Test
    fun onMethodCall_takePendingCrash_withoutEngine_returnsNull() {
        val plugin = GetNativeErrorPlugin()
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)

        plugin.onMethodCall(MethodCall("takePendingCrash", null), mockResult)

        Mockito.verify(mockResult).success(null)
    }

    @Test
    fun onMethodCall_install_withoutEngine_succeeds() {
        val plugin = GetNativeErrorPlugin()
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)

        plugin.onMethodCall(MethodCall("install", null), mockResult)

        Mockito.verify(mockResult).success(null)
    }

    @Test
    fun onMethodCall_unknownMethod_isNotImplemented() {
        val plugin = GetNativeErrorPlugin()
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)

        plugin.onMethodCall(MethodCall("getPlatformVersion", null), mockResult)

        Mockito.verify(mockResult).notImplemented()
    }
}
