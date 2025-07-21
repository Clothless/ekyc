import 'package:flutter/material.dart';
import 'package:flutter_mrz_scanner/flutter_mrz_scanner.dart';
import 'package:mrz_parser/mrz_parser.dart';

class MRZScannerScreen extends StatefulWidget {
  const MRZScannerScreen({super.key});

  @override
  State<MRZScannerScreen> createState() => _MRZScannerScreenState();
}

class _MRZScannerScreenState extends State<MRZScannerScreen> {
  bool isScanning = false;
  MRZResult? mrzResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan MRZ'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isScanning)
              SizedBox(
                height: 300,
                child: MRZScanner(
                  withOverlay: true,
                  onControllerCreated: (controller) {
                    controller.onParsed = (mrzResult) {
                      setState(() {
                        this.mrzResult = mrzResult;
                        isScanning = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('MRZ Scanned Successfully!')),
                      );
                    };
                  },
                ),
              )
            else
              ElevatedButton(
                onPressed: () => setState(() => isScanning = true),
                child: const Text('Start Scanning'),
              ),
            const SizedBox(height: 20),
            if (mrzResult != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Scan Result:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Document Type: ${mrzResult!.documentType}'),
                      Text('Country Code: ${mrzResult!.countryCode}'),
                      Text('Given Names: ${mrzResult!.givenNames}'),
                      Text('Surnames: ${mrzResult!.surnames}'),
                      Text('Document Number: ${mrzResult!.documentNumber}'),
                      Text('Nationality: ${mrzResult!.nationalityCountryCode}'),
                      Text('Date of Birth: ${mrzResult!.birthDate}'),
                      Text('Sex: ${mrzResult!.sex.name}'),
                      Text('Expiry Date: ${mrzResult!.expiryDate}'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
} 