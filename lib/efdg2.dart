import 'dart:typed_data';

import 'package:dmrtd/dmrtd.dart';

class EfDG2 {
  final int deviceType;
  final int expression;
  final int eyeColor;
  final int faceImageType;
  final int facialRecordDataLength;
  final int featureMask;
  final int fid;
  final int gender;
  final int hairColor;
  final int imageColorSpace;
  final Uint8List? imageData;
  final int imageHeight;
  final ImageType? imageType;
  final int imageWidth;
  final int lengthOfRecord;
  final int nrFeaturePoints;
  final int numberOfFacialImages;
  final int poseAngle;
  final int poseAngleUncertainty;
  final int quality;
  final int sfi;
  final int sourceType;
  final int tag;
  final int versionNumber;

  EfDG2({
    required this.deviceType,
    required this.expression,
    required this.eyeColor,
    required this.faceImageType,
    required this.facialRecordDataLength,
    required this.featureMask,
    required this.fid,
    required this.gender,
    required this.hairColor,
    required this.imageColorSpace,
    required this.imageData,
    required this.imageHeight,
    required this.imageType,
    required this.imageWidth,
    required this.lengthOfRecord,
    required this.nrFeaturePoints,
    required this.numberOfFacialImages,
    required this.poseAngle,
    required this.poseAngleUncertainty,
    required this.quality,
    required this.sfi,
    required this.sourceType,
    required this.tag,
    required this.versionNumber,
  });

  factory EfDG2.fromJson(Map<String, dynamic> json) {
    return EfDG2(
      deviceType: json['deviceType'],
      expression: json['expression'],
      eyeColor: json['eyeColor'],
      faceImageType: json['faceImageType'],
      facialRecordDataLength: json['facialRecordDataLength'],
      featureMask: json['featureMask'],
      fid: json['fid'],
      gender: json['gender'],
      hairColor: json['hairColor'],
      imageColorSpace: json['imageColorSpace'],
      imageData: json['imageData'],
      imageHeight: json['imageHeight'],
      imageType: json['imageType'], // you'll likely need to cast or parse this
      imageWidth: json['imageWidth'],
      lengthOfRecord: json['lengthOfRecord'],
      nrFeaturePoints: json['nrFeaturePoints'],
      numberOfFacialImages: json['numberOfFacialImages'],
      poseAngle: json['poseAngle'],
      poseAngleUncertainty: json['poseAngleUncertainty'],
      quality: json['quality'],
      sfi: json['sfi'],
      sourceType: json['sourceType'],
      tag: json['tag'],
      versionNumber: json['versionNumber'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceType': deviceType,
      'expression': expression,
      'eyeColor': eyeColor,
      'faceImageType': faceImageType,
      'facialRecordDataLength': facialRecordDataLength,
      'featureMask': featureMask,
      'fid': fid,
      'gender': gender,
      'hairColor': hairColor,
      'imageColorSpace': imageColorSpace,
      'imageData': imageData,
      'imageHeight': imageHeight,
      'imageType': imageType,
      'imageWidth': imageWidth,
      'lengthOfRecord': lengthOfRecord,
      'nrFeaturePoints': nrFeaturePoints,
      'numberOfFacialImages': numberOfFacialImages,
      'poseAngle': poseAngle,
      'poseAngleUncertainty': poseAngleUncertainty,
      'quality': quality,
      'sfi': sfi,
      'sourceType': sourceType,
      'tag': tag,
      'versionNumber': versionNumber,
    };
  }
}
