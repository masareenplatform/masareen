import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
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
  late final TextEditingController _skills;
  late final TextEditingController _languages;
  late final TextEditingController _coverage;
  late final TextEditingController _coverageHours;
  late final TextEditingController _employment;
  late final TextEditingController _availability;
  late final TextEditingController _website;
  late final TextEditingController _country;
  late final TextEditingController _city;
  late final TextEditingController _bio;
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
    _skills = TextEditingController(text: _join(p.skills));
    _languages = TextEditingController(text: _join(p.languages));
    _coverage = TextEditingController(text: _join(p.coverageRegions));
    _coverageHours = TextEditingController(
        text: p.kpi['coverage_hours']?.toString() ?? '0');
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
      _headline, _summary, _mission, _beat, _expertise, _skills, _languages,
      _coverage, _coverageHours, _employment, _availability, _website, _country,
      _city, _bio,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _join(dynamic value) {
    if (value is! List) return '';
    return value
        .map((e) => e is Map ? (e['name'] ?? e['title'] ?? '') : e.toString())
        .where((e) => e.toString().isNotEmpty)
        .join(', ');
  }

  List<String> _split(String value) => value
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await AuthApi.updatePersonnelProfile({
        'headline': _headline.text.trim(),
        'summary': _summary.text.trim(),
        'mission': _mission.text.trim(),
        'beat': _beat.text.trim(),
        'expertise': _split(_expertise.text),
        'skills': _split(_skills.text),
        'languages': _split(_languages.text),
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
            const SnackBar(content: Text('Professional profile updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit professional profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Identity'),
          _field(_headline, 'Professional headline'),
          _field(_summary, 'Professional summary', lines: 4),
          _field(_mission, 'Mission statement', lines: 3),
          _field(_beat, 'Focus area'),
          _section('Expertise and skills'),
          _field(_expertise, 'Expertise (comma separated)'),
          _field(_skills, 'Skills (comma separated)'),
          _field(_languages, 'Languages (comma separated)'),
          _section('Coverage'),
          _field(_coverage, 'Coverage regions (comma separated)'),
          _field(_coverageHours, 'Coverage hours',
              keyboard: const TextInputType.numberWithOptions(decimal: true)),
          _section('Work'),
          _field(_employment, 'Employment status'),
          _field(_availability, 'Availability'),
          _field(_website, 'Website'),
          _field(_country, 'Country'),
          _field(_city, 'City'),
          _section('About'),
          _field(_bio, 'Bio', lines: 4),
          const SizedBox(height: 20),
          gradientButton(
            label: _saving ? 'Saving…' : 'Save professional profile',
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
}
