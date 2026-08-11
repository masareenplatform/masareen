import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/models.dart';
import 'package:masaren/widgets.dart';

class OpportunitiesScreen extends StatefulWidget {
  final User user;
  const OpportunitiesScreen({super.key, required this.user});

  @override
  State<OpportunitiesScreen> createState() => _OpportunitiesScreenState();
}

class _OpportunitiesScreenState extends State<OpportunitiesScreen> {
  List<Opportunity> _items = [];
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
      _items = await AuthApi.opportunities();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Opportunities')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(message: _error, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    children: [
                      const SectionTitle(title: 'Find your next impact'),
                      if (_items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No opportunities right now.',
                              style: TextStyle(color: AppColors.muted)),
                        ),
                      ..._items.map((o) => _OpportunityCard(o: o)),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  final Opportunity o;
  const _OpportunityCard({required this.o});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.explore, color: AppColors.azure),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(o.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, color: Colors.white, fontSize: 16)),
                ),
                if (o.sdg != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('SDG ${o.sdg}',
                        style: const TextStyle(color: AppColors.accent, fontSize: 12)),
                  ),
              ],
            ),
            if (o.description != null) ...[
              const SizedBox(height: 8),
              Text(o.description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, height: 1.4)),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (o.minPms != null)
                  Chip(
                    label: Text('Min PMS ${o.minPms!.toInt()}',
                        style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                  ),
                if (o.location != null)
                  Chip(
                    label: Text(o.location!, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                  ),
                ...o.skills.take(3).map((s) => Chip(
                      label: Text(s.toString(), style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                    )),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.azure,
                  side: const BorderSide(color: AppColors.azure),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
