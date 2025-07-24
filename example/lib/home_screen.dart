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
    final photo = _result?['dg2']["photo"];
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
            child: Image.memory(Uint8List.fromList(base64Decode(_result!['dg2']["photo"])), fit: BoxFit.cover,),
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

  String decodeWindows1256(List<int> encodedBytes) {
    // Define the reverse mapping for Windows-1256
    final List<String> windows1256ReverseMap = [
      // ... (mapping of byte values back to characters)
    ];

    StringBuffer decodedString = StringBuffer();

    for (int byte in encodedBytes) {
      // Convert each byte back to its corresponding character
      decodedString.write(windows1256ReverseMap[byte]);
    }

    return decodedString.toString();
  }

  Widget _buildResultDetails() {
    if (_result == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPhoto(),
        const SizedBox(height: 20),
        Text("Pesonal Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        _buildResultCard("Full Name", "${_result!['dg1']["firstName"]} ${_result!['dg1']["lastName"]} \n${_result!["dg11"]['arabicName']}"),
        _buildResultCard("Given names", "${_result!['dg1']["firstName"]}, ${_result!['dg11']["nameOfHolder"]}"),
        _buildResultCard("Name", "${_result!['dg1']["lastName"]}"),
        _buildResultCard("Gender", _result!['dg1']["gender"]),
        _buildResultCard("Other Information", _result!["dg11"]['otherInfo']),
        _buildResultCard("Nationality", _result!['dg1']["nationality"]),
        _buildResultCard("Date of Birth", _result!["dg11"]["fullDateOfBirth"]),
        _buildResultCard("Place of Birth", _result!["dg11"]["placeOfBirth"]),
        _buildResultCard("Custodian", _result!["dg11"]["custodian"]),
        _buildResultCard("National Identification Number", _result!["dg11"]["personalNumber"]),
        const SizedBox(height: 20,),
        Divider(thickness: 1, color: Colors.grey[300]),
        Text("Document Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        _buildResultCard("Document Code", _result!['dg1']["documentCode"]),
        _buildResultCard("Document Number", _result!['dg1']["documentNumber"]),
        _buildResultCard("Issuing Country", _result!['dg1']["issuingState"]),
        const SizedBox(height: 20,),
        Divider(thickness: 1, color: Colors.grey[300]),
        Text("Chip Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        _buildResultCard("LDS Version", _result!['com']["ldsVersion"]),
        _buildResultCard("Unicode Version", _result!['com']["unicodeVersion"]),
        _buildResultCard("Data groups", _result!['com']["tagsList"].toString()),
        const SizedBox(height: 20,),
        Divider(thickness: 1, color: Colors.grey[300]),
        Text("Document Signing Certificate", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        _buildResultCard("Serial Number", _result!["sod"]['serialNumber']),
        _buildResultCard("Signature algorithm", _result!["sod"]['Signature algorithm']),
        _buildResultCard("Public Key Algorithm", _result!["sod"]['Public Key'].split(" ")[0]),
        _buildResultCard("Issuer", _result!["sod"]['issuer']),
        // _buildResultCard("Signature Thumbprint", _result!["docSigningCert"]['issuer']),
        _buildResultCard("Subject", _result!["sod"]['Subject']),
        _buildResultCard("Valid from", _result!["sod"]['Valid from']),
        _buildResultCard("Valid to", _result!["sod"]['Valid until']),
        _buildResultCard("Signature", base64Encode(_result!["sod"]['signature'])),
        _buildResultCard("Version", _result!["sod"]['version']),
        const SizedBox(height: 20,),
        Divider(thickness: 1, color: Colors.grey[300]),
        Text("Country Signing Certificate", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        _buildResultCard("Serial Number", _result!["sod"]['serialNumber']),
        _buildResultCard("Signature algorithm", _result!["sod"]['Signature algorithm']),
        _buildResultCard("Public Key Algorithm", _result!["sod"]['Public Key'].split(" ")[0]),
        _buildResultCard("Issuer", _result!["sod"]['issuer']),
        // _buildResultCard("Signature Thumbprint", _result!["docSigningCert"]['issuer']),
        _buildResultCard("Subject", _result!["sod"]['Subject']),
        _buildResultCard("Valid from", _result!["sod"]['Valid from']),
        _buildResultCard("Valid to", _result!["sod"]['Valid until']),
        _buildResultCard("Signature", base64Encode(_result!["sod"]['signature'])),
        _buildResultCard("Version", _result!["sod"]['version']),
        const SizedBox(height: 20,),
        // Divider(thickness: 1, color: Colors.grey[300]),
        // Text("Security", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        // _buildResultCard("Digest Algorithm", _result!["digestAlgorithm"]),
        // _buildResultCard("Digest Algorithm Signer info", _result!["digestAlgorithmSignerInfo"]),
        // _buildResultCard("Unicode Version", _result!["unicodeVersion"]),
        // _buildResultCard("Public Key algorithm", _result!["publicKey"]['algorithm']),
        // _buildResultCard("Public Key Format", _result!["publicKey"]['format']),
        // _buildResultCard("Public key encoded", _result!["publicKey"]['encoded']),
        const SizedBox(height: 20,),
        Divider(thickness: 1, color: Colors.grey[300]),
        Text("Signature", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Image.memory(Uint8List.fromList(base64Decode(_result!['dg7']["images"][0])), fit: BoxFit.cover,),
        const SizedBox(height: 20,),
        Divider(thickness: 1, color: Colors.grey[300]),
        Text("MRZ from chip", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        _buildResultCard("", _result!['dg1']["fullMrz"]),
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
