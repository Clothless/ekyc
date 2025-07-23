import 'package:dmrtd/dmrtd.dart';

import 'ekyc.dart';

class CardDataModel {
  final EfCardAccess? efCardAccess;
  final EfCardSecurity? efCardSecurity;
  final EfCOM efcom;
  final EfDG1 efdg1;
  final EfDG2 efdg2;
  final EfDG3? efdg3;
  final EfDG4? efdg4;
  final EfDG5? efdg5;
  final EfDG6? efdg6;
  final EfDG7? efdg7;
  final EfDG8? efdg8;
  final EfDG9? efdg9;
  final EfSOD? efsod;
  final EfDG10? efdg10;
  final EfDG11? efdg11;
  final EfDG12? efdg12;
  final EfDG13? efdg13;
  final EfDG14? efdg14;
  final EfDG15? efdg15;
  final EfDG16? efdg16;
  
  CardDataModel({
    this.efCardAccess,
    this.efCardSecurity,
    required this.efcom,
    required this.efdg1,
    required this.efdg2,
    this.efdg3,
    this.efdg4,
    this.efdg5,
    this.efdg6,
    this.efdg7,
    this.efdg8,
    this.efdg9,
    this.efsod,
    this.efdg10,
    this.efdg11,
    this.efdg12,
    this.efdg13,
    this.efdg14,
    this.efdg15,
    this.efdg16,
  });
  
  factory CardDataModel.fromJson(Map<String, dynamic> result) {
    return CardDataModel(
      efCardAccess: result["efCardAccess"],
      efCardSecurity: result["efCardSecurity"],
      efcom: result["efcom"],
      efdg1: result["efdg1"],
      efdg2: result["efdg2"],
      efdg3: result['efdg3'],
      efdg4: result['efdg4'],
      efdg5: result['efdg5'],
      efdg6: result['efdg6'],
      efdg7: result['efdg7'],
      efdg8: result['efdg8'],
      efdg9: result['efdg9'],
      efsod: result['efsod'],
      efdg10: result['efdg10'],
      efdg11: result['efdg11'],
      efdg12: result['efdg12'],
      efdg13: result['efdg13'],
      efdg14: result['efdg14'],
      efdg15: result['efdg15'],
      efdg16: result['efdg16'],
    );
  }
  
  
  
}