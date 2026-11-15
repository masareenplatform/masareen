import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

class GpsHistoryScreen extends StatefulWidget {
  final User user;
  const GpsHistoryScreen({super.key, required this.user});

  @override
  State<GpsHistoryScreen> createState() => _GpsHistoryScreenState();
}

class _GpsHistoryScreenState extends State<GpsHistoryScreen> {
  List<GpsRecord> _records = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await AuthApi.gpsHistory();
      if (!mounted) return;
      setState(() {
        _records = rows;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _openMap(GpsRecord r) async {
    final uri = Uri.parse(r.mapsUrl);
    if (!await canLaunchUrl(uri)) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _dateLabel(GpsRecord r) {
    final raw = r.capturedAt ?? r.createdAt;
    if (raw == null) return '';
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return raw;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${parsed.year}-${two(parsed.month)}-${two(parsed.day)} '
        '${two(parsed.hour)}:${two(parsed.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String l(String key, String fallback) {
      final value = MasarenLocalizations.of(context, key);
      return value == key ? fallback : value;
    }
    return Scaffold(
      appBar: AppBar(title: Text(l('gps.title', 'Location history'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(message: _error, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _records.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 120),
                          Icon(Icons.location_off_outlined,
                              size: 56, color: cs.outline),
                          const SizedBox(height: 12),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              l('gps.empty',
                                  'No location records yet. Add a location when you create a post.'),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _records.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: cs.outlineVariant),
                          itemBuilder: (_, i) {
                            final r = _records[i];
                            final accuracy = r.accuracy;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: cs.primaryContainer,
                                child: Icon(Icons.location_on_outlined,
                                    color: cs.onPrimaryContainer),
                              ),
                              title: Text(
                                  '${r.latitude.toStringAsFixed(5)}, ${r.longitude.toStringAsFixed(5)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              subtitle: Text([
                                _dateLabel(r),
                                if (accuracy != null)
                                  '${l('gps.accuracy', 'Accuracy')}: '
                                      '${accuracy.toStringAsFixed(0)} m',
                              ].where((e) => e.isNotEmpty).join(' · ')),
                              trailing: IconButton(
                                icon: const Icon(Icons.map_outlined),
                                tooltip: l('gps.openMap', 'Open in Maps'),
                                onPressed: () => _openMap(r),
                              ),
                              onTap: () => _openMap(r),
                            );
                          },
                        ),
                ),
    );
  }
}
