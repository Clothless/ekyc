import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ekyc/ekyc.dart';

class NfcExample extends StatefulWidget {
  const NfcExample({super.key});

  @override
  State<NfcExample> createState() => _NfcExampleState();
}

class _NfcExampleState extends State<NfcExample> {
  final Ekyc _ekyc = Ekyc();
  Map<String, dynamic>? _nfcStatus;
  Map<String, dynamic>? _nfcData;
  String _errorMessage = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkNfcStatus();
  }

  Future<void> _checkNfcStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final status = await _ekyc.checkNfc();
      setState(() {
        _nfcStatus = status;
        _isLoading = false;
      });
    } on PlatformException catch (e) {
      setState(() {
        _errorMessage = 'Error checking NFC status: ${e.message}';
        _isLoading = false;
      });
    }
  }

  Future<void> _readNfcTag() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _nfcData = null;
    });

    try {
      final data = await _ekyc.readNfc();
      setState(() {
        _nfcData = data;
        _isLoading = false;
      });
    } on PlatformException catch (e) {
      setState(() {
        _errorMessage = 'Error reading NFC tag: ${e.message}';
        _isLoading = false;
      });
    }
  }

  Widget _buildNfcStatusCard() {
    if (_nfcStatus == null) {
      return const Card(
        child: ListTile(
          title: Text('NFC Status'),
          subtitle: Text('Unknown'),
        ),
      );
    }

    final supported = _nfcStatus!['supported'] ?? false;
    final enabled = _nfcStatus!['enabled'] ?? false;

    return Card(
      child: ListTile(
        title: const Text('NFC Status'),
        subtitle: Text('Supported: $supported, Enabled: $enabled'),
        trailing: Icon(
          supported && enabled ? Icons.nfc : Icons.nfc,
          color: supported && enabled ? Colors.green : Colors.red,
        ),
      ),
    );
  }

  Widget _buildNfcDataCard() {
    if (_nfcData == null) {
      return const Card(
        child: ListTile(
          title: Text('NFC Data'),
          subtitle: Text('No data read yet'),
        ),
      );
    }

    return Card(
      child: ExpansionTile(
        title: const Text('NFC Data'),
        subtitle: Text('Tag ID: ${_nfcData!['tagId'] ?? 'Unknown'}'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_nfcData!['tagId'] != null) ...[
                  Text('Tag ID: ${_nfcData!['tagId']}'),
                  const SizedBox(height: 8),
                ],
                if (_nfcData!['techList'] != null) ...[
                  Text('Technologies: ${_nfcData!['techList'].join(', ')}'),
                  const SizedBox(height: 8),
                ],
                if (_nfcData!['ndefMessages'] != null && 
                    (_nfcData!['ndefMessages'] as List).isNotEmpty) ...[
                  const Text('NDEF Messages:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  ...(_nfcData!['ndefMessages'] as List).asMap().entries.map((entry) {
                    final index = entry.key;
                    final message = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Message $index:'),
                          if (message['records'] != null)
                            ...(message['records'] as List).map((record) => Padding(
                              padding: const EdgeInsets.only(left: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Type: ${record['type']}'),
                                  Text('Payload: ${record['payload']}'),
                                  if (record['mimeType'] != null && record['mimeType'].isNotEmpty)
                                    Text('MIME Type: ${record['mimeType']}'),
                                  const SizedBox(height: 4),
                                ],
                              ),
                            )),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC Example'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkNfcStatus,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildNfcStatusCard(),
            const SizedBox(height: 16),
            if (_errorMessage.isNotEmpty)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ),
            if (_errorMessage.isNotEmpty) const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _readNfcTag,
              icon: _isLoading 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.nfc),
              label: Text(_isLoading ? 'Reading...' : 'Read NFC Tag'),
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildNfcDataCard()),
          ],
        ),
      ),
    );
  }
} 