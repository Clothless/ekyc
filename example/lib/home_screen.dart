import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:ekyc/ekyc.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _result;
  bool _scanning = false;
  Timer? _timeoutTimer;
  bool _timeout = false;

  @override
  void initState() {
    super.initState();
    Ekyc.setOnPassportReadListener((passportData) {
      _timeoutTimer?.cancel();
      setState(() {
        _result = passportData;
        _scanning = false;
        _timeout = false;
      });
    });
  }

  void _startScan() {
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

    _startKyc();;
  }


  Future<void> _startKyc() async {
    try {
      debugPrint('eKYC: Starting flow');
      final result = await Ekyc().startKycFlow(context: context);
      debugPrint('eKYC: Flow returned: $result');
    } catch (e) {
      debugPrint('eKYC: Error: $e');
      if (!mounted) return;
    }
  }

  Widget _buildPhoto() {
    final photo = _result?["photo"];
    if (photo != null && photo.isNotEmpty) {
      return Column(
        children: [
          Container(
            width: 160,
            height: 200,
            // decoration: BoxDecoration(
            //   shape: BoxShape.circle,
            //   border: Border.all(color: Colors.grey, width: 2),
            // ),
            child: Image.memory(Uint8List.fromList(base64Decode(_result!["photo"])), fit: BoxFit.cover,),
          ),

        ],
      );
    }
    return const CircleAvatar(
      radius: 60,
      backgroundColor: Colors.grey,
      child: Icon(Icons.person, size: 50),
    );
  }

  Widget _buildScanButton() {
    return ElevatedButton.icon(
      onPressed: _startScan,
      icon: const Icon(Icons.nfc),
      label: const Text("Start NFC Scan"),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontSize: 16),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text("Waiting for NFC..."),
      ],
    );
  }

  Widget _buildResultCard(String label, dynamic value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(label),
        subtitle: Text(value?.toString() ?? "Unknown"),
      ),
    );
  }

  Widget _buildResultDetails() {
    if (_result == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPhoto(),
        const SizedBox(height: 20),
        _buildResultCard("First Name", _result!["firstName"]),
        _buildResultCard("Last Name", _result!["lastName"]),
        _buildResultCard("Date of Birth", _result!["dateOfBirth"]),
        _buildResultCard("Gender", _result!["gender"]),
        _buildResultCard("Nationality", _result!["nationality"]),
        _buildResultCard("Document Number", _result!["documentNumber"]),
        _buildResultCard("Document Code", _result!["documentCode"]),
        _buildResultCard("Document Type", _result!["documentType"]),
        _buildResultCard("Date of Expiry", _result!["dateOfExpiry"]),
        _buildResultCard("Verified", _result!["isVerified"] ? "Yes" : "No"),
        _result!['publicKey'] != null ? Column(
          children: [
            const SizedBox(height: 20,),
            Divider(thickness: 1, color: Colors.grey[300]),
            Text("Security", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            _buildResultCard("Public Key algorithm", _result!["publicKey"]['algorithm']),
            _buildResultCard("Public Key Format", _result!["publicKey"]['format']),
            _buildResultCard("Public key encoded", _result!["publicKey"]['encoded']),
          ],
        ) : Container(),
        (_result!['images'] != null && _result!['images'].isNotEmpty) ? Column(
          children: [
            const SizedBox(height: 20,),
            Divider(thickness: 1, color: Colors.grey[300]),
            Text("Signature", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Image.memory(Uint8List.fromList(base64Decode(_result!["images"][0])), fit: BoxFit.cover,),
          ],
        ) : Container(),
      ],
    );
  }

  Widget _buildTimeoutMessage() {
    return Column(
      children: [
        const Icon(Icons.warning, size: 50, color: Colors.orange),
        const SizedBox(height: 12),
        const Text("NFC read timed out", style: TextStyle(fontSize: 16)),
        const SizedBox(height: 12),
        _buildScanButton(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("eKYC - NFC Passport Reader"),
        centerTitle: true,
      ),
      body: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _scanning
              ? _buildProgressIndicator()
              : _timeout
              ? _buildTimeoutMessage()
              : _result != null
              ? SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildResultDetails(),
          )
              : Center(child: _buildScanButton()),
        ),
      ),
    );
  }
}
