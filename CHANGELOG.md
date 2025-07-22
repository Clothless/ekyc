## 0.0.2

*   **Refactor:** Streamlined plugin architecture to rely primarily on `dmrtd` for core NFC and passport/ID reading, reducing custom native code.
*   **Fix:** Resolved "NFC not recognized" and "double scan sound" issues by carefully managing AndroidManifest.xml intent filters and `singleTask` launch mode.
*   **Enhancement:** Improved User Experience (UX) in `ResultScreen` with more granular, actionable status messages during NFC scanning.
*   **Enhancement:** Removed `CircularProgressIndicator` during NFC scan, replaced by descriptive text.
*   **Build:** Re-introduced minimal native plugin entry points (`EkycPlugin.kt`, `EkycPlugin.swift`) to maintain Flutter plugin compatibility for future extensions.

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
