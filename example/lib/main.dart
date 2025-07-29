import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:ekyc_example/pages/Idcard.dart';
import 'package:ekyc_example/pages/Passport.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';

import 'pages/edit_ocr_result_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Poppins',
        brightness: Brightness.light,
      ),
      home: OnboardingScreen(),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = [
    {
      'title': 'Welcome to eKYC',
      'subtitle': 'Secure and fast verification',
      'animation': 'assets/animation1.json'
    },
    {
      'title': 'Scan Your ID',
      'subtitle': 'Use your camera to scan your ID quickly',
      'animation': 'assets/animation2.json'
    },
    {
      'title': 'Get Verified',
      'subtitle': 'Complete your identity check in seconds',
      'animation': 'assets/animation3.json'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.indigo.shade200,
              Colors.deepPurple.shade300,
            ],
          ),
        ),
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: _pages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Lottie.asset(_pages[index]['animation']!),
                      const SizedBox(height: 30),
                      Text(
                        _pages[index]['title']!,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _pages[index]['subtitle']!,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => WelcomePage()));
                    },
                    child: Text(
                      "Skip",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? Colors.white
                              : Colors.white54,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      if (_currentPage == _pages.length - 1) {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => WelcomePage()));
                      } else {
                        _controller.nextPage(
                            duration: Duration(milliseconds: 300),
                            curve: Curves.easeIn);
                      }
                    },
                    child: Text(
                      _currentPage == _pages.length - 1 ? "Done" : "Next",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WelcomePage extends StatelessWidget {
  void _onScanIDCard(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Idcard(documentType: "ID Card",)),
    );
  }

  void _onScanPassport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Passport(documentType: "Passport",)),
    );
  }

  void _onOCROnly(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => OCRScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.indigo.shade50],
          ),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset('assets/verification.json', height: 180),
            SizedBox(height: 30),
            Text(
              "Choose Verification Method",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              icon: Icon(Icons.camera_alt),
              label: Text("Scan ID Card"),
              onPressed: () => _onScanIDCard(context),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              icon: Icon(Icons.book),
              label: Text("Scan Passport"),
              onPressed: () => _onScanPassport(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
            SizedBox(height: 24),
            Divider(height: 1, thickness: 1, color: Colors.grey.shade300),
            SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(Icons.text_snippet),
              label: Text("OCR only"),
              onPressed: () => _onOCROnly(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OCRScreen extends StatefulWidget {
  @override
  State<OCRScreen> createState() => _OCRScreenState();
}

class _OCRScreenState extends State<OCRScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _loading = false;

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      await _sendToServer(imageFile);
    }
  }

  Future<void> _sendToServer(File image) async {
    setState(() => _loading = true);

    final request = http.MultipartRequest('POST',
        Uri.parse('http://105.96.12.227:8000/extract-text-algerian-id'));
    request.files
        .add(await http.MultipartFile.fromPath('image', image.path));

    var response = await request.send();
    final respStr = await response.stream.bytesToString();
    final responseData = jsonDecode(respStr);

    if (response.statusCode == 200) {

      // if (data.values.any((value) => value == '' && value != data['rawText'])) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(content: Text("Incomplete data, please try again.")),
      //   );
      //   setState(() => _loading = false);
      //   return;
      // }

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EditOCRResultScreen(data: responseData)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to extract text.")),
      );
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("OCR Scanner")),
      body: Center(
        child: _loading
            ? CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => _pickImage(ImageSource.camera),
                    child: Text("Take Picture"),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    child: Text("Choose from Gallery"),
                  ),
                ],
              ),
      ),
    );
  }
}


