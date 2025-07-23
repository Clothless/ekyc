package com.example.ekyc

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.IsoDep
import android.util.Base64
import android.util.Log
import androidx.annotation.Keep
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import net.sf.scuba.smartcards.CardService
import org.bouncycastle.jce.provider.BouncyCastleProvider
import org.jmrtd.BACKey
import org.jmrtd.PassportService
import org.jmrtd.lds.*
import org.jmrtd.lds.icao.*
import java.io.ByteArrayInputStream
import java.security.Security
import java.security.cert.X509Certificate


@Keep
class EkycPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private var nfcAdapter: NfcAdapter? = null
    private var passportService: PassportService? = null
    private var lastUsedBacKey: BACKey? = null

    companion object {
        init {
            Security.addProvider(BouncyCastleProvider())
        }
    }

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "ekyc")
        channel.setMethodCallHandler(this)
        nfcAdapter = NfcAdapter.getDefaultAdapter(context)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        nfcAdapter = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addOnNewIntentListener { intent ->
            handleNfcIntent(intent)
            true
        }
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "checkNfc" -> {
                val supported = nfcAdapter != null
                val enabled = nfcAdapter?.isEnabled == true
                result.success(mapOf("supported" to supported, "enabled" to enabled))
            }

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
        result.success(nfcAdapter?.isEnabled == true)
    }

    private fun readPassport(call: MethodCall, result: Result) {
        val documentNumber = call.argument<String>("documentNumber")
        val dateOfBirth = call.argument<String>("dateOfBirth")
        val dateOfExpiry = call.argument<String>("dateOfExpiry")

        Log.d("BAC", "doc: $documentNumber, dob: $dateOfBirth, doe: $dateOfExpiry")


        if (documentNumber != null && dateOfBirth != null && dateOfExpiry != null) {
            lastUsedBacKey = BACKey(documentNumber, dateOfBirth, dateOfExpiry)

            // NFC intent will trigger handleNfcIntent and complete the read
            result.success("NFC scanning started. Hold your passport near the phone.")
        } else {
            result.error("INPUT_ERROR", "Missing one or more BAC fields", null)
        }
    }

    private fun handleNfcIntent(intent: Intent) {
        val tag = intent.getParcelableExtra<Tag>(NfcAdapter.EXTRA_TAG) ?: return
        val isoDep = IsoDep.get(tag) ?: return

        CoroutineScope(Dispatchers.IO).launch {
            try {
                val bacKey = lastUsedBacKey ?: return@launch
                val data = readActualPassport(tag, bacKey)
                withContext(Dispatchers.Main) {
                    channel.invokeMethod("onPassportRead", data)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun readActualPassport(tag: Tag, bacKey: BACKey): Map<String, Any?> {
        val isoDep = IsoDep.get(tag)
        isoDep.connect()

        try {
            val cardService = CardService.getInstance(isoDep)
            passportService = PassportService(
                cardService,
                PassportService.NORMAL_MAX_TRANCEIVE_LENGTH,
                PassportService.DEFAULT_MAX_BLOCKSIZE,
                true,
                true
            )
            passportService?.open()
            passportService?.sendSelectApplet(false)
            passportService?.doBAC(bacKey)

            // Containers
            var mrzInfo: MRZInfo? = null
            var photoBytes: ByteArray? = null
            var base64Photo: String? = null
            var fingerprintBytes: ByteArray? = null
            var irisBytes: ByteArray? = null
            var signerCert: X509Certificate? = null
            var digestAlgorithm: String? = null
            var validFrom: String? = null
            var validTo: String? = null
            var serialNumber: String? = null
            var issuer: String? = null
            var subject: String? = null
            var signatureAlgorithm: String? = null
            val dg14Info = mutableMapOf<String, Any?>()
            val dg15Info = mutableMapOf<String, Any?>()
            val availableDGs = mutableListOf<Int>()
            var images: Any? = null


            val allDGs = mutableMapOf<String, Any?>()

            try {

                val comBytes = passportService?.getInputStream(PassportService.EF_COM)?.readBytes()

                comBytes?.let {
                    try {
                        val comFile = COMFile(ByteArrayInputStream(it))
                        availableDGs.addAll(comFile.tagList.toList())
                    } catch (e: Exception) {
                        Log.e("COM_READ", "Failed to read COM file: ${e.message}")
                    }
                }


                // === DG1: MRZ Info ===
                passportService?.getInputStream(PassportService.EF_DG1)?.let { dg1Stream ->
                    val dg1Bytes = dg1Stream.readBytes()
                    val dg1File = DG1File(ByteArrayInputStream(dg1Bytes))
                    mrzInfo = dg1File.mrzInfo
                    allDGs["DG1"] = dg1Bytes
                }

                // === DG2: Face image ===
                passportService?.getInputStream(PassportService.EF_DG2)?.let { dg2Stream ->
                    val dg2Bytes = dg2Stream.readBytes()
                    allDGs["DG2"] = dg2Bytes

                    val dg2File = DG2File(ByteArrayInputStream(dg2Bytes))
                    dg2File.faceInfos.firstOrNull()?.faceImageInfos?.firstOrNull()?.let {
                        photoBytes = it.imageInputStream.readBytes()
                    }
                    base64Photo = photoBytes?.let {
                        Base64.encodeToString(it, Base64.NO_WRAP)
                    }
                }

                //Getting Signature
                passportService?.getInputStream(PassportService.EF_DG7)?.let { dg7Stream ->
                    val dg7Bytes = dg7Stream.readBytes()
                    val dg7 = DG7File(ByteArrayInputStream(dg7Bytes))
                    val sigInfos = dg7.getImages()
                    val sigImagesData = sigInfos.mapNotNull { info ->
                        info.imageInputStream.readBytes()
                    }
                    val base64Signatures = sigImagesData.map { bytes ->
                        Base64.encodeToString(bytes, Base64.NO_WRAP)
                    }
                    images = base64Signatures
                }




                // === DG3: Fingerprints ===
                passportService?.getInputStream(PassportService.EF_DG3)?.let { dg3Stream ->
                    val dg3Bytes = dg3Stream.readBytes()
                    allDGs["DG3"] = dg3Bytes
                    fingerprintBytes = dg3Bytes // you can parse with DG3File if needed
                }

                // === DG4: Iris ===
                passportService?.getInputStream(PassportService.EF_DG4)?.let { dg4Stream ->
                    val dg4Bytes = dg4Stream.readBytes()
                    allDGs["DG4"] = dg4Bytes
                    irisBytes = dg4Bytes // you can parse with DG4File if needed
                }

                passportService?.getInputStream(PassportService.EF_SOD)?.use { sodStream ->
                    val sodBytes = sodStream.readBytes()
                    val sodFile = SODFile(ByteArrayInputStream(sodBytes))

                    signerCert = sodFile.getDocSigningCertificate()
                    val signatureBytes = sodFile.encryptedDigest
                    val signatureHex = signatureBytes.joinToString("") { "%02X".format(it) }

                    signatureAlgorithm = sodFile.signerInfoDigestAlgorithm
                    digestAlgorithm = sodFile.digestAlgorithm

                    val dgHashes = sodFile.dataGroupHashes
                    val formattedHashes = dgHashes.mapKeys { "DG${it.key}" }
                        .mapValues { entry -> entry.value.joinToString("") { b -> "%02X".format(b) } }


//                    sodInfo["signatureAlgorithm"] = sodFile.signatureAlgorithm
//                    sodInfo["digestAlgorithm"] = sodFile.digestAlgorithm
//                    sodInfo["signatureHex"] = signatureHex
                    issuer = signerCert.issuerDN.name
                    subject = signerCert.subjectDN.name
                    validFrom = signerCert.notBefore.toString()
                    validTo = signerCert.notAfter.toString()
                    serialNumber = signerCert.serialNumber.toString()
//                    sodInfo["dataGroupHashes"] = formattedHashes
                }

                passportService?.getInputStream(PassportService.EF_DG14)?.let { dg14Stream ->
                    try {
                        val dg14Bytes = dg14Stream.readBytes()
                        val dg14File = DG14File(ByteArrayInputStream(dg14Bytes))
                        dg14Info["securityInfos"] = dg14File.securityInfos
                    } catch (e: Exception) {
                        dg14Info["error"] = "Failed to parse DG14: ${e.message}"
                    }
                }

                passportService?.getInputStream(PassportService.EF_DG15)?.let { dg15Stream ->
                    try {
                        val dg15Bytes = dg15Stream.readBytes()
                        val dg15File = DG15File(ByteArrayInputStream(dg15Bytes))
                        val pubKey = dg15File.publicKey

                        dg15Info["algorithm"] = pubKey.algorithm
                        dg15Info["format"] = pubKey.format
                        dg15Info["encoded"] = pubKey.encoded.joinToString("") { b -> "%02X".format(b) }

                    } catch (e: Exception) {
                        dg15Info["error"] = "Failed to parse DG15: ${e.message}"
                    }
                }



            } catch (e: Exception) {
                e.printStackTrace()
            }

            return mapOf(
                // MRZ Info
                "documentNumber" to mrzInfo?.documentNumber,
                "documentCode" to mrzInfo?.documentCode,
                "documentType" to mrzInfo?.documentType,
                "issuingState" to mrzInfo?.issuingState,
                "firstName" to mrzInfo?.secondaryIdentifier,
                "lastName" to mrzInfo?.primaryIdentifier,
                "nationality" to mrzInfo?.nationality,
                "dateOfBirth" to mrzInfo?.dateOfBirth,
                "dateOfExpiry" to mrzInfo?.dateOfExpiry,
                "gender" to mrzInfo?.gender?.toString(),

                // Images
                "photo" to base64Photo,
                "fingerprints" to fingerprintBytes?.toList(),
                "iris" to irisBytes?.toList(),
/*

* */
                // Raw DGs
                "availableDGs" to availableDGs,

                "dg14Info" to dg14Info,
                "dg15Info" to dg15Info,
                "images" to images,

                //SOD Info
                "signatureAlgorithm" to signatureAlgorithm,
                "signerCert" to signerCert,
                "digestAlgorithm" to digestAlgorithm,
                "validFrom" to validFrom,
                "validTo" to validTo,
                "serialNumber" to serialNumber,
                "issuer" to issuer,
                "subject" to subject,

                "isVerified" to true
            )
        } catch (e: Exception) {
            e.printStackTrace()
            return mapOf("error" to e.message, "isVerified" to false)
        } finally {
            isoDep.close()
        }
    }


    private fun readDataGroups(call: MethodCall, result: Result) {
        result.success(mapOf<String, Any>())
    }

    private fun verifyPassport(result: Result) {
        result.success(false)
    }
}
