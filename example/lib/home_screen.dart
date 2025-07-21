import 'package:flutter/material.dart';
import 'nfc_example.dart';
import 'mrz_scanner_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('eKYC Demo'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MRZScannerScreen()),
                );
              },
              child: const Text('Phase 1: Scan MRZ'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NfcExample()),
                );
              },
              child: const Text('Phase 2 & 3: Read NFC Chip'),
            ),
          ],
        ),
      ),
    );
  }
} 