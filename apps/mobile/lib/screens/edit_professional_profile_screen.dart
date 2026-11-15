import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';

class EditProfessionalProfileScreen extends StatefulWidget {
  final Personnel profile;
  const EditProfessionalProfileScreen({super.key, required this.profile});

  @override
  State<EditProfessionalProfileScreen> createState() =>
      _EditProfessionalProfileScreenState();
}

class _EditProfessionalProfileScreenState
    extends State<EditProfessionalProfileScreen> {
  late final TextEditingController _headline;
  late final TextEditingController _summary;
  late final TextEditingController _mission;
  late final TextEditingController _beat;
  late final TextEditingController _expertise;
  late final TextEditingController _specializations;
  late final TextEditingController _skills;
  late final TextEditingController _languages;
  late final TextEditingController _education;
  late final TextEditingController _experience;
  late final TextEditingController _certificates;
  late final TextEditingController _awards;
  late final TextEditingController _publications;
  late final TextEditingController _memberships;
  late final TextEditingController _socialLinks;
  late final TextEditingController _coverage;
  late final TextEditingController _coverageHours;
  late final TextEditingController _employment;
  late final TextEditingController _availability;
  late final TextEditingController _website;
  late final TextEditingController _country;
  late final TextEditingController _city;
  late final TextEditingController _bio;
  String _visibility = 'PUBLIC';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _headline = TextEditingController(text: p.headline);
    _summary = TextEditingController(text: p.summary);
    _mission = TextEditingController(text: p.mission);
    _beat = TextEditingController(text: p.beat);
    _expertise = TextEditingController(text: _join(p.expertise));
    _specializations = TextEditingController(text: _join(p.specializations));
    _skills = TextEditingController(text: _join(p.skills));
    _languages = TextEditingController(text: _join(p.languages));
    _education = TextEditingController(text: _join(p.education));
    _experience = TextEditingController(text: _join(p.experience));
    _certificates = TextEditingController(text: _join(p.certificates));
    _awards = TextEditingController(text: _join(p.awards));
    _publications = TextEditingController(text: _join(p.publications));
    _memberships = TextEditingController(text: _join(p.memberships));
    _socialLinks = TextEditingController(
        text: p.socialLinks.entries
            .map((entry) => '${entry.key}|${entry.value}')
            .join('\n'));
    _visibility = p.visibility.toUpperCase();
    _coverage = TextEditingController(text: _join(p.coverageRegions));
    _coverageHours =
        TextEditingController(text: p.kpi['coverage_hours']?.toString() ?? '0');
    _employment = TextEditingController(text: p.employmentStatus);
    _availability = TextEditingController(text: p.availability);
    _website = TextEditingController(text: p.website ?? '');
    _country = TextEditingController(text: p.country ?? '');
    _city = TextEditingController(text: p.city ?? '');
    _bio = TextEditingController(text: p.bio);
  }

  @override
  void dispose() {
    for (final c in [
      _headline,
      _summary,
      _mission,
      _beat,
      _expertise,
      _specializations,
      _skills,
      _languages,
      _education,
      _experience,
      _certificates,
      _awards,
      _publications,
      _memberships,
      _socialLinks,
      _coverage,
      _coverageHours,
      _employment,
      _availability,
      _website,
      _country,
      _city,
      _bio,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _loc(String key) => MasarenLocalizations.of(context, key);

  String _join(dynamic value) {
    if (value is! List) return '';
    return value
        .map((e) => e is Map ? (e['name'] ?? e['title'] ?? '') : e.toString())
        .where((e) => e.toString().isNotEmpty)
        .join(', ');
  }

  List<String> _split(String value) =>
      value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Map<String, String> _social() {
    final links = <String, String>{};
    for (final line in _socialLinks.text.split('\n')) {
      final parts = line.split('|');
      if (parts.length != 2) continue;
      final key = parts[0].trim().toLowerCase();
      final value = parts[1].trim();
      if (key.isEmpty || value.isEmpty) continue;
      links[key] = value;
    }
    return links;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await AuthApi.updatePersonnelProfile({
        'headline': _headline.text.trim(),
        'summary': _summary.text.trim(),
        'mission': _mission.text.trim(),
        'beat': _beat.text.trim(),
        'expertise': _split(_expertise.text),
        'specializations': _split(_specializations.text),
        'skills': _split(_skills.text),
        'languages': _split(_languages.text),
        'education': _split(_education.text),
        'experience': _split(_experience.text),
        'certificates': _split(_certificates.text),
        'awards': _split(_awards.text),
        'publications': _split(_publications.text),
        'memberships': _split(_memberships.text),
        'social_links': _social(),
        'visibility': _visibility,
        'coverage_regions': _split(_coverage.text),
        'coverage_hours': double.tryParse(_coverageHours.text.trim()) ?? 0,
        'employment_status': _employment.text.trim(),
        'availability': _availability.text.trim(),
        'website': _website.text.trim(),
        'country': _country.text.trim(),
        'city': _city.text.trim(),
        'bio': _bio.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_loc('professional.updated'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_loc('professional.saveFailed')}: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_loc('professional.editTitle')),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_loc('action.save')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(_loc('professional.section.identity')),
          _field(_headline, _loc('professional.field.headline')),
          _field(_summary, _loc('professional.field.summary'), lines: 4),
          _field(_mission, _loc('professional.field.mission'), lines: 3),
          _field(_beat, _loc('professional.field.focusArea')),
          _section(_loc('professional.section.expertise')),
          _field(_expertise, _loc('professional.field.expertise')),
          _field(_specializations, _loc('professional.field.specializations')),
          _field(_skills, _loc('professional.field.skills')),
          _field(_languages, _loc('professional.field.languages')),
          _section(_loc('professional.section.credentials')),
          _field(_education, _loc('professional.field.education')),
          _field(_experience, _loc('professional.field.experience')),
          _field(_certificates, _loc('professional.field.certificates')),
          _field(_awards, _loc('professional.field.awards')),
          _field(_publications, _loc('professional.field.publications')),
          _field(_memberships, _loc('professional.field.memberships')),
          _section(_loc('professional.section.coverage')),
          _field(_coverage, _loc('professional.field.coverageRegions')),
          _field(_coverageHours, _loc('professional.field.coverageHours'),
              keyboard: const TextInputType.numberWithOptions(decimal: true)),
          _section(_loc('professional.section.work')),
          _field(_employment, _loc('professional.field.employment')),
          _field(_availability, _loc('professional.field.availability')),
          _field(_website, _loc('professional.field.website')),
          _field(_socialLinks, _loc('professional.field.socialLinks'),
              lines: 3),
          _field(_country, _loc('professional.field.country')),
          _field(_city, _loc('professional.field.city')),
          _visibilityField(),
          _section(_loc('professional.section.about')),
          _field(_bio, _loc('professional.field.bio'), lines: 4),
          const SizedBox(height: 20),
          gradientButton(
            label: _saving
                ? _loc('professional.saving')
                : _loc('professional.saveButton'),
            onPressed: _saving ? () {} : _save,
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(title,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.azure)),
      );

  Widget _field(TextEditingController controller, String label,
      {int lines = 1, TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: lines,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: lines > 1,
        ),
      ),
    );
  }

  Widget _visibilityField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: _visibility,
        decoration:
            InputDecoration(labelText: _loc('professional.field.visibility')),
        items: ['PUBLIC', 'CONNECTIONS', 'PRIVATE']
            .map((value) => DropdownMenuItem(
                  value: value,
                  child: Text(
                      _loc('professional.visibility.${value.toLowerCase()}')),
                ))
            .toList(),
        onChanged: (value) {
          if (value != null) setState(() => _visibility = value);
        },
      ),
    );
  }
}
