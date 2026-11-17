import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
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
      appBar: AppBar(
          title: Text(MasarenLocalizations.of(context, 'passport.title'))),
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
                        SectionTitle(
                            title: MasarenLocalizations.of(
                                context, 'passport.badges')),
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
                        title: MasarenLocalizations.of(
                            context, 'passport.claimsEvidence'),
                        action:
                            MasarenLocalizations.of(context, 'passport.verify'),
                        onAction: () async {
                          await Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) =>
                                  VerificationScreen(user: widget.user)));
                          _load();
                        },
                      ),
                      if ((_data!['claims'] as List?)?.isEmpty ?? true)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            MasarenLocalizations.of(
                                context, 'passport.noClaims'),
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ...((_data!['claims'] as List?) ?? []).map((c) =>
                          _claimCard(context, c as Map<String, dynamic>)),
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
          AppAvatar(
              name: name, url: _data!['avatar_url']?.toString(), size: 58),
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
                Text(
                    MasarenLocalizations.of(context, 'passport.impactPoints')
                        .replaceAll(
                            '{count}', '${_data!['impact_score'] ?? 0}'),
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
      (
        MasarenLocalizations.of(context, 'passport.verifiedClaims'),
        _data!['verified_claims']
      ),
      (
        MasarenLocalizations.of(context, 'passport.submissions'),
        _data!['submissions']
      ),
      (
        MasarenLocalizations.of(context, 'passport.programs'),
        _data!['programs']
      ),
      (
        MasarenLocalizations.of(context, 'passport.projects'),
        _data!['projects']
      ),
      (
        MasarenLocalizations.of(context, 'passport.tasksDone'),
        _data!['tasks_completed']
      ),
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

  String _statusLabel(BuildContext context, String status) {
    final key = switch (status) {
      'SUBMITTED' => 'verification.status.submitted',
      'AI_REVIEW' => 'verification.status.aiReview',
      'HUMAN_REVIEW' => 'verification.status.humanReview',
      'VERIFIED' => 'verification.status.verified',
      'REJECTED' => 'verification.status.rejected',
      'PENDING' => 'verification.status.pending',
      _ => 'verification.status.submitted',
    };
    return MasarenLocalizations.of(context, key);
  }

  Widget _claimCard(BuildContext context, Map<String, dynamic> c) {
    final status = (c['status'] ?? 'SUBMITTED').toString().toUpperCase();
    final verified = status == 'VERIFIED';
    final claim = c['claim']?.toString();
    final hasDetail = claim != null && claim.isNotEmpty;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(
          verified ? Icons.verified_rounded : Icons.pending_outlined,
          color: verified ? AppColors.accent : AppColors.amber,
        ),
        title: Text(c['title']?.toString() ??
            MasarenLocalizations.of(context, 'passport.claimFallback')),
        subtitle: Text(
          [
            _statusLabel(context, status),
            if (c['confidence'] is num)
              MasarenLocalizations.of(context, 'passport.confidence')
                  .replaceAll('{value}', '${(c['confidence'] as num).toInt()}'),
          ].join(' - '),
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        trailing: hasDetail ? Icon(directionalChevronIcon(context)) : null,
        onTap: hasDetail
            ? () => showModalBottomSheet(
                  context: context,
                  builder: (sheet) => Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            c['title']?.toString() ??
                                MasarenLocalizations.of(
                                    context, 'passport.claimFallback'),
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        Text(claim,
                            style: const TextStyle(
                                color: AppColors.muted, height: 1.5)),
                        const SizedBox(height: 16),
                        Text(
                            '${_statusLabel(context, status)} - ${c['created_at']?.toString().substring(0, 10) ?? ''}',
                            style: const TextStyle(
                                color: AppColors.azure, fontSize: 12)),
                      ],
                    ),
                  ),
                )
            : null,
      ),
    );
  }
}
