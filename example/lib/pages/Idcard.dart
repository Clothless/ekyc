import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:ekyc/ekyc.dart';

import 'package:path_provider/path_provider.dart';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'result_page.dart';

class Idcard extends StatefulWidget {
  final String documentType;

  const Idcard({Key? key, required this.documentType}) : super(key: key);

  @override
  _IdcardState createState() => _IdcardState();
}

class _IdcardState extends State<Idcard> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _prenomController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _ninController = TextEditingController();
  final TextEditingController _cnumberController = TextEditingController();
  final TextEditingController _birthplaceController = TextEditingController();
  final TextEditingController _releasedateController = TextEditingController();
  final TextEditingController _enddateController = TextEditingController();

  String? _frontCardNumber;
  String? _backCardNumber;
  File? _frontImage;
  File? _backImage;
  bool _frontUploaded = false;
  bool _backUploaded = false;
  String _comparisonResult = '';
  String _extractedendDate = '';
  String _extractedReleaseDate = '';
  String _extractedNIN = '';
  String _extractedCardnumber = '';
  String _extractedNom = '';
  String _extractedPrenom = '';
  final bool _isProcessingImage = false;
  String? _processingError;
  String _extractedBirthdate = '';
  bool isFacesMatched = false;
  double similarityPercentage = 0.0;
  bool _isProcessing = false;
  bool _isProcessingFront = false;
  bool _isProcessingBack = false;
  bool _isVerified = false;
  String _ocrText = '';
  String? _frontIdPath;
  String? _backIdPath;
  String? _selfiePath;
  String? _selfieCroppedPath;
  String? _idCardFacePath; // Path for extracted face from ID card
  String? _selfieCroppedFacePath;
  File? _selfieImage;
  DateTime? _birthDate;
  File? _extractedPhoto;
  Rect? _photoArea;
  List<File> _selfieImages = [];
  Map<String, dynamic>? _result;
  bool _scanning = false;
  Timer? _timeoutTimer;
  bool _timeout = false;
  final ImagePicker _picker = ImagePicker();

  final List<String> _readingSteps = [
    'Reading COM (Card Security Information)...',
    'Reading SOD (Security Object Document)...',
    'Reading DG1 (Personal Details)...',
    'Reading DG2 (Face Image)...',
    'Reading DG7 (Signature Image)...',
    'Reading DG11 (Additional Details)...',
    'Reading DG12 (Document Details)...',
    'Reading DG15 (Public Key Info)...',
  ];
  int _currentStep = 0;
  final int _totalSteps = 8;


  final Map<String, String> _formData = {
    'family_name': '',
    'given_name': '',
    'identity_number': '',
    'card_number': '',
    'birthDate': '',
    'expiryDate': '',
    'document_type': '',
  };

  final Map<String, String> mrzData = {
    'docNumber': '',
    'dob': '',
    'doe': '',
  };

  @override
  void initState() {
    super.initState();
    _formData['document_type'] = widget.documentType;
    Ekyc.setOnPassportReadListener(
          (passportData) async {
        _timeoutTimer?.cancel();
        await savePassportDigitalImageToResultPage(passportData);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ResultPage(result: passportData),
          ),
        );
        setState(() {
          _result = passportData;
          _scanning = false;
          _timeout = false;
        });
      },
      onError: (error) {
        // Show a dialog or snackbar
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Error Reading Passport'),
            content: Text(error),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('OK'),
              ),
            ],
          ),
        );
        setState(() {
          _scanning = false;
          _timeout = false;
        });
      },
    );

  }

  // Base64 image to file function
  Future<File> base64ToFile(String base64String) async {
    final bytes = base64Decode(base64String);
    final dir = await getTemporaryDirectory(); // or getApplicationDocumentsDirectory()
    final file = File('${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(bytes);
    return file;
  }

  void _simulateReadingSteps() async {
    for (int i = 0; i < _readingSteps.length; i++) {
      await Future.delayed(Duration(milliseconds: 700)); // simulate delay per step
      if (!_scanning) break; // exit early if user cancels
      setState(() {
        _currentStep = i;
      });
    }
  }


  Future<void> _startScan() async {
    setState(() {
      _result = null;
      _scanning = true;
      _timeout = false;
    });

    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      setState(() {
        _scanning = false;
        _timeout = true;
      });
    });

    await _startKyc();
  }

  Future<void> _startKyc() async {
    try {
      debugPrint('eKYC: Starting flow');
      final result = await Ekyc().startKycFlow(context: context, mrzData: {
        "docNumber": mrzData['docNumber']!,
        // "dob": mrzData['dob']!,
        "dob": "000528",
        "doe": mrzData['doe']!,
      });
      debugPrint('eKYC: Flow returned: $result');
    } catch (e) {
      debugPrint('eKYC: Error: $e');
      if (!mounted) return;
    }
  }

  Future<String> convertToJpeg(String image) async {
    var comparisonRequest = http.MultipartRequest(
      'POST',
      Uri.parse('http://105.96.12.227:8000/convert'), // FastAPI endpoint
    );
    comparisonRequest.fields.addAll({
      'jp2_base64': image,
    });
    var comparisonResponse = await comparisonRequest.send();
    final comparisonRespStr = await comparisonResponse.stream.bytesToString();
    final comparisonResponseData = jsonDecode(comparisonRespStr);

    if (comparisonResponse.statusCode != 200) {
      return comparisonResponseData;
    }
    return "";
  }

  Widget _buildPhoto() {
    final isJpeg = _result?['dg2']["isJpeg"];

    if (isJpeg) {
      convertToJpeg(_result?['dg2']["photo"]).then((jpegBase64) {
        ;
        if (jpegBase64.isNotEmpty) {
          return Column(
            children: [
              Container(
                width: 160,
                height: 200,
                // decoration: BoxDecoration(
                //   shape: BoxShape.circle,
                //   border: Border.all(color: Colors.grey, width: 2),
                // ),
                child: Image.memory(base64Decode(jpegBase64)),
              ),
            ],
          );
        }
      });
    }
    return Column(
      children: [
        Container(
          width: 160,
          height: 200,
          // decoration: BoxDecoration(
          //   shape: BoxShape.circle,
          //   border: Border.all(color: Colors.grey, width: 2),
          // ),
          child: Image.memory(base64Decode(_result?['dg2']["photo"])),
        ),
      ],
    );
  }

  List<CameraDescription>? _cameras;

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
  }

  Future<void> _verificationBack(String text) async {
    if (text.toLowerCase().contains('iddza') |
        text.toLowerCase().contains('nom:')) {
      setState(() {
        _isVerified = true;
      });
    } else {
      setState(() {
        _isVerified = false;
      });
    }
  }

  Future<void> _verificationFront(String text) async {
    if (text.toLowerCase().contains('rh')) {
      setState(() {
        _isVerified = true;
      });
    } else {
      setState(() {
        _isVerified = false;
      });
    }
  }

  void _showImageSourceDialog(BuildContext context, {required bool isFront}) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.of(context).pop();
                _pickIDCard(ImageSource.camera, isFront: isFront);

                setState(() {
                  if (isFront) {
                    _frontUploaded = true;
                  } else {
                    _backUploaded = true;
                  }
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.of(context).pop();
                _pickIDCard(ImageSource.gallery, isFront: isFront);
                setState(() {
                  if (isFront) {
                    _frontUploaded = true;
                  } else {
                    _backUploaded = true;
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _removeImage(bool isFront) {
    setState(() {
      if (isFront) {
        _frontUploaded = false;
        _clearFields(isFront);
      } else {
        _backUploaded = false;
        _clearFields(isFront);
      }
    });
  }

  Future<void> _pickIDCard(ImageSource source, {bool isFront = true}) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile == null) return;
    final appDir = await getApplicationDocumentsDirectory();
    final fileName =
        '${isFront ? 'front' : 'back'}_id_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedImage =
        await File(pickedFile.path).copy('${appDir.path}/$fileName');
    await File(pickedFile.path).copy(savedImage.path);

    // Open the scanner for the selected image

    setState(() {
      if (isFront) {
        _frontImage = savedImage;
        _frontIdPath = savedImage.path;
      } else {
        _backImage = savedImage;
        _backIdPath = savedImage.path;
      }
    });

    setState(() {
      if (isFront) {
        _frontImage = File(pickedFile.path);
        _isProcessingFront = true;
      } else {
        _backImage = File(pickedFile.path);
        _isProcessingBack = true;
      }
    });

    await _processImage(File(pickedFile.path), isFront: isFront);
    // await uploadAndCompareFaces();
  }

  Future<void> savePassportDigitalImageToResultPage(
      Map<String, dynamic> data) async {
    final isJpeg = data['dg2']["isJpeg"];
    final base64Photo = data['dg2']["photo"];

    if (!isJpeg) {
      final base64String = await convertToJpeg(base64Photo);
      final image = await base64ToFile(base64String);
      ResultPage.imagePath = image.path;
    }else{
      final image = await base64ToFile(base64Photo);
      ResultPage.imagePath = image.path;
    }
  }

  Future<void> _processImage(File image, {required bool isFront}) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final inputImage = InputImage.fromFilePath(image.path);

    try {



      final recognizedText = await textRecognizer.processImage(inputImage);
      _ocrText = _normalizeText(recognizedText.text);

      if (isFront) {
        await _verificationFront(_ocrText);
        if (_isVerified) {
          _batchFrontExtraction();
          _autoFillForm();

          // Handle image cropping with safe context
          final croppedFile = await autoCropIdPhoto(image);
          if (croppedFile != null) {
            setState(() => _extractedPhoto = croppedFile);
          }
        } else {
          _showCustomDialog(
            title: "ID Card not valid",
            message: "Make sure you upload a valid id card.",
            icon: Icons.cancel_presentation_rounded,
            iconColor: Colors.orange,
          );
        }
      } else {
        await _verificationBack(_ocrText);
        if (_isVerified) {
          _processBackOCR(recognizedText.text);
          _autoFillForm();
        } else {
          _showCustomDialog(
            title: "ID Card not valid",
            message: "Make sure you upload a valid id card.",
            icon: Icons.cancel_presentation_rounded,
            iconColor: Colors.orange,
          );
        }
      }
    } catch (e) {
      setState(() => _processingError = 'OCR failed: ${e.toString()}');
    } finally {
      textRecognizer.close();
      setState(() {
        if (isFront) {
          _isProcessingFront = false;
        } else {
          _isProcessingBack = false;
        }
      });
    }
  }

  void _processBackOCR(String text) {
    // Extract nom and prenom from back
    setState(() {
      _extractEndDate();
      _extractBirthdate();
      _extractBackCardNumber(text);
      _extractedNom = _extractNom(text);
      _extractedPrenom = _extractPrenom(text);
    });
  }

  void _batchFrontExtraction() {
    try {
      _extractNIN();

      _extractCardnumber();
    } catch (e) {
      setState(
          () => _processingError = 'Data extraction error: ${e.toString()}');
    }
  }

  Future<File?> autoCropIdPhoto(File originalImage) async {
    try {
      // Step 1: Load the image
      final bytes = await originalImage.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      // Step 2: Initialize the face detector
      final options = FaceDetectorOptions(
        performanceMode:
            FaceDetectorMode.accurate, // Use accurate mode for better detection
        enableContours: false, // No contours needed
        enableClassification: false, // No classifications needed
      );
      final faceDetector = FaceDetector(options: options);

      // Step 3: Detect faces
      final inputImage = InputImage.fromFilePath(originalImage.path);
      final faces = await faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        debugPrint('No face detected in the image.');
        return null;
      }

      // Step 4: Get the largest face (most prominent)
      final face = faces
          .reduce((a, b) => a.boundingBox.width > b.boundingBox.width ? a : b);

      // Step 5: Calculate crop area with padding
      const padding = 0.3; // 30% padding around the face
      final rect = face.boundingBox;
      final expandedRect = Rect.fromLTWH(
        rect.left - rect.width * padding,
        rect.top - rect.height * padding,
        rect.width * (1 + 2 * padding),
        rect.height * (1 + 2 * padding),
      );

      // Step 6: Crop the image
      final cropped = img.copyCrop(
        image,
        x: expandedRect.left.toInt(),
        y: expandedRect.top.toInt(),
        width: expandedRect.width.toInt(),
        height: expandedRect.height.toInt(),
      );

      // Step 7: Save the cropped image
      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/cropped_face_${DateTime.now().millisecondsSinceEpoch}.jpg';
      return File(path)..writeAsBytesSync(img.encodeJpg(cropped));
    } catch (e) {
      debugPrint('Face detection and cropping failed: $e');
      return null;
    } finally {
      // Close the face detector
    }
  }

  void _extractNIN() {
    String? nin;

    final cleanText = _ocrText.replaceAll('\n', ' ').toLowerCase();

    // Match either:
    // 1. 18 digits with optional single spaces between them
    // 2. Or 18 consecutive digits
    final regex = RegExp(r'\b(?:\d\s?){18}\b');

    const keywords = [
      'رقم التعريف الوطني',
      'الوطني التعريف رقم',
      'national identification number',
      'nin'
    ];

    for (final keyword in keywords) {
      final index = cleanText.indexOf(keyword);
      if (index != -1) {
        final afterKeyword = cleanText.substring(index, index + 100);
        final match = regex.firstMatch(afterKeyword);
        if (match != null) {
          // Remove spaces to store only digits
          nin = match.group(0)?.replaceAll(' ', '');
          break;
        }
      }
    }

    // Fallback search
    if (nin == null) {
      final match = regex.firstMatch(cleanText);
      if (match != null) {
        nin = match.group(0)?.replaceAll(' ', '');
      }
    }

    setState(() => _extractedNIN = nin ?? '');

    if (_extractedNIN.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('NIN not found. Try a clearer image.')),
      );
      debugPrint('OCR Text:\n$_ocrText');
    } else {
      debugPrint('Extracted NIN: $_extractedNIN');
    }
  }

  void _extractBirthdate() {
    String? birthdate;

    debugPrint('Extracted OCR Text:\n$_ocrText');

    // Normalize OCR text: remove newlines, lowercase
    final text = _ocrText.replaceAll('\n', ' ').toLowerCase();

    // Match 6 digits with possible spaces before m or f
    final match = RegExp(r'([\d\s]{6,10})\s*[mf]').firstMatch(text);

    if (match != null) {
      // Extract matched group and remove all spaces
      final rawDigits = match.group(1)?.replaceAll(RegExp(r'\s+'), '');
      if (rawDigits != null && rawDigits.length >= 6) {
        final digits =
            rawDigits.substring(0, 6); // Take only the first 6 digits
        setState(() {
          mrzData['dob'] = digits;
        });
        birthdate = _formatDate(digits);
        debugPrint('Extracted Birthdate: $birthdate');
      }
    }

    // Update UI state
    setState(() => _extractedBirthdate = birthdate ?? '');

    if (_extractedBirthdate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Birthdate not found. Try a better quality image')),
      );
      debugPrint('Birthdate NOT FOUND!');
    }
  }

  void _extractEndDate() {
    String? endDate;

    debugPrint('Extracted OCR Text:\n$_ocrText');

    // Normalize OCR text: remove newlines, lowercase
    final text = _ocrText.replaceAll('\n', ' ').toLowerCase();

    // Match: 'm' or 'f' followed by any number of spaces, then digits with optional spaces
    final match = RegExp(r'[mf]\s*((?:\d\s*){6,})').firstMatch(text);

    if (match != null) {
      // Extract matched digits and remove spaces
      final rawDigits = match.group(1)?.replaceAll(RegExp(r'\s+'), '');
      if (rawDigits != null && rawDigits.length >= 6) {
        final digits = rawDigits.substring(0, 6); // First 6 digits
        setState(() {
          mrzData['doe'] = digits;
        });
        endDate = _formatDate(digits);
        debugPrint('Extracted Expiry Date: $endDate');
      }
    }

    // Update UI state
    setState(() => _extractedendDate = endDate ?? '');

    if (_extractedendDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Expiry Date not found. Try a better quality image')),
      );
      debugPrint('Expiry Date NOT FOUND!');
    }
  }

  /** Converts YYMMDD to DD.MM.YYYY */
  String _formatDate(String yyMMdd) {
    int year = int.parse(yyMMdd.substring(0, 2));
    String month = yyMMdd.substring(2, 4);
    String day = yyMMdd.substring(4, 6);

    // Handle 20th & 21st century correction
    int fullYear = (year > 50) ? (1900 + year) : (2000 + year);

    return '$day.$month.$fullYear';
  }

  void _extractBackCardNumber(String input) {
    // Remove all spaces from the input
    String cleanInput = input.replaceAll(' ', '');

    // Regular expression to find 9 digits after 'IDDZA'
    RegExp regex = RegExp(r'IDDZA(\d{9})');

    // Search for a match
    Match? match = regex.firstMatch(cleanInput);

    if (match != null) {
      _backCardNumber = match.group(1);
      print('Back card number: $_backCardNumber');
    } else {
      _backCardNumber = null;
      print('Card number not found.');
    }
  }

  void _extractCardnumber() {
    String? cnumber;

    // Normalize OCR text (remove line breaks, lowercase for consistency)
    final text = _ocrText.replaceAll('\n', ' ').toLowerCase();

    // Pattern 1: Keyword-based extraction
    const keywords = ['بطاقة التعريف الوطنية'];

    for (final keyword in keywords) {
      final index = text.indexOf(keyword);
      if (index != -1) {
        final textAfter = text.substring(index + keyword.length);

        // Match 9 digits even if they contain spaces (e.g. 1 2 3 4 5 6 7 8 9)
        final match = RegExp(r'([\d\s]{9,15})').firstMatch(textAfter);
        if (match != null) {
          final rawDigits = match.group(1)?.replaceAll(RegExp(r'\s+'), '');
          if (rawDigits != null && rawDigits.length == 9) {
            cnumber = rawDigits;
            break;
          }
        }
      }
    }

    // Pattern 2: Standalone 9-digit number with optional spaces
    if (cnumber == null) {
      final matches = RegExp(r'[\d\s]{9,15}').allMatches(text);
      for (final match in matches) {
        final rawDigits = match.group(0)?.replaceAll(RegExp(r'\s+'), '');
        if (rawDigits != null && rawDigits.length == 9) {
          cnumber = rawDigits;
          break;
        }
      }
    }

    setState(() => _extractedCardnumber = cnumber ?? '');
    setState(() {
      mrzData['docNumber'] = _extractedCardnumber;
    });
    _frontCardNumber = cnumber;

    if (_extractedCardnumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Card number not found. Try better quality image')),
      );
      debugPrint('OCR Text:\n$_ocrText'); // For debugging
    }
  }

  String _extractNom(String text) {
    final lines = text.split('\n');
    for (var line in lines) {
      final lowerLine = line.toLowerCase();
      if (lowerLine.startsWith('nom')) {
        // Match both "nom:" and "nom", remove "nom", "nom:", and trim
        return line
            .replaceFirst(RegExp(r'^nom[:]?\s*', caseSensitive: false), '')
            .trim();
      }
    }
    return '';
  }

  String _extractPrenom(String text) {
    final lines = text.split('\n');
    for (var line in lines) {
      final lowerLine = line.toLowerCase();
      if (lowerLine.startsWith('prénom(s)')) {
        // Match both "prénom(s):" and "prénom(s)", remove the prefix, then trim
        return line
            .replaceFirst(
                RegExp(r'^prénom\(s\)[:]?\s*', caseSensitive: false), '')
            .trim();
      }
    }
    return '';
  }

  String _normalizeText(String text) {
    // Clean text for better processing
    return text
        .replaceAll(RegExp(r'\s+'), ' ') // Collapse whitespace
        .replaceAll(RegExp(r'[٫,_-]'), '') // Remove common separators
        .toLowerCase();
  }

  Future<void> _takeSelfie() async {
    final XFile? imageFile = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front, // 👈 Use front camera
    );

    if (imageFile == null) return;

    File image = File(imageFile.path);
    final face = await _detectFace(image);

    if (face != null) {
      final croppedFace = await _cropFace(image, face);
      if (croppedFace != null) {
        setState(() => _selfiePath = croppedFace.path);
        ResultPage.selfiePath = croppedFace.path;
      }
    }else{
      return;
    }

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
    final result = await _startScan();
    // await uploadAndCompareFaces();
  }

  Future<Face?> _detectFace(File imageFile) async {
    final InputImage inputImage = InputImage.fromFile(imageFile);
    final faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableClassification: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );

    final List<Face> faces = await faceDetector.processImage(inputImage);
    await faceDetector.close();

    if (faces.isEmpty) {
      _showCustomDialog(
        title: "No face detected",
        message: "Make sure your face is clearly visible and well lit.",
        icon: Icons.visibility_off,
        iconColor: Colors.red,
      );
      return null;
    }

    // if (faces.length != 1) {
    //   _showCustomDialog(
    //     title: "Multiple faces detected",
    //     message: "Make sure you are alone in the frame.",
    //     icon: Icons.people_outline,
    //     iconColor: Colors.orange,
    //   );
    //   return null;
    // }

    Face face = faces.first;

    if (face.leftEyeOpenProbability != null &&
        face.rightEyeOpenProbability != null) {
      if (face.leftEyeOpenProbability! < 0.3 &&
          face.rightEyeOpenProbability! < 0.3) {
        _showCustomDialog(
          title: "Closed eyes",
          message: "Make sur your eyes are opened and retry",
          icon: Icons.remove_red_eye,
          iconColor: Colors.deepOrange,
        );
        return null;
      }
    }

    if (face.headEulerAngleY != null && (face.headEulerAngleY!.abs() > 10)) {
      _showCustomDialog(
        title: "Head not aligned",
        message: "Keep your head straight and look at the camera.",
        icon: Icons.screen_rotation_alt,
        iconColor: Colors.amber,
      );
      return null;
    }

    if (face.headEulerAngleZ != null && (face.headEulerAngleZ!.abs() > 10)) {
      _showCustomDialog(
        title: "Tilt detected",
        message: "Avoid tilting your head.",
        icon: Icons.rotate_90_degrees_ccw,
        iconColor: Colors.amber,
      );
      return null;
    }

    return face;
  }

  Future<File?> _cropFace(File imageFile, Face face) async {
    Uint8List imageBytes = await imageFile.readAsBytes();
    img.Image? originalImage = img.decodeImage(imageBytes);

    if (originalImage == null) return null;

    final rect = face.boundingBox;

    // Define padding percentage (adjust as needed)
    double paddingFactor = 0.4; // 40% larger area around face

    // Calculate new dimensions with padding
    int newX = (rect.left - rect.width * paddingFactor)
        .toInt()
        .clamp(0, originalImage.width);
    int newY = (rect.top - rect.height * paddingFactor)
        .toInt()
        .clamp(0, originalImage.height);
    int newWidth = (rect.width * (1 + 2 * paddingFactor))
        .toInt()
        .clamp(0, originalImage.width - newX);
    int newHeight = (rect.height * (1 + 2 * paddingFactor))
        .toInt()
        .clamp(0, originalImage.height - newY);

    // Crop the image with adjusted dimensions
    img.Image cropped = img.copyResize(
      img.copyCrop(originalImage,
          x: newX, y: newY, width: newWidth, height: newHeight),
      width: 300, // Resize to fixed dimensions
      height: 300,
    );

    // Save cropped image
    final croppedFile = File(imageFile.path.replaceAll('.jpg', '_cropped.jpg'))
      ..writeAsBytesSync(img.encodeJpg(cropped));
    return croppedFile;
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Error"),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("OK"))
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _birthDate) {
      setState(() {
        _birthDate = picked;
        _birthDateController.text = DateFormat('yyyy.MM.dd').format(picked);
        _formData['birthDate'] = _birthDateController.text;
      });
    }
  }

  // Future<void> uploadAndCompareFaces() async {
  //   try {
  //     if (_frontIdPath == null || _selfiePath == null) {
  //       print("Please upload both images.");
  //       return;
  //     }
  //
  //     // Create a multipart request for the face comparison
  //     var comparisonRequest = http.MultipartRequest(
  //       'POST',
  //       Uri.parse(
  //           'http://105.96.12.227:8000/compare-faces'), // FastAPI endpoint
  //     );
  //
  //     // Add files for comparison
  //     comparisonRequest.files.add(await http.MultipartFile.fromPath(
  //         'idCardFace', _extractedPhoto!.path));
  //     comparisonRequest.files
  //         .add(await http.MultipartFile.fromPath('selfie', _selfiePath!));
  //
  //     // Send the request
  //     var comparisonResponse =
  //         await comparisonRequest.send().timeout(Duration(seconds: 120));
  //     final comparisonRespStr = await comparisonResponse.stream.bytesToString();
  //     final comparisonResponseData = jsonDecode(comparisonRespStr);
  //
  //     if (comparisonResponse.statusCode != 200) {
  //       setState(() {
  //         _comparisonResult =
  //             'Erreur: ${comparisonResponseData['error'] ?? 'Unknown error'}';
  //       });
  //       return;
  //     }
  //
  //     final String message = comparisonResponseData['message'] ?? 'No message';
  //     final bool isVerified = comparisonResponseData['verified'] ?? false;
  //
  //     setState(() {
  //       _comparisonResult = message;
  //     });
  //   } catch (e) {
  //     print('Error during face comparison: $e');
  //     setState(() {
  //       _comparisonResult = 'Erreur lors de la comparaison: ${e.toString()}';
  //     });
  //   }
  // }

  // Method for submitting the form
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_frontIdPath == null ||
        _selfiePath == null ||
        _extractedPhoto == null) {
      _showCustomSnackbar('Please upload all images');
      return;
    }

    if (_comparisonResult.contains('do not match')) {
      _showCustomSnackbar('Error: Faces do not match');
      return;
    }

    if (_frontCardNumber != null &&
        _backCardNumber != null &&
        _frontCardNumber != _backCardNumber) {
      _showCustomDialog(
        title: "Error Detected",
        message: "Front and Back are not from the same",
        icon: Icons.error,
        iconColor: Colors.red,
      );
      return;
    }

    // try {
    //   final expiry = DateFormat('dd.MM.yyyy').parse(_extractedendDate);
    //   if (expiry.isBefore(DateTime.now())) {
    //     _showCustomSnackbar('Card expired. Please use a valid card.');
    //     return;
    //   }
    // } catch (e) {
    //   _showCustomSnackbar("Invalid Expiry Date");
    //   return;
    // }

    setState(() => _isProcessing = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://105.96.12.227:5000/save-id-card'),
      );

      request.fields.addAll({
        'family_name': _nomController.text,
        'given_name': _prenomController.text,
        'identity_number': _ninController.text,
        'card_number': _cnumberController.text,
        'birthdate': _birthDateController.text,
        'expiryDate': _enddateController.text,
        'document_type': 'ID Card',
      });

      request.files
          .add(await http.MultipartFile.fromPath('idCardFront', _frontIdPath!));
      request.files.add(await http.MultipartFile.fromPath(
          'idCardFace', _extractedPhoto!.path));
      request.files
          .add(await http.MultipartFile.fromPath('selfie', _selfiePath!));

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      var response = await request.send();
      final respStr = await response.stream.bytesToString();
      final responseData = jsonDecode(respStr);
      Navigator.pop(context);

      if (response.statusCode == 200 && responseData['success'] == true) {
        _showCustomSnackbar('Registration successful!', success: true);
      } else if (response.statusCode == 400) {
        if (responseData['message'].contains('already exists')) {
          _showCustomDialog(
            title: "Duplicate detected",
            message:
                "This identity number already exist for: ${_formData['document_type']}",
            icon: Icons.warning,
            iconColor: Colors.orange,
          );
        } else {
          _showCustomSnackbar('Error: ${responseData['message']}');
        }
      } else {
        _showCustomSnackbar('Uknown Error: $respStr');
      }
    } catch (e) {
      Navigator.pop(context);
      _showCustomSnackbar('Network Error: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showCustomSnackbar(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(success ? Icons.check_circle : Icons.error,
                color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showCustomDialog({
    required String title,
    required String message,
    IconData icon = Icons.info,
    Color iconColor = Colors.blue,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _autoFillForm() {
    setState(() {
      _nomController.text = _extractedNom;
      _prenomController.text = _extractedPrenom;
      _ninController.text = _extractedNIN;
      _cnumberController.text = _extractedCardnumber;
      _birthDateController.text = _extractedBirthdate;
      _enddateController.text = _extractedendDate;
    });
  }

  void _clearFields(bool isFront) {
    if (isFront) {
      _cnumberController.clear();
      _ninController.clear();
    } else {
      _nomController.clear();
      _prenomController.clear();
      _birthDateController.clear();
      _enddateController.clear();
    }
  }

  bool get _isFrontDataFilled =>
      _cnumberController.text.isNotEmpty || _ninController.text.isNotEmpty;

  bool get _isBackDataFilled =>
      _nomController.text.isNotEmpty ||
      _prenomController.text.isNotEmpty ||
      _birthDateController.text.isNotEmpty ||
      _enddateController.text.isNotEmpty;

// ✅ Version sans carte : formulaire directement dans l'espace blanc entre les vagues

// 🌌 Nouveau design inspiré de la maquette fournie : fond violet dégradé + champs sombres ajustés
  Widget build(BuildContext context) {
    final allFieldsFilled = _nomController.text.isNotEmpty &&
        _prenomController.text.isNotEmpty &&
        _ninController.text.isNotEmpty &&
        _cnumberController.text.isNotEmpty &&
        _birthDateController.text.isNotEmpty &&
        _enddateController.text.isNotEmpty &&
        _frontUploaded &&
        _backUploaded &&
        _selfiePath != null &&
        _comparisonResult.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 50, bottom: 30),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF155970), Color(0xFF2A0A3D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
                child: Column(
                  children: [
                    Image.asset('assets/images/logo.png', height: 80),
                    const SizedBox(height: 12),
                    const Text(
                      'Verify your identity with',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'ID Card',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // _buildTextField(_nomController, 'Family name',
                          //     required: true),
                          // _buildTextField(_prenomController, 'Given name',
                          //     required: true),
                          // _buildTextField(
                          //   _ninController,
                          //   'Identity number',
                          //   required: true,
                          //   keyboardType: TextInputType.number,
                          //   inputFormatters: [
                          //     LengthLimitingTextInputFormatter(18),
                          //     FilteringTextInputFormatter.digitsOnly
                          //   ],
                          // ),
                          // _buildTextField(
                          //   _cnumberController,
                          //   'Card number',
                          //   required: true,
                          //   inputFormatters: [
                          //     LengthLimitingTextInputFormatter(9)
                          //   ],
                          // ),
                          // _buildTextField(
                          //   _birthDateController,
                          //   'Birthdate',
                          //   required: true,
                          //   onTap: () => _selectDate(context),
                          // ),
                          // _buildTextField(
                          //   _enddateController,
                          //   'Expiry Date',
                          //   required: true,
                          //   onTap: () => _selectDate(context),
                          // ),
                          const SizedBox(height: 30),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildUploadCard(
                                  'Front Side',
                                  'assets/images/idcard.png',
                                  true,
                                  _frontUploaded,
                                  _isFrontDataFilled),
                              _buildUploadCard(
                                  'Back Side',
                                  'assets/images/backidcard.png',
                                  false,
                                  _backUploaded,
                                  _isBackDataFilled),
                            ],
                          ),
                          const SizedBox(height: 30),
                          Center(
                            child: _buildUploadIcon(
                              "Selfie",
                              _selfiePath != null,
                              _takeSelfie,
                              // 👈 this should be your actual function
                              Icons.camera_alt,
                            ),
                          ),
                          const SizedBox(height: 30),
                          if (_comparisonResult.isNotEmpty)
                            Text(
                              _comparisonResult,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _comparisonResult
                                        .toLowerCase()
                                        .contains('faces match!')
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          const SizedBox(height: 20),
                          Center(
                            child: ElevatedButton(
                              onPressed:
                                  (!allFieldsFilled) ? null : _submitForm,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 60, vertical: 16),
                                backgroundColor: const Color(0xFF155970),
                                disabledBackgroundColor: Colors.grey.shade400,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: const Text('Submit',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          _scanning
              ? Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            color: Colors.black.withOpacity(0.7),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      "Please keep your ID Document close to the back of your phone while reading the NFC chip...",
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          )
              : Container(),


        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    VoidCallback? onTap,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    FormFieldValidator<String>? validator,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: label,
              style: TextStyle(color: Colors.black87, fontSize: 16),
              children: required
                  ? [TextSpan(text: ' *', style: TextStyle(color: Colors.red))]
                  : [],
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            readOnly: onTap != null,
            onTap: onTap,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            validator: validator ??
                (value) =>
                    value == null || value.isEmpty ? 'Required field' : null,
            style: const TextStyle(fontSize: 16),
            // Texte saisi dans le champ
            decoration: InputDecoration(
              hintText: label,
              hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              // Taille placeholder
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadCard(String title, String imagePath, bool isFront,
      bool uploaded, bool showRemove) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Container(
          width: 140,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              imagePath,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => _showImageSourceDialog(context, isFront: isFront),
              child: Text('Upload',
                  style: TextStyle(color: Colors.blue, fontSize: 14)),
            ),
            if (uploaded && showRemove) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _removeImage(isFront),
                child: Text('Remove',
                    style: TextStyle(color: Colors.red, fontSize: 14)),
              ),
            ]
          ],
        ),
      ],
    );
  }

  Widget _buildUploadIcon(
      String label, bool uploaded, VoidCallback onTap, IconData icon) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: uploaded ? Colors.green : const Color(0xFF155970),
            child: Icon(
              icon,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
