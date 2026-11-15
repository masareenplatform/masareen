import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:masaren/api_client.dart';

class CreateVodScreen extends StatefulWidget {
  const CreateVodScreen({super.key});

  @override
  State<CreateVodScreen> createState() => _CreateVodScreenState();
}

class _CreateVodScreenState extends State<CreateVodScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _category = TextEditingController(text: 'Event');
  final _sdg = TextEditingController();
  final _duration = TextEditingController();
  PlatformFile? _videoFile;
  String? _videoUrl;
  String? _hlsUrl;
  String? _videoPosterUrl;
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
    _duration.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: false,
    );
    final file = result?.files.firstOrNull;
    if (file == null || file.path == null) return;
    setState(() {
      _videoFile = file;
      _uploading = true;
      _error = null;
    });
    try {
      final bytes = await File(file.path!).readAsBytes();
      final ext = file.name.split('.').last.toLowerCase();
      final type = ext == 'mov' ? 'video/quicktime' : 'video/mp4';
      final uploaded = await AuthApi.uploadVideo(bytes, file.name, type);
      if (mounted) {
        setState(() {
          _videoUrl = uploaded['url']?.toString();
          _hlsUrl = uploaded['hls_url']?.toString();
          _videoPosterUrl = uploaded['poster_url']?.toString();
          if (_videoUrl == null && _hlsUrl == null) {
            _error = 'The video upload did not return a playable file.';
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
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
      setState(() => _error = 'Add a video title with at least 3 characters.');
      return;
    }
    if (_videoUrl == null && _hlsUrl == null) {
      setState(() => _error = 'Choose a video from your device.');
      return;
    }
    if (_uploading) {
      setState(() => _error = 'Wait for the video to finish uploading.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final minutes = int.tryParse(_duration.text.trim()) ?? 0;
      final video = await AuthApi.createVod({
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'video_url': _videoUrl,
        'hls_url': _hlsUrl,
        'cover_url': _coverUrl ?? _videoPosterUrl,
        'duration_sec': minutes > 0 ? minutes * 60 : 0,
        'category': _category.text.trim(),
        'sdg': int.tryParse(_sdg.text.trim()),
      });
      if (mounted) Navigator.pop(context, video);
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
        title: const Text('New VOD video'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Publish'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          const Text(
              'Upload a replay, interview, recap or product demo directly from your device. No links required.',
              style: TextStyle(fontSize: 13, height: 1.45)),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            maxLength: 180,
            decoration: const InputDecoration(
                labelText: 'Video title',
                helperText: 'What will someone learn or see?'),
          ),
          TextField(
            controller: _description,
            minLines: 3,
            maxLines: 7,
            maxLength: 4000,
            decoration: const InputDecoration(
              labelText: 'Description',
              helperText:
                  'Context, speakers, chapters and the follow-up action.',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _uploading ? null : _pickVideo,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: .45),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(
                      _videoUrl != null
                          ? Icons.check_circle
                          : Icons.video_file_outlined,
                      color:
                          _videoUrl != null ? cs.primary : cs.onSurfaceVariant,
                      size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            _videoUrl != null
                                ? 'Video uploaded'
                                : 'Choose video from device',
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(
                            _videoFile?.name ??
                                'MP4 or MOV · uploads and optimizes for playback',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11.5, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  if (_uploading)
                    const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    const Icon(Icons.upload_file),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _category,
                  decoration:
                      const InputDecoration(labelText: 'Category'),
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
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _duration,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Minutes', helperText: 'Approx.'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text('Cover image (optional)',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurfaceVariant)),
              ),
              TextButton.icon(
                onPressed: _uploading ? null : _pickCover,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: Text(_coverUrl == null ? 'Add cover' : 'Cover ready'),
              ),
            ],
          ),
          if (_coverPath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(_coverPath!),
                  height: 130, width: double.infinity, fit: BoxFit.cover),
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
            icon: const Icon(Icons.video_library_outlined),
            label: const Text('Publish video'),
          ),
        ],
      ),
    );
  }
}
