import 'package:flutter/material.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('MASAREEN Help Center')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('From activity to opportunity',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900)),
                SizedBox(height: 6),
                Text(
                    'MASAREEN turns real activity into target-linked evidence, host-verified records, measurable impact and discoverable opportunities.',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 12.5, height: 1.45)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _Section(
            title: 'The MASAREEN loop',
            icon: Icons.loop,
            child: _FlowDiagram(steps: [
              'Activity',
              'Evidence',
              'Verification',
              'Impact',
              'Discovery',
              'Opportunity',
            ]),
          ),
          _Section(
            title: 'How verification works',
            icon: Icons.verified_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FlowDiagram(steps: [
                  'Capture',
                  'Deepfake / NSFW scan',
                  'Host review',
                  'Verified record',
                ]),
                const SizedBox(height: 10),
                Text(
                    'Attach evidence to the exact entity it proves. Add photos, video, audio, documents and GPS. A host or scoped moderator reviews the claim; explicit content is blocked and likely AI-generated content requires an explicit override.',
                    style: TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          _Section(
            title: 'Why impact is a percentage',
            icon: Icons.insights_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FlowDiagram(steps: [
                  '6 domains',
                  'Saturating metrics',
                  'Time decay',
                  'GPS + actor + consistency',
                ]),
                const SizedBox(height: 10),
                Text(
                    'Environmental, social, economic, governance, education and infrastructure signals are normalized separately. Repeated metrics cannot inflate the score: each domain saturates, decays over time and is combined with evidence coverage, location confidence, actor history and a consistency penalty.',
                    style: TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          _Section(
            title: 'Feed, entities and ads',
            icon: Icons.dynamic_feed_outlined,
            child: Text(
                'Posts, events, programmes, projects, opportunities, podcasts, VOD and paid ads are blended into one ranked stream. Every entity card shows an impact percentage or a paid label. Pull to refresh, keep scrolling and use the seed-stable infinite feed.',
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: cs.onSurfaceVariant)),
          ),
          _Section(
            title: 'Moderators are scoped',
            icon: Icons.admin_panel_settings_outlined,
            child: Text(
                'An owner can assign a moderator to one event, post or programme. Moderators can remove comments, remove posts, verify contributions or remove that entity only when the owner grants the permission. They never become platform admins.',
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: cs.onSurfaceVariant)),
          ),
          _Section(
            title: 'Documents, safety and sharing',
            icon: Icons.shield_outlined,
            child: Text(
                'PDF and DOCX attachments open inside the app in a sanitized viewer. Only verified posts, events, booths, profiles, shows and videos can be shared externally. Block an account from a profile or post; manage blocked accounts in Settings.',
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: cs.onSurfaceVariant)),
          ),
          const _Section(
            title: 'Frequently asked',
            icon: Icons.help_outline,
            child: Column(
              children: [
                _Faq(
                    q: 'What can I post?',
                    a: 'Updates, verified evidence, stories, opportunities, projects and recognition. Evidence posts need a target and GPS.'),
                _Faq(
                    q: 'Who can verify me?',
                    a: 'The host institution, its scoped moderators or a platform admin. You cannot verify your own contribution.'),
                _Faq(
                    q: 'How do I get discovered?',
                    a: 'Publish complete entity pages, add media and evidence, keep your profile current and engage with the community. Paid boosts only affect discovery, never verification.'),
                _Faq(
                    q: 'How do I report or block?',
                    a: 'Use the menu on a post or profile. Reports go to the platform moderation queue; blocks hide the account and its content from you.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _Section(
      {required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _FlowDiagram extends StatelessWidget {
  final List<String> steps;
  const _FlowDiagram({required this.steps});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: cs.primary.withValues(alpha: .2)),
              ),
              child: Text(steps[i],
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: cs.primary)),
            ),
            if (i < steps.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Icon(Icons.arrow_forward,
                    size: 14, color: cs.onSurfaceVariant),
              ),
          ],
        ],
      ),
    );
  }
}

class _Faq extends StatelessWidget {
  final String q;
  final String a;
  const _Faq({required this.q, required this.a});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Text(q,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(a,
              style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      ],
    );
  }
}
