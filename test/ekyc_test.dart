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

  @override
  Future<dynamic> checkNfc() => Future.value({
    'supported': true,
    'enabled': true,
  });

  @override
  Future<dynamic> readNfc() => Future.value({
    'tagId': '04:A3:B2:C1:D0:E9:F8',
    'ndefMessages': [],
    'techList': ['android.nfc.tech.Ndef']
  });

  @override
  Future<dynamic> onNfcTagDetected() => Future.value({
    'tagId': '04:A3:B2:C1:D0:E9:F8',
    'ndefMessages': [],
    'techList': ['android.nfc.tech.Ndef']
  });
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

  test('checkNfc', () async {
    Ekyc ekycPlugin = Ekyc();
    MockEkycPlatform fakePlatform = MockEkycPlatform();
    EkycPlatform.instance = fakePlatform;

    final result = await ekycPlugin.checkNfc();
    expect(result['supported'], true);
    expect(result['enabled'], true);
  });

  test('readNfc', () async {
    Ekyc ekycPlugin = Ekyc();
    MockEkycPlatform fakePlatform = MockEkycPlatform();
    EkycPlatform.instance = fakePlatform;

    final result = await ekycPlugin.readNfc();
    expect(result['tagId'], '04:A3:B2:C1:D0:E9:F8');
    expect(result['techList'], ['android.nfc.tech.Ndef']);
  });

  test('onNfcTagDetected', () async {
    Ekyc ekycPlugin = Ekyc();
    MockEkycPlatform fakePlatform = MockEkycPlatform();
    EkycPlatform.instance = fakePlatform;

    final result = await ekycPlugin.onNfcTagDetected();
    expect(result['tagId'], '04:A3:B2:C1:D0:E9:F8');
    expect(result['techList'], ['android.nfc.tech.Ndef']);
  });
}
