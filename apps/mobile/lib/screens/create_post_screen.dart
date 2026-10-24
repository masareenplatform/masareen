import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/models.dart';

class CreatePostScreen extends StatefulWidget {
  final User user;
  final Post? initial;
  final String? initialKind;
  const CreatePostScreen({super.key, required this.user, this.initial, this.initialKind});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _text = TextEditingController();
  final _program = TextEditingController();
  final _impact = TextEditingController();
  final _impactLabel = TextEditingController(text: 'impact');
  int _sdg = 0;
  String _kind = 'story';
  File? _image;
  File? _video;
  bool _busy = false;
  bool _showAdvanced = false;
  double? _lat;
  double? _lng;
  bool _gpsLoading = false;

  static const _kinds = [
    _KindOption('story', 'Story', Icons.auto_stories, Color(0xFF1A73E8)),
    _KindOption('impact', 'Impact', Icons.trending_up, Color(0xFF34A853)),
    _KindOption('evidence', 'Evidence', Icons.eco, Color(0xFF0F9D58)),
    _KindOption('program', 'Program', Icons.hub, Color(0xFF4285F4)),
    _KindOption('task', 'Task', Icons.check_circle, Color(0xFF0D652D)),
    _KindOption('announcement', 'Platform', Icons.campaign, Color(0xFFF4B400)),
    _KindOption('recognition', 'Recognition', Icons.emoji_events, Color(0xFFEA4335)),
    _KindOption('course', 'Course', Icons.school, Color(0xFF1E8E3E)),
    _KindOption('event', 'Event', Icons.event, Color(0xFFE37400)),
  ];

  static const _sdgLabels = [
    'None', 'No Poverty', 'Zero Hunger', 'Good Health', 'Quality Education',
    'Gender Equality', 'Clean Water', 'Affordable Energy', 'Decent Work',
    'Industry & Innovation', 'Reduced Inequalities', 'Sustainable Cities',
    'Responsible Consumption', 'Climate Action', 'Life Below Water',
    'Life on Land', 'Peace & Justice', 'Partnerships',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _text.text = widget.initial!.text;
      _program.text = widget.initial!.programTag ?? '';
      _sdg = widget.initial!.sdg ?? 0;
      _kind = widget.initial!.kind ?? 'story';
    }
    if (widget.initialKind != null) _kind = widget.initialKind!;
  }

  @override
  void dispose() {
    _text.dispose();
    _program.dispose();
    _impact.dispose();
    _impactLabel.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1280, imageQuality: 80);
    if (x != null) setState(() { _image = File(x.path); _video = null; });
  }

  Future<void> _takePhoto() async {
    final x = await ImagePicker().pickImage(
        source: ImageSource.camera, maxWidth: 1280, imageQuality: 80);
    if (x != null) setState(() { _image = File(x.path); _video = null; });
  }

  Future<void> _pickVideo() async {
    final x = await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 5));
    if (x != null) setState(() { _video = File(x.path); _image = null; });
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
            const SnackBar(content: Text('Could not check location services')),
          );
        }
        return;
      }
      if (!serviceEnabled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services disabled. Enable in settings.')),
        );
        return;
      }

      LocationPermission permission = LocationPermission.denied;
      try {
        permission = await Geolocator.checkPermission();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not check location permission')),
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
            const SnackBar(content: Text('Location permission denied')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permanently denied. Enable in settings.')),
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ));
      if (mounted) setState(() { _lat = pos.latitude; _lng = pos.longitude; });
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Write something first')));
      return;
    }
    setState(() => _busy = true);
    try {
      final media = <Map<String, dynamic>>[];
      if (_image != null) {
        final bytes = await _image!.readAsBytes();
        final ext = _image!.path.split('.').last;
        final url = await AuthApi.uploadAvatar(bytes, _image!.path.split('/').last,
            'image/${ext == 'png' ? 'png' : 'jpeg'}');
        media.add({'type': 'IMAGE', 'url': url, 'name': _image!.path.split('/').last});
      }
      if (_video != null) {
        final bytes = await _video!.readAsBytes();
        final ext = _video!.path.split('.').last.toLowerCase();
        final ct = ext == 'webm' ? 'video/webm' : ext == 'mkv' ? 'video/x-matroska' : 'video/mp4';
        final result = await AuthApi.uploadVideo(bytes, _video!.path.split('/').last, ct);
        final hlsUrl = result['hls_url'] as String?;
        final jobId = result['job_id'] as String?;
        if (hlsUrl != null) {
          final fullHlsUrl = hlsUrl.startsWith('http') ? hlsUrl : '${api.baseUrl}$hlsUrl';
          media.add({'type': 'VIDEO', 'url': fullHlsUrl, 'name': _video!.path.split('/').last, 'job_id': jobId});
        }
      }

      final body = <String, dynamic>{
        'text': text,
        'kind': _kind,
        'author_name': widget.user.fullName,
        'author_handle': widget.user.email.split('@').first,
      };

      if (_program.text.trim().isNotEmpty) body['program_tag'] = _program.text.trim();
      if (_sdg > 0) body['sdg'] = _sdg;
      final iv = double.tryParse(_impact.text);
      if (iv != null && iv > 0) {
        body['impact_value'] = iv;
        body['impact_label'] = _impactLabel.text.trim().isNotEmpty ? _impactLabel.text.trim() : 'impact';
      }
      if (media.isNotEmpty) body['media'] = media;
      if (_lat != null && _lng != null) {
        body['latitude'] = _lat;
        body['longitude'] = _lng;
      }

      await AuthApi.createPost(body);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Post published')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('New post'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _submit,
            style: TextButton.styleFrom(
              foregroundColor: cs.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: _busy
                ? SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary))
                : const Text('Post', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              AppAvatar(name: widget.user.fullName, url: widget.user.avatarUrl, size: 44),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.user.fullName,
                        style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600)),
                    Text('Posting publicly',
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text('Post type',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500)),
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
                      color: sel ? k.color.withValues(alpha: dark ? 0.3 : 0.15) : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: sel ? k.color : cs.outlineVariant, width: sel ? 2 : 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(k.icon, color: sel ? k.color : cs.onSurfaceVariant, size: 24),
                        const SizedBox(height: 4),
                        Text(k.label, textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
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
              hintText: _kindHint(),
              hintStyle: TextStyle(color: cs.onSurfaceVariant),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),

          if (_image != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(_image!, height: 200, width: double.infinity, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 8, right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() => _image = null),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),

          if (_video != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 200, width: double.infinity,
                    color: Colors.black,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.videocam, color: Colors.white, size: 48),
                        const SizedBox(height: 8),
                        Text(_video!.path.split('/').last,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 8, right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() => _video = null),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              _BuildChip(icon: Icons.photo_library_outlined, label: 'Gallery', onTap: _pickImage, cs: cs),
              _BuildChip(icon: Icons.camera_alt_outlined, label: 'Camera', onTap: _takePhoto, cs: cs),
              _BuildChip(icon: Icons.videocam_outlined, label: 'Video', onTap: _pickVideo, cs: cs),
              _BuildChip(
                icon: Icons.my_location,
                label: _lat != null ? 'GPS Captured' : 'Add GPS',
                onTap: _captureGps, cs: cs, active: _lat != null, loading: _gpsLoading,
              ),
              _BuildChip(
                icon: Icons.expand_more,
                label: _showAdvanced ? 'Less' : 'More',
                onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                cs: cs, active: _showAdvanced,
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
                  const Icon(Icons.location_on, color: AppColors.accent, size: 16),
                  const SizedBox(width: 6),
                  Text('${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                      style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],

          if (_showAdvanced) ...[
            const SizedBox(height: 16),
            Divider(color: cs.outlineVariant),
            const SizedBox(height: 12),
            Text('Link to program',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: _program,
              style: TextStyle(color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'Search or enter program name…',
                prefixIcon: const Icon(Icons.hub, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            Text('SDG Goal',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 18,
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
                        color: sel ? _sdgColor(sdg) : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text('$sdg',
                          style: TextStyle(
                            color: sel ? Colors.white : cs.onSurfaceVariant,
                            fontWeight: FontWeight.w700, fontSize: 14,
                          )),
                    ),
                  );
                },
              ),
            ),
            if (_sdg > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_sdgLabels[_sdg], style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _impact,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: cs.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Impact value',
                      prefixIcon: const Icon(Icons.insights, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _impactLabel,
                    style: TextStyle(color: cs.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Label (e.g. trees planted)',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _kindHint() {
    if (_kind == 'course') return 'Share a course: title, who it is for, lessons and how to enroll. Create it in Courses for enrollment.';
    if (_kind == 'event') return 'Share an event: date, venue or online link, and who should attend. Create it in Events for RSVPs.';
    switch (_kind) {
      case 'impact': return 'Describe the verified impact outcome…';
      case 'evidence': return 'Describe the evidence you captured in the field…';
      case 'program': return 'Share a program update…';
      case 'task': return 'Share a completed task result…';
      case 'announcement': return 'Make an announcement…';
      case 'recognition': return 'Recognize someone\'s contribution…';
      default: return 'Share your impact story…';
    }
  }

  static Color _sdgColor(int sdg) {
    const colors = [
      Colors.transparent,
      Color(0xFFE5243B), Color(0xFFDDA63A), Color(0xFF4C9F38), Color(0xFFC5192D),
      Color(0xFFFF3A21), Color(0xFF26BDE2), Color(0xFF22B14C), Color(0xFFFCC30B),
      Color(0xFFA21942), Color(0xFFFD6925), Color(0xFFDD1367), Color(0xFFFD9D24),
      Color(0xFFBF8B2E), Color(0xFF3F7E44), Color(0xFF0A97D9), Color(0xFF56C02B),
      Color(0xFF00689D), Color(0xFF19486A),
    ];
    return sdg >= 0 && sdg < colors.length ? colors[sdg] : Colors.blue;
  }
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
    required this.icon, required this.label, required this.onTap, required this.cs,
    this.active = false, this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? cs.primary.withValues(alpha: 0.15) : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? cs.primary : cs.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(icon, size: 16, color: active ? cs.primary : cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
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
