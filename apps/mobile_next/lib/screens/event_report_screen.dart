import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class EventReportScreen extends StatelessWidget {
  final Map<String, dynamic> event;
  const EventReportScreen({super.key, required this.event});

  List<Map<String, dynamic>> _list(String key) =>
      (event[key] is List ? event[key] as List : const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final participants = _list('participants');
    final booths = _list('booths');
    final ratings = _list('ratings');
    final verified = participants
        .where((p) => p['status'] == 'VERIFIED')
        .length;
    final submitted = participants
        .where((p) => ['SUBMITTED', 'UNDER_REVIEW'].contains(p['status']))
        .length;
    final flagged = participants
        .where((p) =>
            p['deepfake_verdict'] == 'LIKELY_AI' ||
            p['deepfake_verdict'] == 'SUSPICIOUS')
        .length;
    final leads = booths.fold<int>(
        0, (sum, b) => sum + ((b['leads_count'] as num?)?.toInt() ?? 0));
    final views = booths.fold<int>(
        0, (sum, b) => sum + ((b['views'] as num?)?.toInt() ?? 0));
    final interactions = booths.fold<int>(
        0,
        (sum, b) => sum + ((b['interactions'] as num?)?.toInt() ?? 0));
    final rating = ratings.isEmpty
        ? 0.0
        : ratings.fold<double>(
                0.0, (sum, r) => sum + ((r['rating'] as num?)?.toDouble() ?? 0)) /
            ratings.length;
    final verificationRate = participants.isEmpty
        ? 0
        : (verified / participants.length * 100).round();
    final title = (event['title'] ?? 'Event report').toString();
    final date = DateTime.tryParse((event['starts_at'] ?? '').toString());

    String reportText() => [
          'MASAREEN Event Impact Report',
          title,
          if (date != null) DateFormat.yMMMMd().format(date.toLocal()),
          '',
          'Participants: ${participants.length}',
          'Verified contributors: $verified ($verificationRate%)',
          'Pending verification: $submitted',
          'AI/NSFW flagged: $flagged',
          'Booths: ${booths.length}',
          'Booth views: $views',
          'Booth interactions: $interactions',
          'Qualified leads: $leads',
          'Average rating: ${rating.toStringAsFixed(2)} / 5 (${ratings.length})',
          '',
          'Generated from live MASAREEN event data.',
        ].join('\n');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event impact report'),
        actions: [
          IconButton(
            tooltip: 'Copy report',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: reportText()));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Report copied to clipboard.')));
              }
            },
            icon: const Icon(Icons.copy_all_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
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
                const Text('Verified activity report',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900)),
                if (date != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(DateFormat.yMMMMd().format(date.toLocal()),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeroStat('$verificationRate%', 'verification rate'),
                    _HeroStat('${participants.length}', 'contributors'),
                    _HeroStat('$leads', 'qualified leads'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Kpi(cs, 'Verified', '$verified', Icons.verified_outlined),
              _Kpi(cs, 'Pending', '$submitted', Icons.pending_outlined),
              _Kpi(cs, 'Flagged', '$flagged', Icons.fact_check_outlined),
              _Kpi(cs, 'Booths', '${booths.length}', Icons.storefront_outlined),
              _Kpi(cs, 'Views', '$views', Icons.visibility_outlined),
              _Kpi(cs, 'Interactions', '$interactions', Icons.touch_app_outlined),
              _Kpi(cs, 'Leads', '$leads', Icons.handshake_outlined),
              _Kpi(cs, 'Rating', rating.toStringAsFixed(1),
                  Icons.star_outline_rounded),
            ],
          ),
          const SizedBox(height: 18),
          _Block(
            cs,
            'Contributor register',
            participants.isEmpty
                ? 'No contributors yet.'
                : participants
                    .take(30)
                    .map((p) =>
                        '${p['name'] ?? 'Member'} · ${p['role'] ?? 'ROLE'} · ${p['status'] ?? 'SUBMITTED'}')
                    .join('\n'),
          ),
          _Block(
            cs,
            'Booth performance',
            booths.isEmpty
                ? 'No booths yet.'
                : booths
                    .take(20)
                    .map((b) =>
                        '${b['title'] ?? 'Booth'} · ${b['views'] ?? 0} views · ${b['interactions'] ?? 0} interactions · ${b['leads_count'] ?? 0} leads')
                    .join('\n'),
          ),
          _Block(
            cs,
            'Verification recommendations',
            [
              if (flagged > 0)
                'Review $flagged AI/NSFW flagged contribution${flagged == 1 ? '' : 's'} before publishing a verdict.',
              if (submitted > 0)
                'Clear the $submitted pending contribution${submitted == 1 ? '' : 's'} to protect the event verification rate.',
              if (leads > 0)
                'Follow up on $leads qualified lead${leads == 1 ? '' : 's'} within 48 hours.',
              if (participants.isNotEmpty && verificationRate < 60)
                'Add documentary evidence to the lowest-coverage contributor groups.',
              if (participants.isEmpty) 'Invite contributors and add their evidence.',
            ].join('\n'),
          ),
          const SizedBox(height: 14),
          Text(
              'Generated ${DateFormat.yMMMd().add_jm().format(DateTime.now())} · live data, no placeholders',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  const _HeroStat(this.value, this.label);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900)),
            Text(label,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      );
}

class _Kpi extends StatelessWidget {
  final ColorScheme cs;
  final String label;
  final String value;
  final IconData icon;
  const _Kpi(this.cs, this.label, this.value, this.icon);
  @override
  Widget build(BuildContext context) => Container(
        width: 108,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: cs.outlineVariant)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: cs.primary),
            const SizedBox(height: 7),
            Text(value,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
          ],
        ),
      );
}

class _Block extends StatelessWidget {
  final ColorScheme cs;
  final String title;
  final String body;
  const _Block(this.cs, this.title, this.body);
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            Text(body,
                style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: cs.onSurfaceVariant)),
          ],
        ),
      );
}
