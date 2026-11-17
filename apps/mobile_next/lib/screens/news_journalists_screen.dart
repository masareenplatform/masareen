import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/models.dart';
import 'package:masaren/screens/newsroom_screen.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';

class JournalistDirectoryScreen extends StatefulWidget {
  final User user;
  const JournalistDirectoryScreen({super.key, required this.user});

  @override
  State<JournalistDirectoryScreen> createState() =>
      _JournalistDirectoryScreenState();
}

class _JournalistDirectoryScreenState extends State<JournalistDirectoryScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await AuthApi.newsJournalists(q: _search.text.trim());
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Journalists')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'Search by journalist or outlet',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: _items.length,
                          itemBuilder: (_, i) {
                            final j = _items[i];
                            return Card(
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                leading: AppAvatar(
                                  name: j['name']?.toString() ?? 'Journalist',
                                  url: j['avatar_url']?.toString(),
                                  size: 46,
                                ),
                                title: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        j['name']?.toString() ?? 'Journalist',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    if (j['verified'] == true) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.verified,
                                        size: 15,
                                        color: cs.primary,
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Text(
                                  '${j['outlet_name'] ?? ''}  ${j['articles_count'] ?? 0} stories  ${j['impact_score'] ?? 0} impact',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => JournalistProfileScreen(
                                        journalistId: j['id'].toString(),
                                        user: widget.user,
                                      ),
                                    ),
                                  );
                                  _load();
                                },
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

class JournalistProfileScreen extends StatefulWidget {
  final String journalistId;
  final User user;
  const JournalistProfileScreen({
    super.key,
    required this.journalistId,
    required this.user,
  });

  @override
  State<JournalistProfileScreen> createState() =>
      _JournalistProfileScreenState();
}

class _JournalistProfileScreenState extends State<JournalistProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await AuthApi.newsJournalist(widget.journalistId);
      if (mounted) setState(() => _profile = data);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = _profile;
    return Scaffold(
      appBar: AppBar(title: Text(p?['name']?.toString() ?? 'Journalist')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : p == null
              ? const Center(child: Text('Journalist not found'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0E6B5C), Color(0xFF0A3F36)],
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          AppAvatar(
                            name: p['name']?.toString() ?? 'Journalist',
                            url: p['avatar_url']?.toString(),
                            size: 72,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        p['name']?.toString() ?? 'Journalist',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    if (p['verified'] == true) ...[
                                      const SizedBox(width: 5),
                                      const Icon(
                                        Icons.verified,
                                        size: 18,
                                        color: AppColors.gold,
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  '${p['title'] ?? 'Correspondent'} · ${p['outlet_name'] ?? ''}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: .7),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${p['articles_count'] ?? 0} stories · ${p['impact_score'] ?? 0} impact',
                                  style: const TextStyle(
                                    color: AppColors.gold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if ((p['bio'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        p['bio'].toString(),
                        style: TextStyle(
                          height: 1.6,
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Text(
                      'Stories',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...(p['articles'] as List? ?? const [])
                        .whereType<Map>()
                        .map(
                          (a) => Card(
                            child: ListTile(
                              leading: (a['cover_url'] ?? '')
                                      .toString()
                                      .isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        a['cover_url'].toString(),
                                        width: 54,
                                        height: 54,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.newspaper),
                                      ),
                                    )
                                  : const Icon(Icons.newspaper),
                              title: Text(
                                a['title']?.toString() ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                '${a['impact_score'] ?? 0} impact · ${a['reaction_count'] ?? 0} reactions',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => NewsArticleScreen(
                                    articleId: a['id'].toString(),
                                    user: widget.user,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
    );
  }
}
