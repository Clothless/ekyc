import 'dart:convert';
import 'package:ekyc/ekyc.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eKYC NFC Reader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
        fontFamily: 'Poppins',
      ),
      home: const NfcScanScreen(),
    );
  }
}

class NfcScanScreen extends StatefulWidget {
  const NfcScanScreen({super.key});

  @override
  State<NfcScanScreen> createState() => _NfcScanScreenState();
}

class _NfcScanScreenState extends State<NfcScanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _docNumberController = TextEditingController();
  final _dobController = TextEditingController();
  final _doeController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _scanResult;

  @override
  void dispose() {
    _docNumberController.dispose();
    _dobController.dispose();
    _doeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(
      TextEditingController controller, String title) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1920),
      lastDate: DateTime(2100),
      helpText: title,
    );
    if (picked != null) {
      final yy = (picked.year % 100).toString().padLeft(2, '0');
      final mm = picked.month.toString().padLeft(2, '0');
      final dd = picked.day.toString().padLeft(2, '0');
      controller.text = '$yy$mm$dd';
    }
  }

  Future<void> _startNfcScan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _scanResult = null;
    });

    try {
      final nfcStatus = await Ekyc.checkNfc();
      if (nfcStatus['supported'] == false) {
        final errorMsg = nfcStatus['error'] ??
            'NFC is not supported or enabled on this device.\nPlease check your device settings.';
        setState(() {
          _errorMessage = errorMsg.toString();
          _isLoading = false;
        });
        return;
      }

      await Ekyc.initialize();

      // Listen for background NFC intent on Android
      Ekyc.setOnPassportReadListener((data) {
        if (!mounted) return;
        setState(() {
          _scanResult = data;
          _isLoading = false;
        });
      }, onError: (err) {
        if (!mounted) return;
        setState(() {
          _errorMessage = err;
          _isLoading = false;
        });
      });

      // Start scan (opens native NFC prompt on iOS)
      final result = await Ekyc.readPassport(
        documentNumber: _docNumberController.text.trim(),
        dateOfBirth: _dobController.text.trim(),
        dateOfExpiry: _doeController.text.trim(),
      );

      if (!mounted) return;
      if (result != null && result.isNotEmpty) {
        setState(() {
          _scanResult = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Scan failed: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('eKYC Passport NFC'),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.contactless,
                size: 72,
                color: Colors.indigo,
              ),
              const SizedBox(height: 12),
              const Text(
                'Enter Passport Details',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Enter your passport information to unlock the NFC chip.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 28),

              // Document Number
              TextFormField(
                controller: _docNumberController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Document / Passport Number',
                  hintText: 'e.g. A12345678',
                  prefixIcon: const Icon(Icons.credit_card),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Document number is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Date of Birth
              TextFormField(
                controller: _dobController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'Date of Birth (YYMMDD)',
                  hintText: 'e.g. 950520',
                  prefixIcon: const Icon(Icons.cake),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () =>
                        _selectDate(_dobController, 'Select Date of Birth'),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().length != 6) {
                    return 'Enter date as YYMMDD (6 digits)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // Date of Expiry
              TextFormField(
                controller: _doeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'Date of Expiry (YYMMDD)',
                  hintText: 'e.g. 300520',
                  prefixIcon: const Icon(Icons.event),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _selectDate(
                        _doeController, 'Select Date of Expiry'),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().length != 6) {
                    return 'Enter date as YYMMDD (6 digits)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Error banner
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                              color: Colors.red.shade900, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              // Scan NFC Button
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _startNfcScan,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.nfc, size: 28),
                  label: Text(
                    _isLoading
                        ? 'Ready for NFC... Tap phone to passport'
                        : 'Start NFC Scan',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Scan Result View
              if (_scanResult != null) _buildResultCard(_scanResult!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> data) {
    final photoBase64 = data['photoBase64'] ??
        (data['dg2'] is Map ? data['dg2']['photo'] : null);
    final signatureBase64 = data['signatureBase64'] ??
        (data['dg7'] is Map && data['dg7']['images'] is List && (data['dg7']['images'] as List).isNotEmpty
            ? data['dg7']['images'][0]
            : null);
    final frontImageBase64 = data['frontImageBase64'] ??
        (data['dg12'] is Map ? data['dg12']['imageOfFront'] : null);
    final rearImageBase64 = data['rearImageBase64'] ??
        (data['dg12'] is Map ? data['dg12']['imageOfRear'] : null);

    final firstName = data['firstName'] ??
        (data['dg1'] is Map ? data['dg1']['firstName'] : null);
    final lastName = data['lastName'] ??
        (data['dg1'] is Map ? data['dg1']['lastName'] : null);
    final docNum = data['documentNumber'] ??
        (data['dg1'] is Map ? data['dg1']['documentNumber'] : null);
    final docCode = data['documentCode'] ??
        (data['dg1'] is Map ? data['dg1']['documentCode'] : null);
    final docType = data['documentType'] ??
        (data['dg1'] is Map ? data['dg1']['documentType'] : null);
    final dob = data['birthDate'] ??
        (data['dg1'] is Map ? data['dg1']['dateOfBirth'] : null);
    final doe = data['expiryDate'] ??
        (data['dg1'] is Map ? data['dg1']['dateOfExpiry'] : null);
    final nationality = data['nationality'] ??
        (data['dg1'] is Map ? data['dg1']['nationality'] : null);
    final sex =
        data['sex'] ?? (data['dg1'] is Map ? data['dg1']['gender'] : null);
    final issuingState = data['issuingState'] ??
        (data['dg1'] is Map ? data['dg1']['issuingState'] : null);
    final nin = data['NIN'] ??
        (data['dg11'] is Map ? data['dg11']['personalNumber'] : null);
    final placeOfBirth = data['placeOfBirth'] ??
        (data['dg11'] is Map ? data['dg11']['placeOfBirth'] : null);
    final address = data['residenceAddress'] ??
        (data['dg11'] is Map ? data['dg11']['permanentAddress'] : null);
    final phone = data['telephone'] ??
        (data['dg11'] is Map ? data['dg11']['telephone'] : null);
    final profession = data['profession'] ??
        (data['dg11'] is Map ? data['dg11']['profession'] : null);
    final title = data['title'] ??
        (data['dg11'] is Map ? data['dg11']['title'] : null);
    final fullMrz = data['fullMrz'] ??
        (data['dg1'] is Map ? data['dg1']['fullMrz'] : null);

    final verified = data['verified'] == true;
    final notTampered = data['notTampered'] == true;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(verified ? Icons.verified : Icons.check_circle_outline,
                    color: Colors.green, size: 28),
                const SizedBox(width: 8),
                const Text(
                  'Passport Read Successfully',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _badge('Verified', verified),
                const SizedBox(width: 8),
                _badge('Not Tampered', notTampered),
              ],
            ),
            const Divider(height: 28),

            // Photos Grid
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                if (photoBase64 != null && photoBase64.toString().isNotEmpty)
                  _imagePreview('Face Photo', photoBase64.toString(), 120, 150),
                if (signatureBase64 != null && signatureBase64.toString().isNotEmpty)
                  _imagePreview('Signature', signatureBase64.toString(), 140, 70),
                if (frontImageBase64 != null && frontImageBase64.toString().isNotEmpty)
                  _imagePreview('ID Front', frontImageBase64.toString(), 140, 90),
                if (rearImageBase64 != null && rearImageBase64.toString().isNotEmpty)
                  _imagePreview('ID Rear', rearImageBase64.toString(), 140, 90),
              ],
            ),

            const SizedBox(height: 20),
            const Text('Personal Details',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo)),
            const SizedBox(height: 6),
            _infoTile('First Name', firstName),
            _infoTile('Last Name', lastName),
            _infoTile('Gender', sex),
            _infoTile('Date of Birth', dob),
            _infoTile('Place of Birth', placeOfBirth),
            _infoTile('Nationality', nationality),
            _infoTile('NIN', nin),
            _infoTile('Address', address),
            _infoTile('Phone', phone),
            _infoTile('Profession', profession),
            _infoTile('Title', title),

            const Divider(height: 24),
            const Text('Document Details',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo)),
            const SizedBox(height: 6),
            _infoTile('Document Number', docNum),
            _infoTile('Document Code', docCode),
            _infoTile('Document Type', docType),
            _infoTile('Issuing State', issuingState),
            _infoTile('Date of Expiry', doe),
            _infoTile('Full MRZ', fullMrz),

            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('Raw Data Groups (JSON)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ').convert(
                      Map.fromEntries(data.entries.where((e) =>
                          !e.key.toLowerCase().contains('base64'))),
                    ),
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 11),
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePreview(String label, String base64Data, double width, double height) {
    try {
      final bytes = base64Decode(base64Data.trim());
      return Column(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey)),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                bytes,
                width: width,
                height: height,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Widget _badge(String label, bool ok) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ok ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: ok ? Colors.green.shade300 : Colors.orange.shade300),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: ok ? Colors.green.shade800 : Colors.orange.shade800,
        ),
      ),
    );
  }

  Widget _infoTile(String label, dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}



