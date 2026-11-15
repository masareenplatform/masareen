import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';

class CreateProjectScreen extends StatefulWidget {
  final User user;
  const CreateProjectScreen({super.key, required this.user});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _category = TextEditingController(text: 'Community');
  final _goal = TextEditingController();
  final _institution = TextEditingController();
  final _year = TextEditingController();
  final _students = TextEditingController();
  final _supervisor = TextEditingController();
  final _sdg = TextEditingController();
  String _type = 'COMMUNITY';
  String? _coverUrl;
  String? _coverPath;
  bool _uploading = false;
  bool _busy = false;
  String? _error;

  static const _types = [
    'COMMUNITY',
    'UNIVERSITY',
    'GRADUATION',
    'RESEARCH',
    'SCHOOL'
  ];

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _category.dispose();
    _goal.dispose();
    _institution.dispose();
    _year.dispose();
    _students.dispose();
    _supervisor.dispose();
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
      setState(() => _error =
          _t('projects.titleError', 'Add a project title with at least 3 characters.'));
      return;
    }
    if (_description.text.trim().length < 10) {
      setState(() => _error =
          'Describe the problem, the solution and the change this project should create.');
      return;
    }
    if (_type != 'COMMUNITY' && int.tryParse(_institution.text.trim()) == null) {
      setState(() => _error = _t('projects.institutionError',
          'Link this project to its university or school ID.'));
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
      final project = await AuthApi.createProject({
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'category': _category.text.trim().isEmpty
            ? 'Community'
            : _category.text.trim(),
        'goal': double.tryParse(_goal.text.trim()) ?? 0,
        'project_type': _type,
        'sdg': int.tryParse(_sdg.text.trim()),
        if (int.tryParse(_institution.text.trim()) != null)
          'institution_id': int.parse(_institution.text.trim()),
        if (_year.text.trim().isNotEmpty) 'academic_year': _year.text.trim(),
        if (_students.text.trim().isNotEmpty)
          'student_names': _students.text.trim(),
        if (_supervisor.text.trim().isNotEmpty)
          'supervisor': _supervisor.text.trim(),
        if (_coverUrl != null) 'cover': _coverUrl,
      });
      if (mounted) Navigator.pop(context, project);
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
        title: Text(_t('projects.new', 'New project')),
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
                  colors: [Color(0xFF2C6E8F), Color(0xFF174B43)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Show the work behind the outcome',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                    'A strong project page explains the problem, the team, the method, the evidence and what changes if it succeeds.',
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
            decoration: InputDecoration(
                labelText: _t('projects.titleLabel', 'Project title')),
          ),
          TextField(
            controller: _description,
            minLines: 4,
            maxLines: 8,
            maxLength: 3000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: _t('projects.descriptionLabel', 'Description'),
              helperText:
                  'Problem, approach, team, beneficiaries and the measurable outcome.',
              alignLabelWithHint: true,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _category,
                  decoration: InputDecoration(
                      labelText:
                          _t('projects.categoryLabel', 'Category')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _sdg,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'SDG (1-17)', helperText: 'Primary goal'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: InputDecoration(
                labelText: _t('projects.projectType', 'Project type')),
            items: _types
                .map((v) => DropdownMenuItem(
                    value: v, child: Text(_t('projects.type.$v', v))))
                .toList(),
            onChanged: (v) => setState(() => _type = v ?? 'COMMUNITY'),
          ),
          if (_type != 'COMMUNITY') ...[
            const SizedBox(height: 10),
            TextField(
              controller: _institution,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText:
                      _t('projects.institutionId', 'University / school ID'),
                  helperText:
                      'The institution that owns the academic context.'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _year,
                    decoration: InputDecoration(
                        labelText:
                            _t('projects.academicYear', 'Academic year')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _supervisor,
                    decoration: InputDecoration(
                        labelText: _t('projects.supervisor', 'Supervisor')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _students,
              maxLines: 2,
              decoration: InputDecoration(
                  labelText: _t('projects.students', 'Student names')),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _goal,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: _t('projects.fundingGoal', 'Funding goal'),
                helperText: 'Use 0 if the project does not raise funds.'),
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
              height: 150,
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
                : const Icon(Icons.check_circle_outline),
            label: Text(_t('projects.publish', 'Publish project')),
          ),
        ],
      ),
    );
  }
}
