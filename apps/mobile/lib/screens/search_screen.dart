import 'dart:async';

import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/screens/messages_screen.dart';
import 'package:masaren/screens/post_detail_screen.dart';
import 'package:masaren/screens/profile_view_screen.dart';
import 'package:masaren/widgets.dart';

class SearchScreen extends StatefulWidget {
  final User user;
  const SearchScreen({super.key, required this.user});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctl = TextEditingController();
  Timer? _debounce;
  SocialSearchResult? _result;
  List<HashtagTrend> _trends = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrends();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _loadTrends() async {
    try {
      final rows = await AuthApi.trends();
      if (mounted) setState(() => _trends = rows);
    } catch (_) {}
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() {
        _result = null;
        _error = null;
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await AuthApi.search(q);
      if (!mounted || _ctl.text.trim() != q) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || _ctl.text.trim() != q) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _useTag(String tag) {
    _debounce?.cancel();
    _ctl.text = '#$tag';
    _ctl.selection = TextSelection.collapsed(offset: _ctl.text.length);
    _search('#$tag');
  }

  Future<void> _openPost(Post p) async {
    final result = await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PostDetailScreen(
              post: p,
              currentUser: widget.user,
              onChanged: (updated) {
                final current = _result;
                if (current == null) return;
                final posts = current.posts
                    .map((e) => e.id == updated.id ? updated : e)
                    .toList();
                setState(() => _result = SocialSearchResult(
                    query: current.query,
                    users: current.users,
                    posts: posts,
                    hashtags: current.hashtags));
              },
            )));
    if (result == 'deleted' && mounted && _result != null) {
      final current = _result!;
      setState(() => _result = SocialSearchResult(
          query: current.query,
          users: current.users,
          posts: current.posts.where((e) => e.id != p.id).toList(),
          hashtags: current.hashtags));
    }
  }

  Future<void> _message(Author peer) async {
    try {
      final c = await AuthApi.openConversation(peer.id);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatScreen(conversation: c, user: widget.user)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final loc = (String key) => MasarenLocalizations.of(context, key);
    final result = _result;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctl,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: (v) {
            final q = v.trim();
            if (q.length >= 2) _search(q);
          },
          decoration: InputDecoration(
            hintText: loc('search.hint'),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_ctl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _ctl.clear();
                _onChanged('');
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(
                  message: _error, onRetry: () => _search(_ctl.text.trim()))
              : result == null
                  ? _TrendingList(trends: _trends, onTag: _useTag)
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        if (result.users.isNotEmpty) ...[
                          SectionTitle(title: loc('search.people')),
                          ...result.users.map((u) => ListTile(
                                leading: AppAvatar(
                                    name: u.name, url: u.avatarUrl, size: 42),
                                title: Row(children: [
                                  Flexible(child: Text(u.name)),
                                  if (u.verified)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Icon(Icons.verified,
                                          size: 15, color: Colors.blue),
                                    ),
                                ]),
                                subtitle: Text(
                                    u.handle == null ? '' : '@${u.handle}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                trailing: IconButton(
                                  icon: const Icon(Icons.chat_bubble_outline),
                                  onPressed: () => _message(u),
                                ),
                                onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => ProfileViewScreen(
                                            userId: u.id,
                                            currentUser: widget.user))),
                              )),
                        ],
                        if (result.hashtags.isNotEmpty) ...[
                          SectionTitle(title: loc('search.tags')),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: result.hashtags
                                  .map((h) => ActionChip(
                                        label: Text('#${h.tag}  ${h.count}'),
                                        onPressed: () => _useTag(h.tag),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ],
                        if (result.posts.isNotEmpty) ...[
                          SectionTitle(title: loc('search.posts')),
                          ...result.posts.map((p) =>
                              _PostResult(post: p, onTap: () => _openPost(p))),
                        ],
                        if (result.users.isEmpty &&
                            result.posts.isEmpty &&
                            result.hashtags.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(48),
                            child: Column(children: [
                              Icon(Icons.search_off,
                                  size: 52, color: cs.outline),
                              const SizedBox(height: 12),
                              Text(loc('search.empty'),
                                  style: TextStyle(color: cs.onSurfaceVariant)),
                            ]),
                          ),
                      ],
                    ),
    );
  }
}

class _TrendingList extends StatelessWidget {
  final List<HashtagTrend> trends;
  final ValueChanged<String> onTag;
  const _TrendingList({required this.trends, required this.onTag});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SectionTitle(
            title: MasarenLocalizations.of(context, 'search.trending')),
        if (trends.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
                child: Text(MasarenLocalizations.of(context, 'search.empty'),
                    style: TextStyle(color: cs.onSurfaceVariant))),
          )
        else
          ...trends.asMap().entries.map((e) {
            final t = e.value;
            return ListTile(
              leading: SizedBox(
                width: 28,
                child: Text('${e.key + 1}',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurfaceVariant)),
              ),
              title: Text('#${t.tag}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${t.count} posts'),
              trailing: const Icon(Icons.north_east, size: 18),
              onTap: () => onTag(t.tag),
            );
          }),
      ],
    );
  }
}

class _PostResult extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;
  const _PostResult({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            AppAvatar(
                name: post.author.name, url: post.author.avatarUrl, size: 32),
            const SizedBox(width: 8),
            Expanded(
              child: Text(post.author.name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Text(timeAgo(post.createdAt),
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ]),
          const SizedBox(height: 8),
          Text(post.text, maxLines: 4, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.favorite_border, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Text('${post.likes}',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            const SizedBox(width: 14),
            Icon(Icons.mode_comment_outlined,
                size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Text('${post.comments}',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ]),
          const SizedBox(height: 8),
          Divider(height: 1, color: cs.outlineVariant),
        ]),
      ),
    );
  }
}
