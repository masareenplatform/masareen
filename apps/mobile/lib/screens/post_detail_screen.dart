import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/models.dart';

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
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  Future<void> _toggleLike() async {
    final was = _post.likedByMe;
    setState(() => _post = _post.copyWith(
        likedByMe: !was, likes: _post.likes + (was ? -1 : 1)));
    try {
      final res = await AuthApi.toggleLike(_post.id);
      setState(() => _post = _post.copyWith(
            likedByMe: res['likedByMe'] ?? !was,
            likes: (res['likes'] is num)
                ? (res['likes'] as num).toInt()
                : _post.likes,
          ));
    } catch (_) {
      setState(() => _post = widget.post);
    }
    widget.onChanged(_post);
  }

  Future<void> _addComment() async {
    final text = _commentCtl.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      final c = await AuthApi.comment(_post.id, text);
      _commentCtl.clear();
      final list = [..._post.commentList, c];
      setState(() => _post = _post.copyWith(
          commentList: list, comments: _post.comments + 1));
      widget.onChanged(_post);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Comment failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AppAvatar(name: _post.author.name, size: 44),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(_post.author.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white)),
                                  if (_post.author.verified)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Icon(Icons.verified,
                                          size: 16, color: AppColors.azure),
                                    ),
                                ],
                              ),
                              if (_post.programTag != null)
                                Text(_post.programTag!,
                                    style: const TextStyle(
                                        color: AppColors.muted, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(_post.text,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15, height: 1.5)),
                      if (_post.contentUrl != null &&
                          (_post.type == 'IMAGE' ||
                              _post.type == 'VIDEO' ||
                              _post.type == 'ARTICLE'))
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: GestureDetector(
                              onTap: () =>
                                  showEnlargedImage(context, _post.contentUrl!),
                              child: Image.network(_post.contentUrl!,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox()),
                            ),
                          ),
                        ),
                      if (_post.impactValue != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.azure.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_post.impactValue!.toInt()} ${_post.impactLabel ?? "impact"}',
                              style: const TextStyle(
                                  color: AppColors.azure,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.favorite,
                              color: _post.likedByMe
                                  ? Colors.redAccent
                                  : AppColors.muted,
                            ),
                            onPressed: _toggleLike,
                          ),
                          Text('${_post.likes}',
                              style: const TextStyle(color: AppColors.muted)),
                          const SizedBox(width: 16),
                          const Icon(Icons.mode_comment_outlined,
                              color: AppColors.muted, size: 20),
                          Text(' ${_post.comments}',
                              style: const TextStyle(color: AppColors.muted)),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(),
                const SectionTitle(title: 'Comments'),
                ..._post.commentList.isEmpty
                    ? [
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No comments yet. Start the conversation.',
                              style: TextStyle(color: AppColors.muted)),
                        )
                      ]
                    : _post.commentList
                        .map((c) => _CommentTile(comment: c))
                        .toList()
                        .cast<Widget>(),
              ],
            ),
          ),
          _CommentComposer(
            controller: _commentCtl,
            busy: _busy,
            onSubmit: _addComment,
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Comment comment;
  const _CommentTile({required this.comment});
  @override
  Widget build(BuildContext context) => ListTile(
        leading: AppAvatar(name: comment.authorName ?? 'User', size: 36),
        title: Text(comment.authorName ?? 'User',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(comment.text,
            style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        trailing: Text(timeAgo(comment.createdAt),
            style: const TextStyle(color: AppColors.muted, fontSize: 11)),
      );
}

class _CommentComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSubmit;
  const _CommentComposer(
      {required this.controller, required this.busy, required this.onSubmit});
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.only(
            left: 14, right: 14, bottom: 14 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.darkLine)),
          color: AppColors.darkSurface,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Write a comment…',
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send, color: AppColors.azure),
              onPressed: busy ? null : onSubmit,
            ),
          ],
        ),
      );
}
