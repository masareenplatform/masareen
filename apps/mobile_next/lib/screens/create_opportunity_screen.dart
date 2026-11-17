import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';

class CreateOpportunityScreen extends StatefulWidget {
  final User user;
  const CreateOpportunityScreen({super.key, required this.user});

  @override
  State<CreateOpportunityScreen> createState() =>
      _CreateOpportunityScreenState();
}

class _CreateOpportunityScreenState extends State<CreateOpportunityScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _skills = TextEditingController();
  final _location = TextEditingController();
  final _sdg = TextEditingController();
  final _minPms = TextEditingController();
  String _type = 'JOB';
  bool _remote = false;
  DateTime? _deadline;
  String? _coverUrl;
  String? _coverPath;
  bool _uploading = false;
  bool _busy = false;
  String? _error;

  static const _types = [
    'JOB',
    'INTERNSHIP',
    'GRANT',
    'VOLUNTEER',
    'TRAINING',
    'CSR'
  ];

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _skills.dispose();
    _location.dispose();
    _sdg.dispose();
    _minPms.dispose();
    super.dispose();
  }

  String _t(String key, String fallback) {
    final value = MasarenLocalizations.of(context, key);
    return value == key ? fallback : value;
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

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 1095)),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _save() async {
    if (_title.text.trim().length < 3) {
      setState(() => _error = 'Add an opportunity title with at least 3 characters.');
      return;
    }
    if (_description.text.trim().length < 10) {
      setState(() => _error =
          'Explain the role, the work, who it is for and what success looks like.');
      return;
    }
    if (!_remote && _location.text.trim().isEmpty) {
      setState(() => _error = 'Add a location or mark the opportunity as remote.');
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
      final opportunity = await AuthApi.createOpportunity({
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'type': _type,
        'skills': _skills.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        'sdg': int.tryParse(_sdg.text.trim()),
        'location': _remote ? null : _location.text.trim(),
        'cover_url': _coverUrl,
        'is_remote': _remote,
        'deadline': _deadline?.toUtc().toIso8601String(),
        'min_pms': int.tryParse(_minPms.text.trim()),
      });
      if (mounted) Navigator.pop(context, opportunity);
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
        title: Text(_t('opportunities.publishTitle', 'New opportunity')),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_t('common.create', 'Create')),
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
                  colors: [Color(0xFF2C6E8F), Color(0xFF0E6B5C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    _t('opportunities.createTitle',
                        'Open a real path to opportunity'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                    'Be specific about the work, the skills, the time commitment, the location and how candidates will be evaluated.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: .9),
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
            decoration: const InputDecoration(
              labelText: 'Opportunity title',
              helperText: 'Use the role or programme name candidates will search for.',
            ),
          ),
          TextField(
            controller: _description,
            minLines: 4,
            maxLines: 9,
            maxLength: 2500,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Description',
              helperText:
                  'Scope, responsibilities, time commitment, compensation if any, and evaluation criteria.',
              alignLabelWithHint: true,
            ),
          ),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration:
                InputDecoration(labelText: _t('opportunities.type', 'Type')),
            items: _types
                .map((v) => DropdownMenuItem(
                    value: v,
                    child: Text(_t(
                        'opportunities.type.${v.toLowerCase()}', v))))
                .toList(),
            onChanged: (v) => setState(() => _type = v ?? 'JOB'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _skills,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Skills',
              helperText:
                  'Separate skills with commas, e.g. media, research, Arabic.',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _location,
            enabled: !_remote,
            decoration: const InputDecoration(
              labelText: 'Location',
              helperText: 'City and country, or enable remote below.',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _remote,
            onChanged: (v) => setState(() => _remote = v),
            title: const Text('Remote opportunity',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Candidates can participate from anywhere.'),
          ),
          OutlinedButton.icon(
            onPressed: _pickDeadline,
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48)),
            icon: const Icon(Icons.event_outlined, size: 18),
            label: Text(_deadline == null
                ? 'Application deadline'
                : 'Deadline: ${_deadline!.toIso8601String().substring(0, 10)}'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sdg,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'SDG (1-17)', helperText: 'Primary goal'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _minPms,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Minimum PMS',
                      helperText: 'Optional 0-100 threshold'),
                ),
              ),
            ],
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
              height: 140,
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
                                : 'Choose a photo from your device',
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
                : const Icon(Icons.campaign_outlined),
            label: Text(_t('opportunities.publish', 'Publish opportunity')),
          ),
          const SizedBox(height: 8),
          Text('Opportunities are reviewed before publication.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11.5, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
