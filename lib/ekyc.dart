import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Ekyc {
  static const MethodChannel _methodChannel = MethodChannel('ekyc');

  /// Listen for native passport scan result (from handleNfcIntent on Android).
  static void setOnPassportReadListener(
    Function(Map<String, dynamic>) onData, {
    Function(String error)? onError,
  }) {
    _methodChannel.setMethodCallHandler((call) async {
      if (call.method == 'onPassportRead') {
        final data = Map<String, dynamic>.from(call.arguments ?? {});
        onData(data);
      } else if (call.method == 'onPassportError') {
        final errorMessage = call.arguments?.toString() ?? 'Unknown error';
        onError?.call(errorMessage);
      }
    });
  }

  /// Check if NFC is supported and enabled on the device.
  static Future<Map<String, dynamic>> checkNfc() async {
    final result = await _methodChannel.invokeMethod('checkNfc');
    return Map<String, dynamic>.from(result ?? {});
  }

  /// Initialize NFC adapter/services on the host platform.
  static Future<bool> initialize() async {
    final result = await _methodChannel.invokeMethod('initialize');
    return result == true;
  }

  /// Start listening for NFC tag and read passport/ID chip using BAC key credentials.
  ///
  /// Required arguments:
  /// - [documentNumber]: Document / Passport number
  /// - [dateOfBirth]: Date of birth in YYMMDD format
  /// - [dateOfExpiry]: Date of expiry in YYMMDD format
  static Future<Map<String, dynamic>?> readPassport({
    required String documentNumber,
    required String dateOfBirth,
    required String dateOfExpiry,
  }) async {
    final result = await _methodChannel.invokeMethod('readPassport', {
      'documentNumber': documentNumber,
      'dateOfBirth': dateOfBirth,
      'dateOfExpiry': dateOfExpiry,
    });
    if (result == null) return null;
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    return {'status': result.toString()};
  }

  /// Get host platform version string.
  static Future<String?> getPlatformVersion() async {
    try {
      final version =
          await _methodChannel.invokeMethod<String>('getPlatformVersion');
      return version;
    } catch (e) {
      throw Exception('Failed to get platform version: $e');
    }
  }

  /// Read Data Group COM
  static Future<dynamic> readCOM() async {
    return await _methodChannel.invokeMethod('readCOM');
  }

  /// Read Data Group SOD
  static Future<dynamic> readSOD() async {
    return await _methodChannel.invokeMethod('readSOD');
  }

  /// Read Data Group 1 (MRZ Data)
  static Future<dynamic> readDG1() async {
    return await _methodChannel.invokeMethod('readDG1');
  }

  /// Read Data Group 2 (Face Image)
  static Future<dynamic> readDG2() async {
    return await _methodChannel.invokeMethod('readDG2');
  }

  /// Read Data Group 7 (Signature Image)
  static Future<dynamic> readDG7() async {
    return await _methodChannel.invokeMethod('readDG7');
  }

  /// Read Data Group 11 (Additional Personal Details)
  static Future<dynamic> readDG11() async {
    return await _methodChannel.invokeMethod('readDG11');
  }

  /// Read Data Group 15 (Active Authentication Public Key)
  static Future<dynamic> readDG15() async {
    return await _methodChannel.invokeMethod('readDG15');
  }

  /// Helper flow to verify NFC availability and read passport data.
  Future<Map<String, dynamic>?> startKycFlow({
    required BuildContext context,
    required Map<String, dynamic> mrzData,
  }) async {
    try {
      final nfcStatus = await Ekyc.checkNfc();
      if (nfcStatus['supported'] == false || nfcStatus['enabled'] == false) {
        if (!context.mounted) return null;
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('NFC Not Enabled'),
            content: Text(nfcStatus['error'] != null
                ? 'NFC is not enabled: ${nfcStatus['error']}'
                : 'NFC is not enabled. Please enable NFC in your device settings and try again.'),
            actions: [
              TextButton(
                onPressed: () {
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('OK'),
              )
            ],
          ),
        );
        return null;
      }
    } catch (e) {
      if (!context.mounted) return null;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('NFC Check Failed'),
          content: Text('Failed to check NFC status: $e'),
          actions: [
            TextButton(
              onPressed: () {
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('OK'),
            )
          ],
        ),
      );
      return null;
    }

    try {
      await Ekyc.initialize();
      final docNumber = mrzData['docNumber'] ?? mrzData['documentNumber'];
      final dob = mrzData['dob'] ?? mrzData['dateOfBirth'];
      final doe = mrzData['doe'] ?? mrzData['dateOfExpiry'];

      if (docNumber == null || dob == null || doe == null) {
        throw Exception(
            'Missing required MRZ fields (documentNumber, dateOfBirth, dateOfExpiry)');
      }

      return await Ekyc.readPassport(
        documentNumber: docNumber.toString(),
        dateOfBirth: dob.toString(),
        dateOfExpiry: doe.toString(),
      );
    } catch (e) {
      log('Error reading passport: $e');
      rethrow;
    }
  }
}

