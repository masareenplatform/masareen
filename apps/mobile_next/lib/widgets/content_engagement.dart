import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/models.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';

class ContentEngagement extends StatefulWidget {
  final String targetType;
  final String targetId;
  final User user;
  final int initialReactions;
  final int initialComments;
  final bool initiallyReacted;
  final String? initialMyReaction;
  final Future<void> Function()? onShare;

  const ContentEngagement({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.user,
    this.initialReactions = 0,
    this.initialComments = 0,
    this.initiallyReacted = false,
    this.initialMyReaction,
    this.onShare,
  });

  @override
  State<ContentEngagement> createState() => _ContentEngagementState();
}

class _ContentEngagementState extends State<ContentEngagement> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  List<Comment> _comments = [];
  bool _loading = true;
  bool _sending = false;
  bool _busyReaction = false;
  late int _reactions;
  String? _myReaction;

  bool get _ar => Localizations.localeOf(context).languageCode == 'ar';
  String _t(String en, String ar) => _ar ? ar : en;

  @override
  void initState() {
    super.initState();
    _reactions = widget.initialReactions;
    _myReaction =
        widget.initialMyReaction ?? (widget.initiallyReacted ? 'like' : null);
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final comments = await AuthApi.contentComments(
        widget.targetType,
        widget.targetId,
      );
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleReaction(String reaction) async {
    if (_busyReaction) return;
    setState(() => _busyReaction = true);
    try {
      final result = await AuthApi.toggleContentReaction(
        widget.targetType,
        widget.targetId,
        reaction: reaction,
      );
      if (!mounted) return;
      setState(() {
        _reactions = (result['reactions'] as num?)?.toInt() ?? _reactions;
        _myReaction = result['my_reaction']?.toString();
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _busyReaction = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final comment = await AuthApi.addContentComment(
        widget.targetType,
        widget.targetId,
        text,
      );
      if (!mounted) return;
      _controller.clear();
      setState(() => _comments.add(comment));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        }
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ReactionButton(
                  reaction: _myReaction,
                  count: _reactions,
                  onSelect: _toggleReaction,
                ),
                const SizedBox(width: 8),
                _Action(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: _t('Comments', 'التعليقات'),
                  count: _comments.length,
                  onTap: () {},
                ),
                const Spacer(),
                if (widget.onShare != null)
                  TextButton.icon(
                    onPressed: widget.onShare,
                    icon: const Icon(Icons.ios_share, size: 17),
                    label: Text(_t('Share', 'مشاركة')),
                  ),
              ],
            ),
            const Divider(height: 22),
            Text(
              _t('Comments', 'التعليقات'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_comments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  _t(
                    'No comments yet. Start the conversation.',
                    'لا توجد تعليقات بعد. ابدأ الحديث.',
                  ),
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.builder(
                  controller: _scroll,
                  shrinkWrap: true,
                  itemCount: _comments.length,
                  itemBuilder: (_, i) {
                    final comment = _comments[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppAvatar(
                            name: comment.authorName ?? 'User',
                            url: comment.authorPicture,
                            size: 30,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    comment.authorName ?? 'User',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    comment.text,
                                    textDirection: textDirectionFor(
                                      comment.text,
                                    ),
                                    style: TextStyle(
                                      color: cs.onSurface,
                                      fontSize: 12.5,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                AppAvatar(
                  name: widget.user.fullName,
                  url: widget.user.avatarUrl,
                  size: 30,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: _t('Write a comment...', 'اكتب تعليقاً...'),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  tooltip: _t('Send', 'إرسال'),
                  icon: _sending
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  const _Action({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: cs.onSurfaceVariant,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      icon: Icon(icon, size: 17),
      label: Text(
        '$label $count',
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  final String? reaction;
  final int count;
  final ValueChanged<String> onSelect;
  const _ReactionButton({
    required this.reaction,
    required this.count,
    required this.onSelect,
  });

  static const _reactions = [
    'like',
    'support',
    'insightful',
    'celebrate',
    'question',
  ];

  IconData _icon(String? value) => switch (value) {
        'support' => Icons.volunteer_activism_rounded,
        'insightful' => Icons.lightbulb_rounded,
        'celebrate' => Icons.celebration_rounded,
        'question' => Icons.help_outline_rounded,
        'like' => Icons.favorite_rounded,
        _ => Icons.favorite_border_rounded,
      };

  String _label(String value) => switch (value) {
        'support' => 'Support',
        'insightful' => 'Insightful',
        'celebrate' => 'Celebrate',
        'question' => 'Question',
        _ => 'Like',
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = reaction != null;
    return PopupMenuButton<String>(
      tooltip: 'React',
      onSelected: onSelect,
      itemBuilder: (_) => [
        for (final r in _reactions)
          PopupMenuItem(
            value: r,
            child: Row(
              children: [
                Icon(
                  _icon(r),
                  size: 18,
                  color: r == reaction ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Text(_label(r)),
                if (r == reaction) ...[
                  const Spacer(),
                  Icon(Icons.check, size: 16, color: cs.primary),
                ],
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.warm.withValues(alpha: .09) : null,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icon(reaction),
              size: 17,
              color: active ? AppColors.warm : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Text(
              '${reaction == null ? 'React' : _label(reaction!)} $count',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: active ? AppColors.warm : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
