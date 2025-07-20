import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ekyc_platform_interface.dart';

/// An implementation of [EkycPlatform] that uses method channels.
class MethodChannelEkyc extends EkycPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('ekyc');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<dynamic> checkNfc() async {
    final version = await methodChannel.invokeMethod('checkNfc');
    return version;
  }
}
