import 'package:flutter/material.dart';

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
  final EkycResult result;

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
                      _buildInfoRow('Document Number', widget.result.documentNumber),
                      _buildInfoRow('Date of Birth', widget.result.dateOfBirth),
                      _buildInfoRow('Date of Expiry', widget.result.dateOfExpiry),
                      _buildInfoRow('First Name', widget.result.firstName),
                      _buildInfoRow('Last Name', widget.result.lastName),
                      _buildInfoRow('Gender', widget.result.gender),
                      _buildInfoRow('Nationality', widget.result.nationality),
                      _buildInfoRow('Full MRZ', widget.result.fullMrz ?? 'N/A'),
                    ],
                  ),
                ),
              ),

              // DG11 Data Section (Additional Personal Details)
              if (widget.result.dg11Data != null)
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
                        _buildInfoRow('Full Name', widget.result.dg11Data!.nameOfHolder),
                        _buildInfoRow('Other Names', widget.result.dg11Data!.otherNames.join(' ')),
                        _buildInfoRow('Personal Number', widget.result.dg11Data!.personalNumber),
                        _buildInfoRow('Permanent Address', widget.result.dg11Data!.permanentAddress.join('\n')),
                        _buildInfoRow('Place of Birth', widget.result.dg11Data!.placeOfBirth.join(', ')),
                        _buildInfoRow('Profession', widget.result.dg11Data!.profession),
                        _buildInfoRow('Telephone', widget.result.dg11Data!.telephone),
                        _buildInfoRow('Title', widget.result.dg11Data!.title),
                        _buildInfoRow('Full Date of Birth', widget.result.dg11Data!.fullDateOfBirth != null ? _formatDate(widget.result.dg11Data!.fullDateOfBirth!) : 'N/A'),
                        // Add other DG11 fields as needed
                      ],
                    ),
                  ),
                ),

              // DG12 Data Section (Additional Document Details)
              if (widget.result.dg12Data != null)
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
                        _buildInfoRow('Issuing Authority', widget.result.dg12Data!.issuingAuthority),
                        _buildInfoRow('Date of Issue', widget.result.dg12Data!.dateOfIssue != null ? _formatDate(widget.result.dg12Data!.dateOfIssue!) : 'N/A'),
                        // Add other DG12 fields as needed
                      ],
                    ),
                  ),
                ),

              // Facial Image Section (DG2)
              if (widget.result.base64Image != null)
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
                            base64Decode(widget.result.base64Image!),
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