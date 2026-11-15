import 'dart:async';

import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/screens/institution_profile_screen.dart';
import 'package:masaren/widgets.dart';

class UniversitiesScreen extends StatefulWidget {
  final User user;
  const UniversitiesScreen({super.key, required this.user});

  @override
  State<UniversitiesScreen> createState() => _UniversitiesScreenState();
}

class _UniversitiesScreenState extends State<UniversitiesScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String _filter = 'UNIVERSITY';
  Timer? _debounce;

  static const _filters = [
    'UNIVERSITY',
    'GOVERNMENT',
    'ORGANIZATION',
    'MEDIA',
    'SPORTS',
    'ALL',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await AuthApi.institutions(
          q: _search.text, type: _filter == 'ALL' ? null : _filter);
      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ApiException ? e.message : e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  String _label(String key) {
    final value = MasarenLocalizations.of(context, key);
    return value == key ? key.split('.').last : value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(MasarenLocalizations.of(context, 'universities.title'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: _onSearch,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText:
                    MasarenLocalizations.of(context, 'universities.search'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          _load();
                        }),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: _filters
                  .map((f) => Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: ChoiceChip(
                          label: Text(
                              _label('universities.filter.${f.toLowerCase()}')),
                          selected: _filter == f,
                          onSelected: (_) {
                            setState(() => _filter = f);
                            _load();
                          },
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              FilledButton(
                                  onPressed: _load,
                                  child: Text(MasarenLocalizations.of(
                                      context, 'common.retry'))),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
                          itemCount: _items.length,
                          itemBuilder: (_, index) {
                            final item = _items[index];
                            final rawType = (item['institution_type'] ??
                                    item['role'] ??
                                    'institution')
                                .toString()
                                .toLowerCase();
                            final typeKey = 'institution.type.$rawType';
                            final localized = _label(typeKey);
                            return _InstitutionCard(
                              item: item,
                              typeLabel: localized == typeKey.split('.').last
                                  ? rawType
                                  : localized,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => InstitutionProfileScreen(
                                    institutionId:
                                        (item['id'] ?? '').toString(),
                                    user: widget.user,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _InstitutionCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String typeLabel;
  final VoidCallback onTap;
  const _InstitutionCard(
      {required this.item, required this.typeLabel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final counts = item['counts'] is Map
        ? Map<String, dynamic>.from(item['counts'] as Map)
        : const <String, dynamic>{};
    final name = (item['name'] ?? 'Institution').toString();
    final bio = (item['bio'] ?? '').toString();
    final location = [item['city'], item['country']]
        .where((v) => v != null && v.toString().isNotEmpty)
        .join(', ');
    final chips = <String>[
      if ((counts['courses'] ?? 0) > 0)
        '${counts['courses']} ${MasarenLocalizations.of(context, 'institution.courses')}',
      if ((counts['projects'] ?? 0) > 0)
        '${counts['projects']} ${MasarenLocalizations.of(context, 'institution.projects')}',
      if ((counts['research'] ?? 0) > 0)
        '${counts['research']} ${MasarenLocalizations.of(context, 'institution.research')}',
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppAvatar(
                      name: name,
                      url: item['avatar_url']?.toString(),
                      size: 52),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: cs.onSurface)),
                            ),
                            if (item['verified'] == true)
                              Icon(Icons.verified, size: 18, color: cs.primary),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          location.isEmpty
                              ? typeLabel
                              : '$typeLabel · $location',
                          style: TextStyle(
                              fontSize: 12.5, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                ],
              ),
              if (bio.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: cs.onSurfaceVariant)),
              ],
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: chips
                      .map((c) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(c,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: cs.primary)),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
