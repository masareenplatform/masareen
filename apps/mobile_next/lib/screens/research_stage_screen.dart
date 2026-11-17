import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/models.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets/content_engagement.dart';

class ResearchStageScreen extends StatefulWidget {
  final String stageId;
  final User user;
  const ResearchStageScreen({
    super.key,
    required this.stageId,
    required this.user,
  });

  @override
  State<ResearchStageScreen> createState() => _ResearchStageScreenState();
}

class _ResearchStageScreenState extends State<ResearchStageScreen> {
  Map<String, dynamic>? _stage;
  List<Map<String, dynamic>> _reviews = [];
  bool _loading = true;

  bool get _canReview {
    final role = widget.user.role.toUpperCase();
    return widget.user.isAdmin ||
        [
          'ACADEMIC',
          'RESEARCHER',
          'TEACHING_ASSISTANT',
          'ASSISTANT_LECTURER',
          'LECTURER',
          'ASSISTANT_PROFESSOR',
          'ASSOCIATE_PROFESSOR',
          'PROFESSOR',
        ].contains(role);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        AuthApi.researchDetail(widget.stageId),
        AuthApi.researchReviews(widget.stageId),
      ]);
      if (mounted) {
        setState(() {
          _stage = results[0] as Map<String, dynamic>;
          _reviews = results[1] as List<Map<String, dynamic>>;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _review() async {
    final comments = TextEditingController();
    String verdict = 'ACCEPT';
    double score = 4;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Peer review'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: verdict,
                  decoration: const InputDecoration(
                    labelText: 'Recommendation',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ACCEPT', child: Text('Accept')),
                    DropdownMenuItem(
                      value: 'MINOR_REVISIONS',
                      child: Text('Minor revisions'),
                    ),
                    DropdownMenuItem(
                      value: 'MAJOR_REVISIONS',
                      child: Text('Major revisions'),
                    ),
                    DropdownMenuItem(value: 'REJECT', child: Text('Reject')),
                  ],
                  onChanged: (v) => setDialog(() => verdict = v ?? verdict),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<double>(
                  initialValue: score,
                  decoration: const InputDecoration(labelText: 'Score'),
                  items: const [
                    DropdownMenuItem(value: 1.0, child: Text('1 / 5')),
                    DropdownMenuItem(value: 2.0, child: Text('2 / 5')),
                    DropdownMenuItem(value: 3.0, child: Text('3 / 5')),
                    DropdownMenuItem(value: 4.0, child: Text('4 / 5')),
                    DropdownMenuItem(value: 5.0, child: Text('5 / 5')),
                  ],
                  onChanged: (v) => setDialog(() => score = v ?? score),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: comments,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Constructive review',
                    helperText: 'Reviews earn 8 MRC and research impact.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit review'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final result = await AuthApi.reviewResearch(widget.stageId, {
        'verdict': verdict,
        'score': score,
        'comments': comments.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Review submitted. +${result['reward_mrc'] ?? 8} MRC.'),
        ),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      comments.dispose();
    }
  }

  Future<void> _fund() async {
    final amount = TextEditingController(text: '100');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fund this research'),
        content: TextField(
          controller: amount,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount in MRC',
            helperText: '90% to the researcher, 10% platform fee.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Fund'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final result = await AuthApi.fundResearch(
        widget.stageId,
        double.tryParse(amount.text) ?? 0,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Funded. Researcher received ${result['payout_mrc']} MRC.',
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      amount.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = _stage;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (s == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Not found')),
      );
    }
    final authors = (s['authors'] as List? ?? const []);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Research'),
        actions: [
          IconButton(
            onPressed: _fund,
            tooltip: 'Fund research',
            icon: const Icon(Icons.volunteer_activism_outlined),
          ),
          if (_canReview && s['researcher_id']?.toString() != widget.user.id)
            IconButton(
              onPressed: _review,
              tooltip: 'Peer review',
              icon: const Icon(Icons.rate_review_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0E6B5C), Color(0xFF0A3F36)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s['stage'] ?? 'IDEA'}  ${s['peer_review_status'] ?? 'OPEN'}',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  s['title']?.toString() ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  s['researcher_name']?.toString() ?? 'Researcher',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .72),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _pill('${s['impact_score'] ?? 0} impact'),
                    _pill('${s['review_count'] ?? 0} reviews'),
                    _pill(
                      '${s['funding_raised_mrc'] ?? 0} / ${s['funding_goal_mrc'] ?? 0} MRC',
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (authors.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Authors',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            ...authors.whereType<Map>().map(
                  (a) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(Icons.school_outlined, size: 18),
                    ),
                    title: Text(
                      a['name']?.toString() ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${a['role_title'] ?? ''}${(a['affiliation'] ?? '').toString().isNotEmpty ? ' · ${a['affiliation']}' : ''}',
                      style:
                          TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ),
                ),
          ],
          if ((s['abstract'] ?? s['summary'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Abstract',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              (s['abstract'] ?? s['summary']).toString(),
              style: TextStyle(
                height: 1.55,
                color: cs.onSurfaceVariant,
                fontSize: 13.5,
              ),
            ),
          ],
          if ((s['methodology'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Methodology',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              s['methodology'].toString(),
              style: TextStyle(
                height: 1.55,
                color: cs.onSurfaceVariant,
                fontSize: 13.5,
              ),
            ),
          ],
          if ((s['expected_impact'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Expected impact',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              s['expected_impact'].toString(),
              style: TextStyle(
                height: 1.55,
                color: cs.onSurfaceVariant,
                fontSize: 13.5,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ContentEngagement(
            targetType: 'research',
            targetId: widget.stageId,
            user: widget.user,
            initialReactions: (s['reaction_count'] as num?)?.toInt() ?? 0,
            initialComments: (s['comment_count'] as num?)?.toInt() ?? 0,
          ),
          if (_reviews.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Peer reviews',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            ..._reviews.map(
              (v) => Card(
                margin: const EdgeInsets.only(top: 8),
                child: ListTile(
                  leading: Icon(
                    v['verdict'] == 'ACCEPT'
                        ? Icons.verified_outlined
                        : Icons.edit_note,
                    color: v['verdict'] == 'ACCEPT'
                        ? AppColors.brand
                        : AppColors.amber,
                  ),
                  title: Text(
                    v['reviewer_name']?.toString() ?? 'Reviewer',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${v['verdict']} · ${v['comments'] ?? ''}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _fund,
            icon: const Icon(Icons.volunteer_activism_outlined),
            label: Text(
              'Fund research · ${s['funding_raised_mrc'] ?? 0} / ${s['funding_goal_mrc'] ?? 0} MRC',
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white.withValues(alpha: .14)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}
