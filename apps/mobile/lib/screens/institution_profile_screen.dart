import 'package:flutter/material.dart';
import 'package:masaren/theme.dart';

class InstitutionProfileScreen extends StatelessWidget {
  final String institutionId;
  const InstitutionProfileScreen({super.key, required this.institutionId});

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
    final inst = _registry[institutionId];
    if (inst == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Institution not found')),
      );
    }
    final kind = inst['kind'] as String? ?? 'individual';
    final gradient = _gradients[kind] ?? _gradients['individual']!;
    final icon = _icons[kind] ?? Icons.business;
    final typeLabel = _typeLabels[kind] ?? kind;
    final cs = Theme.of(context).colorScheme;

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
            if (kind == 'government')
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
          Text(label, style: TextStyle(fontSize: 14, color: cs.onSurface)),
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
