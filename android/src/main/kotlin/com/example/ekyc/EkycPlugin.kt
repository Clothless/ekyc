package com.example.ekyc

import androidx.annotation.NonNull

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import com.example.ekyc.nfc.NfcReader

/** EkycPlugin */
class EkycPlugin: FlutterPlugin, MethodCallHandler {
  private lateinit var channel : MethodChannel

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "ekyc")
    private lateinit var nfcReader: NfcReader
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    "checkNfc" -> {
      val supported = nfcReader.isNfcSupported()
      val enabled = nfcReader.isNfcEnabled()
      result.success(mapOf("supported" to supported, "enabled" to enabled))
    }
    "getPlatformVersion" -> {
      result.success("Android edited ${android.os.Build.VERSION.RELEASE}")
    }

    else -> result.notImplemented()
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
