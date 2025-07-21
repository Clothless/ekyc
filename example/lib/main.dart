import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:ekyc/ekyc.dart';
import 'nfc_example.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  String _nfcStatus = 'Unknown';
  String _nfcData = 'No data';
  final _ekycPlugin = Ekyc();

  @override
  void initState() {
    super.initState();
    initPlatformState();
    checkNfcStatus();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion =
          await _ekycPlugin.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  Future<void> checkNfcStatus() async {
    try {
      final nfcStatus = await _ekycPlugin.checkNfc();
      setState(() {
        _nfcStatus = 'Supported: ${nfcStatus['supported']}, Enabled: ${nfcStatus['enabled']}';
      });
    } on PlatformException catch (e) {
      setState(() {
        _nfcStatus = 'Error: ${e.message}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Running on: $_platformVersion\n'),
              Text('NFC Status: $_nfcStatus\n'),
              Text('NFC Data: $_nfcData\n'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final result = await _ekycPlugin.readNfc();
                    setState(() {
                      _nfcData = result.toString();
                    });
                    print('NFC Result: $result');
                  } on PlatformException catch (e) {
                    setState(() {
                      _nfcData = 'Error: ${e.message}';
                    });
                    print('NFC Error: ${e.message}');
                  }
                },
                child: const Text('Read NFC Tag'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: checkNfcStatus,
                child: const Text('Check NFC Status'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NfcExample()),
                  );
                },
                child: const Text('Open NFC Example'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final result = await _ekycPlugin.testConnection();
                    setState(() {
                      _nfcData = 'Test Result: $result';
                    });
                    print('Test Result: $result');
                  } catch (e) {
                    setState(() {
                      _nfcData = 'Test Error: $e';
                    });
                    print('Test Error: $e');
                  }
                },
                child: const Text('Test Plugin Connection'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
