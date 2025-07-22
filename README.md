# ekyc

A Flutter plugin for eKYC (electronic Know Your Customer) processes, enabling secure and efficient reading of ID card and passport data via NFC and MRZ scanning.

## Features

-   **MRZ Scanning**: Accurately scan and parse Machine Readable Zones (MRZ) from passports and ID cards using the device's camera.
-   **NFC Chip Reading (eMRTD)**: Securely read data directly from the NFC chip of ePassports and eID cards (electronic Machine Readable Travel Documents) using Basic Access Control (BAC).
-   **Cross-Platform Compatibility**: Fully supported on both Android and iOS devices.
-   **NFC Status Check**: Programmatically check if NFC is supported and enabled on the device.
-   **Detailed Data Extraction**: Extracts key personal and document details (e.g., name, document number, date of birth, date of expiry, nationality, address, NIN, issuing authority).

## Supported Platforms

-   **Android**: API level 21+ (Android 5.0+)
-   **iOS**: iOS 11.0+ (iPhone 7 and newer) with NFC Tag Reading capability enabled.

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  ekyc: ^0.0.2 # Or the latest version
  # dmrtd is a transitive dependency through ekyc for core NFC reading, but if you need
  # direct access to dmrtd APIs, you might also list it:
  # dmrtd: ^2.0.0 # Or the specific version compatible with ekyc
```

Then, run `flutter pub get`.

## Usage

### Initiate the eKYC Flow

```dart
import 'package:flutter/material.dart';
import 'package:ekyc/ekyc.dart';

Future<void> startMyKycProcess(BuildContext context) async {
  try {
    final EkycResult? result = await Ekyc().startKycFlow(context: context);
    if (result != null) {
      // Handle successful eKYC result
      print('eKYC Success: ${result.name} - ${result.documentNumber}');
      // Navigate to a success screen or display data
    } else {
      // User cancelled or process failed without throwing specific error
      print('eKYC Process cancelled or failed.');
    }
  } catch (e) {
    // Handle errors during the flow
    print('eKYC Error: $e');
    // Display an error message to the user
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('eKYC Failed'),
        content: Text('An error occurred during eKYC: ${e.toString()}'),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }
}

// Example usage in a Widget:
// ElevatedButton(
//   onPressed: () => startMyKycProcess(context),
//   child: const Text('Start eKYC'),
// )
```

### Direct NFC Status Check (Optional)

If you need to check NFC availability before starting the full flow:

```dart
import 'package:ekyc/ekyc.dart';

Future<void> checkNfcStatus() async {
  try {
    final Map<String, dynamic> nfcStatus = await Ekyc.checkNfc();
    print('NFC Supported: ${nfcStatus['supported']}');
    print('NFC Enabled: ${nfcStatus['enabled']}');
    if (nfcStatus['error'] != null) {
      print('NFC Error Details: ${nfcStatus['error']}');
    }
  } catch (e) {
    print('Failed to check NFC status: $e');
  }
}
```

### Direct Card Read (Advanced Usage)

If you have MRZ data from another source and want to directly read the NFC chip:

```dart
import 'package:ekyc/ekyc.dart';

Future<void> readCardDirectly(String docNumber, String dob, String doe) async {
  try {
    final Map<String, dynamic> cardData = await Ekyc.readCard(
      docNumber: docNumber,
      dob: dob,
      doe: doe,
    );
    print('Card Data: $cardData');
  } catch (e) {
    print('Card Read Error: $e');
  }
}
```

## Platform-Specific Setup

### Android

1.  **Permissions**: The plugin requires NFC and Camera permissions. Add them to `android/app/src/main/AndroidManifest.xml`:

    ```xml
    <uses-permission android:name="android.permission.NFC" />
    <uses-permission android:name="android.permission.CAMERA" />
    ```

2.  **Activity Configuration**: Ensure your `MainActivity` handles NFC intents and is configured with `launchMode="singleTask"` to prevent issues with multiple activity instances. In `android/app/src/main/AndroidManifest.xml`:

    ```xml
    <activity
        android:name=".MainActivity"
        android:exported="true"
        android:launchMode="singleTask" <!-- Important for NFC handling! -->
        android:taskAffinity=""
        android:theme="@style/LaunchTheme"
        android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
        android:hardwareAccelerated="true"
        android:windowSoftInputMode="adjustResize">
        <intent-filter>
            <action android:name="android.intent.action.MAIN"/>
            <category android:name="android.intent.category.LAUNCHER"/>
        </intent-filter>
        <!-- Essential for NFC scanning with dmrtd. This allows the system to dispatch NFC intents. -->
        <intent-filter>
            <action android:name="android.nfc.action.TAG_DISCOVERED"/>
            <category android:name="android.intent.category.DEFAULT"/>
        </intent-filter>
        <intent-filter>
            <action android:name="android.nfc.action.TECH_DISCOVERED"/>
        </intent-filter>
        <meta-data android:name="android.nfc.action.TECH_DISCOVERED"
                   android:resource="@xml/nfc_tech_filter"/>
    </activity>
    ```

3.  **NFC Tech Filter**: Create a resource file `android/app/src/main/res/xml/nfc_tech_filter.xml` to specify the NFC technologies your app can discover. This is crucial for eMRTD (e-Passports/e-ID cards) which typically use `IsoDep`.

    ```xml
    <?xml version="1.0" encoding="utf-8"?>
    <resources xmlns:xliff="urn:oasis:names:tc:xliff:document:1.2">
        <tech-list>
            <tech>android.nfc.tech.IsoDep</tech>
            <tech>android.nfc.tech.NfcA</tech>
            <tech>android.nfc.tech.NfcB</tech>
            <tech>android.nfc.tech.NfcF</tech>
            <tech>android.nfc.tech.NfcV</tech>
            <!-- Add other relevant NFC technologies if your documents support them -->
        </tech-list>
    </resources>
    ```

4.  **Google ML Kit Dependencies**: If you use Google ML Kit for OCR (e.g., for MRZ scanning), ensure these meta-data tags are in your `<application>` tag in `AndroidManifest.xml`:

    ```xml
    <application ...>
        <meta-data
            android:name="com.google.mlkit.vision.DEPENDENCIES"
            android:value="ocr" />
        <meta-data
            android:name="com.google.firebase.ml.vision.DEPENDENCIES"
            android:value="ocr" />
        <meta-data
            android:name="com.google.firebase.ml.vision.TELEMETRY_ENABLED"
            android:value="false" />
    </application>
    ```

### iOS

1.  **Capabilities**: Add the "Near Field Communication Tag Reading" capability to your iOS app in Xcode:
    *   Open your project in Xcode.
    *   Select your target.
    *   Go to "Signing & Capabilities".
    *   Click "+" and add "Near Field Communication Tag Reading".

2.  **Info.plist**: Add the following usage descriptions to your `ios/Runner/Info.plist`:

    ```xml
    <key>NFCReaderUsageDescription</key>
    <string>This app uses NFC to read identity documents for eKYC verification.</string>
    <key>NSCameraUsageDescription</key>
    <string>This app needs camera access to scan the MRZ code on your ID card or passport.</string>
    ```

3.  **Podfile**: Ensure your `ios/Podfile` targets `platform :ios, '11.0'` or higher and includes `frameworks = 'CoreNFC'` in your `ekyc.podspec` (already handled by the plugin's setup).

## API Reference

### `Ekyc` Class

#### Methods

-   `Future<Map<String, dynamic>> checkNfc()`: Checks if NFC is supported and enabled on the device. Returns a `Map` with `supported` (bool), `enabled` (bool), and optional `error` (String).
-   `Future<Map<String, dynamic>> readCard({required String docNumber, required String dob, required String doe})`: Initiates NFC reading of a passport or ID card using the provided document number, date of birth (YYMMDD), and date of expiry (YYMMDD) for Basic Access Control (BAC). Returns a `Map` containing extracted eKYC data.
-   `Future<EkycResult?> startKycFlow({required BuildContext context})`: Provides a complete, guided eKYC flow including document type selection, MRZ scanning, and NFC chip reading. Returns an `EkycResult` object on success, or `null` if cancelled.

### `EkycResult` Class

This class encapsulates the data extracted from the eKYC process.

#### Properties (All `String?`)

-   `nin`: National Identity Number
-   `name`: First Name
-   `nameArabic`: Name in Arabic (if available)
-   `address`: Permanent Address
-   `placeOfBirth`: Place of Birth
-   `documentNumber`: Document Number
-   `gender`: Gender
-   `dateOfBirth`: Date of Birth
-   `dateOfExpiry`: Date of Expiry
-   `nationality`: Nationality
-   `country`: Country
-   `issuingAuthority`: Issuing Authority
-   `dateOfIssue`: Date of Issue

### Common Errors and Troubleshooting

Error messages from `readCard` or `startKycFlow` provide user-friendly guidance:

-   **NFC_TIMEOUT**: "No NFC document detected. Please hold your document steadily over the phone and try again."
-   **Connection lost / I/O error**: "Connection lost. Please ensure the document remains still during scanning and try again."
-   **Authentication failed**: "Authentication failed. Please check your document number, date of birth, and expiry date. Ensure the document is valid and try again."
-   **NFC not supported**: "NFC not supported for this document type or device. Please check device compatibility."
-   **NFC is not enabled**: "NFC is currently disabled on your device. Please enable NFC in your phone settings and try again."

## Example

See the `example/` directory for a complete working example of how to integrate this plugin into a Flutter application.

## Contributing

Contributions are welcome! Please refer to the [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

