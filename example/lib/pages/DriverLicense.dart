import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:flutter_tesseract_ocr/android_ios.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class Driverlicense extends StatefulWidget {
  final String documentType;
  const Driverlicense({Key? key, required this.documentType}) : super(key: key);

  @override
  _DriverlicenseState createState() => _DriverlicenseState();
}

class _DriverlicenseState extends State<Driverlicense> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _prenomController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _ninController = TextEditingController();
  final TextEditingController _cnumberController = TextEditingController();
  final TextEditingController _birthplaceController = TextEditingController();
  final TextEditingController _releasedateController = TextEditingController();
  final TextEditingController _enddateController = TextEditingController();
  final TextEditingController _backnumberController = TextEditingController();

  String? _frontCardNumber;
  String? _backCardNumber;
  File? _frontImage;
  File? _backImage;
  bool _frontUploaded = false;
  bool _backUploaded = false;
  String _extractedBirthPlace = '';
  String _extractedendDate = '';
  String _extractedReleaseDate = '';
  String _extractedNIN = '';
  String _comparisonResult = '';
  String _extractedCardnumber = '';
  String _extractedNom = '';
  String _extractedPrenom = '';
  final bool _isProcessingImage = false;
  String? _processingError;
  String _extractedBirthdate = '';
  final String _extractedBacknumber = '';
  bool _isProcessing = false;
  bool _isProcessingFront = false;
  bool _isProcessingBack = false;
  bool _isVerified = false;
  String _ocrText = '';
  String? _frontIdPath;
  String? _backIdPath;
  String? _selfiePath;
  File? _selfieImage;
  DateTime? _birthDate;
  File? _extractedPhoto;
  Rect? _photoArea;
  List<File> _selfieImages = [];
  final ImagePicker _picker = ImagePicker();

  final Map<String, String> _formData = {
    'family_name': '',
    'given_name': '',
    'identity_number': '',
    'card_number': '',
    'birthDate': '',
    'expiryDate': '',
    'document_type': '',
  };
  @override
  void initState() {
    super.initState();
    _formData['document_type'] = widget.documentType;
  }

  // Helper function to normalize the OCR text

  List<CameraDescription>? _cameras;
  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
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
                _pickDriverlicense(ImageSource.camera, isFront: isFront);

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
                _pickDriverlicense(ImageSource.gallery, isFront: isFront);
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

  Future<void> _pickDriverlicense(ImageSource source,
      {bool isFront = true}) async {
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
        _frontUploaded = true;
      } else {
        _backImage = savedImage;
        _backIdPath = savedImage.path;
        _backUploaded = true;
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
    await uploadAndCompareFaces();
  }

  Future<void> _processImage(File image, {required bool isFront}) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final inputImage = InputImage.fromFilePath(image.path);

    try {
      final recognizedText = await textRecognizer.processImage(inputImage);
      _ocrText = _normalizeText(recognizedText.text);

      if (isFront) {
        // Perform front image verification
        await _verificationFront(_ocrText); // Call verification first
        if (_isVerified) {
          // Proceed with extraction if verified
          _batchFrontExtraction(); // Proceed only if the document is verified
          _autoFillForm();

          // Handle image cropping with safe context
          final croppedFile = await autoCropIdPhoto(image);
          if (croppedFile != null) {
            setState(() => _extractedPhoto = croppedFile);
          }
        } else {
          _showCustomDialog(
            title: "DL Card not valid",
            message: "Make sure you upload a valid driving license card.",
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
            title: "DL Card not valid",
            message: "Make sure you upload a valid driving license card.",
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

  String _normalizeText(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  // Show success or error messages for OCR and document verification

  // Front OCR processing to detect if it's a driving license
  Future<void> _verificationFront(String text) async {
    if (text.toLowerCase().contains('driving')) {
      setState(() {
        _isVerified = true;
      });
    } else {
      setState(() {
        _isVerified = false;
      });
    }
  }

  // Back OCR processing to verify document type based on text
  Future<void> _verificationBack(String text) async {
    if (text.toLowerCase().contains('dldz')) {
      setState(() {
        _isVerified = true;
      });
    } else {
      setState(() {
        _isVerified = false;
      });
    }
  }

  void _processFrontOCR(String text) {}

  void _processBackOCR(String text) {
    // Check if the document is verified as a Driving License

    // Extract nom and prenom from the back if the document is verified
    setState(() {
      _extractEndDate();
      _extractBirthdate();
      _extractBackCardNumber(text);
      _extractedNom = _extractFamilyName(text);
      _extractedPrenom = _extractGivenName(text);
    });
  }

  void _batchFrontExtraction() {
    // Check if the document is verified as a Driving License

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

  String _extractFamilyName(String text) {
    // Match all letters and optional spaces before the first '<<'
    final familyMatch = RegExp(r'([a-zA-Z\s]+)<<\s*[a-zA-Z]').firstMatch(text);

    if (familyMatch != null) {
      // Remove spaces and return the result
      return familyMatch.group(1)!.replaceAll(RegExp(r'\s+'), '');
    }
    return '';
  }

String _extractGivenName(String text) {
  // Match given names after the first '<<' and before the next '<<'
  final match = RegExp(r'<<([A-Z<]+)<<*$', caseSensitive: false).firstMatch(text);
  if (match != null) {
    return match.group(1)!
        .replaceAll('<', ' ')
        .replaceAll(RegExp(r'[^A-Z\s]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toUpperCase();
  }
  return '';
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

    // Match pattern: m or f followed by up to 10 characters containing digits and spaces
    final match = RegExp(r'[mf]\s*([\d\s]{6,10})').firstMatch(text);

    if (match != null) {
      // Extract matched group and remove spaces
      final rawDigits = match.group(1)?.replaceAll(RegExp(r'\s+'), '');
      if (rawDigits != null && rawDigits.length >= 6) {
        final digits = rawDigits.substring(0, 6); // Take the first 6 digits
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

    // Regular expression to find 9 alphanumeric characters after 'IDDZA'
    RegExp regex = RegExp(r'DLDZA([A-Z0-9]{9})', caseSensitive: false);

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

    // Pattern 1: Direct keyword match
    const keywords = ['بطاقة التعريف الوطنية'];

    // Search for keyword patterns
    for (final keyword in keywords) {
      final index = _ocrText.indexOf(keyword);
      if (index != -1) {
        final textAfter = _ocrText.substring(index + keyword.length);
        final match = RegExp(r'\b[A-Za-z0-9]{9}\b').firstMatch(textAfter);
        if (match != null) {
          cnumber = match.group(0);
          break;
        }
      }
    }

    // Pattern 2: Standalone 9-character alphanumeric (fallback)
    if (cnumber == null) {
      final matches = RegExp(r'\b[A-Za-z0-9]{9}\b').allMatches(_ocrText);
      if (matches.isNotEmpty) {
        cnumber = matches.first.group(0);
      }
    }

    setState(() => _extractedCardnumber = cnumber ?? '');
    _frontCardNumber = cnumber;

    if (_extractedCardnumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Card number not found. Try better quality image')),
      );
      debugPrint('OCR Text:\n$_ocrText'); // For debugging
    }
  }

  Future<void> _takeSelfie() async {
    final XFile? imageFile =
        await _picker.pickImage(source: ImageSource.camera);
    if (imageFile == null) return;

    File image = File(imageFile.path);
    final face = await _detectFace(image);

    if (face != null) {
      final croppedFace = await _cropFace(image, face);
      if (croppedFace != null) {
        setState(() => _selfiePath = croppedFace.path);
      }
    }
    await uploadAndCompareFaces();
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

    if (faces.length != 1) {
      _showCustomDialog(
        title: "Multiple faces detected",
        message: "Make sure you are alone in the frame.",
        icon: Icons.people_outline,
        iconColor: Colors.orange,
      );
      return null;
    }

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

  Future<void> uploadAndCompareFaces() async {
    try {
      if (_frontIdPath == null || _selfiePath == null) {
        print("Please upload both images.");
        return;
      }

      // Create a multipart request for the face comparison
      var comparisonRequest = http.MultipartRequest(
        'POST',
        Uri.parse('http://105.96.12.227:8000/compare-faces'), // FastAPI endpoint
      );

      // Add files for comparison
      comparisonRequest.files.add(await http.MultipartFile.fromPath(
          'idCardFace', _extractedPhoto!.path));
      comparisonRequest.files
          .add(await http.MultipartFile.fromPath('selfie', _selfiePath!));

      // Send the request
      var comparisonResponse = await comparisonRequest.send();
      final comparisonRespStr = await comparisonResponse.stream.bytesToString();
      final comparisonResponseData = jsonDecode(comparisonRespStr);

      if (comparisonResponse.statusCode != 200) {
        setState(() {
          _comparisonResult =
              'Erreur: ${comparisonResponseData['error'] ?? 'Unknown error'}';
        });
        return;
      }

      final String message = comparisonResponseData['message'] ?? 'No message';
      final bool isVerified = comparisonResponseData['verified'] ?? false;

      setState(() {
        _comparisonResult = message;
      });
    } catch (e) {
      print('Error during face comparison: $e');
      setState(() {
        _comparisonResult = 'Error while comparing: ${e.toString()}';
      });
    }
  }

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
      _showCustomSnackbar('Error: Front and back are from different cards');
      return;
    }

    try {
      final expiry = DateFormat('dd.MM.yyyy').parse(_extractedendDate);
      if (expiry.isBefore(DateTime.now())) {
        _showCustomSnackbar('Card expired. Please use a valid card.');
        return;
      }
    } catch (e) {
      _showCustomSnackbar("Invalid Expiry Date");
      return;
    }

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
        'document_type': 'Driving License',
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

  bool get _isFrontDataFilled =>
      _cnumberController.text.isNotEmpty || _ninController.text.isNotEmpty;

  bool get _isBackDataFilled =>
      _nomController.text.isNotEmpty ||
      _prenomController.text.isNotEmpty ||
      _birthDateController.text.isNotEmpty ||
      _enddateController.text.isNotEmpty;

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
      body: Column(
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
                  'Driving License',
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
                      _buildTextField(_nomController, 'Family name',
                          required: true),
                      _buildTextField(_prenomController, 'Given name',
                          required: true),
                      _buildTextField(
                        _ninController,
                        'Identity number',
                        required: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(18),
                          FilteringTextInputFormatter.digitsOnly
                        ],
                      ),
                      _buildTextField(
                        _cnumberController,
                        'Card number',
                        required: true,
                        inputFormatters: [LengthLimitingTextInputFormatter(9)],
                      ),
                      _buildTextField(
                        _birthDateController,
                        'Birthdate',
                        required: true,
                        onTap: () => _selectDate(context),
                      ),
                      _buildTextField(
                        _enddateController,
                        'Expiry Date',
                        required: true,
                        onTap: () => _selectDate(context),
                      ),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildUploadCard(
                              'Front Side',
                              'assets/images/drivinglicense.png',
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
                          _takeSelfie, // 👈 this should be your actual function
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
                          onPressed: (!allFieldsFilled) ? null : _submitForm,
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
            style: const TextStyle(fontSize: 16), // Texte saisi dans le champ
            decoration: InputDecoration(
              hintText: label,
              hintStyle: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600), // Taille placeholder
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
