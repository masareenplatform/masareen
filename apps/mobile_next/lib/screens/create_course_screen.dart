import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/theme.dart';

class CreateCourseScreen extends StatefulWidget {
  final User user;
  const CreateCourseScreen({super.key, required this.user});

  @override
  State<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends State<CreateCourseScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _provider = TextEditingController();
  final _sdg = TextEditingController();
  final _duration = TextEditingController(text: '60');
  final _price = TextEditingController(text: '50');
  String _level = 'Beginner';
  bool _isFree = true;
  bool _busy = false;
  bool _uploading = false;
  String? _thumbnailUrl;
  String? _thumbnailPath;

  String _t(String key, [String? fallback]) {
    final value = MasarenLocalizations.of(context, key);
    return value == key ? (fallback ?? key) : value;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _provider.dispose();
    _sdg.dispose();
    _duration.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickThumbnail() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 84);
    if (picked == null) return;
    setState(() {
      _thumbnailPath = picked.path;
      _uploading = true;
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
      if (mounted) setState(() => _thumbnailUrl = url);
    } catch (e) {
      if (mounted) _snack(e.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().length < 3) {
      _snack(_t('courses.titleTooShort',
          'Course title must be at least 3 characters.'));
      return;
    }
    final price = double.tryParse(_price.text.trim()) ?? 0;
    if (!_isFree && price <= 0) {
      _snack(_t('courses.invalidPrice',
          'Set a price above zero or make the course free.'));
      return;
    }
    if (_uploading) {
      _snack('Wait for the cover photo to finish uploading.');
      return;
    }
    setState(() => _busy = true);
    try {
      final course = await AuthApi.createCourse({
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'provider': _provider.text.trim(),
        'level': _level,
        'sdg': int.tryParse(_sdg.text.trim()),
        'duration_min': int.tryParse(_duration.text.trim()) ?? 0,
        'thumbnail': _thumbnailUrl,
        'is_free': _isFree,
        'price_mrc': _isFree ? 0 : price,
      });
      if (mounted) Navigator.pop(context, course);
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
      appBar: AppBar(title: Text(_t('courses.new', 'New course'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                gradient: brandGradient,
                borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t('courses.createTitle', 'Turn your knowledge into a course'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                    _t('courses.createSubtitle',
                        'Courses cost 50 MRC to publish. Pro members publish for free. New courses are reviewed by the platform team.'),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12.5,
                        height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
                labelText: _t('courses.titleLabel', 'Course title')),
            maxLength: 120,
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _description,
            minLines: 3,
            maxLines: 8,
            maxLength: 2000,
            decoration: InputDecoration(
                labelText: _t('courses.descriptionLabel', 'What will people learn?')),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _provider,
            decoration: InputDecoration(
                labelText: _t('courses.providerLabel', 'Provider or instructor')),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _level,
            decoration: InputDecoration(
                labelText: _t('courses.levelLabel', 'Level')),
            items: [
              for (final level in ['Beginner', 'Intermediate', 'Advanced'])
                DropdownMenuItem(value: level, child: Text(level)),
            ],
            onChanged: (value) => setState(() => _level = value ?? _level),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sdg,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: _t('courses.sdgLabel', 'SDG (1-17)')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _duration,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText:
                          _t('courses.durationMinutesLabel', 'Duration (minutes)')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _uploading ? null : _pickThumbnail,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: _thumbnailPath != null
                  ? Image.file(File(_thumbnailPath!),
                      fit: BoxFit.cover, width: double.infinity)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _uploading
                            ? const CircularProgressIndicator(strokeWidth: 2)
                            : Icon(Icons.add_photo_alternate_outlined,
                                size: 32, color: cs.primary),
                        const SizedBox(height: 6),
                        Text(
                            _uploading
                                ? 'Uploading cover...'
                                : 'Choose a course cover from your device',
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant)),
                        const Text('No links needed',
                            style: TextStyle(fontSize: 10.5)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isFree,
                  onChanged: (value) => setState(() => _isFree = value),
                  title: Text(_t('courses.freeCourse', 'Free course'),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                      _t('courses.freeHint',
                          'Anyone can enroll and watch every lesson.'),
                      style: TextStyle(
                          color: cs.onSurfaceVariant, fontSize: 12)),
                ),
                if (!_isFree)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TextField(
                      controller: _price,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          labelText: _t('courses.priceLabel', 'Price in MRC'),
                          suffixText: 'MRC',
                          helperText: _t('courses.priceHint',
                              'Paid course sales go directly to you.')),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.school_outlined, size: 18),
            label: Text(_t('courses.publish', 'Submit course')),
          ),
          const SizedBox(height: 8),
          Text(
              _t('courses.reviewNote',
                  'You can add lessons from the course page after it is approved.'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: cs.onSurfaceVariant, fontSize: 11.5)),
        ],
      ),
    );
  }
}
