import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:url_launcher/url_launcher.dart';

class CreateLessonScreen extends StatefulWidget {
  final Course course;
  final User user;
  final CourseLesson? lesson;
  const CreateLessonScreen(
      {super.key,
      required this.course,
      required this.user,
      this.lesson});

  @override
  State<CreateLessonScreen> createState() => _CreateLessonScreenState();
}

class _CreateLessonScreenState extends State<CreateLessonScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _content = TextEditingController();
  final _duration = TextEditingController(text: '10');
  final _position = TextEditingController();
  final _linkUrl = TextEditingController();
  final _linkLabel = TextEditingController();
  final List<PostMedia> _media = [];
  final List<PostFile> _files = [];
  final List<LessonLink> _links = [];
  bool _isPreview = false;
  bool _busy = false;
  bool _uploading = false;
  String? _uploadLabel;

  String _t(String key, [String? fallback]) {
    final value = MasarenLocalizations.of(context, key);
    return value == key ? (fallback ?? key) : value;
  }

  @override
  void initState() {
    super.initState();
    final l = widget.lesson;
    if (l != null) {
      _title.text = l.title;
      _description.text = l.description ?? '';
      _content.text = l.content ?? '';
      _duration.text = '${l.durationMin}';
      _position.text = '${l.position}';
      _isPreview = l.isPreview;
      _media.addAll(l.media);
      _files.addAll(l.files);
      _links.addAll(l.links);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _content.dispose();
    _duration.dispose();
    _position.dispose();
    _linkUrl.dispose();
    _linkLabel.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await ImagePicker().pickMultiImage();
    if (picked.isEmpty) return;
    setState(() {
      _uploading = true;
      _uploadLabel = _t('lesson.uploadingImages', 'Uploading images...');
    });
    try {
      for (final image in picked.take(10)) {
        final bytes = await image.readAsBytes();
        final ext = image.path.split('.').last.toLowerCase();
        final ct = ext == 'png'
            ? 'image/png'
            : ext == 'webp'
                ? 'image/webp'
                : 'image/jpeg';
        final url = await AuthApi.uploadMedia(
            bytes, image.path.split(Platform.pathSeparator).last, ct);
        _media.add(PostMedia(url: url, type: 'IMAGE'));
      }
    } catch (e) {
      _snack(_t('common.failed').replaceAll('{error}', '$e'));
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadLabel = null;
        });
      }
    }
  }

  Future<void> _pickVideo() async {
    final picked = await ImagePicker().pickVideo(
        source: ImageSource.gallery, maxDuration: const Duration(minutes: 30));
    if (picked == null) return;
    setState(() {
      _uploading = true;
      _uploadLabel = _t('lesson.uploadingVideo', 'Uploading video...');
    });
    try {
      final bytes = await File(picked.path).readAsBytes();
      final ext = picked.path.split('.').last.toLowerCase();
      final ct = ext == 'webm'
          ? 'video/webm'
          : ext == 'mov'
              ? 'video/quicktime'
              : 'video/mp4';
      final result = await AuthApi.uploadVideo(
          bytes, picked.path.split(Platform.pathSeparator).last, ct);
      final rawUrl = result['url'] as String?;
      if (rawUrl != null && rawUrl.isNotEmpty) {
        final rawHls = result['hls_url'] as String?;
        final rawPoster = result['poster_url'] as String?;
        _media.removeWhere((m) => m.isVideo);
        _media.add(PostMedia(
          url: rawUrl,
          type: 'VIDEO',
          hlsUrl: rawHls == null
              ? null
              : (rawHls.startsWith('http') ? rawHls : '${api.baseUrl}$rawHls'),
          posterUrl: rawPoster == null
              ? null
              : (rawPoster.startsWith('http')
                  ? rawPoster
                  : '${api.baseUrl}$rawPoster'),
        ));
      }
    } catch (e) {
      _snack(_t('common.failed').replaceAll('{error}', '$e'));
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadLabel = null;
        });
      }
    }
  }

  Future<void> _pickAudio() async {
    final result =
        await FilePicker.platform.pickFiles(type: FileType.audio);
    final file = result?.files.first;
    if (file == null || file.path == null) return;
    if (file.size > 25 * 1024 * 1024) {
      _snack(_t('lesson.audioTooLarge', 'Audio must be 25 MB or smaller.'));
      return;
    }
    setState(() {
      _uploading = true;
      _uploadLabel = _t('lesson.uploadingAudio', 'Uploading audio...');
    });
    try {
      final bytes = await File(file.path!).readAsBytes();
      final ext = file.name.split('.').last.toLowerCase();
      final ct = ext == 'mp3'
          ? 'audio/mpeg'
          : ext == 'aac'
              ? 'audio/aac'
              : ext == 'ogg'
                  ? 'audio/ogg'
                  : ext == 'wav'
                      ? 'audio/wav'
                      : 'audio/mp4';
      final url = await AuthApi.uploadAudio(bytes, file.name, ct);
      if (url.isNotEmpty) {
        _media.removeWhere((m) => m.isAudio);
        _media.add(PostMedia(url: url, type: 'AUDIO'));
      }
    } catch (e) {
      _snack(_t('common.failed').replaceAll('{error}', '$e'));
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadLabel = null;
        });
      }
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'ppt',
        'pptx',
        'txt',
        'csv',
        'zip',
      ],
    );
    if (result == null) return;
    setState(() {
      _uploading = true;
      _uploadLabel = _t('lesson.uploadingFiles', 'Uploading files...');
    });
    try {
      for (final file in result.files) {
        if (file.path == null) continue;
        if (file.size > 25 * 1024 * 1024) continue;
        final bytes = await File(file.path!).readAsBytes();
        final ct = _contentTypeFor(file.name);
        final uploaded = await AuthApi.uploadFile(bytes, file.name, ct);
        final url = uploaded['url'] as String?;
        if (url == null || url.isEmpty) continue;
        _files.add(PostFile(
          url: url,
          name: (uploaded['name'] ?? file.name).toString(),
          size: file.size,
          contentType: ct,
        ));
      }
    } catch (e) {
      _snack(_t('common.failed').replaceAll('{error}', '$e'));
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadLabel = null;
        });
      }
    }
  }

  String _contentTypeFor(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'csv':
        return 'text/csv';
      case 'zip':
        return 'application/zip';
      default:
        return 'text/plain';
    }
  }

  void _addLink() {
    final url = _linkUrl.text.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      _snack(_t('lesson.invalidLink', 'Use a full https:// link.'));
      return;
    }
    setState(() {
      _links.add(LessonLink(
          url: url,
          label: _linkLabel.text.trim().isEmpty
              ? url
              : _linkLabel.text.trim()));
      _linkUrl.clear();
      _linkLabel.clear();
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().length < 2) {
      _snack(_t('lesson.titleRequired', 'Lesson title is required.'));
      return;
    }
    setState(() => _busy = true);
    try {
      final body = <String, dynamic>{
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'content': _content.text.trim(),
        'duration_min': int.tryParse(_duration.text) ?? 0,
        'position': int.tryParse(_position.text) ?? 0,
        'is_preview': _isPreview,
        if (_media.isNotEmpty)
          'media': _media
              .map((m) => {
                    'type': m.type,
                    'url': m.url,
                    if (m.hlsUrl != null) 'hls_url': m.hlsUrl,
                    if (m.posterUrl != null) 'poster_url': m.posterUrl,
                  })
              .toList(),
        if (_files.isNotEmpty)
          'files': _files
              .map((f) => {
                    'url': f.url,
                    'name': f.name,
                    if (f.size != null) 'size': f.size,
                    if (f.contentType != null)
                      'content_type': f.contentType,
                  })
              .toList(),
        if (_links.isNotEmpty)
          'links': _links
              .map((l) => {'url': l.url, 'label': l.label})
              .toList(),
      };
      final CourseLesson saved;
      if (widget.lesson == null) {
        saved = await AuthApi.addCourseLesson(widget.course.id, body);
      } else {
        saved = await AuthApi.updateCourseLesson(
            widget.course.id, widget.lesson!.id, body);
      }
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) {
        _snack(_t('common.failed').replaceAll('{error}', '$e'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lesson == null
            ? _t('lesson.create', 'New lesson')
            : _t('lesson.edit', 'Edit lesson')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          TextField(
            controller: _title,
            maxLength: 140,
            decoration: InputDecoration(
                labelText: _t('lesson.title', 'Lesson title')),
          ),
          TextField(
            controller: _description,
            maxLength: 2000,
            decoration: InputDecoration(
                labelText:
                    _t('lesson.summary', 'Short summary (optional)')),
          ),
          TextField(
            controller: _content,
            minLines: 5,
            maxLines: 14,
            decoration: InputDecoration(
                labelText: _t('lesson.content', 'Lesson notes and content')),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _duration,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: _t('lesson.duration', 'Minutes')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _position,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: _t('lesson.position', 'Order'),
                      hintText: '1, 2, 3...'),
                ),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _isPreview,
            onChanged: (value) => setState(() => _isPreview = value),
            title: Text(_t('lesson.preview', 'Free preview lesson'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
                _t('lesson.previewHint',
                    'Anyone can open this lesson before enrolling.'),
                style:
                    TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          ),
          const Divider(height: 30),
          Text(_t('lesson.attachments', 'Attachments'),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
              _t('lesson.attachmentsHint',
                  'Add images, a video, audio (podcast), documents or resource links.'),
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(Icons.photo_library_outlined,
                  _t('lesson.addImages', 'Images'), _uploading ? null : _pickImages),
              _chip(Icons.videocam_outlined,
                  _t('lesson.addVideo', 'Video'), _uploading ? null : _pickVideo),
              _chip(Icons.mic_none_rounded,
                  _t('lesson.addAudio', 'Audio'), _uploading ? null : _pickAudio),
              _chip(Icons.attach_file_rounded,
                  _t('lesson.addFiles', 'Files'), _uploading ? null : _pickFiles),
            ],
          ),
          if (_uploading) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 10),
                Text(_uploadLabel ?? _t('lesson.uploading', 'Uploading...')),
              ],
            ),
          ],
          if (_media.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(_t('lesson.media', 'Media'),
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 12.5)),
            const SizedBox(height: 6),
            ..._media.map((m) => Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    leading: Icon(m.isVideo
                        ? Icons.videocam_outlined
                        : m.isAudio
                            ? Icons.mic_none
                            : Icons.image_outlined),
                    title: Text(
                        m.isVideo
                            ? _t('lesson.video', 'Video')
                            : m.isAudio
                                ? _t('lesson.audio', 'Audio')
                                : _t('lesson.image', 'Image'),
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(m.url,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      onPressed: () => setState(() => _media.remove(m)),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ),
                )),
          ],
          if (_files.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(_t('lesson.files', 'Files'),
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 12.5)),
            const SizedBox(height: 6),
            ..._files.map((f) => Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    leading:
                        const Icon(Icons.description_outlined, size: 20),
                    title: Text(f.name,
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(f.url,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      onPressed: () => setState(() => _files.remove(f)),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ),
                )),
          ],
          const SizedBox(height: 14),
          Text(_t('lesson.links', 'Resource links'),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _linkUrl,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                      labelText: _t('lesson.linkUrl', 'https://...')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _linkLabel,
                  decoration: InputDecoration(
                      labelText: _t('lesson.linkLabel', 'Label')),
                ),
              ),
              IconButton(
                  onPressed: _addLink, icon: const Icon(Icons.add_link)),
            ],
          ),
          const SizedBox(height: 6),
          ..._links.map((l) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link, size: 20),
                title: Text(l.label,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(l.url,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  onPressed: () => setState(() => _links.remove(l)),
                  icon: const Icon(Icons.close, size: 18),
                ),
                onTap: () async {
                  final uri = Uri.tryParse(l.url);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                  }
                },
              )),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy || _uploading ? null : _save,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(_t('lesson.save', 'Save lesson')),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, VoidCallback? onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label),
    );
  }
}
