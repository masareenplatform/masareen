import 'package:flutter/material.dart';
import 'package:masaren/screens/impact_frameworks_screen.dart';

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
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'From activity to opportunity',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'MASAREEN turns real activity into target-linked evidence, host-verified records, measurable impact and discoverable opportunities.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _Section(
            title: 'The MASAREEN loop',
            icon: Icons.loop,
            child: _FlowDiagram(
              steps: [
                'Activity',
                'Evidence',
                'Verification',
                'Impact',
                'Discovery',
                'Opportunity',
              ],
            ),
          ),
          _Section(
            title: 'How verification works',
            icon: Icons.verified_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FlowDiagram(
                  steps: [
                    'Capture',
                    'Deepfake / NSFW scan',
                    'Host review',
                    'Verified record',
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Attach evidence to the exact entity it proves. Add photos, video, audio, documents and GPS. A host or scoped moderator reviews the claim; explicit content is blocked and likely AI-generated content requires an explicit override.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _Section(
            title: 'Why impact is a percentage',
            icon: Icons.insights_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FlowDiagram(
                  steps: [
                    '6 domains',
                    'Saturating metrics',
                    'Time decay',
                    'GPS + actor + consistency',
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Environmental, social, economic, governance, education and infrastructure signals are normalized separately. Repeated metrics cannot inflate the score: each domain saturates, decays over time and is combined with evidence coverage, location confidence, actor history and a consistency penalty.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: cs.onSurfaceVariant,
                  ),
                ),
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
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          _Section(
            title: 'Moderators are scoped',
            icon: Icons.admin_panel_settings_outlined,
            child: Text(
              'An owner can assign a moderator to one event, post or programme. Moderators can remove comments, remove posts, verify contributions or remove that entity only when the owner grants the permission. They never become platform admins.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          _Section(
            title: 'Documents, safety and sharing',
            icon: Icons.shield_outlined,
            child: Text(
              'PDF and DOCX attachments open inside the app in a sanitized viewer. Only verified posts, events, booths, profiles, shows and videos can be shared externally. Block an account from a profile or post; manage blocked accounts in Settings.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          const _Section(
            title: 'Who does what',
            icon: Icons.groups_2_outlined,
            child: Column(
              children: [
                _PathCard(
                  icon: Icons.newspaper,
                  title: 'Journalists and media',
                  body:
                      'Publish or verify news, attach source and media, earn 5 MRC per verification and build a public journalist profile.',
                ),
                _PathCard(
                  icon: Icons.agriculture_outlined,
                  title: 'Agricultural and field professionals',
                  body:
                      'Capture field evidence, join programs and projects, train others and turn adoption, water, yield and resilience into measured impact.',
                ),
                _PathCard(
                  icon: Icons.science_outlined,
                  title: 'Researchers and academics',
                  body:
                      'Move research through the visible pipeline, name every author and role, earn 8 MRC for peer review, raise funding and build research impact.',
                ),
                _PathCard(
                  icon: Icons.school_outlined,
                  title: 'Trainers and students',
                  body:
                      'Complete role-based pathways, submit evidence, join calls and rooms, and convert learning and contribution into opportunities and MRC.',
                ),
              ],
            ),
          ),
          _Section(
            title: 'Impact indicators are entity-specific',
            icon: Icons.tune,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ImpactLine(
                  icon: Icons.newspaper,
                  title: 'News',
                  body:
                      'Views, reactions, comments, ratings, verification verdicts and corrections.',
                ),
                const _ImpactLine(
                  icon: Icons.science_outlined,
                  title: 'Research',
                  body:
                      'Peer review score, reviewed stages, funding, open data and public engagement.',
                ),
                const _ImpactLine(
                  icon: Icons.agriculture_outlined,
                  title: 'Agriculture',
                  body:
                      'Yield change, water saved, adoption, field evidence, training and resilience.',
                ),
                const _ImpactLine(
                  icon: Icons.school_outlined,
                  title: 'Learning and training',
                  body:
                      'Completion, assessment, applied evidence, reach and follow-on opportunities.',
                ),
                const _ImpactLine(
                  icon: Icons.hub_outlined,
                  title: 'Organisations and events',
                  body:
                      'Verified projects, beneficiaries, attendance, evidence coverage, funding and transparency.',
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ImpactFrameworksScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Open measured frameworks'),
                  ),
                ),
              ],
            ),
          ),
          const _Section(
            title: 'Newsroom and live TV',
            icon: Icons.live_tv_outlined,
            child: Text(
              'The newsroom ingests trusted Egyptian outlets every 30 minutes, creates real journalist profiles and attaches photos and videos. MASAREEN Live TV runs an in-sequence newsroom bulletin and channel bumpers, so viewers see current stories rather than a static logo. Eligible reviewers can verify or dispute a story and every review feeds the impact score.',
              style: TextStyle(fontSize: 12.5, height: 1.5),
            ),
          ),
          const _Section(
            title: 'Admins, moderators and support',
            icon: Icons.admin_panel_settings_outlined,
            child: Text(
              'Admins can assign platform roles from the user menu: admin, moderator, support or analyst. Entity owners can still assign scoped moderators to a single event, programme, project or post. Platform roles are audited, and no role can verify its own content.',
              style: TextStyle(fontSize: 12.5, height: 1.5),
            ),
          ),
          const _Section(
            title: 'Updates and version channels',
            icon: Icons.system_update_alt,
            child: Text(
              'Open Check for updates to see the available channels. You can stay on the stable MASAREEN build or install the Next visual direction side by side. Updates preserve your data and never overwrite the other app.',
              style: TextStyle(fontSize: 12.5, height: 1.5),
            ),
          ),
          const _Section(
            title: 'Frequently asked',
            icon: Icons.help_outline,
            child: Column(
              children: [
                _Faq(
                  q: 'What can I post?',
                  a: 'Updates, verified evidence, stories, opportunities, projects and recognition. Evidence posts need a target and GPS.',
                ),
                _Faq(
                  q: 'Who can verify me?',
                  a: 'The host institution, its scoped moderators or a platform admin. You cannot verify your own contribution.',
                ),
                _Faq(
                  q: 'How do I get discovered?',
                  a: 'Publish complete entity pages, add media and evidence, keep your profile current and engage with the community. Paid boosts only affect discovery, never verification.',
                ),
                _Faq(
                  q: 'How do I report or block?',
                  a: 'Use the menu on a post or profile. Reports go to the platform moderation queue; blocks hide the account and its content from you.',
                ),
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
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

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
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
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
              child: Text(
                steps[i],
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
            ),
            if (i < steps.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Icon(
                  Icons.arrow_forward,
                  size: 14,
                  color: cs.onSurfaceVariant,
                ),
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
      title: Text(
        q,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
      ),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            a,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _PathCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _PathCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cs.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImpactLine extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _ImpactLine({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: cs.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: cs.onSurfaceVariant,
                  fontFamily: 'Cairo',
                ),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(text: body),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
