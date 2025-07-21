import 'package:flutter/material.dart';
import 'package:ekyc/ekyc.dart';

class ManualNfcScreen extends StatefulWidget {
  const ManualNfcScreen({super.key});

  @override
  _ManualNfcScreenState createState() => _ManualNfcScreenState();
}

class _ManualNfcScreenState extends State<ManualNfcScreen> {
  final _formKey = GlobalKey<FormState>();
  final _docNumController = TextEditingController();
  final _dobController = TextEditingController();
  final _doeController = TextEditingController();

  bool _isLoading = false;
  String _status = '';
  EkycResult? _result;

  Future<void> _readNfcTag() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
      _status = 'Please hold your card against the phone...';
      _result = null;
    });
    try {
      final result = await Ekyc().readCard(
        docNumber: _docNumController.text,
        dob: _dobController.text,
        doe: _doeController.text,
      );
      setState(() {
        _result = result;
        _status = 'Successfully read ID card! You can now remove the card.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('eKYC - Manual Input'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _docNumController,
                decoration: const InputDecoration(labelText: 'Document Number'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a document number' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dobController,
                decoration: const InputDecoration(
                    labelText: 'Date of Birth (YYMMDD)'),
                validator: (value) =>
                    value!.length != 6 ? 'Must be 6 digits' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _doeController,
                decoration:
                    const InputDecoration(labelText: 'Date of Expiry (YYMMDD)'),
                validator: (value) =>
                    value!.length != 6 ? 'Must be 6 digits' : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _readNfcTag,
                child: _isLoading
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                    : const Text('Read ID Card via NFC'),
              ),
              const SizedBox(height: 32),
              if (_status.isNotEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              if (_result != null) ...[
                const SizedBox(height: 16),
                _buildInfoCard(
                  title: 'Personal Details',
                  data: {
                    'First Name': _result!.name,
                    'Name in Arabic': _result!.nameArabic,
                    'National Identity Number': _result!.nin,
                    'Document Number': _result!.documentNumber,
                    'Gender': _result!.gender,
                    'Date of Birth': _result!.dateOfBirth,
                    'Date of Expiry': _result!.dateOfExpiry,
                    'Nationality': _result!.nationality,
                    'Country': _result!.country,
                  },
                ),
                const SizedBox(height: 16),
                _buildInfoCard(
                  title: 'Address & Birth',
                  data: {
                    'Address': _result!.address,
                    'Place of Birth': _result!.placeOfBirth,
                  },
                ),
                const SizedBox(height: 16),
                _buildInfoCard(
                  title: 'Document Details',
                  data: {
                    'Issuing Authority': _result!.issuingAuthority,
                    'Date of Issue': _result!.dateOfIssue,
                  },
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
      {required String title, required Map<String, String?> data}) {
    final filtered = data.entries
        .where((entry) => entry.value != null && entry.value!.isNotEmpty)
        .toList();
    if (filtered.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            ...filtered.map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          flex: 2,
                          child: Text('${entry.key}:',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold))),
                      Expanded(flex: 3, child: Text(entry.value!)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
} 