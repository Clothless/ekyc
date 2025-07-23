import 'package:flutter/material.dart';

import '../../card_portal.dart';
import '../../ekyc.dart';
import 'dart:convert'; // Import for Base64 decoding

enum NfcScanStage {
  waiting,
  initializing,
  reading,
  done,
  error,
}

class ResultScreen extends StatefulWidget {
  final CardDataModel result;

  const ResultScreen({
    super.key,
    required this.result,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('eKYC Result'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // MRZ Data Section
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MRZ Information', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildInfoRow('MRZ version', widget.result.efdg1.mrz.version.name),
                      _buildInfoRow('FID', widget.result.efdg1.fid.toString()),
                      _buildInfoRow('SFI', widget.result.efdg1.sfi.toString()),
                      _buildInfoRow('Document Number', widget.result.efdg1.mrz.documentNumber),
                      _buildInfoRow('Document Code', widget.result.efdg1.mrz.documentCode),
                      _buildInfoRow('Optional Data 1', widget.result.efdg1.mrz.optionalData),
                      _buildInfoRow('Optional Data 2', widget.result.efdg1.mrz.optionalData2),
                      _buildInfoRow('Country', widget.result.efdg1.mrz.country),
                      _buildInfoRow('Nationality', widget.result.efdg1.mrz.nationality),

                      _buildInfoRow('Version', widget.result.efcom.version.toString()),
                      _buildInfoRow('UniCode Version', widget.result.efcom.unicodeVersion.toString()),
                      // _buildInfoRow('Date of Expiry', widget.result.dateOfExpiry),
                      // _buildInfoRow('First Name', widget.result.firstName),
                      // _buildInfoRow('Last Name', widget.result.lastName),
                      // _buildInfoRow('Gender', widget.result.gender),
                      // _buildInfoRow('Nationality', widget.result.nationality),
                      // _buildInfoRow('Full MRZ', widget.result.fullMrz ?? 'N/A'),
                    ],
                  ),
                ),
              ),

              // DG11 Data Section (Additional Personal Details)
              if (widget.result.efdg11 != null)
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Personal Details (DG11)', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _buildInfoRow('Full Name', widget.result.efdg11!.nameOfHolder),
                        _buildInfoRow('Other Names', widget.result.efdg11!.otherNames.join(' ')),
                        _buildInfoRow('Personal Number', widget.result.efdg11!.personalNumber),
                        _buildInfoRow('Permanent Address', widget.result.efdg11!.permanentAddress.join('\n')),
                        _buildInfoRow('Place of Birth', widget.result.efdg11!.placeOfBirth.join(', ')),
                        _buildInfoRow('Profession', widget.result.efdg11!.profession),
                        _buildInfoRow('Telephone', widget.result.efdg11!.telephone),
                        _buildInfoRow('Title', widget.result.efdg11!.title),
                        _buildInfoRow('Full Date of Birth', widget.result.efdg11!.fullDateOfBirth != null ? _formatDate(widget.result.efdg11!.fullDateOfBirth!) : 'N/A'),
                        // Add other DG11 fields as needed
                      ],
                    ),
                  ),
                ),

              // DG12 Data Section (Additional Document Details)
              if (widget.result.efdg12 != null)
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Document Details (DG12)', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _buildInfoRow('Issuing Authority', widget.result.efdg12!.issuingAuthority),
                        _buildInfoRow('Date of Issue', widget.result.efdg12!.dateOfIssue != null ? _formatDate(widget.result.efdg12!.dateOfIssue!) : 'N/A'),
                        // Add other DG12 fields as needed
                      ],
                    ),
                  ),
                ),

              // Facial Image Section (DG2)
              if (widget.result.efdg2.imageData != null)
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Facial Image', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Center(
                          child: Image.memory(
                            widget.result.efdg2.imageData!,
                            fit: BoxFit.contain,
                            height: 200, // Adjust height as needed
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 3, child: Text(value ?? '-')),
        ],
      ),
    );
  }

  // Helper for date formatting, consistent with Ekyc class
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
} 