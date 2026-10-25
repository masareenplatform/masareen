import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/screens/messages_screen.dart';
import 'package:masaren/screens/profile_view_screen.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/widgets/post_media_gallery.dart';

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

  String _loc(String key) => MasarenLocalizations.of(context, key);

  bool get _isMine => _post.author.id == widget.currentUser.id;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _comments = widget.post.commentList;
    _loadComments();
  }

  @override
  void dispose() {
    _commentCtl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final list = await AuthApi.comments(_post.id);
      if (!mounted) return;
      setState(() {
        _comments = list;
        _post = _post.copyWith(commentList: list, comments: list.length);
        _loadingComments = false;
      });
      widget.onChanged(_post);
    } catch (_) {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  void _changed() {
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
        content: const Text(
            'This removes the post and its comments. This cannot be undone.'),
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
    const reasons = [
      ('misinformation', 'Misleading or false information'),
      ('spam', 'Spam or repetitive content'),
      ('harassment', 'Harassment or hate'),
      ('violence', 'Violence or dangerous content'),
      ('other', 'Something else'),
    ];
    String reason = reasons.first.$1;
    final details = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(_loc('post.report')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            ...reasons.map((r) => RadioListTile<String>(
                  value: r.$1,
                  groupValue: reason,
                  title: Text(r.$2),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  onChanged: (v) => setLocal(() => reason = v ?? reason),
                )),
            TextField(
              controller: details,
              maxLines: 2,
              decoration: const InputDecoration(
                  hintText: 'Add context (optional)',
                  border: OutlineInputBorder()),
            ),
          ]),
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
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Report sent for review.')));
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
            'Posts and messages from ${_post.author.name} will be hidden from you.'),
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
          content: Text(blocked
              ? '${_post.author.name} is blocked.'
              : '${_post.author.name} is unblocked.')));
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
                          style: const TextStyle(fontSize: 16, height: 1.55)),
                      if (_post.media.isNotEmpty || _post.videoHlsUrl != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: PostMediaGallery(
                              media: _post.media,
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
                      if (_post.impactValue != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Chip(
                            avatar:
                                const Icon(Icons.fact_check_outlined, size: 16),
                            label: Text(
                                '${_post.impactValue!.toStringAsFixed(1)} ${_post.impactLabel ?? "impact"}'),
                          ),
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
                  child: Text('No comments yet. Start the conversation.',
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
                    '${_loc('post.replyTo')} ${_replyTo!.authorName ?? 'User'}',
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
            name: comment.authorName ?? 'User',
            url: comment.authorPicture,
            size: 34),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(comment.authorName ?? 'User',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              if (comment.authorVerified)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.verified, size: 14, color: Colors.blue),
                ),
              const SizedBox(width: 6),
              Text(timeAgo(comment.createdAt),
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
            ]),
            const SizedBox(height: 3),
            Text(comment.text, style: const TextStyle(height: 1.4)),
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
