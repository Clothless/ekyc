import 'package:flutter/material.dart';
import 'package:ekyc/ekyc.dart';

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
      _status = '';
      _result = null;
    });
    try {
      print('eKYC: Starting flow');
      final result = await Ekyc().startKycFlow(context: context);
      print('eKYC: Flow returned: $result');
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
      print('eKYC: Error: $e');
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
    return SingleChildScrollView(
      child: Column(
        children: [
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
        ],
      ),
    );
  }

  Widget _buildInfoCard({required String title, required Map<String, String?> data}) {
    final filtered = data.entries.where((entry) => entry.value != null && entry.value!.isNotEmpty).toList();
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