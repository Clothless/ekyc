package com.example.ekyc_example

import io.flutter.embedding.android.FlutterActivity

class MainActivity : AppCompatActivity(), NfcAdapter.ReaderCallback {
    private val CHANNEL = "ekyc"
    private lateinit var nfcReader: NfcReader

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkNfc" -> {
                    val supported = nfcReader.isNfcSupported()
                    val enabled = nfcReader.isNfcEnabled()
                    result.success(mapOf("supported" to supported, "enabled" to enabled))
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        nfcReader = NfcReader(this)

        if (!nfcReader.isNfcSupported()) {
            Toast.makeText(this, "NFC not supported on this device", Toast.LENGTH_LONG).show()
        } else if (!nfcReader.isNfcEnabled()) {
            Toast.makeText(this, "NFC is disabled", Toast.LENGTH_LONG).show()
        }
    }

    override fun onResume() {
        super.onResume()
        nfcReader.enableForegroundDispatch()
    }

    override fun onPause() {
        super.onPause()
        nfcReader.disableForegroundDispatch()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        nfcReader.processNfcIntent(intent)
    }
}
