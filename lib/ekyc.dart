import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'src/ui/mrz_scanner_screen.dart';
import 'dart:convert'; // Add this import for base64 encoding

class Ekyc {
  static const MethodChannel _methodChannel = MethodChannel('ekyc');

  /// Listen for native passport scan result (from handleNfcIntent).
  static void setOnPassportReadListener(Function(Map<String, dynamic>) onData) {
    _methodChannel.setMethodCallHandler((call) async {
      if (call.method == 'onPassportRead') {
        final data = Map<String, dynamic>.from(call.arguments);
        onData(data);
      }
    });
  }

  /// Check if NFC is supported and enabled
  static Future<Map<String, dynamic>> checkNfc() async {
    final result = await _methodChannel.invokeMethod('checkNfc');
    return Map<String, dynamic>.from(result ?? {});
  }

  /// Reinitialize NFC (optional)
  static Future<bool> initialize() async {
    return await _methodChannel.invokeMethod('initialize');
  }

  /// Start listening for NFC tag and provide BAC key info
  static Future<void> readPassport({
    required String documentNumber,
    required String dateOfBirth,
    required String dateOfExpiry,
  }) async {
    await _methodChannel.invokeMethod('readPassport', {
      'documentNumber': documentNumber,
      'dateOfBirth': dateOfBirth,
      'dateOfExpiry': dateOfExpiry,
    });
  }

  static Future<String?> getPlatformVersion() async {
    try {
      final version =
      await _methodChannel.invokeMethod<String>('getPlatformVersion');
      return version;
    } catch (e) {
      throw Exception('Failed to get platform version: $e');
    }
  }

  static Future<dynamic> init() async {
    try {
      final result = await _methodChannel.invokeMethod('initialize');
      if (result == null) {
        throw Exception('No response from platform for initialize');
      }
      return Map<String, dynamic>.from(result);
    } catch (e) {
      throw Exception('Failed to initialize: $e');
    }
  }

  static DateTime _parseDate(String dateStr) {
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

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<Map<String, dynamic>?> startKycFlow({required BuildContext context, required Map<String, String> mrzData}) async {
    var result;

    // 1. Show Document Type Dialog
    // final docType = await showDialog<DocumentType>(
    //   context: context,
    //   builder: (context) => AlertDialog(
    //     title: const Text('Select Document Type'),
    //     content: Column(
    //       mainAxisSize: MainAxisSize.min,
    //       children: [
    //         ListTile(
    //           title: const Text('ID Card / Residence Permit'),
    //           onTap: () {
    //             if (!context.mounted) return;
    //             Navigator.of(context).pop(DocumentType.idCard);
    //           },
    //         ),
    //         ListTile(
    //           title: const Text('Passport'),
    //           onTap: () {
    //             if (!context.mounted) return;
    //             Navigator.of(context).pop(DocumentType.passport);
    //           },
    //         ),
    //       ],
    //     ),
    //   ),
    // );
    // if (docType == null) return null; // User cancelled
    // 1.5. Check NFC status before proceeding
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
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'))
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
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                },
                child: const Text('OK'))
          ],
        ),
      );
      return null;
    }
    // 2. Push MRZ Scanner
    // final mrzData = await Navigator.of(context).push<Map<String, String>>(
    //   MaterialPageRoute(
    //     builder: (context) => MrzScannerScreen(
    //       documentType: docType,
    //     ),
    //   ),
    // );
    // if (mrzData == null) return null; // User cancelled scan
    // 3. Trigger NFC read and return result
    try {
      await Ekyc.initialize();
      await Ekyc.readPassport(
        documentNumber: mrzData['docNumber']!,
        dateOfBirth: mrzData['dob']!,
        dateOfExpiry: mrzData['doe']!,
      );
      // await Ekyc.readPassport(
      //   documentNumber: "302127750",
      //   dateOfBirth: "000527",
      //   dateOfExpiry: "310119",
      // );
      return result; // Return the EkycResult directly
    } catch (e) {
      rethrow;
    }
  }
}
