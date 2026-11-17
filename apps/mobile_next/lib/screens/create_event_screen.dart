import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/theme.dart';

class CreateEventScreen extends StatefulWidget {
  final User user;
  const CreateEventScreen({super.key, required this.user});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _link = TextEditingController();
  final _sdg = TextEditingController();
  final _capacity = TextEditingController();
  final _funding = TextEditingController();
  String? _coverUrl;
  String? _coverPath;
  bool _uploading = false;
  DateTime? _starts;
  DateTime? _ends;
  bool _online = false;
  bool _announce = true;
  bool _busy = false;

  String _t(String key, [String? fallback]) {
    final value = MasarenLocalizations.of(context, key);
    return value == key ? (fallback ?? key) : value;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _link.dispose();
    _sdg.dispose();
    _capacity.dispose();
    _funding.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 1800, imageQuality: 84);
    if (picked == null) return;
    setState(() {
      _coverPath = picked.path;
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
      if (mounted) setState(() => _coverUrl = url);
    } catch (e) {
      if (mounted) _snack(e.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null) return null;
    if (!mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: initial != null
          ? TimeOfDay.fromDateTime(initial)
          : const TimeOfDay(hour: 10, minute: 0),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _save() async {
    if (_title.text.trim().length < 3) {
      _snack(_t(
          'events.titleError', 'Event title must be at least 3 characters.'));
      return;
    }
    if (_starts == null) {
      _snack(_t('events.dateError', 'Choose the start date and time.'));
      return;
    }
    if (_online && _link.text.trim().isEmpty) {
      _snack(_t('events.linkError', 'Add the online meeting link.'));
      return;
    }
    if (!_online && _location.text.trim().isEmpty) {
      _snack(_t('events.venueError', 'Add the event venue.'));
      return;
    }
    if (_uploading) {
      _snack('Wait for the cover photo to finish uploading.');
      return;
    }
    setState(() => _busy = true);
    try {
      final event = await AuthApi.createEvent({
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'starts_at': _starts!.toUtc().toIso8601String(),
        'ends_at': _ends?.toUtc().toIso8601String(),
        'is_online': _online,
        'location': _online ? null : _location.text.trim(),
        'link_url': _online ? _link.text.trim() : null,
        'cover_url': _coverUrl,
        'sdg': int.tryParse(_sdg.text.trim()),
        'capacity': int.tryParse(_capacity.text.trim()),
        'funding_goal': double.tryParse(_funding.text.trim()) ?? 0,
        'announce': _announce,
      });
      if (mounted) Navigator.pop(context, event);
    } catch (e) {
      if (mounted) _snack(_t('common.failed').replaceAll('{error}', '$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_t('events.new', 'New event'))),
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
                Text(_t('events.createTitle', 'Bring people together'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                    _t('events.createSubtitle',
                        'Events cost 25 MRC to publish. Pro members publish for free. New events are reviewed before going live.'),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12.5,
                        height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            maxLength: 140,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
                labelText: _t('events.titleLabel', 'Event title')),
          ),
          TextField(
            controller: _description,
            minLines: 3,
            maxLines: 8,
            maxLength: 2000,
            decoration: InputDecoration(
                labelText:
                    _t('events.descriptionLabel', 'What is this event about?')),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await _pickDateTime(_starts);
                    if (picked != null) setState(() => _starts = picked);
                  },
                  icon: const Icon(Icons.event, size: 18),
                  label: Text(_starts == null
                      ? _t('events.pickDateTime', 'Start date & time')
                      : _starts!.toString().substring(0, 16)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await _pickDateTime(
                        _ends ?? _starts?.add(const Duration(hours: 2)));
                    if (picked != null) setState(() => _ends = picked);
                  },
                  icon: const Icon(Icons.event_available, size: 18),
                  label: Text(_ends == null
                      ? _t('events.endsAt', 'Ends (optional)')
                      : _ends!.toString().substring(0, 16)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _online,
            onChanged: (value) => setState(() => _online = value),
            title: Text(_t('events.online', 'Online event'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          TextField(
            controller: _online ? _link : _location,
            decoration: InputDecoration(
                labelText: _online
                    ? _t('events.meetingLink', 'Meeting link')
                    : _t('events.venue', 'Venue')),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sdg,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: _t('events.sdgLabel', 'SDG (1-17)')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _capacity,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: _t('events.capacity', 'Capacity (optional)')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _funding,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText:
                    _t('events.fundingGoal', 'Funding goal in MRC (optional)'),
                prefixIcon: const Icon(Icons.volunteer_activism_outlined)),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _uploading ? null : _pickCover,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(16),
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
                                size: 32, color: cs.primary),
                        const SizedBox(height: 6),
                        Text(
                            _uploading
                                ? 'Uploading cover...'
                                : 'Choose an event cover from your device',
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        Text('No links needed',
                            style: TextStyle(
                                fontSize: 10.5,
                                color:
                                    cs.onSurfaceVariant.withValues(alpha: .7))),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _announce,
            onChanged: (value) => setState(() => _announce = value),
            title: Text(_t('events.announce', 'Announce in the feed'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
                _t('events.announceHint',
                    'Publish a post with the event details so the community sees it.'),
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.event, size: 18),
            label: Text(_t('events.publish', 'Submit event')),
          ),
        ],
      ),
    );
  }
}
