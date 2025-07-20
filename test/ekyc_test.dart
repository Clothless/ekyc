import 'package:flutter_test/flutter_test.dart';
import 'package:ekyc/ekyc.dart';
import 'package:ekyc/ekyc_platform_interface.dart';
import 'package:ekyc/ekyc_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockEkycPlatform
    with MockPlatformInterfaceMixin
    implements EkycPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final EkycPlatform initialPlatform = EkycPlatform.instance;

  test('$MethodChannelEkyc is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelEkyc>());
  });

  test('getPlatformVersion', () async {
    Ekyc ekycPlugin = Ekyc();
    MockEkycPlatform fakePlatform = MockEkycPlatform();
    EkycPlatform.instance = fakePlatform;

    expect(await ekycPlugin.getPlatformVersion(), '42');
  });
}
