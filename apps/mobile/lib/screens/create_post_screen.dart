import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/models.dart';
import 'package:masaren/profile_ui.dart';
import 'package:masaren/widgets/voice_recorder_sheet.dart';

class CreatePostScreen extends StatefulWidget {
  final User user;
  final Post? initial;
  final String? initialKind;
  const CreatePostScreen(
      {super.key, required this.user, this.initial, this.initialKind});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _text = TextEditingController();
  final _program = TextEditingController();
  final _link = TextEditingController();
  final _place = TextEditingController();
  final Map<String, TextEditingController> _metricCtrl = {};
  int _sdg = 0;
  String _kind = 'story';
  final List<_PickedImage> _images = [];
  final List<PlatformFile> _files = [];
  PlatformFile? _voice;
  XFile? _video;
  String _captureSource = 'UNKNOWN';
  bool _busy = false;
  bool _showAdvanced = false;
  double? _lat;
  double? _lng;
  bool _gpsLoading = false;

  static const _kinds = [
    _KindOption(
        'story', 'post.story', Icons.auto_stories, ProfileColors.forest),
    _KindOption(
        'impact', 'post.impact', Icons.trending_up, ProfileColors.emerald),
    _KindOption('evidence', 'post.evidence', Icons.eco, ProfileColors.petrol),
    _KindOption('program', 'post.program', Icons.hub, ProfileColors.forest),
    _KindOption(
        'task', 'post.task', Icons.check_circle, ProfileColors.graphite),
    _KindOption(
        'announcement', 'post.platform', Icons.campaign, ProfileColors.gold),
    _KindOption('recognition', 'post.recognition', Icons.emoji_events,
        ProfileColors.rose),
    _KindOption('course', 'post.course', Icons.school, ProfileColors.petrol),
    _KindOption('event', 'post.event', Icons.event, ProfileColors.emerald),
  ];

  static const _sdgKeys = [
    'sdg.0',
    'sdg.1',
    'sdg.2',
    'sdg.3',
    'sdg.4',
    'sdg.5',
    'sdg.6',
    'sdg.7',
    'sdg.8',
    'sdg.9',
    'sdg.10',
    'sdg.11',
    'sdg.12',
    'sdg.13',
    'sdg.14',
    'sdg.15',
    'sdg.16',
    'sdg.17',
  ];

  static const Map<String, Map<String, _ImpactMetricDef>> _impactMetricDefs = {
    'environmental': {
      'co2_kg': _ImpactMetricDef('CO2 avoided / sequestered', 'kg'),
      'water_liters': _ImpactMetricDef('Water saved', 'litres'),
      'trees': _ImpactMetricDef('Trees planted', 'trees'),
      'biodiversity': _ImpactMetricDef('Biodiversity score', '0-1'),
    },
    'social': {
      'people_reached': _ImpactMetricDef('People reached', 'people'),
      'volunteer_hours': _ImpactMetricDef('Volunteer hours', 'hours'),
      'lives_improved': _ImpactMetricDef('Lives improved', 'people'),
      'inclusion': _ImpactMetricDef('Inclusion score', '0-1'),
    },
    'economic': {
      'income_egp': _ImpactMetricDef('Income generated', 'EGP'),
      'jobs': _ImpactMetricDef('Jobs created', 'jobs'),
      'local_gdp_egp': _ImpactMetricDef('Local GDP contribution', 'EGP'),
    },
    'governance': {
      'transparency': _ImpactMetricDef('Transparency score', '0-100'),
      'policy_adherence': _ImpactMetricDef('Policy adherence', '%'),
      'community_engagement': _ImpactMetricDef('Community engagement', '0-1'),
    },
    'educational': {
      'students_reached': _ImpactMetricDef('Students reached', 'students'),
      'learning_hours': _ImpactMetricDef('Learning hours', 'hours'),
      'curriculum': _ImpactMetricDef('Curriculum coverage', '%'),
      'retention': _ImpactMetricDef('Knowledge retention', '%'),
    },
    'infrastructure': {
      'facilities': _ImpactMetricDef('Facilities built', 'facilities'),
      'maintenance_hours': _ImpactMetricDef('Maintenance hours', 'hours'),
      'access': _ImpactMetricDef('People with new access', 'people'),
    },
  };
  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _text.text = widget.initial!.text;
      _program.text = widget.initial!.programTag ?? '';
      _link.text = widget.initial!.linkUrl ?? '';
      _sdg = widget.initial!.sdg ?? 0;
      _kind = widget.initial!.kind ?? 'story';
    }
    if (widget.initialKind != null) _kind = widget.initialKind!;
  }

  @override
  void dispose() {
    _text.dispose();
    _program.dispose();
    _link.dispose();
    _place.dispose();
    for (final controller in _metricCtrl.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_images.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(MasarenLocalizations.of(context, 'createPost.photoLimit'))));
      return;
    }
    final picked = await ImagePicker().pickMultiImage(
        maxWidth: 1600, imageQuality: 82, limit: 10 - _images.length);
    if (picked.isEmpty) return;
    final added = <_PickedImage>[];
    for (final x in picked.take(10 - _images.length)) {
      added.add(_PickedImage(await x.readAsBytes(), x.name));
    }
    if (!mounted) return;
    setState(() {
      _video = null;
      _captureSource = 'GALLERY';
      _images.addAll(added);
    });
  }

  Future<void> _takePhoto() async {
    final x = await ImagePicker().pickImage(
        source: ImageSource.camera, maxWidth: 1600, imageQuality: 82);
    if (x != null) {
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      setState(() {
        _video = null;
        _captureSource = 'CAMERA';
        if (_images.length < 10) {
          _images.add(_PickedImage(bytes, x.name));
        }
      });
    }
  }

  Future<void> _takeVideo() async {
    final x = await ImagePicker().pickVideo(
        source: ImageSource.camera, maxDuration: const Duration(minutes: 10));
    if (x != null) {
      setState(() {
        _video = x;
        _captureSource = 'CAMERA';
        _images.clear();
      });
    }
  }
  Future<void> _pickVideo() async {
    final x = await ImagePicker().pickVideo(
        source: ImageSource.gallery, maxDuration: const Duration(minutes: 10));
    if (x != null) {
      setState(() {
        _video = x;
        _captureSource = 'GALLERY';
        _images.clear();
      });
    }
  }

  Future<void> _showVoiceMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.mic_none_rounded),
              title: const Text('Record a voice note'),
              subtitle: const Text(
                  'Use the microphone with noise filtering and echo cancellation.'),
              onTap: () => Navigator.pop(ctx, 'record'),
            ),
            ListTile(
              leading: const Icon(Icons.audio_file_outlined),
              title: const Text('Choose an audio file'),
              subtitle: const Text('MP3, WAV, M4A, AAC or OGG.'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'record') {
      final recorded = await showVoiceRecorder(context);
      if (recorded == null || !mounted) return;
      final file = File(recorded.path);
      final size = await file.length();
      if (!mounted) return;
      setState(() => _voice = PlatformFile(
            name: recorded.name,
            size: size,
            path: recorded.path,
          ));
    } else if (choice == 'file') {
      await _pickVoice();
    }
  }
  Future<void> _pickVoice() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.size > 25 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              MasarenLocalizations.of(context, 'createPost.fileTooLarge'))));
      return;
    }
    setState(() => _voice = file);
  }

  String _audioTypeFor(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'mp3':
        return 'audio/mpeg';
      case 'aac':
        return 'audio/aac';
      case 'ogg':
        return 'audio/ogg';
      case 'wav':
        return 'audio/wav';
      case 'webm':
        return 'audio/webm';
      default:
        return 'audio/mp4';
    }
  }

  Future<void> _pickFiles() async {
    if (_files.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(MasarenLocalizations.of(context, 'createPost.fileLimit'))));
      return;
    }
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
        'zip'
      ],
    );
    if (!mounted || result == null) return;
    final accepted = <PlatformFile>[];
    for (final file in result.files) {
      if (_files.length + accepted.length >= 5) break;
      if (file.size > 25 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                MasarenLocalizations.of(context, 'createPost.fileTooLarge'))));
        continue;
      }
      accepted.add(file);
    }
    if (accepted.isNotEmpty) setState(() => _files.addAll(accepted));
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

  Future<void> _editCaption(int index) async {
    if (index < 0 || index >= _images.length) return;
    final controller = TextEditingController(text: _images[index].caption);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            Text(MasarenLocalizations.of(context, 'createPost.photoCaption')),
        content: TextField(
          controller: controller,
          maxLength: 240,
          maxLines: 3,
          decoration: InputDecoration(
              hintText:
                  MasarenLocalizations.of(context, 'createPost.photoHint')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(MasarenLocalizations.of(context, 'action.cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(MasarenLocalizations.of(context, 'action.save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) setState(() => _images[index].caption = value);
  }

  Future<void> _captureGps() async {
    if (!mounted) return;
    setState(() => _gpsLoading = true);
    try {
      bool serviceEnabled = false;
      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(MasarenLocalizations.of(
                    context, 'createPost.locationCheckFailed'))),
          );
        }
        return;
      }
      if (!serviceEnabled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(MasarenLocalizations.of(
                  context, 'createPost.locationDisabled'))),
        );
        return;
      }

      LocationPermission permission = LocationPermission.denied;
      try {
        permission = await Geolocator.checkPermission();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(MasarenLocalizations.of(
                    context, 'createPost.locationPermissionCheckFailed'))),
          );
        }
        return;
      }
      if (permission == LocationPermission.denied) {
        try {
          permission = await Geolocator.requestPermission();
        } catch (_) {}
        if (permission == LocationPermission.denied && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(MasarenLocalizations.of(
                    context, 'createPost.locationDenied'))),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(MasarenLocalizations.of(
                  context, 'createPost.locationPermanentlyDenied'))),
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ));
      if (mounted) {
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
        });
      }
      AuthApi.captureGps({
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'accuracy': pos.accuracy,
        'altitude': pos.altitude,
        'speed': pos.speed,
        'heading': pos.heading,
        'captured_at': DateTime.now().toUtc().toIso8601String(),
      }).catchError((_) => <String, dynamic>{});
    } catch (e) {
      if (mounted) {
        debugPrint('GPS error: $e');
      }
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  Future<void> _submit() async {
    final text = _text.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(MasarenLocalizations.of(context, 'createPost.writeFirst'))));
      return;
    }
    if ((_kind == 'impact' || _kind == 'evidence') && _lat == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'GPS is required for impact and evidence posts so the claimed place can be checked.')));
      return;
    }
    if (_kind == 'evidence' &&
        _link.text.trim().isEmpty &&
        _images.isEmpty &&
        _files.isEmpty &&
        _voice == null &&
        _video == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Add a proof link, image, file or video for evidence.')));
      return;
    }
    setState(() => _busy = true);
    try {
      final media = <Map<String, dynamic>>[];
      for (final image in _images) {
        final bytes = image.bytes;
        final ext = image.name.split('.').last.toLowerCase();
        final ct = ext == 'png'
            ? 'image/png'
            : ext == 'webp'
                ? 'image/webp'
                : 'image/jpeg';
        final url = await AuthApi.uploadMedia(
            bytes, image.name, ct);
        media.add({
          'type': 'IMAGE',
          'url': url,
          if (image.caption.trim().isNotEmpty) 'caption': image.caption.trim(),
        });
      }

      String? videoUrl;
      String? videoJobId;
      String? videoHlsUrl;
      String? videoPosterUrl;
      if (_video != null) {
        final bytes = await _video!.readAsBytes();
        final ext = _video!.name.split('.').last.toLowerCase();
        final ct = ext == 'webm'
            ? 'video/webm'
            : ext == 'mov'
                ? 'video/quicktime'
                : 'video/mp4';
        final result =
            await AuthApi.uploadVideo(bytes, _video!.name, ct);
        videoUrl = result['url'] as String?;
        videoJobId = (result['job_id'] ?? result['video_job_id']) as String?;
        final rawHls = result['hls_url'] as String?;
        videoHlsUrl = rawHls == null
            ? null
            : (rawHls.startsWith('http') ? rawHls : '${api.baseUrl}$rawHls');
        final rawPoster = result['poster_url'] as String?;
        videoPosterUrl = rawPoster == null
            ? null
            : (rawPoster.startsWith('http')
                ? rawPoster
                : '${api.baseUrl}$rawPoster');
        if (videoUrl != null && videoUrl.isNotEmpty) {
          media.add({
            'type': 'VIDEO',
            'url': videoUrl,
            if (videoHlsUrl != null) 'hls_url': videoHlsUrl,
            if (videoPosterUrl != null) 'poster_url': videoPosterUrl,
          });
        }
      }

      if (_voice != null) {
        final bytes = _voice!.bytes ??
            (_voice!.path == null
                ? null
                : await File(_voice!.path!).readAsBytes());
        if (bytes != null) {
          final url = await AuthApi.uploadAudio(
              bytes, _voice!.name, _audioTypeFor(_voice!.name));
          if (url.isNotEmpty) {
            media.add({'type': 'AUDIO', 'url': url});
          }
        }
      }

      final files = <Map<String, dynamic>>[];
      for (final file in _files) {
        final bytes = file.bytes ??
            (file.path == null ? null : await File(file.path!).readAsBytes());
        if (bytes == null) continue;
        final ct = _contentTypeFor(file.name);
        final result = await AuthApi.uploadFile(bytes, file.name, ct);
        final url = result['url'] as String?;
        if (url == null || url.isEmpty) continue;
        files.add({
          'url': url,
          'name': (result['name'] ?? file.name).toString(),
          'size': file.size,
          'content_type': ct,
        });
      }

      final body = <String, dynamic>{
        'text': text,
        'kind': _kind,
        'capture_source': _captureSource,
        'author_name': widget.user.fullName,
        'author_handle': widget.user.email.split('@').first,
      };

      if (_program.text.trim().isNotEmpty) {
        body['program_tag'] = _program.text.trim();
      }
      if (_link.text.trim().isNotEmpty) body['link_url'] = _link.text.trim();
      if (_sdg > 0) body['sdg'] = _sdg;
      final metricValues = <String, Map<String, double>>{};
      for (final domain in _impactMetricDefs.entries) {
        final values = <String, double>{};
        for (final metric in domain.value.keys) {
          final value = double.tryParse(_metricCtrl['.']?.text.trim() ?? '');
          if (value != null && value > 0) values[metric] = value;
        }
        if (values.isNotEmpty) metricValues[domain.key] = values;
      }
      if (metricValues.isNotEmpty) body['impact_metrics'] = metricValues;
      if (_place.text.trim().isNotEmpty) {
        body['location_claim'] = _place.text.trim();
      }
      if (media.isNotEmpty) body['media'] = media;
      if (files.isNotEmpty) body['files'] = files;
      if (videoJobId != null) body['video_job_id'] = videoJobId;
      if (videoHlsUrl != null) body['video_hls_url'] = videoHlsUrl;
      if (videoPosterUrl != null) body['video_poster_url'] = videoPosterUrl;
      if (_lat != null && _lng != null) {
        body['latitude'] = _lat;
        body['longitude'] = _lng;
      }

      if (widget.initial != null) {
        await AuthApi.editPostFull(widget.initial!.id, body);
      } else {
        await AuthApi.createPost(body);
      }
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(MasarenLocalizations.of(
                context,
                widget.initial != null
                    ? 'createPost.updated'
                    : 'createPost.published'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(MasarenLocalizations.of(context, 'common.failed')
                .replaceAll('{error}', '$e'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(directionalBackIcon(context), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(MasarenLocalizations.of(context, 'createPost.newPost')),
        actions: [
          TextButton(
            onPressed: _busy ? null : _submit,
            style: TextButton.styleFrom(
              foregroundColor: cs.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: _busy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: cs.primary))
                : Text(MasarenLocalizations.of(context, 'createPost.post'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildComposerHero(cs, dark),
          const SizedBox(height: 18),
          Text(MasarenLocalizations.of(context, 'createPost.postType'),
              style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _kinds.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final k = _kinds[i];
                final sel = _kind == k.value;
                return GestureDetector(
                  onTap: () => setState(() => _kind = k.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 82,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: sel
                          ? k.color.withValues(alpha: dark ? 0.3 : 0.15)
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: sel ? k.color : cs.outlineVariant,
                          width: sel ? 2 : 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(k.icon,
                            color: sel ? k.color : cs.onSurfaceVariant,
                            size: 24),
                        const SizedBox(height: 4),
                        Text(MasarenLocalizations.of(context, k.label),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  sel ? FontWeight.w700 : FontWeight.w500,
                              color: sel ? k.color : cs.onSurfaceVariant,
                            )),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _text,
            maxLines: 5,
            minLines: 3,
            style: TextStyle(color: cs.onSurface, fontSize: 15),
            decoration: InputDecoration(
              hintText: _kindHint(context),
              hintStyle: TextStyle(color: cs.onSurfaceVariant),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          if (_images.isNotEmpty)
            SizedBox(
              height: 148,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final image = _images[i];
                  return GestureDetector(
                    onTap: () => _editCaption(i),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.memory(
                            image.bytes,
                            width: 148,
                            height: 148,
                            fit: BoxFit.cover,
                          ),
                        ),
                        if (image.caption.isNotEmpty)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(8, 18, 8, 6),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black87],
                                ),
                              ),
                              child: Text(
                                image.caption,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11),
                              ),
                            ),
                          ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => setState(() => _images.removeAt(i)),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                                color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.edit,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          if (_video != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    color: Colors.black,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.videocam,
                            color: Colors.white, size: 48),
                        const SizedBox(height: 8),
                        Text(_video!.name,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() => _video = null),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          if (_voice != null) ...[
            const SizedBox(height: 10),
            _buildVoicePreview(cs),
          ],
          if (_files.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildFilesPreview(cs, dark),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _BuildChip(
                  icon: Icons.photo_library_outlined,
                  label: MasarenLocalizations.of(context, 'createPost.gallery'),
                  onTap: _pickImage,
                  cs: cs),
              _BuildChip(
                  icon: Icons.camera_alt_outlined,
                  label: MasarenLocalizations.of(context, 'createPost.camera'),
                  onTap: _takePhoto,
                  cs: cs),
              _BuildChip(
                  icon: Icons.videocam_outlined,
                  label: MasarenLocalizations.of(context, 'createPost.video'),
                  onTap: _pickVideo,
                  cs: cs),
              _BuildChip(
                  icon: Icons.video_camera_back_outlined,
                  label: 'Reel',
                  onTap: _takeVideo,
                  cs: cs),
              _BuildChip(
                  icon: Icons.mic_none_rounded,
                  label:
                      MasarenLocalizations.of(context, 'createPost.voiceNote'),
                  onTap: _showVoiceMenu,
                  cs: cs,
                  active: _voice != null),
              _BuildChip(
                  icon: Icons.attach_file_rounded,
                  label: MasarenLocalizations.of(context, 'createPost.addFile'),
                  onTap: _pickFiles,
                  cs: cs,
                  active: _files.isNotEmpty),
              _BuildChip(
                icon: Icons.my_location,
                label: MasarenLocalizations.of(
                    context,
                    _lat != null
                        ? 'createPost.gpsCaptured'
                        : 'createPost.addGps'),
                onTap: _captureGps,
                cs: cs,
                active: _lat != null,
                loading: _gpsLoading,
              ),
              _BuildChip(
                icon: Icons.expand_more,
                label: MasarenLocalizations.of(context,
                    _showAdvanced ? 'createPost.less' : 'createPost.more'),
                onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                cs: cs,
                active: _showAdvanced,
              ),
            ],
          ),
          if (_lat != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on,
                      color: AppColors.accent, size: 16),
                  const SizedBox(width: 6),
                  Text(
                      '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                      style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
          if (_hasKindDetails) ...[
            const SizedBox(height: 16),
            _buildKindDetails(cs),
          ],
          if (_showAdvanced) ...[
            const SizedBox(height: 16),
            Divider(color: cs.outlineVariant),
            const SizedBox(height: 12),
            if (!_showsProgram) ...[
              _detailLabel(cs, 'createPost.linkProgram'),
              const SizedBox(height: 8),
              _programField(cs),
              const SizedBox(height: 16),
            ],
            if (!_showsImpact) ...[
              _impactFields(cs),
              const SizedBox(height: 16),
            ],
            _detailLabel(cs, 'createPost.sdgGoal'),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 17,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final sdg = i + 1;
                  final sel = _sdg == sdg;
                  return GestureDetector(
                    onTap: () => setState(() => _sdg = sel ? 0 : sdg),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      decoration: BoxDecoration(
                        color:
                            sel ? _sdgColor(sdg) : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text('$sdg',
                          style: TextStyle(
                            color: sel ? Colors.white : cs.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          )),
                    ),
                  );
                },
              ),
            ),
            if (_sdg > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(MasarenLocalizations.of(context, _sdgKeys[_sdg]),
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              ),
            if (!_showsLink) ...[
              const SizedBox(height: 16),
              _detailLabel(cs, 'createPost.linkUrl'),
              const SizedBox(height: 8),
              _linkField(cs),
            ],
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildComposerHero(ColorScheme cs, bool dark) {
    final option =
        _kinds.firstWhere((k) => k.value == _kind, orElse: () => _kinds.first);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [option.color, option.color.withValues(alpha: 0.78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: option.color.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: Icon(option.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      MasarenLocalizations.of(context, option.label),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800),
                    ),
                    Text(
                      MasarenLocalizations.of(
                          context, 'createPost.postingPublicly'),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              AppAvatar(
                  name: widget.user.fullName,
                  url: widget.user.avatarUrl,
                  size: 36),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _kindHint(context),
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.86),
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildVoicePreview(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.primary.withValues(alpha: 0.25))),
      child: Row(
        children: [
          Icon(Icons.graphic_eq_rounded, color: cs.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
                '${MasarenLocalizations.of(context, 'createPost.voiceNote')} · ${_voice!.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
          IconButton(
            onPressed: () => setState(() => _voice = null),
            icon: const Icon(Icons.close, size: 18),
            tooltip: MasarenLocalizations.of(context, 'createPost.removeFile'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesPreview(ColorScheme cs, bool dark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _files.map((file) {
        final ext = file.name.split('.').last.toUpperCase();
        return Container(
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.fromLTRB(10, 7, 6, 7),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF1A2622) : const Color(0xFFF1F4EF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color:
                    dark ? const Color(0xFF2E3B36) : const Color(0xFFDDE5DE)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insert_drive_file_outlined,
                  size: 17, color: cs.primary),
              const SizedBox(width: 7),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600)),
                    Text('$ext  ·  ${(file.size / 1024).ceil()} KB',
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 10)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _files.remove(file)),
                icon: const Icon(Icons.close_rounded, size: 15),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  bool get _showsImpact => _kind == 'impact' || _kind == 'evidence';

  bool get _showsProgram => _kind == 'program' || _kind == 'task';

  bool get _showsLink =>
      _kind == 'evidence' ||
      _kind == 'event' ||
      _kind == 'course' ||
      _kind == 'announcement' ||
      _kind == 'recognition';

  bool get _hasKindDetails => _showsImpact || _showsProgram || _showsLink;

  Widget _detailLabel(ColorScheme cs, String key) {
    return Text(MasarenLocalizations.of(context, key),
        style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.w500));
  }

  Widget _buildKindDetails(ColorScheme cs) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final option =
        _kinds.firstWhere((k) => k.value == _kind, orElse: () => _kinds.first);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: option.color.withValues(alpha: dark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: option.color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 18, color: option.color),
              const SizedBox(width: 7),
              Text(
                MasarenLocalizations.of(context, 'createPost.details'),
                style: TextStyle(
                    color: option.color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (_showsImpact) ...[
            const SizedBox(height: 12),
            _impactFields(cs),
          ],
          if (_showsProgram) ...[
            const SizedBox(height: 12),
            _programField(cs),
          ],
          if (_showsLink) ...[
            const SizedBox(height: 12),
            _linkField(cs),
          ],
        ],
      ),
    );
  }

  Widget _programField(ColorScheme cs) {
    return TextField(
      controller: _program,
      style: TextStyle(color: cs.onSurface),
      decoration: InputDecoration(
        hintText: MasarenLocalizations.of(context, 'createPost.programHint'),
        prefixIcon: const Icon(Icons.hub, size: 20),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _impactFields(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Impact is non-linear: each domain saturates, decays over time, and is weighted by evidence coverage, actor history, consistency and community confirmation. GPS is optional and only adds a geographic confidence factor.',
          style: TextStyle(
              fontSize: 11.5, height: 1.45, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _place,
          style: TextStyle(color: cs.onSurface, fontSize: 13),
          decoration: const InputDecoration(
            labelText: 'Claimed location (city, venue, site)',
            prefixIcon: Icon(Icons.place_outlined, size: 19),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        ..._impactMetricDefs.entries
            .map((domain) => _impactDomainCard(cs, domain.key, domain.value)),
      ],
    );
  }

  Widget _impactDomainCard(
      ColorScheme cs, String domain, Map<String, _ImpactMetricDef> defs) {
    final meta = switch (domain) {
      'environmental' => ('Environment', Icons.eco_outlined),
      'social' => ('Social', Icons.groups_outlined),
      'economic' => ('Economic', Icons.trending_up),
      'governance' => ('Governance', Icons.account_balance_outlined),
      'educational' => ('Education', Icons.school_outlined),
      'infrastructure' => ('Infrastructure', Icons.construction_outlined),
      _ => (domain, Icons.insights),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(meta.$2, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text(meta.$1,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface)),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: defs.entries.map((entry) {
              final controller = _metricCtrl.putIfAbsent(
                  '$domain.${entry.key}', () => TextEditingController());
              return SizedBox(
                width: (MediaQuery.sizeOf(context).width - 80) / 2,
                child: TextField(
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: cs.onSurface, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: entry.value.label,
                    suffixText: entry.value.unit,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _linkField(ColorScheme cs) {
    return TextField(
      controller: _link,
      keyboardType: TextInputType.url,
      style: TextStyle(color: cs.onSurface),
      decoration: InputDecoration(
        hintText: MasarenLocalizations.of(context, 'createPost.linkUrlHint'),
        prefixIcon: const Icon(Icons.link_rounded, size: 20),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  String _kindHint(BuildContext context) {
    if (_kind == 'course') {
      return MasarenLocalizations.of(context, 'createPost.hint.course');
    }
    if (_kind == 'event') {
      return MasarenLocalizations.of(context, 'createPost.hint.event');
    }
    switch (_kind) {
      case 'impact':
        return MasarenLocalizations.of(context, 'createPost.hint.impact');
      case 'evidence':
        return MasarenLocalizations.of(context, 'createPost.hint.evidence');
      case 'program':
        return MasarenLocalizations.of(context, 'createPost.hint.program');
      case 'task':
        return MasarenLocalizations.of(context, 'createPost.hint.task');
      case 'announcement':
        return MasarenLocalizations.of(context, 'createPost.hint.announcement');
      case 'recognition':
        return MasarenLocalizations.of(context, 'createPost.hint.recognition');
      default:
        return MasarenLocalizations.of(context, 'createPost.hint.story');
    }
  }

  static Color _sdgColor(int sdg) {
    const colors = [
      Colors.transparent,
      Color(0xFFE5243B),
      Color(0xFFDDA63A),
      Color(0xFF4C9F38),
      Color(0xFFC5192D),
      Color(0xFFFF3A21),
      Color(0xFF26BDE2),
      Color(0xFF22B14C),
      Color(0xFFFCC30B),
      Color(0xFFA21942),
      Color(0xFFFD6925),
      Color(0xFFDD1367),
      Color(0xFFFD9D24),
      Color(0xFFBF8B2E),
      Color(0xFF3F7E44),
      Color(0xFF0A97D9),
      Color(0xFF56C02B),
      Color(0xFF00689D),
      Color(0xFF19486A),
    ];
    return sdg >= 0 && sdg < colors.length ? colors[sdg] : Colors.blue;
  }
}

class _PickedImage {
  final Uint8List bytes;
  final String name;
  String caption = '';
  _PickedImage(this.bytes, this.name);
}

class _KindOption {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _KindOption(this.value, this.label, this.icon, this.color);
}

class _BuildChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme cs;
  final bool active;
  final bool loading;
  const _BuildChip({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.cs,
    this.active = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? cs.primary.withValues(alpha: 0.15)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? cs.primary : cs.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(icon,
                  size: 16, color: active ? cs.primary : cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  fontSize: 13,
                  color: active ? cs.primary : cs.onSurfaceVariant,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                )),
          ],
        ),
      ),
    );
  }
}

class _ImpactMetricDef {
  final String label;
  final String unit;
  const _ImpactMetricDef(this.label, this.unit);
}
