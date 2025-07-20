import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'ekyc_method_channel.dart';

abstract class EkycPlatform extends PlatformInterface {
  /// Constructs a EkycPlatform.
  EkycPlatform() : super(token: _token);

  static final Object _token = Object();

  static EkycPlatform _instance = MethodChannelEkyc();

  /// The default instance of [EkycPlatform] to use.
  ///
  /// Defaults to [MethodChannelEkyc].
  static EkycPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [EkycPlatform] when
  /// they register themselves.
  static set instance(EkycPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<dynamic> checkNfc() {
    throw UnimplementedError('checkNfc() has not been implemented.');
  }
}
