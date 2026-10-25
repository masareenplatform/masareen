import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/theme.dart';

class InstitutionProfileScreen extends StatefulWidget {
  final String institutionId;
  const InstitutionProfileScreen({super.key, required this.institutionId});

  @override
  State<InstitutionProfileScreen> createState() =>
      _InstitutionProfileScreenState();
}

class _InstitutionProfileScreenState extends State<InstitutionProfileScreen> {
  Map<String, dynamic>? _remote;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (int.tryParse(widget.institutionId) != null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await api
          .get('/api/v1/users/${widget.institutionId}/institution') as Map<String, dynamic>;
      if (!mounted) return;
      final type = (data['institution_type'] ?? data['role'] ?? '')
          .toString()
          .toUpperCase();
      final kind = type.contains('SPORT')
          ? 'sports'
          : type.contains('MEDIA')
              ? 'media'
              : type.contains('PLATFORM')
                  ? 'platform'
                  : type.contains('GOV')
                      ? 'government'
                      : 'organization';
      final metrics = data['metrics'];
      final services = data['services'];
      final departments = data['departments'];
      setState(() {
        _remote = {
          ...data,
          'kind': kind,
          'handle': data['handle'] ?? 'institution',
          'badge': data['verified'] == true ? 'Verified Institution' : 'Institution',
          'note': data['bio'] ?? '',
          'mandate': data['bio'] ?? '',
          'hq': data['city'] ?? data['country'] ?? '',
          'established': data['jurisdiction'] ?? '',
          'sectors': services is List
              ? services
                  .map((s) => s is Map ? (s['name'] ?? s['title'] ?? '') : s)
                  .where((s) => s.toString().isNotEmpty)
                  .toList()
              : <dynamic>[],
          'services': services is List ? services : <dynamic>[],
          'departments': departments is List ? departments : <dynamic>[],
          'metrics': metrics is Map ? metrics : <String, dynamic>{},
          'remote': true,
        };
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  static const Map<String, Map<String, dynamic>> _registry = {
    'inst-1': {
      'name': 'Al-Baraka Foundation',
      'handle': 'albaraka',
      'kind': 'media',
      'badge': 'Platinum',
      'note': 'Recognized for education · 12 communities in Egypt',
    },
    'inst-2': {
      'name': 'Green Hope Initiative',
      'handle': 'greenhope',
      'kind': 'organization',
      'badge': 'Gold',
      'note': 'Environmental stewardship · Sustainability leadership',
    },
    'u_gov': {
      'name': 'Ministry of Environment',
      'handle': 'moenv',
      'kind': 'government',
      'badge': 'Government Partner',
      'note': 'Official SDG reporting channel',
      'mandate':
          'Leads national environmental policy, climate adaptation and verified public-impact reporting across all governorates.',
      'sectors': ['Climate', 'Biodiversity', 'Water', 'Public Health'],
      'established': '1975',
      'hq': 'Capital District',
    },
    'u_almasareen': {
      'name': 'Al-Masareen News Network',
      'handle': 'almasareen',
      'kind': 'media',
      'badge': 'Esteemed Media',
      'note': '96% evidence accuracy · 14 countries',
    },
    'u_usf': {
      'name': 'United Sports Federation',
      'handle': 'usports',
      'kind': 'sports',
      'badge': 'Esteemed Sports',
      'note': 'Verified youth-impact coverage',
    },
    'platform': {
      'name': 'MASAREEN Platform',
      'handle': 'masareen',
      'kind': 'platform',
      'badge': 'Official Platform',
      'note': 'Official platform announcements and updates',
    },
  };

  static const Map<String, LinearGradient> _gradients = {
    'government': LinearGradient(
      colors: [Color(0xFF0B1B3A), Color(0xFF14305F)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    'media': LinearGradient(
      colors: [Color(0xFF0D4B4B), Color(0xFF0E6B6B)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    'sports': LinearGradient(
      colors: [Color(0xFF1A4D1A), Color(0xFF2D7A2D)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    'organization': LinearGradient(
      colors: [Color(0xFF3D1A5C), Color(0xFF5B2D8C)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    'individual': LinearGradient(
      colors: [Color(0xFF1A73E8), Color(0xFF4285F4)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    'platform': LinearGradient(
      colors: [Color(0xFF0250A3), Color(0xFF1565C0)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  };

  static const Map<String, IconData> _icons = {
    'government': Icons.shield_outlined,
    'media': Icons.newspaper,
    'sports': Icons.emoji_events_outlined,
    'organization': Icons.handshake_outlined,
    'individual': Icons.person_outline,
    'platform': Icons.verified,
  };

  static const Map<String, String> _typeLabels = {
    'government': 'Government Body',
    'media': 'Media Institution',
    'sports': 'Sports Organization',
    'organization': 'Community Organization',
    'individual': 'Individual',
    'platform': 'MASAREEN Platform',
  };

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final inst = _remote ?? _registry[widget.institutionId];
    if (inst == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: _error == null
              ? const Text('Institution not found')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
        ),
      );
    }
    final kind = inst['kind'] as String? ?? 'individual';
    final gradient = _gradients[kind] ?? _gradients['individual']!;
    final icon = _icons[kind] ?? Icons.business;
    final typeLabel = _typeLabels[kind] ?? kind;

    return Scaffold(
      appBar: AppBar(title: Text(inst['name'])),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Icon(icon, color: Colors.white, size: 32),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(inst['name'],
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900)),
                              Text('@${inst['handle']}',
                                  style: const TextStyle(color: Colors.white70)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(inst['badge'],
                                    style: const TextStyle(
                                        color: AppColors.brand,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(icon, color: Colors.white70, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          typeLabel.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (inst['remote'] == true)
              _RemoteBody(inst: inst)
            else if (kind == 'government')
              _GovBody(inst: inst)
            else if (kind == 'sports')
              _SportsBody(inst: inst)
            else if (kind == 'media')
              _MediaBody(inst: inst)
            else if (kind == 'platform')
              _PlatformBody(inst: inst)
            else
              _GenericBody(inst: inst, typeLabel: typeLabel),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _RemoteBody extends StatelessWidget {
  final Map<String, dynamic> inst;
  const _RemoteBody({required this.inst});

  String _label(String key) => key
      .replaceAll('_', ' ')
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final metrics = inst['metrics'] is Map ? inst['metrics'] as Map : const {};
    final services = inst['services'] is List ? inst['services'] as List : const [];
    final departments =
        inst['departments'] is List ? inst['departments'] as List : const [];
    final note = (inst['note'] ?? '').toString();
    final transparency = (inst['transparency_score'] as num?) ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (note.isNotEmpty)
            _SectionCard(
              title: 'About',
              child: Text(note,
                  style: TextStyle(
                      fontSize: 15, height: 1.6, color: cs.onSurface)),
            ),
          if (metrics.isNotEmpty)
            _SectionCard(
              title: 'Key metrics',
              child: Wrap(
                spacing: 12,
                runSpacing: 0,
                children: metrics.entries
                    .map((e) => SizedBox(
                          width: 150,
                          child: _Stat(
                            e.value is num
                                ? (e.value as num) % 1 == 0
                                    ? (e.value as num).toInt().toString()
                                    : (e.value as num).toStringAsFixed(1)
                                : e.value.toString(),
                            _label(e.key.toString()),
                          ),
                        ))
                    .toList(),
              ),
            ),
          if (services.isNotEmpty)
            _SectionCard(
              title: 'Services',
              child: Column(
                children: services.map((s) {
                  final map = s is Map ? s : const {};
                  final name = (map['name'] ?? map['title'] ?? s).toString();
                  final description =
                      (map['description'] ?? map['detail'] ?? '').toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FeatureRow(Icons.check_circle_outline, name),
                        if (description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 30, bottom: 4),
                            child: Text(description,
                                style: TextStyle(
                                    color: cs.onSurfaceVariant, height: 1.4)),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          if (departments.isNotEmpty)
            _SectionCard(
              title: 'Departments',
              child: Column(
                children: departments.map((d) {
                  final map = d is Map ? d : const {};
                  final name = (map['name'] ?? map['title'] ?? d).toString();
                  final contact = (map['contact'] ?? '').toString();
                  return _FeatureRow(
                    Icons.account_balance_outlined,
                    contact.isEmpty ? name : '$name · $contact',
                  );
                }).toList(),
              ),
            ),
          if (transparency > 0)
            _SectionCard(
              title: 'Transparency',
              child: Row(
                children: [
                  Expanded(
                      child: _Stat(
                          '${transparency % 1 == 0 ? transparency.toInt() : transparency}%',
                          'Transparency score')),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _Stat(
                          (inst['verified'] == true) ? 'Verified' : 'Listed',
                          'Status')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GovBody extends StatelessWidget {
  final Map<String, dynamic> inst;
  const _GovBody({required this.inst});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionCard(
            title: 'Official Mandate',
            child: Text(inst['mandate'],
                style: TextStyle(fontSize: 15, height: 1.6, color: cs.onSurface)),
          ),
          Row(
            children: [
              Expanded(child: _Stat(inst['established'], 'Established')),
              const SizedBox(width: 12),
              Expanded(child: _Stat(inst['hq'], 'Headquarters')),
            ],
          ),
          _SectionCard(
            title: 'Sectors of Competence',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (inst['sectors'] as List)
                  .map((s) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.1),
                          border: Border.all(color: AppColors.brand),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(s,
                            style: const TextStyle(
                                color: AppColors.brand,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ))
                  .toList(),
            ),
          ),
          _SectionCard(
            title: 'Public Impact Reporting',
            child: Text(
              'This ministry publishes verified, evidence-backed reports through '
              'MASAREEN. All submissions are audited via POAI and carry an official '
              'government verification seal.',
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaBody extends StatelessWidget {
  final Map<String, dynamic> inst;
  const _MediaBody({required this.inst});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          _SectionCard(
            title: 'Why Recognized',
            child: Text(inst['note'],
                style: TextStyle(fontSize: 15, color: cs.onSurface)),
          ),
          Row(
            children: [
              Expanded(child: _Stat('96%', 'Evidence accuracy')),
              const SizedBox(width: 12),
              Expanded(child: _Stat('14', 'Countries')),
              const SizedBox(width: 12),
              Expanded(child: _Stat('A+', 'Trust rating')),
            ],
          ),
        ],
      ),
    );
  }
}

class _SportsBody extends StatelessWidget {
  final Map<String, dynamic> inst;
  const _SportsBody({required this.inst});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          _SectionCard(
            title: 'About',
            child: Text(inst['note'],
                style: TextStyle(fontSize: 15, color: cs.onSurface)),
          ),
          Row(
            children: [
              Expanded(child: _Stat('Active', 'Status')),
              const SizedBox(width: 12),
              Expanded(child: _Stat(inst['badge'], 'Level')),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlatformBody extends StatelessWidget {
  final Map<String, dynamic> inst;
  const _PlatformBody({required this.inst});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          _SectionCard(
            title: 'About',
            child: Text(inst['note'],
                style: TextStyle(fontSize: 15, color: cs.onSurface)),
          ),
          _SectionCard(
            title: 'Features',
            child: Column(
              children: [
                _FeatureRow(Icons.verified, 'Verified impact tracking'),
                _FeatureRow(Icons.campaign_outlined, 'Official announcements'),
                _FeatureRow(Icons.emoji_events, 'Recognition programs'),
                _FeatureRow(Icons.work_outline, 'Opportunity board'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureRow(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 14, color: cs.onSurface)),
          ),
        ],
      ),
    );
  }
}

class _GenericBody extends StatelessWidget {
  final Map<String, dynamic> inst;
  final String typeLabel;
  const _GenericBody({required this.inst, required this.typeLabel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          _SectionCard(
            title: 'About',
            child: Text(inst['note'],
                style: TextStyle(fontSize: 15, color: cs.onSurface)),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 8, right: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.brand, width: 2)),
            ),
            child: Text(title.toUpperCase(),
                style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    fontSize: 12)),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface)),
        ],
      ),
    );
  }
}
