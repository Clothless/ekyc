import 'dart:async';

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
  bool _isListening = false;
  StreamSubscription<dynamic>? _nfcSubscription;

  @override
  void initState() {
    super.initState();
    _checkNfcStatus();
  }

  @override
  void dispose() {
    _nfcSubscription?.cancel();
    if (_isListening) {
      _stopNfcListener();
    }
    super.dispose();
  }

  Future<void> _checkNfcStatus() async {
    try {
      final status = await _ekyc.checkNfc();
      if (mounted) {
        setState(() {
          _nfcStatus = Map<String, dynamic>.from(status);
        });
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error checking NFC status: ${e.message}';
        });
      }
    }
  }

  Future<void> _startNfcListener() async {
    setState(() {
      _isListening = true;
      _errorMessage = '';
      _nfcData = null;
    });

    try {
      await _ekyc.startNfc();
      _nfcSubscription = _ekyc.nfcDataStream.listen((data) {
        setState(() {
          _nfcData = Map<String, dynamic>.from(data);
        });
        Navigator.of(context).pop(); // Close the dialog
        _stopNfcListener();
      }, onError: (error) {
        setState(() {
          _errorMessage = 'Error reading NFC tag: $error';
        });
        Navigator.of(context).pop(); // Close the dialog
        _stopNfcListener();
      });

      _showWaitingDialog();
    } on PlatformException catch (e) {
      setState(() {
        _errorMessage = 'Error starting NFC listener: ${e.message}';
        _isListening = false;
      });
    }
  }

  Future<void> _stopNfcListener() async {
    try {
      await _ekyc.stopNfc();
    } on PlatformException catch (e) {
      // Handle error if needed
    } finally {
      setState(() {
        _isListening = false;
        _nfcSubscription?.cancel();
        _nfcSubscription = null;
      });
    }
  }

  void _showWaitingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reading NFC'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Waiting for NFC tag...'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _stopNfcListener();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNfcStatusCard() {
    if (_nfcStatus == null) {
      return const Card(
        child: ListTile(
          title: Text('NFC Status'),
          subtitle: Text('Checking...'),
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
          subtitle: Text('Press "Read NFC Tag" to start'),
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
              onPressed: _isListening ? null : _startNfcListener,
              icon: _isListening
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.nfc),
              label: Text(_isListening ? 'Listening...' : 'Read NFC Tag'),
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildNfcDataCard()),
          ],
        ),
      ),
    );
  }
} 