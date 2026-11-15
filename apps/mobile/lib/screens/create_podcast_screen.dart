import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:masaren/api_client.dart';

class CreatePodcastScreen extends StatefulWidget {
  const CreatePodcastScreen({super.key});

  @override
  State<CreatePodcastScreen> createState() => _CreatePodcastScreenState();
}

class _CreatePodcastScreenState extends State<CreatePodcastScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _category = TextEditingController(text: 'Media');
  final _sdg = TextEditingController();
  String _language = 'ar';
  String? _coverUrl;
  String? _coverPath;
  bool _uploading = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _category.dispose();
    _sdg.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 1800, imageQuality: 84);
    if (picked == null) return;
    setState(() {
      _coverPath = picked.path;
      _uploading = true;
      _error = null;
    });
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last.toLowerCase();
      final url = await AuthApi.uploadMedia(
          bytes,
          picked.name,
          ext == 'png'
              ? 'image/png'
              : ext == 'webp'
                  ? 'image/webp'
                  : 'image/jpeg');
      if (mounted) setState(() => _coverUrl = url);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().length < 3) {
      setState(() => _error = 'Add a podcast title with at least 3 characters.');
      return;
    }
    if (_description.text.trim().length < 10) {
      setState(() => _error =
          'Describe the show, its audience and the conversations it will host.');
      return;
    }
    if (_uploading) {
      setState(() => _error = 'Wait for the cover photo to finish uploading.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final show = await AuthApi.createPodcastShow({
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'category': _category.text.trim(),
        'language': _language,
        'sdg': int.tryParse(_sdg.text.trim()),
        'cover_url': _coverUrl,
      });
      if (mounted) Navigator.pop(context, show);
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = e is ApiException ? (e.message ?? '$e') : e.toString());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('New podcast show'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Create'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF2C6E8F), Color(0xFF174B43)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Build a show people return to',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 6),
                Text(
                    'A clear promise, a specific audience and a cover that looks credible from the first scroll.',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 12.5, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            maxLength: 160,
            decoration: const InputDecoration(
                labelText: 'Show title',
                helperText: 'Short, memorable and searchable.'),
          ),
          TextField(
            controller: _description,
            minLines: 4,
            maxLines: 8,
            maxLength: 3000,
            decoration: const InputDecoration(
              labelText: 'Show description',
              helperText:
                  'Who is it for, what will each episode deliver, and why should someone subscribe?',
              alignLabelWithHint: true,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _category,
                  decoration: const InputDecoration(
                      labelText: 'Category',
                      helperText: 'Media, business, education...'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _sdg,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'SDG (1-17)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _language,
            decoration: const InputDecoration(labelText: 'Language'),
            items: const [
              DropdownMenuItem(value: 'ar', child: Text('Arabic')),
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'ar-en', child: Text('Arabic + English')),
            ],
            onChanged: (v) => setState(() => _language = v ?? 'ar'),
          ),
          const SizedBox(height: 18),
          Text('Cover photo',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          InkWell(
            onTap: _uploading ? null : _pickCover,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: _coverPath != null
                  ? Image.file(File(_coverPath!),
                      fit: BoxFit.cover, width: double.infinity)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _uploading
                            ? const CircularProgressIndicator(strokeWidth: 2)
                            : Icon(Icons.add_photo_alternate_outlined,
                                size: 34, color: cs.primary),
                        const SizedBox(height: 6),
                        Text(
                            _uploading
                                ? 'Uploading photo...'
                                : 'Choose a cover from your device',
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        Text('No links needed',
                            style: TextStyle(
                                fontSize: 10.5,
                                color: cs.onSurfaceVariant.withValues(alpha: .7))),
                      ],
                    ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!,
                  style: TextStyle(color: cs.error, fontSize: 12.5)),
            ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy || _uploading ? null : _save,
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.podcasts),
            label: const Text('Create show'),
          ),
        ],
      ),
    );
  }
}
