import 'package:flutter/material.dart';

class EditOCRResultScreen extends StatefulWidget {
  final Map<String, dynamic> data;

  const EditOCRResultScreen({required this.data, Key? key}) : super(key: key);

  @override
  State<EditOCRResultScreen> createState() => _EditOCRResultScreenState();
}

class _EditOCRResultScreenState extends State<EditOCRResultScreen> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    widget.data.forEach((key, value) {
      if (key != 'rawText') {
        _controllers[key] = TextEditingController(text: value?.toString() ?? '');
      }
    });
  }

  @override
  void dispose() {
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  Widget _buildFieldCard(String label, TextEditingController controller) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: _formatLabel(label),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  String _formatLabel(String key) {
    return key
        .replaceAll(RegExp(r'([A-Z])'), ' \$1')
        .replaceAll('_', ' ')
        .replaceFirstMapped(RegExp(r'^[a-z]'), (m) => m.group(0)!.toUpperCase());
  }

  void _rescan() {
    Navigator.pop(context); // Go back to the previous OCR screen
  }

  @override
  Widget build(BuildContext context) {
    final fields = _controllers.entries.map(
          (entry) => _buildFieldCard(entry.key, entry.value),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit OCR Details"),
        centerTitle: true,
        backgroundColor: Colors.indigo,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Extracted Fields",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                )),
            const SizedBox(height: 12),
            ...fields,
            const SizedBox(height: 24),
            Divider(thickness: 1),
            SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: null, // Disabled
              icon: Icon(Icons.save),
              label: Text("Save (Disabled)"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _rescan,
              icon: Icon(Icons.camera_alt),
              label: Text("Rescan Image"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
