package app.gsmlg.secrethub_agent

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test

internal class SecrethubAgentPluginTest {
    @Test
    fun onMethodCall_getPlatformVersion_returnsExpectedValue() {
        val plugin = SecrethubAgentPlugin()
        val result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(MethodCall("getPlatformVersion", null), result)
        Mockito.verify(result).success("Android " + android.os.Build.VERSION.RELEASE)
    }

    @Test
    fun onMethodCall_unknownMethod_isNotImplemented() {
        val plugin = SecrethubAgentPlugin()
        val result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(MethodCall("runtime.request", null), result)
        Mockito.verify(result).notImplemented()
        Mockito.verifyNoMoreInteractions(result)
    }
}
