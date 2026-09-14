package com.getnativeerror.get_native_error

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test

internal class GetNativeErrorPluginTest {
    @Test
    fun onMethodCall_peekPendingCrash_withoutEngine_returnsNull() {
        val plugin = GetNativeErrorPlugin()

        val call = MethodCall("peekPendingCrash", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult).success(null)
    }
}
