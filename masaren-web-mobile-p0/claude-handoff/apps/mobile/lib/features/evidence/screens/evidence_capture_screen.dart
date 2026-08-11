import 'package:flutter/material.dart';
import 'package:masaren/core/theme/masaren_theme.dart';
import 'package:permission_handler/permission_handler.dart';

class EvidenceCaptureScreen extends StatefulWidget {
  const EvidenceCaptureScreen({super.key});

  @override
  State<EvidenceCaptureScreen> createState() => _EvidenceCaptureScreenState();
}

class _EvidenceCaptureScreenState extends State<EvidenceCaptureScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _gpsCaptured = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _request(Permission permission, String what, VoidCallback onGranted) async {
    final status = await permission.request();
    if (status.isGranted) {
      onGranted();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$what permission ${status.name}. Please enable it in settings.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Capture Evidence')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: TextButton.icon(
                onPressed: () => _request(Permission.camera, 'Camera', () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Camera ready. Photo captured (mock).')),
                  );
                }),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Tap to capture photo'),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () => _request(Permission.photos, 'Gallery', () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Gallery image selected (mock).')),
                  );
                }),
                icon: const Icon(Icons.photo_library),
                label: const Text('Upload from gallery'),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Evidence Title', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), alignLabelWithHint: true),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
              items: ['Impact Report', 'Task Completion', 'Community Event', 'Other'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (_) {},
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.location_on, color: MasarenTheme.navyLight),
                const SizedBox(width: 8),
                Text(_gpsCaptured ? 'Location captured' : 'Location: Not captured'),
                const Spacer(),
                TextButton(
                  onPressed: () => _request(Permission.locationWhenInUse, 'Location', () {
                    setState(() => _gpsCaptured = true);
                  }),
                  child: const Text('Capture GPS'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: () {}, child: const Text('Submit Evidence')),
            ),
          ],
        ),
      ),
    );
  }
}



