import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:masaren/api_client.dart';

class CreateEpisodeScreen extends StatefulWidget {
  final String showId;
  final String showTitle;
  final String? eventId;
  const CreateEpisodeScreen(
      {super.key, required this.showId, required this.showTitle, this.eventId});

  @override
  State<CreateEpisodeScreen> createState() => _CreateEpisodeScreenState();
}

class _CreateEpisodeScreenState extends State<CreateEpisodeScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _guests = TextEditingController();
  final _season = TextEditingController(text: '1');
  final _episode = TextEditingController(text: '1');
  final _duration = TextEditingController();
  PlatformFile? _audioFile;
  String? _audioUrl;
  String? _coverUrl;
  String? _coverPath;
  bool _uploading = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _guests.dispose();
    _season.dispose();
    _episode.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg'],
      withData: false,
    );
    final file = result?.files.firstOrNull;
    if (file == null || file.path == null) return;
    setState(() {
      _audioFile = file;
      _uploading = true;
      _error = null;
    });
    try {
      final bytes = await File(file.path!).readAsBytes();
      final ext = file.name.split('.').last.toLowerCase();
      final type = ext == 'wav'
          ? 'audio/wav'
          : ext == 'm4a'
              ? 'audio/mp4'
              : ext == 'aac'
                  ? 'audio/aac'
                  : ext == 'ogg'
                      ? 'audio/ogg'
                      : 'audio/mpeg';
      final url = await AuthApi.uploadAudio(bytes, file.name, type);
      if (mounted) setState(() => _audioUrl = url);
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
      setState(() => _error = 'Add an episode title with at least 3 characters.');
      return;
    }
    if (_audioUrl == null) {
      setState(() => _error = 'Choose an audio file from your device.');
      return;
    }
    if (_uploading) {
      setState(() => _error = 'Wait for the media to finish uploading.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final minutes = int.tryParse(_duration.text.trim()) ?? 0;
      await AuthApi.createPodcastEpisode(widget.showId, {
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'audio_url': _audioUrl,
        'cover_url': _coverUrl,
        'duration_sec': minutes > 0 ? minutes * 60 : 0,
        'season_number': int.tryParse(_season.text.trim()) ?? 1,
        'episode_number': int.tryParse(_episode.text.trim()) ?? 1,
        if (widget.eventId != null)
          'event_id': int.tryParse(widget.eventId!),
        'guests': _guests.text
            .split(',')
            .map((g) => g.trim())
            .where((g) => g.isNotEmpty)
            .toList(),
      });
      if (mounted) Navigator.pop(context, true);
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
        title: Text('New episode · ${widget.showTitle}'),
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
              'Upload the episode audio directly from your phone. No file hosting or links required.',
              style: TextStyle(fontSize: 13, height: 1.45)),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            maxLength: 180,
            decoration: const InputDecoration(
                labelText: 'Episode title',
                helperText: 'The specific question or story this episode covers.'),
          ),
          TextField(
            controller: _description,
            minLines: 3,
            maxLines: 7,
            maxLength: 4000,
            decoration: const InputDecoration(
              labelText: 'Episode notes',
              helperText:
                  'Key points, timestamps, resources and what listeners should do next.',
              alignLabelWithHint: true,
            ),
          ),
          TextField(
            controller: _guests,
            decoration: const InputDecoration(
                labelText: 'Guests',
                helperText: 'Separate guest names with commas.'),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _uploading ? null : _pickAudio,
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
                      _audioUrl != null
                          ? Icons.check_circle
                          : Icons.audio_file_outlined,
                      color: _audioUrl != null ? cs.primary : cs.onSurfaceVariant,
                      size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            _audioUrl != null
                                ? 'Audio uploaded'
                                : 'Choose episode audio',
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(
                            _audioFile?.name ??
                                'MP3, WAV, M4A, AAC or OGG from your device',
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
                  controller: _season,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Season'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _episode,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Episode number'),
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
                child: Text('Episode cover (optional)',
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
            icon: const Icon(Icons.podcasts),
            label: const Text('Publish episode'),
          ),
        ],
      ),
    );
  }
}
