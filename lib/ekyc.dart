
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'ekyc_platform_interface.dart';

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
  Future<EkycResult> readCard({
    required String docNumber,
    required String dob,
    required String doe,
  }) async {
    final result = await EkycPlatform.instance.readCard(
      docNumber: docNumber,
      dob: dob,
      doe: doe,
    );
    return EkycResult.fromMap(result);
  }

  Future<String?> getPlatformVersion() {
    return EkycPlatform.instance.getPlatformVersion();
  }

  Future<dynamic> checkNfc() {
    return EkycPlatform.instance.checkNfc();
  }

  Future<String> startNfc() {
    return EkycPlatform.instance.startNfc();
  }

  Future<String> stopNfc() {
    return EkycPlatform.instance.stopNfc();
  }

  Stream<dynamic> get nfcDataStream {
    return EkycPlatform.instance.nfcDataStream;
  }
}
