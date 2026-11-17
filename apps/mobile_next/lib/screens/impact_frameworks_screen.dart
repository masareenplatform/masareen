import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/theme.dart';

class ImpactFrameworksScreen extends StatefulWidget {
  const ImpactFrameworksScreen({super.key});

  @override
  State<ImpactFrameworksScreen> createState() => _ImpactFrameworksScreenState();
}

class _ImpactFrameworksScreenState extends State<ImpactFrameworksScreen> {
  List<Map<String, dynamic>> _items = [];
  String _type = 'NEWS';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await AuthApi.impactFrameworks();
      if (!mounted) return;
      setState(() {
        _items = rows;
        if (rows.isNotEmpty && !rows.any((r) => r['entity_type'] == _type)) {
          _type = rows.first['entity_type'].toString();
        }
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = _items.where((r) => r['entity_type'] == _type).toList();
    final current = selected.isEmpty ? <String, dynamic>{} : selected.first;
    final indicators = (current['indicators'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Impact frameworks')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Text(
                    'Different entities create different kinds of value. These are the indicators MASAREEN uses to keep measurement fair.',
                    style: TextStyle(
                        color: cs.onSurfaceVariant, height: 1.5, fontSize: 13)),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final item in _items)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 6),
                          child: ChoiceChip(
                            label: Text(item['entity_type'].toString()),
                            selected: _type == item['entity_type'],
                            onSelected: (_) => setState(
                                () => _type = item['entity_type'].toString()),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF0E6B5C), Color(0xFF0A3F36)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_type,
                          style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 10,
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      Text(current['title']?.toString() ?? 'Impact framework',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(current['description']?.toString() ?? '',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: .7),
                              fontSize: 12,
                              height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                for (final indicator in indicators)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                    indicator['label']?.toString() ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                              ),
                              Text(
                                  '${((indicator['weight'] as num? ?? 0) * 100).round()}%',
                                  style: TextStyle(
                                      color: cs.primary,
                                      fontWeight: FontWeight.w900)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value:
                                  (indicator['weight'] as num? ?? 0).toDouble(),
                              minHeight: 5,
                              backgroundColor: cs.outlineVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                              '${indicator['source'] ?? ''} · ${indicator['unit'] ?? ''}',
                              style: TextStyle(
                                  color: cs.onSurfaceVariant, fontSize: 10.5)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
