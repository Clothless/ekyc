package com.example.ekyc

import android.app.Activity
import android.app.PendingIntent
import android.content.Intent
import android.content.IntentFilter
import android.nfc.NfcAdapter
import android.nfc.NdefMessage
import android.nfc.Tag
import android.nfc.tech.Ndef
import android.os.Build
import android.util.Log
import android.widget.Toast

class EkycNfcReader(private val activity: Activity) {

    private val nfcAdapter: NfcAdapter? = NfcAdapter.getDefaultAdapter(activity)

    fun isNfcSupported(): Boolean {
        return nfcAdapter != null
    }

    fun isNfcEnabled(): Boolean {
        return nfcAdapter?.isEnabled == true
    }

    fun enableForegroundDispatch() {
        val intent = Intent(activity.applicationContext, activity.javaClass).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            activity,
            0,
            intent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            else
                PendingIntent.FLAG_UPDATE_CURRENT
        )

        val filters = arrayOf(IntentFilter(NfcAdapter.ACTION_NDEF_DISCOVERED))
        val techList = arrayOf(arrayOf(Ndef::class.java.name))

        nfcAdapter?.enableForegroundDispatch(activity, pendingIntent, filters, techList)
    }

    fun disableForegroundDispatch() {
        nfcAdapter?.disableForegroundDispatch(activity)
    }

    fun handleIntent(intent: Intent): String? {
        if (intent.action == NfcAdapter.ACTION_NDEF_DISCOVERED ||
            intent.action == NfcAdapter.ACTION_TAG_DISCOVERED ||
            intent.action == NfcAdapter.ACTION_TECH_DISCOVERED
        ) {
            val rawMessages = intent.getParcelableArrayExtra(NfcAdapter.EXTRA_NDEF_MESSAGES)
            if (rawMessages != null) {
                for (message in rawMessages) {
                    val ndefMessage = message as NdefMessage
                    for (record in ndefMessage.records) {
                        val payload = String(record.payload)
                        Log.d("EkycNfcReader", "NFC Tag Payload: $payload")
                        Toast.makeText(activity, "NFC Payload: $payload", Toast.LENGTH_SHORT).show()
                        return payload
                    }
                }
            } else {
                val tag: Tag? = intent.getParcelableExtra(NfcAdapter.EXTRA_TAG)
                tag?.let {
                    val tagId = it.id.joinToString(":") { b -> "%02X".format(b) }
                    Log.d("EkycNfcReader", "NFC Tag ID: $tagId")
                    Toast.makeText(activity, "NFC Tag ID: $tagId", Toast.LENGTH_SHORT).show()
                    return tagId
                }
            }
        }
        return null
    }
}
