import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dmrtd/dmrtd.dart' as dmrtd;
import 'src/ui/mrz_scanner_screen.dart';

class EkycResult {
  final String? nin;
  final String? name;
  final String? nameArabic;
  final String? address;
  final String? placeOfBirth;
  final String? documentNumber;
  final String? gender;
  final String? dateOfBirth;
  final String? dateOfExpiry;
  final String? nationality;
  final String? country;
  final String? issuingAuthority;
  final String? dateOfIssue;

  EkycResult({
    this.nin,
    this.name,
    this.nameArabic,
    this.address,
    this.placeOfBirth,
    this.documentNumber,
    this.gender,
    this.dateOfBirth,
    this.dateOfExpiry,
    this.nationality,
    this.country,
    this.issuingAuthority,
    this.dateOfIssue,
  });

  factory EkycResult.fromMap(Map<String, dynamic> map) {
    return EkycResult(
      nin: map['nin'],
      name: map['name'],
      nameArabic: map['nameArabic'],
      address: map['address'],
      placeOfBirth: map['placeOfBirth'],
      documentNumber: map['documentNumber'],
      gender: map['gender'],
      dateOfBirth: map['dateOfBirth'],
      dateOfExpiry: map['dateOfExpiry'],
      nationality: map['nationality'],
      country: map['country'],
      issuingAuthority: map['issuingAuthority'],
      dateOfIssue: map['dateOfIssue'],
    );
  }

  Map<String, dynamic> toMap() => {
        'nin': nin,
        'name': name,
        'nameArabic': nameArabic,
        'address': address,
        'placeOfBirth': placeOfBirth,
        'documentNumber': documentNumber,
        'gender': gender,
        'dateOfBirth': dateOfBirth,
        'dateOfExpiry': dateOfExpiry,
        'nationality': nationality,
        'country': country,
        'issuingAuthority': issuingAuthority,
        'dateOfIssue': dateOfIssue,
      };
}

class Ekyc {
  static const MethodChannel _methodChannel = MethodChannel('ekyc');

  static Future<String?> getPlatformVersion() async {
    try {
      final version = await _methodChannel.invokeMethod<String>('getPlatformVersion');
      return version;
    } catch (e) {
      throw Exception('Failed to get platform version: $e');
    }
  }

  static Future<Map<String, dynamic>> checkNfc() async {
    try {
      final result = await _methodChannel.invokeMethod('checkNfc');
      if (result == null) {
        throw Exception('No response from platform for checkNfc');
      }
      return Map<String, dynamic>.from(result);
    } catch (e) {
      throw Exception('Failed to check NFC: $e');
    }
  }

  static Future<Map<String, dynamic>> readCard({
    required String docNumber,
    required String dob,
    required String doe,
  }) async {
    final nfcProvider = dmrtd.NfcProvider();
    try {
      await nfcProvider.connect(
        timeout: const Duration(seconds: 10),
        iosAlertMessage: "Hold your document close to the phone",
      );
      final passport = dmrtd.Passport(nfcProvider);
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
      final errorMsg = e.toString();
      if (errorMsg.contains('Polling tag timeout') || errorMsg.contains('408')) {
        throw Exception('NFC_TIMEOUT: No NFC document detected. Please hold your document close to the phone and try again.');
      }
      throw Exception('eKYC NFC read failed: $e');
    } finally {
      try {
        await nfcProvider.disconnect();
      } catch (_) {}
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

  Future<EkycResult?> startKycFlow({required BuildContext context}) async {
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
      if (nfcStatus['enabled'] == false || nfcStatus['enabled'] == null) {
        if (!context.mounted) return null;
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('NFC Not Enabled'),
            content: Text(nfcStatus['error'] != null ? 'NFC is not enabled: ${nfcStatus['error']}' : 'NFC is not enabled. Please enable NFC in your device settings and try again.'),
            actions: [TextButton(onPressed: () {
              if (!context.mounted) return;
              Navigator.of(context).pop();
            }, child: const Text('OK'))],
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
          actions: [TextButton(onPressed: () {
            if (!context.mounted) return;
            Navigator.of(context).pop();
          }, child: const Text('OK'))],
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
      final result = await Ekyc.readCard(
        docNumber: mrzData['docNumber']!,
        dob: mrzData['dob']!,
        doe: mrzData['doe']!,
      );
      return EkycResult.fromMap(result);
    } catch (e) {
      rethrow;
    }
  }
}
