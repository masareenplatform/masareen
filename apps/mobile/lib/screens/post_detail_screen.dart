import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/screens/messages_screen.dart';
import 'package:masaren/screens/moderators_screen.dart';
import 'package:masaren/screens/profile_view_screen.dart';
import 'package:masaren/services/live_sync_service.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/widgets/animations.dart';
import 'package:masaren/widgets/post_media_gallery.dart';
import 'package:masaren/widgets/role_badge.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;
  final User currentUser;
  final void Function(Post) onChanged;
  const PostDetailScreen(
      {super.key,
      required this.post,
      required this.currentUser,
      required this.onChanged});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Post _post;
  final _commentCtl = TextEditingController();
  final _scroll = ScrollController();
  List<Comment> _comments = [];
  Comment? _replyTo;
  bool _busy = false;
  bool _loadingComments = true;
  String? _lastCommentId;

  String _loc(String key) => MasarenLocalizations.of(context, key);

  bool get _isMine => _post.author.id == widget.currentUser.id;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _comments = widget.post.commentList;
    _lastCommentId = _comments.isEmpty ? null : _comments.last.id;
    LiveSyncService.instance.addListener(_onLiveSync);
    LiveSyncService.instance.watch(this, [_post.id]);
    _loadComments();
  }

  @override
  void dispose() {
    LiveSyncService.instance.removeListener(_onLiveSync);
    LiveSyncService.instance.unwatch(this);
    _commentCtl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onLiveSync() {
    if (!mounted) return;
    final stats = LiveSyncService.instance.statsFor(_post.id);
    if (stats == null) return;
    final shouldReload = stats.comments != _post.comments ||
        (stats.latestCommentId != null &&
            stats.latestCommentId != _lastCommentId);
    setState(() {
      _post = _post.copyWith(
        likes: stats.likes,
        comments: stats.comments,
        shares: stats.shares,
        likedByMe: stats.likedByMe,
        bookmarkedByMe: stats.bookmarkedByMe,
        impactValue: stats.impactValue ?? _post.impactValue,
        confidenceScore: stats.confidenceScore ?? _post.confidenceScore,
      );
    });
    widget.onChanged(_post);
    if (shouldReload) _loadComments();
  }

  Future<void> _loadComments() async {
    try {
      final list = await AuthApi.comments(_post.id);
      if (!mounted) return;
      setState(() {
        _comments = list;
        _lastCommentId = list.isEmpty ? null : list.last.id;
        _post = _post.copyWith(commentList: list, comments: list.length);
        _loadingComments = false;
      });
      widget.onChanged(_post);
    } catch (_) {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  void _changed() {
    _lastCommentId = _comments.isEmpty ? null : _comments.last.id;
    _post = _post.copyWith(commentList: _comments, comments: _comments.length);
    widget.onChanged(_post);
    if (mounted) setState(() {});
  }

  Future<void> _toggleLike() async {
    final was = _post.likedByMe;
    final likesBefore = _post.likes;
    setState(() => _post =
        _post.copyWith(likedByMe: !was, likes: _post.likes + (was ? -1 : 1)));
    widget.onChanged(_post);
    try {
      final res = await AuthApi.toggleLike(_post.id);
      if (!mounted) return;
      setState(() => _post = _post.copyWith(
            likedByMe: res['liked'] ?? res['likedByMe'] ?? !was,
            likes: (res['likes'] is num)
                ? (res['likes'] as num).toInt()
                : _post.likes,
          ));
      widget.onChanged(_post);
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _post = _post.copyWith(likedByMe: was, likes: likesBefore));
      widget.onChanged(_post);
    }
  }

  Future<void> _toggleBookmark() async {
    final was = _post.bookmarkedByMe;
    setState(() => _post = _post.copyWith(bookmarkedByMe: !was));
    widget.onChanged(_post);
    try {
      final res = await AuthApi.toggleBookmark(_post.id);
      if (!mounted) return;
      setState(() =>
          _post = _post.copyWith(bookmarkedByMe: res['bookmarked'] ?? !was));
      widget.onChanged(_post);
    } catch (_) {
      if (!mounted) return;
      setState(() => _post = _post.copyWith(bookmarkedByMe: was));
      widget.onChanged(_post);
    }
  }

  Future<void> _addComment() async {
    final text = _commentCtl.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      final c = await AuthApi.comment(_post.id, text, parentId: _replyTo?.id);
      _commentCtl.clear();
      _replyTo = null;
      setState(() => _comments = [..._comments, c]);
      _changed();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleCommentLike(Comment c) async {
    if (c.id == null) return;
    final i = _comments.indexWhere((e) => e.id == c.id);
    if (i == -1) return;
    final was = c.likedByMe;
    setState(() => _comments[i] =
        c.copyWith(likedByMe: !was, likeCount: c.likeCount + (was ? -1 : 1)));
    try {
      final res = await AuthApi.toggleCommentLike(c.id!);
      if (!mounted) return;
      final j = _comments.indexWhere((e) => e.id == c.id);
      if (j == -1) return;
      setState(() => _comments[j] = _comments[j].copyWith(
            likedByMe: res['liked'] ?? !was,
            likeCount: (res['likes'] is num)
                ? (res['likes'] as num).toInt()
                : _comments[j].likeCount,
          ));
      _changed();
    } catch (_) {
      if (!mounted) return;
      final j = _comments.indexWhere((e) => e.id == c.id);
      if (j != -1) setState(() => _comments[j] = c);
    }
  }

  Future<void> _deleteComment(Comment c) async {
    if (c.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_loc('post.deleteComment')),
        content: Text(c.text),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_loc('action.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(_loc('action.delete'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AuthApi.deleteComment(c.id!);
      if (!mounted) return;
      setState(() {
        final ids = <String>{c.id!};
        if (c.parentId == null) {
          for (final e in _comments) {
            if (e.parentId == c.id && e.id != null) ids.add(e.id!);
          }
        }
        _comments.removeWhere((e) => e.id != null && ids.contains(e.id));
      });
      _changed();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _editPost() async {
    final ctl = TextEditingController(text: _post.text);
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_loc('post.edit')),
        content: TextField(
            controller: ctl,
            autofocus: true,
            minLines: 3,
            maxLines: 8,
            maxLength: 5000,
            decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_loc('action.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
              child: Text(_loc('action.save'))),
        ],
      ),
    );
    ctl.dispose();
    if (text == null || text.isEmpty || text == _post.text) return;
    setState(() => _busy = true);
    try {
      final updated = await AuthApi.editPost(_post.id, text);
      if (!mounted) return;
      setState(() => _post =
          updated.copyWith(commentList: _comments, comments: _comments.length));
      widget.onChanged(_post);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deletePost() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_loc('post.delete')),
        content: Text(_loc('post.deleteConfirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_loc('action.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(_loc('action.delete'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AuthApi.deletePost(_post.id);
      if (mounted) Navigator.of(context).pop('deleted');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _report() async {
    final reasons = [
      ('misinformation', _loc('post.report.misinformation')),
      ('spam', _loc('post.report.spam')),
      ('harassment', _loc('post.report.harassment')),
      ('violence', _loc('post.report.violence')),
      ('other', _loc('post.report.other')),
    ];
    String reason = reasons.first.$1;
    final details = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(_loc('post.report')),
          content: RadioGroup<String>(
            groupValue: reason,
            onChanged: (v) => setLocal(() => reason = v ?? reason),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ...reasons.map((r) => RadioListTile<String>(
                    value: r.$1,
                    title: Text(r.$2),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  )),
              TextField(
                controller: details,
                maxLines: 2,
                decoration: InputDecoration(
                    hintText: _loc('post.reportContext'),
                    border: const OutlineInputBorder()),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(_loc('action.cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(_loc('action.report'))),
          ],
        ),
      ),
    );
    if (submit == true) {
      try {
        await AuthApi.report('post', _post.id,
            reason: reason, details: details.text);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(_loc('post.reportSent'))));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
    details.dispose();
  }

  Future<void> _blockAuthor() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_loc('post.block')),
        content: Text(
            _loc('post.blockConfirm').replaceAll('{name}', _post.author.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_loc('action.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(_loc('action.block'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await AuthApi.toggleBlock(_post.author.id);
      if (!mounted) return;
      final blocked = res['blocked'] == true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_loc(blocked ? 'post.blocked' : 'post.unblocked')
              .replaceAll('{name}', _post.author.name))));
      if (blocked) Navigator.of(context).pop('deleted');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _messageAuthor() async {
    try {
      final c = await AuthApi.openConversation(_post.author.id);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              ChatScreen(conversation: c, user: widget.currentUser)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _openAuthor() {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ProfileViewScreen(
            userId: _post.author.id, currentUser: widget.currentUser)));
  }

  void _showImpactInfo() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('How ISA v2 works'),
        content: const Text(
            'The Impact Score is non-linear: each domain saturates with diminishing returns, decays over time at a domain-specific rate, and is combined with evidence coverage, GPS location confidence, actor history and a consistency penalty. Community ratings use a Bayesian prior, so one vote cannot dominate. The final 0-1000 score is mapped to the 0-10 impact value.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _boostPost() async {
    final amount = TextEditingController(text: '25');
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Boost post with MRC'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Promoted posts are reserved a share of home-feed slots.',
              style: TextStyle(fontSize: 12)),
          const SizedBox(height: 10),
          TextField(
            controller: amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Amount (MRC, min 5)', suffixText: 'MRC'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_loc('action.cancel'))),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(amount.text.trim());
              if (parsed != null && parsed >= 5) {
                Navigator.pop(dialogContext, parsed);
              }
            },
            child: const Text('Boost'),
          ),
        ],
      ),
    );
    amount.dispose();
    if (value == null) return;
    try {
      await AuthApi.boostPost(_post.id, value);
      final updated = await AuthApi.postById(_post.id);
      if (!mounted) return;
      setState(() => _post = updated);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Post boosted and promoted in the home feed.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final roots = _comments.where((c) => c.parentId == null).toList();
    final replies = <String, List<Comment>>{};
    for (final c in _comments) {
      if (c.parentId != null) {
        replies.putIfAbsent(c.parentId!, () => []).add(c);
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_loc('post.comments')),
        actions: [
          IconButton(
            icon: Icon(
                _post.bookmarkedByMe ? Icons.bookmark : Icons.bookmark_border),
            tooltip:
                _post.bookmarkedByMe ? _loc('post.saved') : _loc('post.save'),
            onPressed: _toggleBookmark,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'edit':
                  _editPost();
                  break;
                case 'delete':
                  _deletePost();
                  break;
                case 'boost':
                  _boostPost();
                  break;
                case 'moderators':
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ModeratorsScreen(
                            entityType: 'POST',
                            entityId: _post.id,
                            entityTitle: _post.text,
                            currentUser: widget.currentUser,
                          )));
                  break;
                case 'report':
                  _report();
                  break;
                case 'block':
                  _blockAuthor();
                  break;
                case 'message':
                  _messageAuthor();
                  break;
              }
            },
            itemBuilder: (_) => [
              if (_isMine) ...[
                PopupMenuItem(value: 'edit', child: Text(_loc('post.edit'))),
                PopupMenuItem(
                    value: 'delete', child: Text(_loc('post.delete'))),
                const PopupMenuItem(
                    value: 'boost', child: Text('Boost with MRC')),
                const PopupMenuItem(
                    value: 'moderators', child: Text('Moderators')),
              ] else ...[
                PopupMenuItem(
                    value: 'message', child: Text(_loc('post.message'))),
                PopupMenuItem(
                    value: 'report', child: Text(_loc('post.report'))),
                PopupMenuItem(value: 'block', child: Text(_loc('post.block'))),
              ],
            ],
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: _openAuthor,
                        child: Row(children: [
                          AppAvatar(
                              name: _post.author.name,
                              url: _post.author.avatarUrl,
                              size: 44),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Flexible(
                                        child: Text(_post.author.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700))),
                                    if (_post.author.verified)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 4),
                                        child: Icon(Icons.verified,
                                            size: 16, color: Colors.blue),
                                      ),
                                    RoleBadge(role: _post.author.role),
                                  ]),
                                  if (_post.programTag != null)
                                    Text(_post.programTag!,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: cs.onSurfaceVariant)),
                                ]),
                          ),
                          if (_post.editedAt != null)
                            Text(_loc('post.edited'),
                                style: TextStyle(
                                    fontSize: 11, color: cs.onSurfaceVariant)),
                        ]),
                      ),
                      const SizedBox(height: 14),
                      Text(_post.text,
                          textDirection: textDirectionFor(_post.text),
                          style: const TextStyle(fontSize: 16, height: 1.55)),
                      if (_post.captureSource != 'UNKNOWN')
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                  _post.captureSource == 'CAMERA'
                                      ? Icons.camera_alt_outlined
                                      : Icons.photo_library_outlined,
                                  size: 14,
                                  color: _post.captureSource == 'CAMERA'
                                      ? cs.primary
                                      : null),
                              const SizedBox(width: 4),
                              Text(
                                  ' · trust %',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      if (_post.deepfakeVerdict != 'UNSCANNED' &&
                          _post.deepfakeVerdict != 'LIKELY_AUTHENTIC')
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 6),
                            decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: .14),
                                borderRadius: BorderRadius.circular(9)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_awesome,
                                    size: 15, color: Colors.amber),
                                const SizedBox(width: 5),
                                Text(
                                    'AI content: ${_post.deepfakeVerdict} (${_post.deepfakeScore.toStringAsFixed(2)})',
                                    style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.amber)),
                              ],
                            ),
                          ),
                        ),
                      if (_post.media.isNotEmpty || _post.videoHlsUrl != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: PostMediaGallery(
                              media: _post.media,
                              videoId: _post.id,
                              videoHlsUrl: _post.videoHlsUrl,
                              videoPosterUrl: _post.videoPosterUrl,
                              onImageTap: (url) =>
                                  showEnlargedImage(context, url),
                            ),
                          ),
                        )
                      else if (_post.contentUrl != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              _post.contentUrl!,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      if (_post.files.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: PostFilesList(files: _post.files),
                        ),
                      if (_post.linkUrl != null && _post.linkUrl!.isNotEmpty)
                        PostLinkCard(url: _post.linkUrl!),
                      if (_post.impactValue != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Chip(
                            avatar:
                                const Icon(Icons.fact_check_outlined, size: 16),
                            label: Text(
                                '${_post.impactValue!.toStringAsFixed(1)} ${_post.impactLabel ?? _loc('post.impact')}'),
                          ),
                        ),
                      if (_post.isaScore != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child:
                              _IsaCard(post: _post, onExplain: _showImpactInfo),
                        ),
                      const SizedBox(height: 8),
                      Row(children: [
                        IconButton(
                          icon: Icon(
                            _post.likedByMe
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: _post.likedByMe
                                ? Colors.redAccent
                                : cs.onSurfaceVariant,
                          ),
                          onPressed: _toggleLike,
                        ),
                        Text('${_post.likes}'),
                        const SizedBox(width: 18),
                        Icon(Icons.mode_comment_outlined,
                            size: 20, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text('${_post.comments}'),
                        const Spacer(),
                        IconButton(
                          icon: Icon(_post.bookmarkedByMe
                              ? Icons.bookmark
                              : Icons.bookmark_border),
                          onPressed: _toggleBookmark,
                        ),
                      ]),
                    ]),
              ),
              Divider(height: 1, color: cs.outlineVariant),
              SectionTitle(title: _loc('post.comments')),
              if (_loadingComments)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (roots.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(_loc('post.noComments'),
                      style: TextStyle(color: cs.onSurfaceVariant)),
                )
              else
                ...roots.expand((root) => [
                      _CommentTile(
                        comment: root,
                        currentUserId: widget.currentUser.id,
                        onLike: () => _toggleCommentLike(root),
                        onReply: () {
                          setState(() => _replyTo = root);
                          _commentCtl.text = '';
                        },
                        onDelete: () => _deleteComment(root),
                      ),
                      ...(replies[root.id] ?? []).map((reply) => Padding(
                            padding:
                                const EdgeInsetsDirectional.only(start: 34),
                            child: _CommentTile(
                              comment: reply,
                              currentUserId: widget.currentUser.id,
                              onLike: () => _toggleCommentLike(reply),
                              onReply: () {
                                setState(() => _replyTo = root);
                                _commentCtl.text = '';
                              },
                              onDelete: () => _deleteComment(reply),
                            ),
                          )),
                    ]),
              const SizedBox(height: 16),
            ],
          ),
        ),
        if (_replyTo != null)
          Container(
            color: cs.surfaceContainerHighest,
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(children: [
              Expanded(
                child: Text(
                    '${_loc('post.replyTo')} ${_replyTo!.authorName ?? _loc('post.userFallback')}',
                    style: const TextStyle(fontSize: 12)),
              ),
              IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _replyTo = null)),
            ]),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _commentCtl,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: _loc('post.writeComment'),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _busy ? null : _addComment,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Comment comment;
  final String currentUserId;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final VoidCallback onDelete;
  const _CommentTile({
    required this.comment,
    required this.currentUserId,
    required this.onLike,
    required this.onReply,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppAvatar(
            name: comment.authorName ??
                MasarenLocalizations.of(context, 'post.userFallback'),
            url: comment.authorPicture,
            size: 34),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(
                    comment.authorName ??
                        MasarenLocalizations.of(context, 'post.userFallback'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              if (comment.authorVerified)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.verified, size: 14, color: Colors.blue),
                ),
              const SizedBox(width: 6),
              Text(timeAgo(comment.createdAt, context: context),
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
            ]),
            const SizedBox(height: 3),
            Text(comment.text,
                textDirection: textDirectionFor(comment.text),
                style: const TextStyle(height: 1.4)),
            const SizedBox(height: 4),
            Row(children: [
              InkWell(
                onTap: onLike,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(children: [
                    Icon(
                        comment.likedByMe
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 15,
                        color: comment.likedByMe
                            ? Colors.redAccent
                            : cs.onSurfaceVariant),
                    const SizedBox(width: 3),
                    Text('${comment.likeCount}',
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant)),
                  ]),
                ),
              ),
              const SizedBox(width: 14),
              InkWell(
                onTap: onReply,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(MasarenLocalizations.of(context, 'post.reply'),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cs.primary)),
                ),
              ),
              if (comment.authorId == currentUserId) ...[
                const SizedBox(width: 14),
                InkWell(
                  onTap: onDelete,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                        MasarenLocalizations.of(context, 'post.deleteComment'),
                        style: TextStyle(fontSize: 11, color: cs.error)),
                  ),
                ),
              ],
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _IsaCard extends StatelessWidget {
  final Post post;
  final VoidCallback onExplain;
  const _IsaCard({required this.post, required this.onExplain});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final domains = post.impactDomains ?? const <String, dynamic>{};
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_outlined, size: 18, color: cs.primary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                    'ISA v2 · ${post.isaScore!.toInt()}/1000 · ${post.impactLabel ?? 'Impact'}',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface)),
              ),
              if (post.geoLevel > 0)
                Tooltip(
                  message: post.geoLevel == 2
                      ? 'GPS + claimed location recorded'
                      : 'GPS location recorded',
                  child: Icon(Icons.location_on, size: 17, color: cs.primary),
                ),
              IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onExplain,
                  icon: const Icon(Icons.info_outline, size: 17)),
            ],
          ),
          if (domains.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...domains.entries.map((entry) {
              final value = entry.value is Map
                  ? Map<String, dynamic>.from(entry.value as Map)
                  : const <String, dynamic>{};
              final score = (value['score'] as num?)?.toDouble() ?? 0;
              return Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Row(
                  children: [
                    SizedBox(
                        width: 38,
                        child: Text(
                            (value['code'] ??
                                    entry.key.toString().substring(0, 3))
                                .toString()
                                .toUpperCase(),
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: cs.primary))),
                    Expanded(
                        child: AnimatedProgressBar(
                            value: (score / 100).clamp(0.0, 1.0), height: 4)),
                    const SizedBox(width: 6),
                    SizedBox(
                        width: 30,
                        child: Text('${score.toInt()}',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                                fontSize: 9.5, color: cs.onSurfaceVariant))),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
