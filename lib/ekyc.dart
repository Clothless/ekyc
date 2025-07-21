import 'package:flutter/material.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'ekyc_platform_interface.dart';
import 'src/ui/mrz_scanner_screen.dart';
import 'src/ui/result_screen.dart';

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
              onTap: () => Navigator.of(context).pop(DocumentType.idCard),
            ),
            ListTile(
              title: const Text('Passport'),
              onTap: () => Navigator.of(context).pop(DocumentType.passport),
            ),
          ],
        ),
      ),
    );

    if (docType == null) return null; // User cancelled

    // 1.5. Check NFC status before proceeding
    try {
      final nfcStatus = await EkycPlatform.instance.checkNfc();
      if (nfcStatus is Map && nfcStatus['enabled'] == false) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('NFC Not Enabled'),
            content: const Text('NFC is not enabled. Please enable NFC in your device settings and try again.'),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
          ),
        );
        return null;
      }
    } catch (e) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('NFC Check Failed'),
          content: Text('Failed to check NFC status: $e'),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
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
      final result = await EkycPlatform.instance.readCard(
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
