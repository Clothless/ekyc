import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:mrz_parser/mrz_parser.dart' as MrzParser;
import 'package:flutter/foundation.dart';

enum DocumentType { idCard, passport }

class MrzScannerScreen extends StatefulWidget {
  final DocumentType documentType;

  const MrzScannerScreen({
    super.key, 
    required this.documentType,
  });

  @override
  State<MrzScannerScreen> createState() => _MrzScannerScreenState();
}

class _MrzScannerScreenState extends State<MrzScannerScreen> {
  CameraController? _controller;
  late Future<void> _initializeControllerFuture;
  bool _isProcessing = false;
  String? _error;
  String? _rawOcr;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _error = 'No camera found on this device.';
        });
        _showErrorDialog('No camera found on this device.');
        return;
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      _initializeControllerFuture = _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize camera: $e';
      });
      _showErrorDialog('Failed to initialize camera: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _scanFrame() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) return;
    setState(() { _isProcessing = true; _error = null; });
    TextRecognizer? textRecognizer;
    try {
      final file = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(file.path);
      textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final recognizedText = await textRecognizer.processImage(inputImage);
      final mrzLines = _extractMrz(recognizedText.text);
      _rawOcr = recognizedText.text;

      if (mrzLines == null) {
        final docName = widget.documentType == DocumentType.idCard ? 'card' : 'passport';
        final message = 'Could not read the MRZ. Please ensure the ${docName} is well-lit, flat, and the MRZ is fully inside the box.';
        setState(() { _error = message; });
        _showErrorDialog(message);
        return;
      }

      try {
        final result = MrzParser.MRZParser.parse(mrzLines);
        if (result != null) {
          // Pop with the scanned data
          if (mounted) {
            Navigator.of(context).pop({
              'docNumber': result.documentNumber,
              'dob': _formatDate(result.birthDate),
              'doe': _formatDate(result.expiryDate),
            });
          }
        } else {
          throw Exception('MRZParser returned null');
        }
      } catch (e) {
        final docName = widget.documentType == DocumentType.idCard ? 'card' : 'passport';
        final message = 'Could not parse the MRZ. Please ensure the ${docName} is well-lit, flat, and the MRZ is fully inside the box.';
        setState(() { _error = message; });
        _showErrorDialog(message);
      }
    } catch (e) {
      setState(() { _error = 'An error occurred while scanning. Please try again.'; });
      _showErrorDialog('An error occurred while scanning. Please try again.');
    } finally {
      setState(() { _isProcessing = false; });
      try {
        await textRecognizer?.close();
      } catch (_) {}
    }
  }

  List<String>? _extractMrz(String ocrText) {
    final lines = ocrText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    for (var i = 0; i < lines.length; i++) {
        final line = lines[i].replaceAll(' ', '');
        // TD3 format (passports)
        if (line.length == 44 && i + 1 < lines.length) {
            final nextLine = lines[i+1].replaceAll(' ', '');
            if (nextLine.length == 44) {
                return [line, nextLine];
            }
        }
        // TD2 format
        if (line.length == 36 && i + 1 < lines.length) {
            final nextLine = lines[i+1].replaceAll(' ', '');
            if (nextLine.length == 36) {
                return [line, nextLine];
            }
        }
        // TD1 format (credit card size)
        if (line.length == 30 && i + 2 < lines.length) {
            final line2 = lines[i+1].replaceAll(' ', '');
            final line3 = lines[i+2].replaceAll(' ', '');
            if (line2.length == 30 && line3.length == 30) {
                return [line, line2, line3];
            }
        }
    }
    return null;
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString().substring(2);
    return '$y$m$d';
  }

  Future<void> _showErrorDialog(String message) async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan Error'),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
    _dialogOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan MRZ')), 
      body: _controller == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    CameraPreview(_controller!),
                    
                    // Card Guide Box
                    _buildGuideBox(),

                    if (_isProcessing)
                       const Center(child: CircularProgressIndicator()),
                    
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _scanFrame,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Scan Document'),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildGuideBox() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.maxWidth * 0.9;
        final boxHeight = boxWidth / 1.586;
        final isPassport = widget.documentType == DocumentType.passport;
        final label = isPassport
            ? 'Align the bottom of your passport photo page'
            : 'Align the back of your card';

        return Center(
          child: Container(
            width: boxWidth,
            height: boxHeight,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green, width: 2.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                // Sample MRZ Text Overlay
                Positioned(
                  bottom: 10,
                  left: 10,
                  right: 10,
                  child: Column(
                    children: isPassport
                        ? _buildSampleMrzLines(2, 44) // Passport: 2 lines of 44
                        : _buildSampleMrzLines(3, 30), // ID Card: 3 lines of 30
                  ),
                ),
                // Instructional Text
                Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        backgroundColor: Colors.black54),
                  ),
                ),
                Positioned(
                  bottom: 5,
                  left: 0,
                  right: 0,
                  child: Text(
                    'and tap screen to scan',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        backgroundColor: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildSampleMrzLines(int lineCount, int lineLength) {
    final sampleLine = '<' * lineLength;
    return List.generate(
      lineCount,
      (index) => Text(
        sampleLine,
        overflow: TextOverflow.fade,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontFamily: 'monospace',
          color: Colors.green.withOpacity(0.4),
          fontWeight: FontWeight.bold,
          letterSpacing: 2.2,
          fontSize: 14,
        ),
      ),
    );
  }
} 