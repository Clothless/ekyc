package com.example.ekyc

import android.app.Activity
import android.content.Intent
import android.util.Log
import androidx.annotation.Keep
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import android.nfc.NfcAdapter


@Keep
class EkycPlugin : FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.NewIntentListener, EventChannel.StreamHandler {

    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null

    private var activity: Activity? = null
    private var nfcReader: EkycNfcReader? = null
    private var binding: ActivityPluginBinding? = null

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        Log.d("EkycPlugin", "Plugin attached to engine")
        channel = MethodChannel(binding.binaryMessenger, "ekyc")
        eventChannel = EventChannel(binding.binaryMessenger, "ekyc_events")
        channel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
        Log.d("EkycPlugin", "Method and Event channels set up")
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        Log.d("EkycPlugin", "Plugin attached to activity")
        this.activity = binding.activity
        this.binding = binding
        nfcReader = EkycNfcReader(activity!!)
        binding.addOnNewIntentListener(this)
        Log.d("EkycPlugin", "NFC Reader initialized and NewIntentListener added")
        // Log for foreground dispatch
        Log.d("EkycPlugin", "(AUDIT) onAttachedToActivity: nfcReader = $nfcReader, activity = $activity")
    }

    override fun onDetachedFromActivity() {
        Log.d("EkycPlugin", "Plugin detached from activity")
        binding?.removeOnNewIntentListener(this)
        activity = null
        binding = null
        nfcReader = null
        Log.d("EkycPlugin", "(AUDIT) onDetachedFromActivity: nfcReader set to null")
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        Log.d("EkycPlugin", "Plugin reattached to activity for config changes")
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        Log.d("EkycPlugin", "Plugin detached from activity for config changes")
        onDetachedFromActivity()
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        Log.d("EkycPlugin", "Method called: ${call.method}")
        when (call.method) {
            "checkNfc" -> {
                Log.d("EkycPlugin", "Checking NFC support and enabled status")
                if (nfcReader == null) {
                    Log.e("EkycPlugin", "nfcReader is null!")
                    result.error("NFC_READER_NOT_READY", "NFC Reader not initialized", null)
                    return
                }
                val supported = nfcReader!!.isNfcSupported()
                val enabled = nfcReader!!.isNfcEnabled()
                Log.d("EkycPlugin", "NFC supported: $supported, enabled: $enabled")
                result.success(mapOf("supported" to supported, "enabled" to enabled))
            }
            "startNfc" -> {
                if (nfcReader == null || activity == null) {
                    result.error("NFC_NOT_READY", "NFC reader or activity not initialized", null)
                    return
                }
                try {
                    nfcReader!!.enableForegroundDispatch()
                    result.success("NFC listening started")
                } catch (e: Exception) {
                    result.error("NFC_ERROR", "Failed to start NFC: ${e.message}", null)
                }
            }
            "stopNfc" -> {
                 if (nfcReader == null || activity == null) {
                    result.error("NFC_NOT_READY", "NFC reader or activity not initialized", null)
                    return
                }
                try {
                    nfcReader!!.disableForegroundDispatch()
                    result.success("NFC listening stopped")
                } catch (e: Exception) {
                    result.error("NFC_ERROR", "Failed to stop NFC: ${e.message}", null)
                }
            }
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            else -> result.notImplemented()
        }
    }

    override fun onNewIntent(intent: Intent): Boolean {
        Log.d("EkycPlugin", "onNewIntent called with action: ${intent.action}")
        // Forward the intent to the dmrtd NfcProvider if available
        try {
            val nfcProviderField = this::class.java.getDeclaredField("_nfcProvider")
            nfcProviderField.isAccessible = true
            val nfcProvider = nfcProviderField.get(this)
            val onNewIntentMethod = nfcProvider?.javaClass?.methods?.find { it.name == "onNewIntent" }
            if (nfcProvider != null && onNewIntentMethod != null) {
                onNewIntentMethod.invoke(nfcProvider, intent)
                Log.d("EkycPlugin", "Forwarded intent to dmrtd NfcProvider.onNewIntent")
            }
        } catch (e: Exception) {
            Log.e("EkycPlugin", "Failed to forward intent to dmrtd NfcProvider: $e")
        }
        if (nfcReader != null && (intent.action == NfcAdapter.ACTION_NDEF_DISCOVERED || intent.action == NfcAdapter.ACTION_TAG_DISCOVERED || intent.action == NfcAdapter.ACTION_TECH_DISCOVERED)) {
            val nfcData = nfcReader!!.readNfc(intent)
            eventSink?.success(nfcData)
        }
        return false
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        this.eventSink = null
    }
}
