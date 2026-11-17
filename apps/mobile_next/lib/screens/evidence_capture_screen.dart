import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/widgets/animations.dart';
import 'package:masaren/widgets.dart';

class EvidenceCaptureScreen extends StatefulWidget {
  final User user;
  final String? targetType;
  final String? targetId;
  final String? targetTitle;
  final String? participantId;
  final bool createSubmission;
  const EvidenceCaptureScreen({
    super.key,
    required this.user,
    this.targetType,
    this.targetId,
    this.targetTitle,
    this.participantId,
    this.createSubmission = false,
  });

  @override
  State<EvidenceCaptureScreen> createState() => _EvidenceCaptureScreenState();
}

class _EvidenceCaptureScreenState extends State<EvidenceCaptureScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _claim = TextEditingController();
  final _targetId = TextEditingController();
  final _locationLabel = TextEditingController();
  final _sourceName = TextEditingController();
  final _witnesses = TextEditingController();
  final Map<String, TextEditingController> _fieldControllers = {};
  final List<XFile> _images = [];
  XFile? _video;
  String _captureSource = 'UNKNOWN';
  PlatformFile? _audio;
  final List<PlatformFile> _files = [];
  String _kind = 'PHOTO';
  String _targetType = 'PROGRAM';
  double? _lat;
  double? _lng;
  bool _gpsBusy = false;
  bool _busy = false;
  String? _error;

  static const _targets = [
    'POST',
    'PROGRAM',
    'PROJECT',
    'EVENT',
    'TASK',
    'OPPORTUNITY',
    'INSTITUTION',
    'RESEARCH_STAGE',
    'COURSE',
  ];
  static const _kinds = [
    'PHOTO',
    'VIDEO',
    'DOCUMENT',
    'GPS',
    'SENSOR',
    'TESTIMONY',
  ];
  static const _fieldDefs = <String, List<List<String>>>{
    'POST': [
      ['observed_change', 'Observed change'],
      ['metric', 'Measured metric'],
      ['source', 'Primary source'],
    ],
    'PROGRAM': [
      ['activity_date', 'Activity date'],
      ['beneficiaries', 'Beneficiaries reached'],
      ['outputs', 'Outputs delivered'],
    ],
    'PROJECT': [
      ['milestone', 'Milestone'],
      ['deliverable', 'Deliverable'],
      ['team', 'Team / partners'],
    ],
    'EVENT': [
      ['role', 'Your role'],
      ['attendance', 'Attendance'],
      ['venue', 'Venue'],
    ],
    'TASK': [
      ['task_outcome', 'Task outcome'],
      ['completion_date', 'Completion date'],
      ['quantity', 'Quantity / scope'],
    ],
    'OPPORTUNITY': [
      ['application_stage', 'Application stage'],
      ['result', 'Result / decision'],
      ['reference', 'Reference'],
    ],
    'INSTITUTION': [
      ['service', 'Service or activity'],
      ['claim_reference', 'Official reference'],
      ['authority', 'Issuing authority'],
    ],
    'RESEARCH_STAGE': [
      ['research_stage', 'Research stage'],
      ['sample_size', 'Sample size'],
      ['method', 'Method'],
    ],
    'COURSE': [
      ['lesson', 'Lesson / module'],
      ['completion', 'Completion evidence'],
      ['assessment', 'Assessment result'],
    ],
  };

  @override
  void initState() {
    super.initState();
    if (widget.targetType != null) _targetType = widget.targetType!;
    if (widget.targetId != null) _targetId.text = widget.targetId!;
    if (widget.targetTitle != null) _title.text = widget.targetTitle!;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _claim.dispose();
    _targetId.dispose();
    _locationLabel.dispose();
    _sourceName.dispose();
    _witnesses.dispose();
    for (final controller in _fieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _t(String key, String fallback) {
    final value = MasarenLocalizations.of(context, key);
    return value == key ? fallback : value;
  }

  TextEditingController _field(String key) =>
      _fieldControllers.putIfAbsent(key, () => TextEditingController());

  Future<void> _browseTarget() async {
    setState(() => _gpsBusy = true);
    try {
      final items = <Map<String, String>>[];
      switch (_targetType) {
        case 'PROGRAM':
          for (final p in await AuthApi.programs()) {
            items.add({'id': p.id, 'title': p.title});
          }
          break;
        case 'EVENT':
          for (final e in await AuthApi.events(includePast: true)) {
            items.add({'id': e.id, 'title': e.title});
          }
          break;
        case 'PROJECT':
          for (final p in await AuthApi.projects()) {
            items.add({'id': p.id, 'title': p.title});
          }
          break;
        case 'INSTITUTION':
          for (final i in await AuthApi.institutions()) {
            items.add({
              'id': (i['id'] ?? '').toString(),
              'title': (i['name'] ?? i['title'] ?? 'Institution').toString(),
            });
          }
          break;
        case 'RESEARCH_STAGE':
          for (final r in await AuthApi.researchStages()) {
            items.add({
              'id': (r['id'] ?? '').toString(),
              'title': (r['title'] ??
                      r['stage_title'] ??
                      r['focus_area'] ??
                      'Research stage')
                  .toString(),
            });
          }
          break;
        default:
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    'Enter the entity ID for this target type, or choose Program, Event, Project, Institution or Research stage.')));
          }
          return;
      }
      if (!mounted) return;
      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No entities found for this target yet.')));
        return;
      }
      final chosen = await showModalBottomSheet<Map<String, String>>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * .65,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text('Choose ${_targetType.toLowerCase()}',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w800))),
                      IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final item = items[index];
                      return ListTile(
                        leading: const Icon(Icons.link),
                        title: Text(item['title'] ?? ''),
                        subtitle: Text('#${item['id']}'),
                        onTap: () => Navigator.pop(ctx, item),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (chosen != null) {
        setState(() {
          _targetId.text = chosen['id'] ?? '';
          if (_title.text.trim().isEmpty) _title.text = chosen['title'] ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _gpsBusy = false);
    }
  }
  Future<void> _captureGps() async {
    setState(() => _gpsBusy = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) throw Exception('Location services are disabled.');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required for evidence.');
      }
      final position = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high));
      if (!mounted) return;
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _gpsBusy = false);
    }
  }

  Future<void> _capturePhoto() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.camera, maxWidth: 1800, imageQuality: 84);
    if (picked == null) return;
    setState(() {
      _images.add(picked);
      _video = null;
      _captureSource = 'CAMERA';
    });
  }

  Future<void> _captureVideo() async {
    final picked = await ImagePicker().pickVideo(
        source: ImageSource.camera, maxDuration: const Duration(minutes: 5));
    if (picked == null) return;
    setState(() {
      _video = picked;
      _images.clear();
      _captureSource = 'CAMERA';
    });
  }
  Future<void> _pickImages() async {
    final picked = await ImagePicker().pickMultiImage(
        maxWidth: 1800, imageQuality: 84, limit: 10 - _images.length);
    if (picked.isEmpty) return;
    setState(() {
      _images.addAll(picked.take(10 - _images.length));
      _video = null;
      _captureSource = 'GALLERY';
    });
  }

  Future<void> _pickVideo() async {
    final picked =
        await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() {
      _video = picked;
      _images.clear();
      _captureSource = 'GALLERY';
    });
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg'],
      withData: false,
    );
    final file = result?.files.firstOrNull;
    if (file != null) setState(() => _audio = file);
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
    );
    if (result == null) return;
    setState(() {
      _files.addAll(result.files.take(8 - _files.length));
    });
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final targetId = _targetId.text.trim();
    if (title.length < 3) {
      setState(() => _error =
          _t('evidence.titleError', 'Add a clear evidence title.'));
      return;
    }
    if (targetId.isEmpty) {
      setState(() => _error = _t(
          'evidence.targetError', 'Choose the exact entity this evidence proves.'));
      return;
    }
    if (_lat == null || _lng == null) {
      setState(() => _error = _t('evidence.gpsError',
          'Capture GPS so the evidence can be checked against the claimed place.'));
      return;
    }
    if (_description.text.trim().isEmpty &&
        _images.isEmpty &&
        _video == null &&
        _audio == null &&
        _files.isEmpty) {
      setState(() => _error = _t('evidence.contentError',
          'Add a description, photo, video, audio or document.'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final media = <Map<String, dynamic>>[];
      for (final image in _images) {
        final bytes = await image.readAsBytes();
        final ext = image.path.split('.').last.toLowerCase();
        final contentType = ext == 'png'
            ? 'image/png'
            : ext == 'webp'
                ? 'image/webp'
                : 'image/jpeg';
        final url =
            await AuthApi.uploadMedia(bytes, image.name, contentType);
        media.add({'type': 'IMAGE', 'url': url});
      }
      if (_video != null) {
        final bytes = await _video!.readAsBytes();
        final ext = _video!.path.split('.').last.toLowerCase();
        final contentType = ext == 'mov' ? 'video/quicktime' : 'video/mp4';
        final uploaded =
            await AuthApi.uploadVideo(bytes, _video!.name, contentType);
        if (uploaded['url'] is String) {
          media.add({
            'type': 'VIDEO',
            'url': uploaded['url'],
            if (uploaded['hls_url'] != null) 'hls_url': uploaded['hls_url'],
            if (uploaded['poster_url'] != null)
              'poster_url': uploaded['poster_url'],
          });
        }
      }
      if (_audio != null && _audio!.path != null) {
        final bytes = await File(_audio!.path!).readAsBytes();
        final url = await AuthApi.uploadAudio(
            bytes, _audio!.name, _audioContentType(_audio!.name));
        if (url.isNotEmpty) media.add({'type': 'AUDIO', 'url': url});
      }
      final files = <Map<String, dynamic>>[];
      for (final file in _files) {
        if (file.path == null) continue;
        final bytes = await File(file.path!).readAsBytes();
        final result =
            await AuthApi.uploadFile(bytes, file.name, 'application/octet-stream');
        final url = result['url'] as String?;
        if (url == null || url.isEmpty) continue;
        files.add({
          'url': url,
          'name': file.name,
          'size': file.size,
          'content_type': 'application/octet-stream',
        });
      }
      final fields = <String, String>{};
      for (final def in _fieldDefs[_targetType] ?? const <List<String>>[]) {
        final value = _field(def[0]).text.trim();
        if (value.isNotEmpty) fields[def[0]] = value;
      }
      final witnesses = _witnesses.text
          .split(',')
          .map((w) => w.trim())
          .where((w) => w.isNotEmpty)
          .toList();
      final created = await AuthApi.createEvidence({
        'title': title,
        'description': _description.text.trim(),
        if (_claim.text.trim().isNotEmpty) 'claim': _claim.text.trim(),
        'kind': _kind,
        'capture_source': _captureSource,
        'target_type': _targetType,
        'target_id': int.tryParse(targetId) ?? targetId,
        if (widget.participantId != null)
          'participant_id': int.tryParse(widget.participantId!),
        if (media.isNotEmpty) 'media': media,
        if (files.isNotEmpty) 'files': files,
        if (fields.isNotEmpty) 'fields': fields,
        if (witnesses.isNotEmpty) 'witnesses': witnesses,
        if (_sourceName.text.trim().isNotEmpty)
          'source_name': _sourceName.text.trim(),
        if (_locationLabel.text.trim().isNotEmpty)
          'location_label': _locationLabel.text.trim(),
        'latitude': _lat,
        'longitude': _lng,
        'captured_at': DateTime.now().toUtc().toIso8601String(),
      });
      final evidenceId = (created['id'] ?? '').toString();
      if (widget.createSubmission && evidenceId.isNotEmpty) {
        final submission = await AuthApi.createSubmission({
          'title': title,
          'claim': _claim.text.trim().isEmpty
              ? _description.text.trim()
              : _claim.text.trim(),
          'evidence_id': int.tryParse(evidenceId),
          'target_type': _targetType,
          'target_id': int.tryParse(targetId) ?? targetId,
        });
        await AuthApi.startPipeline(submission.id);
      }
      if (!mounted) return;
      await _showResult(created);
      if (mounted) Navigator.pop(context, created);
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = e is ApiException ? (e.message ?? '$e') : e.toString());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showResult(Map<String, dynamic> evidence) async {
    final verdict = (evidence['deepfake_verdict'] ?? 'UNSCANNED').toString();
    final signals = evidence['deepfake_signals'];
    final nsfw = signals is Map ? signals['nsfw_verdict'] : null;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Evidence scanned'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Target: ${evidence['target_type'] ?? _targetType} #${evidence['target_id'] ?? _targetId.text}'),
            const SizedBox(height: 6),
            Text('AI-content verdict: $verdict'),
            if (nsfw != null) Text('NSFW: $nsfw'),
            const SizedBox(height: 8),
            const Text(
                'The host will see this scan in the verification pipeline. Flagged evidence cannot be verified without an explicit override.'),
          ],
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done')),
        ],
      ),
    );
  }

  String _audioContentType(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'wav' => 'audio/wav',
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'ogg' => 'audio/ogg',
      _ => 'audio/mpeg',
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fixedTarget = widget.targetType != null;
    final fieldDefs = _fieldDefs[_targetType] ?? const <List<String>>[];
    return Scaffold(
      appBar: AppBar(
          title: Text(_t('evidence.captureTitle', 'Capture evidence'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          FadeSlideIn(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.primary.withValues(alpha: .16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.fact_check_outlined,
                          size: 19, color: cs.primary),
                      const SizedBox(width: 7),
                      Text(
                          _t('evidence.structuredTitle',
                              'Structured evidence record'),
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                      _t('evidence.structuredBody',
                          'Evidence is tied to one exact entity, captured with GPS, files and target-specific fields.'),
                      style: TextStyle(
                          fontSize: 11.5,
                          height: 1.45,
                          color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (!fixedTarget) ...[
            DropdownButtonFormField<String>(
              initialValue: _targetType,
              decoration: InputDecoration(
                  labelText: _t('evidence.targetType', 'What does this prove?')),
              items: _targets
                  .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(_t('evidence.target.$t', t))))
                  .toList(),
              onChanged: (v) => setState(() => _targetType = v ?? _targetType),
            ),
            const SizedBox(height: 10),
          ],
          if (!fixedTarget || widget.targetId == null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _targetId,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText:
                            _t('evidence.targetId', 'Target entity ID'),
                        helperText: widget.targetTitle),
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: IconButton.filledTonal(
                    tooltip: 'Choose target',
                    onPressed: _browseTarget,
                    icon: const Icon(Icons.travel_explore, size: 20),
                  ),
                ),
              ],
            )
          else
            _TargetChip(type: _targetType, id: widget.targetId!),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            maxLength: 160,
            decoration: InputDecoration(
                labelText: _t('evidence.title', 'Evidence title')),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _description,
            minLines: 3,
            maxLines: 8,
            maxLength: 4000,
            decoration: InputDecoration(
                labelText: _t('evidence.description',
                    'What happened, what was delivered, what can be checked')),
          ),
          if (widget.createSubmission)
            TextField(
              controller: _claim,
              maxLines: 3,
              decoration: InputDecoration(
                  labelText: _t('evidence.claim', 'Claim being verified')),
            ),
          const SizedBox(height: 10),
          Text(_t('evidence.kind', 'Evidence type'),
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: _kinds
                .map((k) => ChoiceChip(
                      label: Text(_t('evidence.kind.$k', k)),
                      selected: _kind == k,
                      onSelected: (_) => setState(() => _kind = k),
                    ))
                .toList(),
          ),
          const SizedBox(height: 14),
          if (fieldDefs.isNotEmpty) ...[
            Text(_t('evidence.details', 'Details for this target'),
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant)),
            const SizedBox(height: 6),
            ...fieldDefs.map((def) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: _field(def[0]),
                    decoration: InputDecoration(
                        labelText: _t('evidence.field.${def[0]}', def[1])),
                  ),
                )),
          ],
          const SizedBox(height: 6),
          TextField(
            controller: _locationLabel,
            decoration: InputDecoration(
                labelText:
                    _t('evidence.locationLabel', 'Claimed location')),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _gpsBusy ? null : _captureGps,
                icon: _gpsBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location, size: 18),
                label: Text(_lat == null
                    ? _t('evidence.captureGps', 'Capture GPS')
                    : '${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}'),
              ),
              if (_lat != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: Icon(Icons.verified,
                      size: 18, color: cs.primary),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sourceName,
            decoration: InputDecoration(
                labelText:
                    _t('evidence.sourceName', 'Source / collector name')),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _witnesses,
            decoration: InputDecoration(
                labelText: _t('evidence.witnesses',
                    'Witnesses (comma separated)')),
          ),
          const SizedBox(height: 14),
          Text(_t('evidence.attachments', 'Attachments'),
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AttachChip(
                  icon: Icons.photo_library_outlined,
                  label: '${_t('evidence.photos', 'Photos')} (${_images.length})',
                  onTap: _pickImages),
              _AttachChip(
                  icon: Icons.camera_alt_outlined,
                  label: 'Take photo',
                  onTap: _capturePhoto),
              _AttachChip(
                  icon: Icons.video_camera_back_outlined,
                  label: 'Record video',
                  onTap: _captureVideo),
              _AttachChip(
                  icon: Icons.videocam_outlined,
                  label: _video == null
                      ? _t('evidence.video', 'Video')
                      : _video!.name,
                  onTap: _pickVideo),
              _AttachChip(
                  icon: Icons.mic_none,
                  label: _audio == null
                      ? _t('evidence.audio', 'Audio')
                      : _audio!.name,
                  onTap: _pickAudio),
              _AttachChip(
                  icon: Icons.attach_file,
                  label: '${_t('evidence.files', 'Files')} (${_files.length})',
                  onTap: _pickFiles),
            ],
          ),
          if (_images.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, index) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(File(_images[index].path),
                            width: 80, height: 80, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Clickable(
                          onTap: () => setState(() => _images.removeAt(index)),
                          child: const CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.close,
                                  size: 13, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!,
                  style: TextStyle(color: cs.error, fontSize: 12.5)),
            ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50)),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.verified_outlined),
            label: Text(_t('evidence.submit',
                widget.createSubmission
                    ? 'Submit evidence & start verification'
                    : 'Save evidence')),
          ),
        ],
      ),
    );
  }
}

class _TargetChip extends StatelessWidget {
  final String type;
  final String id;
  const _TargetChip({required this.type, required this.id});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.link, size: 17, color: cs.primary),
          const SizedBox(width: 7),
          Text('$type #$id',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface)),
          const Spacer(),
          Icon(Icons.lock_outline, size: 15, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _AttachChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _AttachChip(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 17),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
