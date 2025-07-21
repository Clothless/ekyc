## 0.0.1

* Initial release with NFC functionality
* Added NFC tag reading support for Android and iOS
* Implemented NFC status checking
* Added comprehensive error handling
* Created example app with NFC demonstration
* Added unit tests for all NFC methods
* Updated documentation with usage examples and platform-specific setup instructions

### Features
- `checkNfc()`: Check if NFC is supported and enabled on the device
- `readNfc()`: Read NFC tag data including tag ID, NDEF messages, and technology information
- `onNfcTagDetected()`: Handle NFC tag detection (Android only)

### Supported Platforms
- Android: API level 21+ (Android 5.0+)
- iOS: iOS 11.0+ (iPhone 7 and newer)

### Breaking Changes
None - This is the initial release.

### Known Issues
- iOS NFC reading requires physical device testing (not available in simulator)
- Some NFC tag types may not be fully supported on all devices
