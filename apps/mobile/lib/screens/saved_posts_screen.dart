import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/screens/post_detail_screen.dart';
import 'package:masaren/widgets.dart';

class SavedPostsScreen extends StatefulWidget {
  final User user;
  const SavedPostsScreen({super.key, required this.user});

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  List<Post> _posts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await AuthApi.bookmarks();
      if (!mounted) return;
      setState(() {
        _posts = rows;
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

  Future<void> _remove(Post p) async {
    setState(() => _posts.removeWhere((e) => e.id == p.id));
    try {
      await AuthApi.toggleBookmark(p.id);
    } catch (_) {
      if (mounted) setState(() => _posts.insert(0, p));
    }
  }

  Future<void> _open(Post p) async {
    final result = await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PostDetailScreen(
              post: p,
              currentUser: widget.user,
              onChanged: (updated) {
                final i = _posts.indexWhere((e) => e.id == updated.id);
                if (i == -1) return;
                setState(() {
                  if (updated.bookmarkedByMe) {
                    _posts[i] = updated;
                  } else {
                    _posts.removeAt(i);
                  }
                });
              },
            )));
    if (result == 'deleted' && mounted) {
      setState(() => _posts.removeWhere((e) => e.id == p.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar:
          AppBar(title: Text(MasarenLocalizations.of(context, 'saved.title'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(message: _error, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _posts.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 120),
                          Icon(Icons.bookmark_border,
                              size: 56, color: cs.outline),
                          const SizedBox(height: 12),
                          Center(
                              child: Text(
                                  MasarenLocalizations.of(
                                      context, 'saved.empty'),
                                  style:
                                      TextStyle(color: cs.onSurfaceVariant))),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _posts.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: cs.outlineVariant),
                          itemBuilder: (_, i) {
                            final p = _posts[i];
                            return ListTile(
                              leading: AppAvatar(
                                  name: p.author.name,
                                  url: p.author.avatarUrl,
                                  size: 40),
                              title: Text(p.author.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              subtitle: Text(p.text,
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              trailing: IconButton(
                                icon: const Icon(Icons.bookmark),
                                onPressed: () => _remove(p),
                              ),
                              onTap: () => _open(p),
                            );
                          },
                        ),
                ),
    );
  }
}
