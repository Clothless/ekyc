import 'package:dmrtd/dmrtd.dart';
import 'package:ekyc/card_portal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dmrtd/dmrtd.dart' as dmrtd;
import 'src/ui/mrz_scanner_screen.dart';
import 'dart:convert'; // Add this import for base64 encoding

class EkycResult {
  // Core MRZ data
  final String documentNumber;
  final String dateOfBirth; // Formatted string
  final String dateOfExpiry; // Formatted string
  final String firstName;
  final String lastName;
  final String gender; // This will be the name of the Gender enum value
  final String nationality;
  final String? fullMrz; // Raw MRZ string

  // DG data as custom objects
  final EfDG2? dg2Data;
  final EfDG11? dg11Data;
  final EfDG12? dg12Data;

  // For backward compatibility or simpler direct image display
  final String? base64Image;

  EkycResult({
    required this.documentNumber,
    required this.dateOfBirth,
    required this.dateOfExpiry,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.nationality,
    this.fullMrz,
    this.dg2Data,
    this.base64Image,
    this.dg11Data,
    this.dg12Data,
  });

  factory EkycResult.fromMap(Map<String, dynamic> map) {
    return EkycResult(
      documentNumber: map['documentNumber'],
      dateOfBirth: map['dateOfBirth'],
      dateOfExpiry: map['dateOfExpiry'],
      firstName: map['firstName'],
      lastName: map['lastName'],
      gender: map['gender'],
      // Expecting a string here now
      nationality: map['nationality'],
      fullMrz: map['fullMrz'],
      base64Image: map['base64Image'],
      dg2Data: map['dg2Data'] != null ? map['dg2Data'] : null,
      dg11Data: map['dg11Data'] != null ? map['dg11Data'] : null,
      dg12Data: map['dg12Data'] != null ? map['dg12Data'] : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'documentNumber': documentNumber,
      'dateOfBirth': dateOfBirth,
      'dateOfExpiry': dateOfExpiry,
      'firstName': firstName,
      'lastName': lastName,
      'gender': gender,
      'nationality': nationality,
      'fullMrz': fullMrz,
      'base64Image': base64Image,
      'dg2Data': dg2Data!,
      'dg11Data': dg11Data!,
      'dg12Data': dg12Data!,
    };
  }
}

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

  Future<CardDataModel> gettingCardData({required Passport passport}) async {
    try {
      // final cardAccess = await passport.readEfCardAccess();
      // final cardSecurity = await passport.readEfCardSecurity();
      final efcom = await passport.readEfCOM();
      final efdg1 = await passport.readEfDG1();
      final efdg2 = await passport.readEfDG2();
      // final efdg3 = await passport.readEfDG3();
      // final efdg4 = await passport.readEfDG4();
      // final efdg5 = await passport.readEfDG5();
      // final efdg6 = await passport.readEfDG6();
      // final efdg7 = await passport.readEfDG7();
      // final efdg8 = await passport.readEfDG8();
      // final efdg9 = await passport.readEfDG9();
      // final efsod = await passport.readEfSOD();
      // final efdg10 = await passport.readEfDG10();
      // final efdg11 = await passport.readEfDG11();
      // final efdg12 = await passport.readEfDG12();
      // final efdg13 = await passport.readEfDG13();
      // final efdg14 = await passport.readEfDG14();
      // final efdg15 = await passport.readEfDG15();
      // final efdg16 = await passport.readEfDG16();
      final temp = {
        'cardAccess': null,
        'cardSecurity': null,
        'efcom': efcom,
        'efdg1': efdg1,
        'efdg2': efdg2,
        'efdg3': null,
        'efdg4': null,
        'efdg5': null,
        'efdg6': null,
        'efdg7': null,
        'efdg8': null,
        'efdg9': null,
        'efsod': null,
        'efdg10': null,
        'efdg11': null,
        'efdg12': null,
        'efdg13': null,
        'efdg14': null,
        'efdg15': null,
        'efdg16': null,
      };

      return CardDataModel.fromJson(temp);
    } catch (e, stackTrace) {
      // Log the error and stack trace for debugging
      print('Error getting card data: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to get card data: $e');
    }
  }

  Future<EkycResult> readCard({
    required String documentNumber,
    required String dateOfBirth,
    required String dateOfExpiry,
  }) async {
    final nfcProvider = dmrtd.NfcProvider();

    try {
      await nfcProvider.connect(
        timeout: const Duration(seconds: 10),
        iosAlertMessage: "Hold your document close to the phone",
      );
      final passport = dmrtd.Passport(nfcProvider);

      final bacKey = dmrtd.DBAKey(documentNumber, _parseDate(dateOfBirth),
          _parseDate(dateOfExpiry)); // Use DBAKey for session

      await passport.startSession(bacKey);

      CardDataModel result = await gettingCardData(passport: passport);

      dmrtd.MRZ mrz = result.efdg1.mrz;

      EfDG2? customDg2Data; // Your custom DG2 object
      EfDG11? customDg11Data; // Your custom DG11 object
      EfDG12? customDg12Data; // Your custom DG12 object
      String? base64Image; // For direct UI display (from DG2)

      // Read DG2 (Facial Image)
      if (result.efcom.dgTags.contains(dmrtd.EfDG2.TAG)) {
        try {
          if (result.efdg2.imageData != null) {
            base64Image = base64Encode(result.efdg2.imageData!);
            customDg2Data = result.efdg2;
          }
        } catch (e) {
          print('Failed to read DG2: $e');
        }
      }

      // Read DG11 (Additional Personal Details)
      if (result.efcom.dgTags.contains(dmrtd.EfDG11.TAG)) {
        try {
          customDg11Data = result.efdg11;
        } catch (e) {
          print('Failed to read DG11: $e');
        }
      }

      // Read DG12 (Additional Document Details)
      if (result.efcom.dgTags.contains(dmrtd.EfDG12.TAG)) {
        try {
          customDg12Data = result.efdg12;
        } catch (e) {
          print('Failed to read DG12: $e');
        }
      }

      return EkycResult(
        documentNumber: mrz.documentNumber,
        dateOfBirth: _formatDate(mrz.dateOfBirth),
        dateOfExpiry: _formatDate(mrz.dateOfExpiry),
        firstName: mrz.firstName,
        lastName: mrz.lastName,
        gender: mrz.gender,
        // Correct: Access the name of the enum value for display
        nationality: mrz.nationality,
        fullMrz: mrz.toString(),
        // As per your latest change
        dg2Data: customDg2Data,
        base64Image: base64Image,
        dg11Data: customDg11Data,
        dg12Data: customDg12Data,
      );
    } finally {
      // Ensure disconnect is always called
      await nfcProvider.disconnect();
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

  Future<Map<String, dynamic>?> startKycFlow({required BuildContext context}) async {
    var result;

    // 1. Show Document Type Dialog
    final docType = await showDialog<DocumentType>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Document Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('ID Card / Residence Permit'),
              onTap: () {
                if (!context.mounted) return;
                Navigator.of(context).pop(DocumentType.idCard);
              },
            ),
            ListTile(
              title: const Text('Passport'),
              onTap: () {
                if (!context.mounted) return;
                Navigator.of(context).pop(DocumentType.passport);
              },
            ),
          ],
        ),
      ),
    );
    if (docType == null) return null; // User cancelled
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
    final mrzData = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(
        builder: (context) => MrzScannerScreen(
          documentType: docType,
        ),
      ),
    );
    if (mrzData == null) return null; // User cancelled scan
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
