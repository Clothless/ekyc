
import 'ekyc_platform_interface.dart';

class Ekyc {
  Future<String?> getPlatformVersion() {
    return EkycPlatform.instance.getPlatformVersion();
  }

  Future<dynamic> checkNfc() {
    return EkycPlatform.instance.checkNfc();
  }
}
