import 'dart:typed_data';

class EfDG11 {
  final String? custodyInformation;
  final String? ersonalSummary; // Assuming the typo is intentional; otherwise, use `personalSummary`
  final int fid;
  final DateTime? fullDateOfBirth;
  final String? nameOfHolder;
  final List<String> otherNames;
  final List<String> otherValidTDNumbers;
  final List<String> permanentAddress;
  final String? personalNumber;
  final List<String> placeOfBirth;
  final String? profession;
  final Uint8List? proofOfCitizenship;
  final int sfi;
  final int tag;
  final String? telephone;
  final String? title;


  EfDG11({
    this.custodyInformation,
    this.ersonalSummary, // Assuming the typo is intentional; otherwise, use `personalSummary`
    required this.fid,
    this.fullDateOfBirth,
    this.nameOfHolder,
    required this.otherNames,
    required this.otherValidTDNumbers,
    required this.permanentAddress,
    this.personalNumber,
    required this.placeOfBirth,
    this.profession,
    this.proofOfCitizenship,
    required this.sfi,
    required this.tag,
    this.telephone,
    this.title,
  });

  factory EfDG11.fromMap(Map<String, dynamic> map) {
    return EfDG11(
      custodyInformation: map['custodyInformation'],
      ersonalSummary: map['personalSummary'], // Assuming the typo is intentional; otherwise, use `personalSummary`
      fid: map['fid'],
      fullDateOfBirth: map['fullDateOfBirth'] != null ? DateTime.parse(map['fullDateOfBirth']) : null,
      nameOfHolder: map['nameOfHolder'],
      otherNames: List<String>.from(map['otherNames'] ?? []),
      otherValidTDNumbers: List<String>.from(map['otherValidTDNumbers'] ?? []),
      permanentAddress: List<String>.from(map['permanentAddress'] ?? []),
      personalNumber: map['personalNumber'],
      placeOfBirth: List<String>.from(map['placeOfBirth'] ?? []),
      profession: map['profession'],
      proofOfCitizenship: map['proofOfCitizenship'] != null ? Uint8List.fromList(List<int>.from(map['proofOfCitizenship'])) : null,
      sfi: map['sfi'],
      tag: map['tag'],
      telephone: map['telephone'],
      title: map['title'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'custodyInformation': custodyInformation,
      'personalSummary': ersonalSummary, // Assuming the typo is intentional; otherwise, use `personalSummary`
      'fid': fid,
      'fullDateOfBirth': fullDateOfBirth?.toIso8601String(),
      'nameOfHolder': nameOfHolder,
      'otherNames': otherNames,
      'otherValidTDNumbers': otherValidTDNumbers,
      'permanentAddress': permanentAddress,
      'personalNumber': personalNumber,
      'placeOfBirth': placeOfBirth,
      'profession': profession,
      'proofOfCitizenship': proofOfCitizenship,
      'sfi': sfi,
      'tag': tag,
      'telephone': telephone,
      'title': title,
    };
  }
}