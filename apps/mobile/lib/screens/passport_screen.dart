import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/models.dart';
import 'package:masaren/screens/verification_screen.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';

/// Verified impact passport: claims, programs, projects and tasks in one place.
class PassportScreen extends StatefulWidget {
  final User user;
  const PassportScreen({super.key, required this.user});

  @override
  State<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends State<PassportScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _data = await AuthApi.passport(widget.user.id);
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Impact passport')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(message: _error, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    children: [
                      _header(context),
                      _stats(context),
                      if ((_data!['badges'] as List?)?.isNotEmpty == true) ...[
                        const SectionTitle(title: 'Badges'),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: (_data!['badges'] as List)
                                .map((b) => Chip(
                                      avatar: const Icon(Icons.verified,
                                          size: 16, color: AppColors.accent),
                                      label: Text(b.toString()),
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                      SectionTitle(
                        title: 'Claims & evidence',
                        action: 'Verify',
                        onAction: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    VerificationScreen(user: widget.user))),
                      ),
                      if ((_data!['claims'] as List?)?.isEmpty ?? true)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No claims yet. Submit evidence to build your verified passport.',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ...((_data!['claims'] as List?) ?? [])
                          .map((c) => _claimCard(context, c as Map<String, dynamic>)),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _header(BuildContext context) {
    final name = _data!['name']?.toString() ?? widget.user.fullName;
    final role = _data!['role']?.toString() ?? '';
    final country = _data!['country']?.toString();
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: brandGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          AppAvatar(name: name, url: _data!['avatar_url']?.toString(), size: 58),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  [if (role.isNotEmpty) role, if (country != null) country]
                      .join(' - '),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Text('${_data!['impact_score'] ?? 0} impact points',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stats(BuildContext context) {
    final stats = [
      ('Verified claims', _data!['verified_claims']),
      ('Submissions', _data!['submissions']),
      ('Programs', _data!['programs']),
      ('Projects', _data!['projects']),
      ('Tasks done', _data!['tasks_completed']),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: stats
            .map((s) => SizedBox(
                  width: (MediaQuery.of(context).size.width - 40) / 2,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${s.$2 ?? 0}',
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                          const SizedBox(height: 2),
                          Text(s.$1,
                              style: const TextStyle(
                                  color: AppColors.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _claimCard(BuildContext context, Map<String, dynamic> c) {
    final status = (c['status'] ?? 'SUBMITTED').toString().toUpperCase();
    final verified = status == 'VERIFIED';
    return Card(
      child: ListTile(
        leading: Icon(
          verified ? Icons.verified_rounded : Icons.pending_outlined,
          color: verified ? AppColors.accent : AppColors.amber,
        ),
        title: Text(c['title']?.toString() ?? 'Claim'),
        subtitle: Text(
          [
            status,
            if (c['confidence'] is num) '${(c['confidence'] as num).toInt()}% confidence',
          ].join(' - '),
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
