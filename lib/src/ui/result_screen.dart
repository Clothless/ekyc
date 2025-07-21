import 'package:flutter/material.dart';

import '../../ekyc.dart';
import '../../ekyc_platform_interface.dart';

class ResultScreen extends StatefulWidget {
  final String docNumber;
  final String dob;
  final String doe;

  const ResultScreen({
    super.key,
    required this.docNumber,
    required this.dob,
    required this.doe,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _isLoading = true;
  String _status = '';
  String _nfcStage = 'waiting'; // 'waiting', 'reading', 'done', 'error'
  EkycResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _readNfcTag());
  }

  Future<void> _readNfcTag() async {
    setState(() {
      _nfcStage = 'waiting';
      _status = 'Please hold your card against the phone’s NFC area…';
      _isLoading = true;
      _result = null;
    });
    await Future.delayed(const Duration(milliseconds: 500)); // Give user a moment to place card
    setState(() {
      _nfcStage = 'reading';
      _status = 'Reading card, please keep holding…';
    });
    try {
      final result = await EkycPlatform.instance.readCard(
        docNumber: widget.docNumber,
        dob: widget.dob,
        doe: widget.doe,
      );
      if (!mounted) return;
      setState(() {
        _result = EkycResult.fromMap(result);
        _status = 'Success! eKYC process complete.';
        _isLoading = false;
        _nfcStage = 'done';
      });
    } catch (e) {
      if (!mounted) return;
      String errorMsg = e.toString();
      if (errorMsg.contains('NFC_TIMEOUT')) {
        errorMsg = 'No NFC document detected. Please hold your document close to the phone and try again.';
      } else {
        errorMsg = 'NFC Read Error: $e';
      }
      setState(() {
        _status = errorMsg;
        _isLoading = false;
        _nfcStage = 'error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('eKYC Result'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isLoading)
              Column(
                children: [
                  const SizedBox(height: 32),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            if (!_isLoading && _status.isNotEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    children: [
                      Text(
                        _status,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (_nfcStage == 'error')
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry NFC Scan'),
                            onPressed: _readNfcTag,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (_result != null) Expanded(child: _buildResultDisplay()),
          ],
        ),
      ),
    );
  }

  Widget _buildResultDisplay() {
    if (_result == null) {
      return const Center(child: Text('No result available.'));
    }
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildInfoCard(
            title: 'Personal Details',
            data: {
              'First Name': _result!.name ?? '-',
              'Name in Arabic': _result!.nameArabic ?? '-',
              'National Identity Number': _result!.nin ?? '-',
              'Document Number': _result!.documentNumber ?? '-',
              'Gender': _result!.gender ?? '-',
              'Date of Birth': _result!.dateOfBirth ?? '-',
              'Date of Expiry': _result!.dateOfExpiry ?? '-',
              'Nationality': _result!.nationality ?? '-',
              'Country': _result!.country ?? '-',
            },
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: 'Address & Birth',
            data: {
              'Address': _result!.address ?? '-',
              'Place of Birth': _result!.placeOfBirth ?? '-',
            },
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: 'Document Details',
            data: {
              'Issuing Authority': _result!.issuingAuthority ?? '-',
              'Date of Issue': _result!.dateOfIssue ?? '-',
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({required String title, required Map<String, String?> data}) {
    final filtered = data.entries.where((entry) => entry.value != null && entry.value!.isNotEmpty && entry.value != '-').toList();
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
                  Expanded(flex: 2, child: Text('${entry.key}:', style: const TextStyle(fontWeight: FontWeight.bold))),
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