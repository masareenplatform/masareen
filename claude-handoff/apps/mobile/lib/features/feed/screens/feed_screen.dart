import 'package:flutter/material.dart';
import 'package:masaren/core/theme/masaren_theme.dart';
import 'package:masaren/core/widgets/app_avatar.dart';
import 'package:masaren/core/widgets/badges.dart';
import 'package:masaren/core/feedback/feedback_service.dart';
import 'package:masaren/core/settings/app_settings.dart';
import 'package:masaren/core/logging/ui_logger.dart';
import 'package:masaren/features/feed/feed_store.dart';
import 'package:masaren/features/feed/widgets/post_media.dart';
import 'package:masaren/features/shell/social_app_bar.dart';

/// Social home feed (Facebook / LinkedIn / Instagram fusion).
///
/// Reads from the shared [feedStore] (real backend feed), shows Instagram-style
/// story highlights, pull-to-refresh, and posts of every media type (TEXT /
/// IMAGE / VIDEO[HLS] / AUDIO / ARTICLE / LINK) with animated like, comment and
/// share actions. Entrance is staggered for a fluid, animated feel.
class FeedScreen extends StatefulWidget {
  final ScrollController? scrollController;
  const FeedScreen({super.key, this.scrollController});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (feedStore.posts.isEmpty) feedStore.load();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.scrollController ?? _scrollController;
    return Scaffold(
      appBar: const SocialAppBar(title: 'MASAREEN'),
      body: Container(
        decoration: MasarenTheme.backgroundOf(context),
        child: RefreshIndicator(
          color: MasarenTheme.brand,
          onRefresh: () => feedStore.load(),
          child: ListenableBuilder(
            listenable: feedStore,
            builder: (context, _) {
              if (feedStore.posts.isEmpty && feedStore.loading) {
                return const Center(child: CircularProgressIndicator(color: MasarenTheme.green));
              }
              return CustomScrollView(
                controller: controller,
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(child: _StoryHighlights()),

                  if (feedStore.posts.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: Text('No posts yet. Be the first to share!', style: TextStyle(color: MasarenTheme.muted))),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _AnimatedPost(index: i, post: feedStore.posts[i]),
                        childCount: feedStore.posts.length,
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Wraps a post card with a staggered fade + slide entrance animation.
class _AnimatedPost extends StatefulWidget {
  final int index;
  final Map<String, dynamic> post;
  const _AnimatedPost({required this.index, required this.post});

  @override
  State<_AnimatedPost> createState() => _AnimatedPostState();
}

class _AnimatedPostState extends State<_AnimatedPost> {
  bool _shown = false;
  @override
  void initState() {
    super.initState();
    if (AppSettings.instance.reducedMotion.value) {
      _shown = true;
    } else {
      Future.delayed(Duration(milliseconds: 60 * widget.index), () => mounted ? setState(() => _shown = true) : null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      opacity: _shown ? 1 : 0,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        padding: _shown ? EdgeInsets.zero : const EdgeInsets.only(top: 24),
        child: _PostCard(post: widget.post),
      ),
    );
  }
}

/// Instagram-style story rings at the top of the home feed, showing the real
/// people behind the impact posts (with their avatars) rather than placeholders.
class _StoryHighlights extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: feedStore,
      builder: (context, _) {
        final creators = <Map<String, String>>[];
        final seen = <String>{};
        for (final p in feedStore.posts) {
          final name = (p['creator']?.toString() ?? '').trim();
          final av = p['creatorAvatar']?.toString() ?? '';
          if (name.isNotEmpty && !seen.contains(name)) {
            seen.add(name);
            creators.add({'name': name, 'avatar': av});
          }
        }
        return SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemCount: creators.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [MasarenTheme.brand, MasarenTheme.green]),
                      ),
                      child: const CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.add, color: MasarenTheme.brand),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('Add', style: TextStyle(fontSize: 11, color: MasarenTheme.muted)),
                  ],
                );
              }
              final c = creators[i - 1];
              return GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(c['name']!),
                    content: const Text('Impact story — verified by POAI Crew.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    AppAvatar(url: c['avatar'], name: c['name']!, radius: 28),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 56,
                      child: Text(c['name']!,
                          style: const TextStyle(fontSize: 11, color: MasarenTheme.muted),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final creator = post['creator']?.toString() ?? 'Unknown';
    final sdg = post['sdg'] ?? 0;
    final type = post['type']?.toString() ?? 'TEXT';
    final liked = post['likedByMe'] == true;
    final badges = UserBadge.demoFor(creator).take(2).toList();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: AppAvatar(url: post['creatorAvatar'], name: creator, radius: 22),
            title: Row(
              children: [
                Text(creator, style: TextStyle(fontWeight: FontWeight.bold, color: MasarenTheme.inkOf(context))),
                const SizedBox(width: 6),
                const Icon(Icons.verified_rounded, color: MasarenTheme.azure, size: 16),
                const Spacer(),
                ...badges.map((b) => Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: BadgeMedallion(badge: b, radius: 11),
                )),
              ],
            ),
            subtitle: Text(sdg != 0 ? 'Verified Impact · SDG $sdg' : 'Impact builder', style: TextStyle(color: MasarenTheme.mutedOf(context))),
            trailing: const Icon(Icons.more_vert_rounded, color: MasarenTheme.muted),
          ),
          if (type != 'TEXT' && type != 'AUDIO')
            PostMedia(post: post),
          if (type == 'AUDIO') PostMedia(post: post),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post['caption']?.toString() ?? post['content']?.toString() ?? '',
                    style: TextStyle(color: MasarenTheme.inkOf(context), fontSize: 14, height: 1.4)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _LikeButton(liked: liked, onTap: () {
                      FeedbackService.instance.like();
                      UiLogger.instance.tap('feed:like');
                      feedStore.toggleLike(post['id']);
                    }),
                    const SizedBox(width: 6),
                    Text('${post['likes'] ?? 0}', style: TextStyle(color: MasarenTheme.mutedOf(context), fontWeight: FontWeight.w600)),
                    const SizedBox(width: 18),
                    _CommentButton(post: post),
                    const SizedBox(width: 6),
                    Text('${_commentCount(post)}', style: TextStyle(color: MasarenTheme.mutedOf(context), fontWeight: FontWeight.w600)),
                    const Spacer(),
                    _ShareButton(post: post),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Verified by POAI Crew · Confidence ${post['score'] ?? '-'}%',
                    style: const TextStyle(fontSize: 12, color: MasarenTheme.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _commentCount(Map<String, dynamic> post) {
    if (post['comments'] is List) return (post['comments'] as List).length;
    return (post['comments'] is num ? (post['comments'] as num).toInt() : 0);
  }
}

/// Heart that pops/scales when the like state changes, with haptic + sound.
class _LikeButton extends StatefulWidget {
  final bool liked;
  final VoidCallback onTap;
  const _LikeButton({required this.liked, required this.onTap});

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  late final Animation<double> _scale = Tween<double>(begin: 1, end: 1.4).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));

  @override
  void didUpdateWidget(covariant _LikeButton old) {
    super.didUpdateWidget(old);
    if (widget.liked != old.liked && !AppSettings.instance.reducedMotion.value) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('like_button'),
      onTap: widget.onTap,
      child: Semantics(
        label: widget.liked ? 'Liked' : 'Like',
        child: ScaleTransition(
          scale: _scale,
          child: Icon(
            widget.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: widget.liked ? MasarenTheme.like : MasarenTheme.muted,
          ),
        ),
      ),
    );
  }
}

class _CommentButton extends StatelessWidget {
  final Map<String, dynamic> post;
  const _CommentButton({required this.post});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => _CommentSheet(post: post),
      ),
      child: const Icon(Icons.chat_bubble_outline_rounded, color: MasarenTheme.muted),
    );
  }
}

class _CommentSheet extends StatefulWidget {
  final Map<String, dynamic> post;
  const _CommentSheet({super.key, required this.post});
  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  final _ctrl = TextEditingController();
  late List<Map<String, dynamic>> _comments;

  @override
  void initState() {
    super.initState();
    final c = widget.post['comments'];
    _comments = (c is List) ? List<Map<String, dynamic>>.from(c) : [];
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _add() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _comments.add({'author': 'You', 'text': t, 'avatar': 'asset://avatars/p1.jpg'});
      widget.post['comments'] = _comments;
    });
    _ctrl.clear();
    UiLogger.instance.tap('feed:comment');
  }

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + kb),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: MasarenTheme.line, borderRadius: BorderRadius.circular(999))),
        const SizedBox(height: 12),
        Text('Comments', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: MasarenTheme.ink, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _comments.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (_, i) {
              final c = _comments[i];
              return Row(children: [
                AppAvatar(url: c['avatar']?.toString(), name: c['author']?.toString() ?? '', radius: 18),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c['author']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(c['text']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
                ])),
              ]);
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: _ctrl, decoration: const InputDecoration(hintText: 'Add a comment…', border: OutlineInputBorder()))),
          const SizedBox(width: 8),
          FilledButton(onPressed: _add, child: const Text('Post')),
        ]),
      ]),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final Map<String, dynamic> post;
  const _ShareButton({required this.post});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('share_button'),
      onTap: () {
        UiLogger.instance.tap('feed:share');
        final int shares = ((post['shares'] is num ? post['shares'] : 0) as int) + 1;
        post['shares'] = shares;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Shared "${post['caption']?.toString() ?? 'this post'}"')),
        );
      },
      child: const Icon(Icons.share_outlined, color: MasarenTheme.muted),
    );
  }
}
