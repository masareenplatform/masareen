import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/models.dart';
import 'package:masaren/widgets.dart';

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
    final title = TextEditingController();
    final evidenceId = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Submit evidence'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: evidenceId,
                decoration: const InputDecoration(labelText: 'Evidence ID')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (title.text.trim().isEmpty) return;
              Navigator.pop(c, true);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final sub = await AuthApi.createSubmission({
        'title': title.text.trim(),
        'evidence_id': evidenceId.text.trim().isNotEmpty
            ? evidenceId.text.trim()
            : null,
        'owner_id': widget.user.id,
      });
      // Kick off the verification pipeline automatically.
      await AuthApi.startPipeline(sub.id);
      _items.insert(0, sub);
      if (mounted) setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Submission sent to verification pipeline')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verification')),
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
                    children: [
                      const SectionTitle(title: 'Evidence tracing & pipeline'),
                      if (_items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                              'No submissions yet. Submit evidence to start the verification pipeline.',
                              style: TextStyle(color: AppColors.muted)),
                        ),
                      ..._items.map((s) => _SubmissionCard(sub: s)),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  final Submission sub;
  const _SubmissionCard({required this.sub});

  @override
  Widget build(BuildContext context) {
    final stages = const ['SUBMITTED', 'AI_REVIEW', 'HUMAN_REVIEW', 'VERIFIED'];
    final current = sub.status != null
        ? stages.indexOf(sub.status!.toUpperCase())
        : 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(sub.title ?? 'Submission',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (sub.status ?? '').toUpperCase() == 'VERIFIED'
                        ? AppColors.accent.withValues(alpha: 0.15)
                        : AppColors.azure.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(sub.status ?? 'SUBMITTED',
                      style: TextStyle(
                          color: (sub.status ?? '').toUpperCase() == 'VERIFIED'
                              ? AppColors.accent
                              : AppColors.azure,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: stages.asMap().entries.map((e) {
                final done = e.key <= (current < 0 ? 0 : current);
                return Expanded(
                  child: Column(
                    children: [
                      Container(
                        height: 4,
                        color: done ? AppColors.accent : AppColors.darkSurface2,
                      ),
                      const SizedBox(height: 4),
                      Text(e.value.split('_').first,
                          style: TextStyle(
                              color: done ? AppColors.accent : AppColors.muted,
                              fontSize: 10)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
