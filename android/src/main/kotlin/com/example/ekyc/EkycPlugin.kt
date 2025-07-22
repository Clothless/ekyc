package com.example.ekyc

import android.nfc.NfcAdapter
import androidx.annotation.Keep
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

@Keep
class EkycPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private var nfcAdapter: NfcAdapter? = null

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "ekyc")
        channel.setMethodCallHandler(this)
        nfcAdapter = NfcAdapter.getDefaultAdapter(binding.applicationContext)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        nfcAdapter = null
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "checkNfc" -> {
                val supported = nfcAdapter != null
                val enabled = nfcAdapter?.isEnabled == true
                result.success(mapOf("supported" to supported, "enabled" to enabled))
            }
            else -> result.notImplemented()
        }
    }
} 