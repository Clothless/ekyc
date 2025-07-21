import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ekyc_platform_interface.dart';
import 'package:dmrtd/dmrtd.dart' as dmrtd;

/// An implementation of [EkycPlatform] that uses method channels.
class MethodChannelEkyc extends EkycPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('ekyc');

  /// The event channel used to receive NFC data from the native platform.
  @visibleForTesting
  final eventChannel = const EventChannel('ekyc_events');

  Stream<dynamic>? _nfcDataStream;

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<dynamic> checkNfc() async {
    final result = await methodChannel.invokeMethod('checkNfc');
    return result;
  }

  @override
  Future<String> startNfc() async {
    final result = await methodChannel.invokeMethod<String>('startNfc');
    return result ?? 'Failed to start NFC';
  }

  @override
  Future<String> stopNfc() async {
    final result = await methodChannel.invokeMethod<String>('stopNfc');
    return result ?? 'Failed to stop NFC';
  }

  @override
  Stream<dynamic> get nfcDataStream {
    _nfcDataStream ??= eventChannel.receiveBroadcastStream();
    return _nfcDataStream!;
  }

  @override
  Future<Map<String, dynamic>> readCard({
    required String docNumber,
    required String dob,
    required String doe,
  }) async {
    // NFC reading and parsing logic using dmrtd
    final nfc = dmrtd.NfcProvider();
    try {
      await nfc.connect();
      final passport = dmrtd.Passport(nfc);
      final bacKey = dmrtd.DBAKey(docNumber, _parseDate(dob), _parseDate(doe));
      await passport.startSession(bacKey);
      final efCom = await passport.readEfCOM();
      final dg1 = await passport.readEfDG1();
      dmrtd.EfDG11? dg11;
      if (efCom.dgTags.contains(dmrtd.EfDG11.TAG)) {
        try {
          dg11 = await passport.readEfDG11();
        } catch (_) {}
      }
      dmrtd.EfDG12? dg12;
      if (efCom.dgTags.contains(dmrtd.EfDG12.TAG)) {
        try {
          dg12 = await passport.readEfDG12();
        } catch (_) {}
      }
      await nfc.disconnect();
      // Build result map
      return {
        'nin': dg11?.personalNumber,
        'name': dg1.mrz.firstName,
        'nameArabic': dg11?.otherNames?.join(' '),
        'address': dg11?.permanentAddress?.join('\n'),
        'placeOfBirth': dg11?.placeOfBirth?.join(', '),
        'documentNumber': dg1.mrz.documentNumber,
        'gender': dg1.mrz.gender,
        'dateOfBirth': _formatDate(dg1.mrz.dateOfBirth),
        'dateOfExpiry': _formatDate(dg1.mrz.dateOfExpiry),
        'nationality': dg1.mrz.nationality,
        'country': dg1.mrz.country,
        'issuingAuthority': dg12?.issuingAuthority,
        'dateOfIssue': dg12?.dateOfIssue == null ? null : _formatDate(dg12!.dateOfIssue!),
      };
    } catch (e) {
      if (await nfc.isConnected()) {
        await nfc.disconnect();
      }
      throw Exception('eKYC NFC read failed: $e');
    }
  }

  DateTime _parseDate(String dateStr) {
    // Expects YYMMDD format
    int year = int.parse(dateStr.substring(0, 2));
    int month = int.parse(dateStr.substring(2, 4));
    int day = int.parse(dateStr.substring(4, 6));
    if (year > 50) {
      year += 1900;
    } else {
      year += 2000;
    }
    return DateTime(year, month, day);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
