package com.example.ekyc

import android.app.Activity
import android.content.Intent
import android.nfc.*
import android.nfc.tech.Ndef
import android.os.Parcelable
import android.util.Log
import android.widget.Toast

class NfcReader(private val activity: Activity) {

    private var nfcAdapter: NfcAdapter? = null

    init {
        nfcAdapter = NfcAdapter.getDefaultAdapter(activity)
    }

    fun isNfcSupported(): Boolean {
        return nfcAdapter != null
    }

    fun isNfcEnabled(): Boolean {
        return nfcAdapter?.isEnabled == true
    }

    fun enableForegroundDispatch() {
        val intent = Intent(activity.applicationContext, activity.javaClass)
        intent.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP

        val pendingIntent = PendingIntent.getActivity(
            activity,
            0,
            intent,
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val filters = arrayOf(IntentFilter(NfcAdapter.ACTION_NDEF_DISCOVERED))
        val techList = arrayOf(arrayOf(Ndef::class.java.name))

        nfcAdapter?.enableForegroundDispatch(activity, pendingIntent, filters, techList)
    }

    fun disableForegroundDispatch() {
        nfcAdapter?.disableForegroundDispatch(activity)
    }

    fun getPayloadFromIntent(intent: Intent): String? {
        if (intent.action == NfcAdapter.ACTION_NDEF_DISCOVERED ||
            intent.action == NfcAdapter.ACTION_TAG_DISCOVERED ||
            intent.action == NfcAdapter.ACTION_TECH_DISCOVERED) {

            val rawMessages = intent.getParcelableArrayExtra(NfcAdapter.EXTRA_NDEF_MESSAGES)
            if (rawMessages != null) {
                for (message in rawMessages) {
                    val ndefMessage = message as NdefMessage
                    for (record in ndefMessage.records) {
                        val payload = String(record.payload)
                        Log.d("NfcReader", "Payload: $payload")
                        return payload
                    }
                }
            } else {
                val tag: Tag? = intent.getParcelableExtra(NfcAdapter.EXTRA_TAG)
                tag?.let {
                    return it.id.joinToString(":") { b -> "%02X".format(b) }
                }
            }
        }
        return null
    }

}
