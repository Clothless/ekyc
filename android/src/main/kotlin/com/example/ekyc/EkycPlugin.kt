package com.example.ekyc

import android.app.Activity
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result


/** EkycPlugin */
class EkycPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

  private lateinit var channel: MethodChannel
  private var activity: Activity? = null
  private var nfcReader: EkycNfcReader? = null

  override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(binding.binaryMessenger, "ekyc")
    channel.setMethodCallHandler(this)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    nfcReader = EkycNfcReader(activity!!)
  }

  override fun onDetachedFromActivity() {
    activity = null
    nfcReader = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    onAttachedToActivity(binding)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity()
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "checkNfc" -> {
        if (nfcReader == null) {
          result.error("NFC_READER_NOT_READY", "NFC Reader not initialized", null)
          return
        }
        val supported = nfcReader!!.isNfcSupported()
        val enabled = nfcReader!!.isNfcEnabled()
        result.success(mapOf("supported" to supported, "enabled" to enabled))
      }

      "getPlatformVersion" -> {
        result.success("Android ${android.os.Build.VERSION.RELEASE}")
      }

      else -> result.notImplemented()
    }
  }

}
