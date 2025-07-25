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
import org.jmrtd.lds.iso19794.FingerImageInfo
import org.jmrtd.lds.iso19794.FingerInfo
import java.io.ByteArrayInputStream
import java.math.BigInteger
import java.security.Security
import java.security.cert.X509Certificate
import org.jmrtd.lds.icao.DG11File
import org.jmrtd.lds.icao.DG12File
import java.nio.charset.StandardCharsets
import java.nio.charset.Charset


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

    private fun extractPersonalNumber(mrzInfo: MRZInfo?): String? {
        if (mrzInfo == null) return null

        // Method 1: Direct personal number field
        val directPersonalNumber = mrzInfo.personalNumber
        if (!directPersonalNumber.isNullOrBlank() && directPersonalNumber != "<") {
            return directPersonalNumber.replace("<", "").trim().takeIf { it.isNotBlank() }
        }

        // Method 2: Check optional data fields
        val optionalData1 = mrzInfo.optionalData1
        if (!optionalData1.isNullOrBlank() && optionalData1 != "<") {
            val cleaned = optionalData1.replace("<", "").trim()
            if (cleaned.isNotBlank()) return cleaned
        }

        val optionalData2 = mrzInfo.optionalData2
        if (!optionalData2.isNullOrBlank() && optionalData2 != "<") {
            val cleaned = optionalData2.replace("<", "").trim()
            if (cleaned.isNotBlank()) return cleaned
        }

        // Method 3: Parse from raw MRZ string
        try {
            val fullMrz = mrzInfo.toString()
            Log.d("MRZ_RAW", "Raw MRZ: $fullMrz")

            when (mrzInfo.documentType) {
                MRZInfo.DOC_TYPE_ID1 -> {
                    // ID cards - personal number is usually in line 1, positions 15-29
                    val lines = fullMrz.split("\n")
                    if (lines.isNotEmpty()) {
                        val line1 = lines[0]
                        if (line1.length >= 29) {
                            val personalNum = line1.substring(14, 29).replace("<", "").trim()
                            if (personalNum.isNotBlank()) return personalNum
                        }
                    }
                }

                MRZInfo.DOC_TYPE_ID3 -> {
                    // Passports - personal number might be in line 2, positions 28-42
                    val lines = fullMrz.split("\n")
                    if (lines.size >= 2) {
                        val line2 = lines[1]
                        if (line2.length >= 42) {
                            val personalNum = line2.substring(27, 42).replace("<", "").trim()
                            if (personalNum.isNotBlank()) return personalNum
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.e("MRZ_PARSE", "Failed to parse personal number from MRZ: ${e.message}")
        }

        return null
    }

    private fun isArabicText(text: String?): Boolean {
        if (text.isNullOrBlank()) return false

        return text.any { char ->
            // Arabic Unicode ranges
            char.code in 0x0600..0x06FF ||  // Arabic
                    char.code in 0x0750..0x077F ||  // Arabic Supplement
                    char.code in 0x08A0..0x08FF ||  // Arabic Extended-A
                    char.code in 0xFB50..0xFDFF ||  // Arabic Presentation Forms-A
                    char.code in 0xFE70..0xFEFF     // Arabic Presentation Forms-B
        }
    }

    private fun fixEncodingIssues(text: String?): String? {
        if (text.isNullOrBlank()) return text

        // Log the original text for debugging
        Log.d("ENCODING_DEBUG", "Original text: '$text'")
        Log.d("ENCODING_DEBUG", "Text bytes: ${text.toByteArray().contentToString()}")

        // Try different encoding approaches
        val encodings = listOf(
            StandardCharsets.UTF_8,
            StandardCharsets.UTF_16,
            StandardCharsets.UTF_16BE,
            StandardCharsets.UTF_16LE,
            Charset.forName("windows-1256"), // Arabic Windows encoding
            Charset.forName("ISO-8859-6"),   // Arabic ISO encoding
            StandardCharsets.ISO_8859_1
        )

        // Method 1: If text contains replacement characters, try re-encoding
        if (text.contains("�")) {
            for (encoding in encodings) {
                try {
                    // Get the original bytes assuming they were incorrectly decoded as ISO-8859-1
                    val originalBytes = text.toByteArray(StandardCharsets.ISO_8859_1)
                    val reEncodedText = String(originalBytes, encoding)

                    if (isValidText(reEncodedText) && !reEncodedText.contains("�")) {
                        Log.d("ENCODING_SUCCESS", "Fixed with $encoding: '$reEncodedText'")
                        return reEncodedText
                    }
                } catch (e: Exception) {
                    // Continue to next encoding
                }
            }

            // Method 2: Try CP1256 specifically for Arabic
            try {
                val cp1256Bytes = text.toByteArray(StandardCharsets.ISO_8859_1)
                val arabicText = String(cp1256Bytes, Charset.forName("windows-1256"))
                if (isArabicText(arabicText)) {
                    Log.d("ENCODING_SUCCESS", "Fixed with CP1256: '$arabicText'")
                    return arabicText
                }
            } catch (e: Exception) {
                Log.e("ENCODING_ERROR", "CP1256 conversion failed: ${e.message}")
            }
        }

        // Method 3: Direct byte analysis for common Arabic patterns
        return tryDirectByteConversion(text) ?: text
    }

    private fun tryDirectByteConversion(text: String): String? {
        try {
            // Convert to bytes and try different interpretations
            val bytes = text.toByteArray(StandardCharsets.ISO_8859_1)

            // Try UTF-8 interpretation
            val utf8Text = String(bytes, StandardCharsets.UTF_8)
            if (isValidText(utf8Text) && !utf8Text.contains("�")) {
                return utf8Text
            }

            // Try Windows-1256 (Arabic)
            val arabicText = String(bytes, Charset.forName("windows-1256"))
            if (isArabicText(arabicText)) {
                return arabicText
            }

            // Try UTF-16 variants
            if (bytes.size >= 2) {
                val utf16Text = String(bytes, StandardCharsets.UTF_16)
                if (isValidText(utf16Text) && !utf16Text.contains("�")) {
                    return utf16Text
                }
            }

        } catch (e: Exception) {
            Log.e("ENCODING_CONVERSION", "Direct byte conversion failed: ${e.message}")
        }

        return null
    }

    private fun isValidText(text: String): Boolean {
        // Check if text seems valid (not just control characters or garbage)
        if (text.isBlank()) return false

        val validChars = text.count { char ->
            char.isLetter() || char.isDigit() || char.isWhitespace() ||
                    char in ".,;:!?-()[]{}\"'<>" ||
                    char.code in 0x0600..0x06FF || // Arabic
                    char.code in 0x0750..0x077F || // Arabic Supplement
                    char.code in 0x08A0..0x08FF || // Arabic Extended-A
                    char.code in 0xFB50..0xFDFF || // Arabic Presentation Forms-A
                    char.code in 0xFE70..0xFEFF    // Arabic Presentation Forms-B
        }

        return validChars.toDouble() / text.length > 0.7 // At least 70% valid characters
    }

    private fun tryManualNameExtraction(dg11Bytes: ByteArray): String? {
        try {
            // Look for patterns that might indicate name data
            // DG11 structure: Tag + Length + Data
            // Name is typically in the first field after the DG11 header

            val hexString = dg11Bytes.joinToString("") { "%02x".format(it) }
            Log.d("DG11_HEX", "DG11 hex: ${hexString.take(200)}...")

            // Try to find UTF-8 encoded Arabic text in the raw bytes
            val utf8Attempts = mutableListOf<String>()

            // Try Windows-1256 encoding
            for (offset in 0 until minOf(50, dg11Bytes.size - 10)) {
                for (length in 10..minOf(100, dg11Bytes.size - offset)) {
                    try {
                        val slice = dg11Bytes.sliceArray(offset until offset + length)
                        val arabicText = String(slice, Charset.forName("windows-1256"))

                        if (isArabicText(arabicText)) {
                            utf8Attempts.add("CP1256 Offset $offset, Length $length: '$arabicText'")
                            Log.d(
                                "MANUAL_windows-1256_PARSE",
                                "Found potential Arabic (CP1256) at offset $offset: '$arabicText'"
                            )
                        }
                    } catch (e: Exception) {
                        // Continue
                    }
                }
            }

            return if (utf8Attempts.isNotEmpty()) utf8Attempts.joinToString(" | ") else null

        } catch (e: Exception) {
            Log.e("MANUAL_PARSE", "Manual parsing failed: ${e.message}")
            return null
        }
    }

    private fun detectArabicName(name: String?): String? {
        if (name.isNullOrBlank()) return null
        return if (isArabicText(name)) name else null
    }

    private fun extractNativeScriptNames(unicodeName: String?): Map<String, String?> {
        if (unicodeName.isNullOrBlank()) return emptyMap()

        val result = mutableMapOf<String, String?>()

        // Check for different scripts
        if (isArabicText(unicodeName)) {
            result["arabic"] = unicodeName
            result["script_type"] = "Arabic"
        }

        // Add other script detections as needed (Cyrillic, Chinese, etc.)

        return result
    }

    fun getArabic(bytes: ByteArray): List<String> {
        val iso8859_6Arabic = mapOf(
            0x20 to ' ', // Space
            0xC1 to 'ء', 0xC2 to 'آ', 0xC3 to 'أ', 0xC4 to 'ؤ', 0xC5 to 'إ', 0xC6 to 'ئ',
            0xC7 to 'ا', 0xC8 to 'ب', 0xC9 to 'ة', 0xCA to 'ت', 0xCB to 'ث', 0xCC to 'ج',
            0xCD to 'ح', 0xCE to 'خ', 0xCF to 'د', 0xD0 to 'ذ', 0xD1 to 'ر', 0xD2 to 'ز',
            0xD3 to 'س', 0xD4 to 'ش', 0xD5 to 'ص', 0xD6 to 'ض', 0xD7 to 'ط', 0xD8 to 'ظ',
            0xD9 to 'ع', 0xDA to 'غ', 0xE0 to 'ـ', 0xE1 to 'ف', 0xE2 to 'ق', 0xE3 to 'ك',
            0xE4 to 'ل', 0xE5 to 'م', 0xE6 to 'ن', 0xE7 to 'ه', 0xE8 to 'و', 0xE9 to 'ى',
            0xEA to 'ي', 0xEB to 'ً', 0xEC to 'ٌ', 0xED to 'ٍ', 0xEE to 'َ', 0xEF to 'ُ',
            0xF0 to 'ِ', 0xF1 to 'ّ', 0xF2 to 'ْ'
        )

        val words = mutableListOf<String>()
        val currentWord = StringBuilder()

        for (byte in bytes) {
            val b = byte.toInt() and 0xFF // Convert to unsigned
            if (iso8859_6Arabic.containsKey(b)) {
                currentWord.append(iso8859_6Arabic[b])
            } else {
                if (currentWord.isNotEmpty()) {
                    words.add(currentWord.toString())
                    currentWord.clear()
                }
            }
        }

        if (currentWord.isNotEmpty()) {
            words.add(currentWord.toString())
        }

        // Filter out words that are only space or contain newline
        val filteredWords = words.filterNot { it == " " || it.contains("\n") }

        return filteredWords
    }

    private fun readCOM(): Map<String, Any?> {
        return try {
            val dgcomBytes = passportService?.getInputStream(PassportService.EF_COM)?.readBytes()
            val dgcom = COMFile(ByteArrayInputStream(dgcomBytes))
            val lds = dgcom.getLDSVersion()
            val unic = dgcom.getUnicodeVersion()
            val tags = dgcom.getTagList().toList()

            mapOf(
                "ldsVersion" to lds,
                "unicodeVersion" to unic,
                "tagsList" to tags
            )
        } catch (e: Exception) {
            Log.e("READ_DG1", "Failed: ${e.message}")
            mapOf(
                "ldsVersion" to "",
                "unicodeVersion" to "",
                "tagsList" to ""
            )
        }
    }

    private fun readSOD(): Map<String, Any?> {
        return try {
            val sodBytes = passportService?.getInputStream(PassportService.EF_SOD)?.readBytes()
            val sodFile = SODFile(ByteArrayInputStream(sodBytes))

            val digestAlgorithm = sodFile.getDigestAlgorithm()
            val digestAlgorithmSignerInfo = sodFile.getSignerInfoDigestAlgorithm()

            mapOf(
                "version" to (sodFile.getDocSigningCertificate() as X509Certificate).version,
                "serialNumber" to (sodFile.getDocSigningCertificate() as X509Certificate).getSerialNumber().toString(),
                "signature" to (sodFile.getDocSigningCertificate() as X509Certificate).signature,
                "Subject" to (sodFile.getDocSigningCertificate() as X509Certificate).getSubjectDN().toString(),
                "issuer" to (sodFile.getDocSigningCertificate() as X509Certificate).getIssuerDN().toString(),
                "Valid from" to (sodFile.getDocSigningCertificate() as X509Certificate).getNotBefore().toString(),
                "Valid until" to (sodFile.getDocSigningCertificate() as X509Certificate).getNotAfter().toString(),
                "Public Key" to (sodFile.getDocSigningCertificate() as X509Certificate).getPublicKey().toString(),
                "Signature algorithm" to (sodFile.getDocSigningCertificate() as X509Certificate).getSigAlgName()
                    .toString(),
                "full" to (sodFile.getDocSigningCertificate() as X509Certificate).toString(),
                "digestAlgorithm" to digestAlgorithm,
                "digestAlgorithmSignerInfo" to digestAlgorithmSignerInfo,
            )
        } catch (e: Exception) {
            Log.e("READ_DG1", "Failed: ${e.message}")
            mapOf(
                "version" to "",
                "serialNumber" to "",
                "signature" to "",
                "Subject" to "",
                "issuer" to "",
                "Valid from" to "",
                "Valid until" to "",
                "Public Key" to "",
                "Signature algorithm" to "",
                "full" to "",
                "full" to "",
            )
        }
    }

    private fun readDG1(): Map<String, Any?> {
        return try {
            val dg1Bytes = passportService?.getInputStream(PassportService.EF_DG1)?.readBytes()
            val dg1File = dg1Bytes?.let { DG1File(ByteArrayInputStream(it)) }
            val mrzInfo = dg1File?.mrzInfo
            Log.d("DG1Bytes", "BytesArray: ${dg1Bytes.toString()}")

            mapOf(
                "documentNumber" to mrzInfo?.documentNumber,
                "documentCode" to mrzInfo?.getDocumentCode(),
                "documentType" to mrzInfo?.documentType,
                "issuingState" to mrzInfo?.getIssuingState(),
                "firstName" to mrzInfo?.secondaryIdentifier,
                "lastName" to mrzInfo?.primaryIdentifier,
                "nationality" to mrzInfo?.nationality,
                "dateOfBirth" to mrzInfo?.dateOfBirth,
                "dateOfExpiry" to mrzInfo?.dateOfExpiry.toString(),
                "gender" to mrzInfo?.gender.toString(),
                "opt1" to mrzInfo?.optionalData1,
                "opt2" to mrzInfo?.optionalData2,
                "fullMrz" to mrzInfo?.toString(),
            )
        } catch (e: Exception) {
            Log.e("READ_DG1", "Failed: ${e.message}")
            mapOf(
                "documentNumber" to "",
                "documentCode" to "",
                "documentType" to "",
                "issuingState" to "",
                "firstName" to "",
                "lastName" to "",
                "nationality" to "",
                "dateOfBirth" to "",
                "dateOfExpiry" to "",
                "gender" to "",
                "opt1" to "",
                "opt2" to "",
                "fullMrz" to "",
            )
        }
    }

    private fun readDG2(): Map<String, Any?> {
        return try {
            val dg2Bytes = passportService?.getInputStream(PassportService.EF_DG2)?.readBytes()
            val dg2File = dg2Bytes?.let { DG2File(ByteArrayInputStream(it)) }
            val photoBytes = dg2File?.faceInfos?.firstOrNull()
                ?.faceImageInfos?.firstOrNull()
                ?.imageInputStream?.readBytes()

            var base64Photo: String? = null
            var isJpeg = false

            if (photoBytes != null && photoBytes.size >= 2) {
                isJpeg = photoBytes[0] == 0xFF.toByte() && photoBytes[1] == 0xD8.toByte()
                base64Photo = Base64.encodeToString(photoBytes, Base64.NO_WRAP)
            }

            mapOf(
                "photo" to base64Photo,
                "isJpeg" to isJpeg,
                "rawBytes" to if (!isJpeg) photoBytes else null // optionally return raw if not jpeg
            )
        } catch (e: Exception) {
            Log.e("READ_DG1", "Failed: ${e.message}")
            mapOf(
                "photo" to null,
                "isJpeg" to false,
                "error" to e.message
            )
        }
    }

    private fun readDG7(): Map<String, Any?> {
        return try {
            val dg7Bytes = passportService?.getInputStream(PassportService.EF_DG7)?.readBytes()
            val dg7File = dg7Bytes?.let { DG7File(ByteArrayInputStream(it)) }
            val sigInfos = dg7File?.getImages()
            val sigImagesData = sigInfos?.mapNotNull { info ->
                info.imageInputStream.readBytes()
            }
            val base64Signatures = sigImagesData?.map { bytes ->
                Base64.encodeToString(bytes, Base64.NO_WRAP)
            }
            val images = base64Signatures
            Log.d("DG7Bytes", "BytesArray: ${dg7Bytes.toString()}")

            mapOf(
                "images" to images,
            )
        } catch (e: Exception) {
            Log.e("READ_DG1", "Failed: ${e.message}")
            mapOf(
                "images" to "",
            )
        }
    }

    private fun readDG11(): Map<String, Any?> {
        return try {
            val dg11Bytes = passportService?.getInputStream(PassportService.EF_DG11)?.readBytes()
            val dg11File = dg11Bytes?.let { DG11File(ByteArrayInputStream(it)) }

            val arabicWords = dg11Bytes?.let { getArabic(it) }
            val address = dg11File?.getPermanentAddress()

            Log.d("DG11Bytes", "BytesArray: ${dg11Bytes}")

            mapOf(
                "full" to arabicWords?.joinToString(" "),
                "arabicName" to if (arabicWords!!.size > 1) "${arabicWords!![0]} ${arabicWords!![1]}" else "",
                "nameOfHolder" to if (arabicWords.size > 1) arabicWords!![1] else "",
                "nameOfHolderOriginal" to dg11File?.nameOfHolder,
                "personalNumber" to dg11File?.personalNumber,
                "fullDateOfBirth" to dg11File?.fullDateOfBirth,
                "placeOfBirth" to if (arabicWords.size > 2) "${dg11File?.placeOfBirth[0]}, ${arabicWords!![2]}" else dg11File?.placeOfBirth[0],
                "otherInfo" to if (arabicWords.size > 4) arabicWords!![4] else "--",
                "permanentAddress" to if (address.isNullOrEmpty()) "" else address.joinToString(", "),
                "permanentAddress1" to address?.joinToString(" "),
//                "custodian" to if(dg11File?.permanentAddress!!.isNullOrEmpty()) "" else if(dg11File.permanentAddress!!.size > 2) dg11File.permanentAddress?.joinToString(" ") else "",
                "telephone" to dg11File?.telephone,
                "profession" to dg11File?.profession,
                "title" to dg11File?.title,
                "personalSummary" to dg11File?.personalSummary,
                "proofOfCitizenship" to dg11File?.proofOfCitizenship?.toString(),
                "custodyInformation" to dg11File?.custodyInformation
            )
        } catch (e: Exception) {
            Log.e("READ_DG11", "Failed: ${e.message}")
            e.printStackTrace()
            mapOf(
                "full" to "",
                "arabicName" to "",
                "nameOfHolder" to "",
                "nameOfHolderOriginal" to "",
                "otherNames" to "",
                "personalNumber" to "",
                "fullDateOfBirth" to "",
                "placeOfBirth" to "",
                "otherInfo" to "",
                "permanentAddress" to "",
                "permanentAddress1" to "",
                "custodian" to "",
                "telephone" to "",
                "profession" to "",
                "title" to "",
                "personalSummary" to "",
                "proofOfCitizenship" to "",
                "custodyInformation" to ""
            )
        }
    }

    private fun readDG12(): Map<String, Any?> {
        return try {
            val dg12Bytes = passportService?.getInputStream(PassportService.EF_DG12)?.readBytes()
            val dg12File = DG12File(ByteArrayInputStream(dg12Bytes))

            val issuingAuthority = dg12File.issuingAuthority
            val dateOfIssue = dg12File.dateOfIssue
            val otherPersons = dg12File.namesOfOtherPersons
            val endorsementsObservations = dg12File.endorsementsAndObservations
            val taxExitRequirements = dg12File.taxOrExitRequirements
            val imageOfFront = dg12File.imageOfFront
            val imageOfRear = dg12File.imageOfRear
            val personalizationTime = dg12File.dateAndTimeOfPersonalization
            val personalizationDeviceSerialNumber = dg12File.personalizationSystemSerialNumber
            Log.d("DG12Bytes", "BytesArray: ${dg12Bytes.toString()}")

            mapOf(
                "issuingAuthority" to issuingAuthority,
                "dateOfIssue" to dateOfIssue,
                "otherPersons" to otherPersons?.joinToString(", "),
                "endorsementsObservations" to endorsementsObservations,
                "taxExitRequirements" to taxExitRequirements,
                "personalizationTime" to personalizationTime,
                "personalizationDeviceSerialNumber" to personalizationDeviceSerialNumber
            )

        } catch (e: Exception) {
            Log.e("READ_DG12", "Failed: ${e.message}")
            mapOf(
                "issuingAuthority" to "",
                "dateOfIssue" to "",
                "otherPersons" to "",
                "endorsementsObservations" to "",
                "taxExitRequirements" to "",
                "personalizationTime" to "",
                "personalizationDeviceSerialNumber" to ""
            )
        }
    }

    private fun readDG15(): Map<String, Any?> {
        return try {
            val dg15Bytes = passportService?.getInputStream(PassportService.EF_DG15)?.readBytes()
            val dg15File = DG15File(ByteArrayInputStream(dg15Bytes))
            val pubKey = dg15File.getPublicKey()
            mapOf(
                "algorithm" to pubKey.algorithm,
                "format" to pubKey.format,
                "encoded" to pubKey.encoded
            )
        } catch (e: Exception) {
            Log.e("READ_DG11", "Failed: ${e.message}")
            mapOf(
                "algorithm" to "",
                "format" to "",
                "encoded" to ""
            )
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

            val com = readCOM()
            val sod = readSOD()
            val dg1 = readDG1()
            val dg2 = readDG2()
            val dg7 = readDG7()
            val dg11 = readDG11()
            val dg12 = readDG12()
            val dg15 = readDG15()

            // You can continue calling other DG readers similarly

            return mapOf(
                "com" to com,
                "sod" to sod,
                "dg1" to dg1,
                "dg2" to dg2,
                "dg7" to dg7,
                "dg11" to dg11,
                "dg12" to dg12,
                "dg15" to dg15
            )

        } catch (e: Exception) {
            Log.e("READ_PASSPORT", "Error: ${e.message}")
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
