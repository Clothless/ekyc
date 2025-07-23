package com.example.jmrtd_flutter_plugin

import android.app.Activity
import android.content.Context
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.IsoDep
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import org.jmrtd.*
import org.jmrtd.protocol.*
import org.jmrtd.lds.*
import org.jmrtd.lds.icao.*
import net.sf.scuba.smartcards.*
import java.io.ByteArrayInputStream
import java.security.Security
import org.bouncycastle.jce.provider.BouncyCastleProvider

class JmrtdFlutterPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var context: Context? = null
    private var nfcAdapter: NfcAdapter? = null
    private var passportService: PassportService? = null

    companion object {
        init {
            Security.addProvider(BouncyCastleProvider())
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "jmrtd_flutter_plugin")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> initialize(result)
            "isNfcAvailable" -> isNfcAvailable(result)
            "readPassport" -> readPassport(call, result)
            "readDataGroups" -> readDataGroups(call, result)
            "verifyPassport" -> verifyPassport(result)
            else -> result.notImplemented()
        }
    }

    private fun initialize(result: Result) {
        try {
            nfcAdapter = NfcAdapter.getDefaultAdapter(context)
            result.success(nfcAdapter != null)
        } catch (e: Exception) {
            result.error("INIT_ERROR", "Failed to initialize NFC: ${e.message}", null)
        }
    }

    private fun isNfcAvailable(result: Result) {
        val isAvailable = nfcAdapter?.isEnabled == true
        result.success(isAvailable)
    }

    private fun readPassport(call: MethodCall, result: Result) {
        val documentNumber = call.argument<String>("documentNumber")
        val dateOfBirth = call.argument<String>("dateOfBirth")
        val dateOfExpiry = call.argument<String>("dateOfExpiry")

        if (documentNumber == null || dateOfBirth == null || dateOfExpiry == null) {
            result.error("INVALID_ARGS", "Missing required arguments", null)
            return
        }

        CoroutineScope(Dispatchers.IO).launch {
            try {
                val passportData = readPassportData(documentNumber, dateOfBirth, dateOfExpiry)
                withContext(Dispatchers.Main) {
                    result.success(passportData)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("READ_ERROR", "Failed to read passport: ${e.message}", null)
                }
            }
        }
    }

    private suspend fun readPassportData(
        documentNumber: String,
        dateOfBirth: String,
        dateOfExpiry: String
    ): Map<String, Any?> = withContext(Dispatchers.IO) {
        // This is a simplified implementation
        // In reality, you need to handle NFC tag detection and reading

        val bacKey = BACKey(documentNumber, dateOfBirth, dateOfExpiry)

        // Wait for NFC tag (this would be triggered by NFC intent)
        // For now, returning mock data structure

        mapOf(
            "documentNumber" to documentNumber,
            "firstName" to null,
            "lastName" to null,
            "nationality" to null,
            "dateOfBirth" to dateOfBirth,
            "dateOfExpiry" to dateOfExpiry,
            "gender" to null,
            "photo" to null,
            "isVerified" to false
        )
    }

    private fun readActualPassport(tag: Tag, bacKey: BACKey): Map<String, Any?> {
        val isoDep = IsoDep.get(tag)
        isoDep.connect()

        try {
            // Create CardService - this might be from scuba library
            // If CardService is not available, we might need to use FileSystemCardService
            val cardService = net.sf.scuba.smartcards.CardService.getInstance(isoDep)

            passportService = PassportService(cardService, 256, 256, true, false)
            passportService?.open()

            // Perform BAC authentication
            passportService?.doBAC(bacKey)

            val passportFiles = mutableMapOf<Short, ByteArray>()
            var photoBytes: ByteArray? = null
            var mrzInfo: MRZInfo? = null

            try {
                // Read DG1 (MRZ - Machine Readable Zone)
                val dg1InputStream = passportService?.getInputStream(PassportService.EF_DG1)
                if (dg1InputStream != null) {
                    val dg1Bytes = dg1InputStream.readBytes()
                    passportFiles[PassportService.EF_DG1] = dg1Bytes

                    // Parse MRZ data
                    val dg1File = DG1File(ByteArrayInputStream(dg1Bytes))
                    mrzInfo = dg1File.mrzInfo
                }

                // Read DG2 (Encoded face image)
                val dg2InputStream = passportService?.getInputStream(PassportService.EF_DG2)
                if (dg2InputStream != null) {
                    val dg2Bytes = dg2InputStream.readBytes()
                    passportFiles[PassportService.EF_DG2] = dg2Bytes

                    // Parse DG2 for photo extraction
                    val dg2File = DG2File(ByteArrayInputStream(dg2Bytes))
                    val faceInfos = dg2File.faceInfos
                    if (faceInfos.isNotEmpty()) {
                        val faceInfo = faceInfos[0]
                        val faceImageInfos = faceInfo.faceImageInfos
                        if (faceImageInfos.isNotEmpty()) {
                            val imageInfo = faceImageInfos[0]
                            photoBytes = imageInfo.imageInputStream.readBytes()
                        }
                    }
                }

            } catch (e: Exception) {
                // Handle file reading errors but continue
                e.printStackTrace()
            }

            passportService?.close()

            return mapOf(
                "documentNumber" to mrzInfo?.documentNumber,
                "firstName" to mrzInfo?.secondaryIdentifier,
                "lastName" to mrzInfo?.primaryIdentifier,
                "nationality" to mrzInfo?.nationality,
                "dateOfBirth" to mrzInfo?.dateOfBirth,
                "dateOfExpiry" to mrzInfo?.dateOfExpiry,
                "gender" to mrzInfo?.gender?.toString(),
                "photo" to photoBytes?.toList(),
                "isVerified" to true
            )

        } catch (e: Exception) {
            e.printStackTrace()
            return mapOf(
                "documentNumber" to null,
                "firstName" to null,
                "lastName" to null,
                "nationality" to null,
                "dateOfBirth" to null,
                "dateOfExpiry" to null,
                "gender" to null,
                "photo" to null,
                "isVerified" to false,
                "error" to e.message
            )
        } finally {
            isoDep.close()
        }
    }

    private fun readDataGroups(call: MethodCall, result: Result) {
        // Implementation for reading specific data groups
        result.success(mapOf<String, Any>())
    }

    private fun verifyPassport(result: Result) {
        // Implementation for passport verification
        result.success(false)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}