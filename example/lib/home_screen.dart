import 'package:flutter/material.dart';
import 'package:ekyc/ekyc.dart';
import 'dart:convert'; // Added for base64Decode

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  EkycResult? _result;
  String _status = '';
  bool _isLoading = false;

  Future<void> _startKyc() async {
    setState(() {
      _isLoading = true;
      _status = 'Keep your document close to the back of your phone while we read it.';
      _result = null;
    });
    try {
      debugPrint('eKYC: Starting flow');
      final result = await Ekyc().startKycFlow(context: context);
      debugPrint('eKYC: Flow returned: $result');
      if (!mounted) return;
      if (result == null) {
        setState(() {
          _status = 'Process cancelled or failed. Please try again.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _result = result;
          _status = 'Success! eKYC process complete.';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('eKYC: Error: $e');
      if (!mounted) return;
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
        title: const Text('eKYC Plugin Demo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _startKyc,
              child: const Text('Start eKYC Flow'),
            ),
            const SizedBox(height: 32),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
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
                  _buildInfoRow('Document Number', _result!.documentNumber),
                  _buildInfoRow('Date of Birth', _result!.dateOfBirth),
                  _buildInfoRow('Date of Expiry', _result!.dateOfExpiry),
                  _buildInfoRow('First Name', _result!.firstName),
                  _buildInfoRow('Last Name', _result!.lastName),
                  _buildInfoRow('Gender', _result!.gender),
                  _buildInfoRow('Nationality', _result!.nationality),
                  _buildInfoRow('Full MRZ', _result!.fullMrz ?? 'N/A'),
                ],
              ),
            ),
          ),

          // DG11 Data Section (Additional Personal Details)
          if (_result!.dg11Data != null)
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
                    _buildInfoRow('Full Name', _result!.dg11Data!.nameOfHolder),
                    _buildInfoRow('Other Names', _result!.dg11Data!.otherNames.join(' ')),
                    _buildInfoRow('Personal Number', _result!.dg11Data!.personalNumber),
                    _buildInfoRow('Permanent Address', _result!.dg11Data!.permanentAddress.join('\n')),
                    _buildInfoRow('Place of Birth', _result!.dg11Data!.placeOfBirth.join(', ')),
                    _buildInfoRow('Profession', _result!.dg11Data!.profession),
                    _buildInfoRow('Telephone', _result!.dg11Data!.telephone),
                    _buildInfoRow('Title', _result!.dg11Data!.title),
                    _buildInfoRow('Full Date of Birth', _result!.dg11Data!.fullDateOfBirth != null ? _formatDate(_result!.dg11Data!.fullDateOfBirth!) : 'N/A'),
                    // Add other DG11 fields as needed
                  ],
                ),
              ),
            ),

          // DG12 Data Section (Additional Document Details)
          if (_result!.dg12Data != null)
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
                    _buildInfoRow('Issuing Authority', _result!.dg12Data!.issuingAuthority),
                    _buildInfoRow('Date of Issue', _result!.dg12Data!.dateOfIssue != null ? _formatDate(_result!.dg12Data!.dateOfIssue!) : 'N/A'),
                    // Add other DG12 fields as needed
                  ],
                ),
              ),
            ),

          // Facial Image Section (DG2)
          if (_result!.base64Image != null)
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
                        base64Decode(_result!.base64Image!),
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
              setState(() {
                _result = null; // Clear result to allow re-scanning
                _status = '';
              });
            },
            child: const Text('Done / Rescan'),
          ),
        ],
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