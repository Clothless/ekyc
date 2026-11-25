import 'dart:convert';

import 'package:ekyc/ekyc.dart';
import 'package:flutter/material.dart';

class ManualNfcPage extends StatefulWidget {
  const ManualNfcPage({super.key});

  @override
  State<ManualNfcPage> createState() => _ManualNfcPageState();
}

class _ManualNfcPageState extends State<ManualNfcPage> {
  final _formKey = GlobalKey<FormState>();
  final _documentNumberController = TextEditingController();
  final _dobController = TextEditingController();
  final _doeController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _documentNumberController.dispose();
    _dobController.dispose();
    _doeController.dispose();
    super.dispose();
  }

  /// Pick a date and fill the controller in YYMMDD format
  Future<void> _pickDate(TextEditingController controller, String label) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1920),
      lastDate: DateTime(2100),
      helpText: label,
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
    });

    try {
      // Check NFC availability first
      final nfcStatus = await Ekyc.checkNfc();
      if (nfcStatus['supported'] != true || nfcStatus['enabled'] != true) {
        setState(() {
          _errorMessage = 'NFC is not available on this device.';
          _isLoading = false;
        });
        return;
      }

      // Read passport via NFC
      final result = await Ekyc.readPassport(
        documentNumber: _documentNumberController.text.trim(),
        dateOfBirth: _dobController.text.trim(),
        dateOfExpiry: _doeController.text.trim(),
      );

      if (!mounted) return;

      if (result != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NfcResultPage(result: result),
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'No data received from passport.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual NFC Scan'),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.nfc, size: 64, color: Colors.indigo),
              const SizedBox(height: 12),
              const Text(
                'Enter MRZ Details',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the document number, date of birth, and date of expiry from your passport\'s MRZ zone.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),

              // Document Number
              TextFormField(
                controller: _documentNumberController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Document Number',
                  hintText: 'e.g. AB1234567',
                  prefixIcon: const Icon(Icons.credit_card),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Document number is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Date of Birth
              TextFormField(
                controller: _dobController,
                decoration: InputDecoration(
                  labelText: 'Date of Birth (YYMMDD)',
                  hintText: 'e.g. 900115',
                  prefixIcon: const Icon(Icons.cake),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _pickDate(_dobController, 'Date of Birth'),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
                validator: (v) {
                  if (v == null || v.trim().length != 6) {
                    return 'Enter date as YYMMDD (6 digits)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Date of Expiry
              TextFormField(
                controller: _doeController,
                decoration: InputDecoration(
                  labelText: 'Date of Expiry (YYMMDD)',
                  hintText: 'e.g. 300115',
                  prefixIcon: const Icon(Icons.event),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () =>
                        _pickDate(_doeController, 'Date of Expiry'),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
                validator: (v) {
                  if (v == null || v.trim().length != 6) {
                    return 'Enter date as YYMMDD (6 digits)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Error message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade800, fontSize: 14),
                  ),
                ),

              // Scan button
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _startNfcScan,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.contactless),
                  label: Text(
                    _isLoading ? 'Waiting for NFC...' : 'Scan Passport NFC',
                    style: const TextStyle(fontSize: 16),
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
              const SizedBox(height: 16),
              Text(
                'Hold your phone near the passport chip after pressing scan.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Result page ----------

class NfcResultPage extends StatelessWidget {
  final Map<String, dynamic> result;
  const NfcResultPage({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC Scan Result'),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Photo
            if (result['photoBase64'] != null)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    base64Decode(result['photoBase64']),
                    width: 160,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // Verification badges
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _badge('Verified', result['verified'] == true),
                const SizedBox(width: 12),
                _badge('Not Tampered', result['notTampered'] == true),
              ],
            ),
            const SizedBox(height: 24),

            _sectionTitle('Personal Information'),
            _row('First Name', result['firstName']),
            _row('Last Name', result['lastName']),
            _row('Date of Birth', result['birthDate']),
            _row('Gender', result['sex']),
            _row('Nationality', result['nationality']),
            _row('Place of Birth', result['placeOfBirth']),
            _row('Residence Address', result['residenceAddress']),
            _row('NIN', result['NIN']),

            const Divider(height: 32),
            _sectionTitle('Document Information'),
            _row('Document Number', result['documentNumber']),
            _row('Expiry Date', result['expiryDate']),
            _row('Issuing State', result['issuingState']),

            // Signature image
            if (result['signatureBase64'] != null) ...[
              const Divider(height: 32),
              _sectionTitle('Signature'),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  base64Decode(result['signatureBase64']),
                  height: 80,
                  fit: BoxFit.contain,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Raw data (expandable)
            ExpansionTile(
              title: const Text('Raw Data',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ').convert(
                      // Filter out base64 blobs for readability
                      Map.fromEntries(result.entries.where((e) =>
                          !e.key.toLowerCase().contains('base64'))),
                    ),
                    style: const TextStyle(
                        fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
      );

  Widget _row(String label, dynamic value) {
    final display = value?.toString() ?? '—';
    if (display.isEmpty || display == 'null') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.grey[700])),
          ),
          Expanded(child: Text(display)),
        ],
      ),
    );
  }

  Widget _badge(String label, bool ok) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: ok ? Colors.green.shade50 : Colors.red.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: ok ? Colors.green.shade300 : Colors.red.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ok ? Icons.check_circle : Icons.error,
                size: 18, color: ok ? Colors.green : Colors.red),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: ok ? Colors.green.shade800 : Colors.red.shade800,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
