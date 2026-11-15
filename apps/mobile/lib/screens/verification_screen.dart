import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/models.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/widgets/animations.dart';
import 'package:masaren/screens/evidence_capture_screen.dart';

/// Evidence tracing & verification pipeline tracker.
class VerificationScreen extends StatefulWidget {
  final User user;
  const VerificationScreen({super.key, required this.user});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  List<Submission> _items = [];
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
      _error = null;
      _items = await AuthApi.mySubmissions(widget.user.id);
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _newSubmission() async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EvidenceCaptureScreen(
              user: widget.user,
              createSubmission: true,
            )));
    await _load();
  }
  Future<void> _openDetail(Submission sub) async {
    final canRetract =
        ['SUBMITTED', 'AI_REVIEW'].contains((sub.status ?? '').toUpperCase());
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(c).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                sub.title ??
                    MasarenLocalizations.of(
                        context, 'verification.submissionFallback'),
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (sub.claim != null && sub.claim!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(sub.claim!,
                    style:
                        const TextStyle(color: AppColors.muted, height: 1.4)),
              ),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _pill(_statusLabel(context, sub.status), AppColors.azure),
              if (sub.confidence > 0)
                _pill(
                    '${sub.confidence.toStringAsFixed(0)}%', AppColors.accent),
            ]),
            if (canRetract)
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.undo),
                    onPressed: () => Navigator.pop(c, 'retract'),
                    label: Text(MasarenLocalizations.of(
                        context, 'verification.retractSubmission')),
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (action != 'retract' || !mounted) return;
    try {
      await AuthApi.retractSubmission(sub.id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                MasarenLocalizations.of(context, 'verification.retracted'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(MasarenLocalizations.of(context, 'common.failed')
                .replaceAll('{error}', '$e'))));
      }
    }
  }

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999)),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(MasarenLocalizations.of(context, 'verification.title'))),
      floatingActionButton: FloatingActionButton(
        onPressed: _newSubmission,
        backgroundColor: AppColors.azure,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(message: _error, onRetry: () => _load())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      SectionTitle(
                          title: MasarenLocalizations.of(
                              context, 'verification.pipelineTitle')),
                      if (_items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                              MasarenLocalizations.of(
                                  context, 'verification.noSubmissions'),
                              style: const TextStyle(color: AppColors.muted)),
                        ),
                      ..._items.asMap().entries.map((entry) => SlideInWidget(
                            delay: Duration(milliseconds: 60 * entry.key),
                            child: _SubmissionCard(
                                sub: entry.value, onTap: _openDetail),
                          )),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  final Submission sub;
  final void Function(Submission) onTap;
  const _SubmissionCard({required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const stages = ['SUBMITTED', 'AI_REVIEW', 'HUMAN_REVIEW', 'VERIFIED'];
    final raw = (sub.status ?? 'SUBMITTED').toUpperCase();
    final rejected = raw == 'REJECTED';
    final current = stages.indexOf(raw);
    final badgeColor = raw == 'VERIFIED'
        ? AppColors.accent
        : rejected
            ? AppColors.warm
            : AppColors.azure;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onTap(sub),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                        sub.title ??
                            MasarenLocalizations.of(
                                context, 'verification.submissionFallback'),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(_statusLabel(context, sub.status),
                        style: TextStyle(
                            color: badgeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: stages.asMap().entries.map((e) {
                  final done =
                      !rejected && e.key <= (current < 0 ? -1 : current);
                  return Expanded(
                    child: Column(
                      children: [
                        Container(
                          height: 4,
                          color:
                              done ? AppColors.accent : AppColors.darkSurface2,
                        ),
                        const SizedBox(height: 4),
                        Text(_stageLabel(context, e.value),
                            style: TextStyle(
                                color:
                                    done ? AppColors.accent : AppColors.muted,
                                fontSize: 10)),
                      ],
                    ),
                  );
                }).toList(),
              ),
              if (rejected)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    MasarenLocalizations.of(
                        context, 'verification.rejectedNote'),
                    style: const TextStyle(color: AppColors.warm, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _stageLabel(BuildContext context, String stage) {
  final key = switch (stage) {
    'SUBMITTED' => 'verification.stage.submitted',
    'AI_REVIEW' => 'verification.stage.ai',
    'HUMAN_REVIEW' => 'verification.stage.human',
    'VERIFIED' => 'verification.stage.verified',
    _ => 'verification.stage.submitted',
  };
  return MasarenLocalizations.of(context, key);
}

String _statusLabel(BuildContext context, String? status) {
  final value = (status ?? 'SUBMITTED').toUpperCase();
  final key = switch (value) {
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
