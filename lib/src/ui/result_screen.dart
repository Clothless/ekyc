import 'package:flutter/material.dart';

import '../../ekyc.dart';

enum NfcScanStage {
  waiting,
  initializing,
  reading,
  done,
  error,
}

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
  NfcScanStage _nfcStage = NfcScanStage.waiting;
  EkycResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _readNfcTag());
  }

  Future<void> _readNfcTag() async {
    setState(() {
      _nfcStage = NfcScanStage.waiting;
      _status = 'Please hold your document close to the phone’s NFC area…';
      _isLoading = true;
      _result = null;
    });

    // Give the user a moment to place the card before initiating the scan
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _nfcStage = NfcScanStage.initializing;
      _status = 'NFC reader activated. Please keep your document steadily attached to the phone.';
    });

    try {
      final result = await Ekyc.readCard(
        docNumber: widget.docNumber,
        dob: widget.dob,
        doe: widget.doe,
      );

      if (!mounted) return;

      setState(() {
        _result = EkycResult.fromMap(result);
        _status = 'Success! Document data retrieved.';
        _isLoading = false;
        _nfcStage = NfcScanStage.done;
      });
    } catch (e) {
      if (!mounted) return;
      String errorMsg = e.toString();
      String userFriendlyMessage;

      if (errorMsg.contains('NFC_TIMEOUT') || errorMsg.contains('408')) {
        userFriendlyMessage = 'No NFC document detected. Please hold your document steadily over the phone and try again.';
      } else if (errorMsg.contains('Tag was lost') || errorMsg.contains('Transceive failed') || errorMsg.contains('I/O error')) {
        userFriendlyMessage = 'Connection lost. Please ensure the document remains still during scanning and try again.';
      } else if (errorMsg.contains('Authentication failed') || errorMsg.contains('BAC failed') || errorMsg.contains('Access denied')) {
        userFriendlyMessage = 'Authentication failed. Please check your document number, date of birth, and expiry date. Ensure the document is valid and try again.';
      } else if (errorMsg.contains('Not supported by NFC adapter')) {
        userFriendlyMessage = 'NFC not supported for this document type or device. Please check device compatibility.';
      } else if (errorMsg.contains('NFC is not enabled') || errorMsg.contains('NFC_NOT_ENABLED')) {
        userFriendlyMessage = 'NFC is currently disabled on your device. Please enable NFC in your phone settings and try again.';
      }
      else {
        userFriendlyMessage = 'NFC Read Error: An unexpected error occurred. Please try again or contact support.';
        debugPrint('Original NFC Error: $e');
      }

      setState(() {
        _status = userFriendlyMessage;
        _isLoading = false;
        _nfcStage = NfcScanStage.error;
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
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              )
            else // Added else for better UI state management
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
                      if (_nfcStage == NfcScanStage.error)
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