import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';

class CreateProgramScreen extends StatefulWidget {
  final User user;
  const CreateProgramScreen({super.key, required this.user});

  @override
  State<CreateProgramScreen> createState() => _CreateProgramScreenState();
}

class _CreateProgramScreenState extends State<CreateProgramScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _category = TextEditingController(text: 'Education');
  final _organization = TextEditingController();
  final _budget = TextEditingController();
  final _currency = TextEditingController(text: 'EGP');
  final _country = TextEditingController(text: 'Egypt');
  final _governorate = TextEditingController();
  final _beneficiaries = TextEditingController();
  final _sdg = TextEditingController();
  DateTime? _starts;
  DateTime? _ends;
  String? _coverUrl;
  String? _coverPreviewPath;
  bool _uploading = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _organization.text = widget.user.fullName;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _category.dispose();
    _organization.dispose();
    _budget.dispose();
    _currency.dispose();
    _country.dispose();
    _governorate.dispose();
    _beneficiaries.dispose();
    _sdg.dispose();
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
      _uploading = true;
      _coverPreviewPath = picked.path;
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

  Future<DateTime?> _pickDate(DateTime? initial) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    return picked;
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.length < 3) {
      setState(() => _error = 'Add a programme title with at least 3 characters.');
      return;
    }
    if (_description.text.trim().isEmpty) {
      setState(() => _error =
          'Describe what the programme delivers, who it serves and how success is measured.');
      return;
    }
    if (_organization.text.trim().isEmpty) {
      setState(() => _error = 'Name the institution accountable for delivery.');
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
      final sdg = int.tryParse(_sdg.text.trim());
      final program = await AuthApi.createProgram({
        'title': title,
        'description': _description.text.trim(),
        'category': _category.text.trim(),
        'organization': _organization.text.trim(),
        'cover_url': _coverUrl,
        'budget': double.tryParse(_budget.text.trim()) ?? 0,
        'currency': _currency.text.trim().isEmpty ? 'EGP' : _currency.text.trim(),
        'country': _country.text.trim(),
        'governorate': _governorate.text.trim().isEmpty
            ? null
            : _governorate.text.trim(),
        'start_date': _starts?.toUtc().toIso8601String(),
        'end_date': _ends?.toUtc().toIso8601String(),
        'target_beneficiaries':
            int.tryParse(_beneficiaries.text.trim()) ?? 0,
        'sdg_goals': sdg != null && sdg >= 1 && sdg <= 17 ? [sdg] : <int>[],
        'sdg': sdg,
        'organization_id': widget.user.id,
      });
      if (mounted) Navigator.pop(context, program);
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
        title: Text(_t('programs.new', 'New programme')),
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
                  colors: [Color(0xFF0E6B5C), Color(0xFF174B43)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    _t('programs.createTitle',
                        'Turn a programme into a verified impact pathway'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                    'Add the real context: who leads it, who it serves, where it runs, the resources behind it and how progress will be proven.',
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
              labelText: 'Programme title',
              helperText: 'The public name people will recognise.',
            ),
          ),
          TextField(
            controller: _description,
            minLines: 4,
            maxLines: 8,
            maxLength: 3000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Description and theory of change',
              helperText:
                  'What is delivered, for whom, and what measurable change should it create?',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _category,
                  decoration: const InputDecoration(
                      labelText: 'Category',
                      helperText: 'Education, health, climate...'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _sdg,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'SDG (1-17)',
                      helperText: 'Primary goal'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _organization,
            decoration: const InputDecoration(
                labelText: 'Lead organisation',
                helperText: 'The institution accountable for delivery.'),
          ),
          const SizedBox(height: 16),
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
              height: 150,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: _coverPreviewPath != null
                  ? Image.file(
                      File(_coverPreviewPath!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                    )
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
          const SizedBox(height: 18),
          Text('Where and when',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _country,
                  decoration: const InputDecoration(labelText: 'Country'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _governorate,
                  decoration: const InputDecoration(
                      labelText: 'Governorate / region'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final date = await _pickDate(_starts);
                    if (date != null) setState(() => _starts = date);
                  },
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text(_starts == null
                      ? 'Start date'
                      : _starts!.toIso8601String().substring(0, 10)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final date = await _pickDate(
                        _ends ?? _starts?.add(const Duration(days: 180)));
                    if (date != null) setState(() => _ends = date);
                  },
                  icon: const Icon(Icons.event_available_outlined, size: 18),
                  label: Text(_ends == null
                      ? 'End date'
                      : _ends!.toIso8601String().substring(0, 10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Resources and reach',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _budget,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Budget',
                      helperText: 'Planned programme budget'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _currency,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Currency'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _beneficiaries,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Target beneficiaries',
                helperText: 'How many people should the programme reach?'),
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
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50)),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_circle_outline),
            label: Text(_t('programs.publish', 'Publish programme')),
          ),
          const SizedBox(height: 8),
          Text(
              'Programmes are reviewed before publication. Pro members publish programmes for free.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
