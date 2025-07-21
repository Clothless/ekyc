# EKYC Flutter Plugin

A Flutter plugin for Electronic Know Your Customer (E-KYC) functionality with NFC (Near Field Communication) support for reading identity documents and smart cards.

## Features

- **NFC Tag Reading**: Read NFC tags and extract NDEF messages
- **Cross-Platform Support**: Works on both Android and iOS
- **NFC Status Checking**: Check if NFC is supported and enabled on the device
- **Comprehensive Data Extraction**: Extract tag ID, NDEF messages, and technology information

## Supported Platforms

- **Android**: API level 21+ (Android 5.0+)
- **iOS**: iOS 11.0+ (iPhone 7 and newer)

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  ekyc:
    git:
      url: https://github.com/your-username/ekyc.git
      ref: main
```

## Usage

### Basic NFC Reading

```dart
import 'package:ekyc/ekyc.dart';

final ekyc = Ekyc();

// Check NFC status
final nfcStatus = await ekyc.checkNfc();
print('NFC Supported: ${nfcStatus['supported']}');
print('NFC Enabled: ${nfcStatus['enabled']}');

// Read NFC tag
try {
  final nfcData = await ekyc.readNfc();
  print('NFC Data: $nfcData');
} catch (e) {
  print('NFC Error: $e');
}
```

### NFC Data Structure

The plugin returns NFC data in the following format:

```dart
{
  "tagId": "04:A3:B2:C1:D0:E9:F8", // Tag unique identifier
  "ndefMessages": [                // NDEF messages (if available)
    {
      "records": [
        {
          "type": "text/plain",
          "payload": "Hello World",
          "mimeType": "text/plain"
        }
      ]
    }
  ],
  "techList": [                    // Supported technologies
    "android.nfc.tech.Ndef",
    "android.nfc.tech.NfcA"
  ]
}
```

## Platform-Specific Setup

### Android

1. **Permissions**: The plugin automatically adds the required NFC permission to your app's `AndroidManifest.xml`.

2. **Intent Filters**: Add the following intent filters to your main activity in `android/app/src/main/AndroidManifest.xml`:

```xml
<intent-filter>
    <action android:name="android.nfc.action.NDEF_DISCOVERED"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <data android:mimeType="text/plain" />
</intent-filter>
<intent-filter>
    <action android:name="android.nfc.action.TAG_DISCOVERED"/>
    <category android:name="android.intent.category.DEFAULT"/>
</intent-filter>
<intent-filter>
    <action android:name="android.nfc.action.TECH_DISCOVERED"/>
    <category android:name="android.intent.category.DEFAULT"/>
</intent-filter>
<meta-data android:name="android.nfc.action.TECH_DISCOVERED"
    android:resource="@xml/nfc_tech_filter" />
```

3. **NFC Tech Filter**: Create `android/app/src/main/res/xml/nfc_tech_filter.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources xmlns:xliff="urn:oasis:names:tc:xliff:document:1.2">
    <tech-list>
        <tech>android.nfc.tech.IsoDep</tech>
        <tech>android.nfc.tech.NfcA</tech>
        <tech>android.nfc.tech.NfcB</tech>
        <tech>android.nfc.tech.NfcF</tech>
        <tech>android.nfc.tech.NfcV</tech>
        <tech>android.nfc.tech.Ndef</tech>
        <tech>android.nfc.tech.NdefFormatable</tech>
        <tech>android.nfc.tech.MifareClassic</tech>
        <tech>android.nfc.tech.MifareUltralight</tech>
    </tech-list>
</resources>
```

### iOS

1. **Capabilities**: Add NFC capability to your iOS app in Xcode:
   - Open your project in Xcode
   - Select your target
   - Go to "Signing & Capabilities"
   - Click "+" and add "Near Field Communication Tag Reading"

2. **Info.plist**: Add the following to your `ios/Runner/Info.plist`:

```xml
<key>NFCReaderUsageDescription</key>
<string>This app uses NFC to read identity documents for E-KYC verification.</string>
```

## API Reference

### Ekyc Class

#### Methods

- `Future<Map<String, dynamic>> checkNfc()`: Check if NFC is supported and enabled
- `Future<Map<String, dynamic>> readNfc()`: Read NFC tag data
- `Future<Map<String, dynamic>> onNfcTagDetected()`: Handle NFC tag detection (Android only)

### Error Codes

- `NFC_NOT_SUPPORTED`: NFC is not supported on the device
- `NFC_READER_NOT_READY`: NFC reader is not initialized
- `ACTIVITY_NOT_READY`: Activity is not ready for NFC operations
- `NFC_ERROR`: General NFC error

## Example

See the `example/` directory for a complete working example.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Getting Started

This project is a starting point for a Flutter
[plug-in package](https://flutter.dev/to/develop-plugins),
a specialized package that includes platform-specific implementation code for
Android and/or iOS.

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

