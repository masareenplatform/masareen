import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/models.dart';
import 'package:masaren/screens/post_detail_screen.dart';
import 'package:masaren/screens/messages_screen.dart';
import 'package:masaren/widgets/animations.dart';
import 'package:masaren/profile_ui.dart';

class ProfileViewScreen extends StatefulWidget {
  final String userId;
  final User currentUser;
  const ProfileViewScreen(
      {super.key, required this.userId, required this.currentUser});

  @override
  State<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends State<ProfileViewScreen> {
  Personnel? _personnel;
  List<Post> _posts = [];
  bool _loading = true;
  bool _busy = false;
  bool _following = false;
  String? _error;
  String _displayName = 'User';
  String _role = '';
  String? _bio;

  String _roleLabel(BuildContext context, String role) {
    final value = role.toUpperCase();
    final key = switch (value) {
      String r when r.contains('GOV') => 'profile.role.government',
      String r
          when r.contains('MEDIA') ||
              r.contains('PRESS') ||
              r.contains('NEWS') =>
        'profile.role.media',
      String r
          when r.contains('SPORT') ||
              r.contains('CLUB') ||
              r.contains('ATHLETE') =>
        'profile.role.sports',
      String r
          when r.contains('NGO') ||
              r.contains('ORG') ||
              r.contains('COMPANY') ||
              r.contains('INSTITUTION') =>
        'profile.role.organization',
      String r
          when r.contains('ACADEMIC') ||
              r.contains('STUDENT') ||
              r.contains('RESEARCHER') =>
        'profile.role.academic',
      String r when r.contains('UNIVERSITY') => 'profile.role.organization',
      String r when r.contains('JOURNALIST') => 'profile.role.journalist',
      _ => 'profile.role.individual',
    };
    final label = MasarenLocalizations.of(context, key);
    return label == key ? 'MASAREEN' : label;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Try personnel endpoint first
      try {
        _personnel = await AuthApi.personnel(widget.userId);
        _displayName = _personnel!.name;
        _role = _personnel!.role;
        _bio = _personnel!.bio.isNotEmpty ? _personnel!.bio : null;
        _following = _personnel!.isFollowing;
      } catch (_) {
        // personnel failed, try getUser as fallback
        try {
          final user = await AuthApi.getUser(widget.userId);
          _displayName = user.fullName;
          _role = user.role;
          _bio = user.bio;
          _following = user.isFollowing;
        } catch (_) {
          // both failed, try to get name from feed
          try {
            final posts = await AuthApi.feed(authorId: widget.userId);
            if (posts.isNotEmpty) {
              _displayName = posts.first.author.name;
            }
          } catch (_) {
            // everything failed, show generic
          }
        }
      }

      // Load posts (always try, even if profile data failed)
      try {
        _posts = await AuthApi.feed(authorId: widget.userId);
      } catch (_) {
        _posts = [];
      }
    } catch (e) {
      _error = 'Unable to load profile.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _follow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res = await AuthApi.followPersonnel(widget.userId);
      if (mounted) {
        setState(
            () => _following = res['following'] == true ? true : !_following);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(MasarenLocalizations.of(context,
                _following ? 'action.following' : 'profile.unfollowed'))));
      }
    } catch (e) {
      if (mounted) {
        final message = MasarenLocalizations.of(context, 'common.failed')
            .replaceAll('{error}', '$e');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _message() async {
    try {
      final c = await AuthApi.openConversation(widget.userId);
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

  Future<void> _openPost(Post p) async {
    final result = await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PostDetailScreen(
            post: p,
            currentUser: widget.currentUser,
            onChanged: (updated) {
              final i = _posts.indexWhere((e) => e.id == updated.id);
              if (i == -1) return;
              setState(() => _posts[i] = updated);
            })));
    if (result == 'deleted' && mounted) {
      setState(() => _posts.removeWhere((e) => e.id == p.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _personnel == null && _posts.isEmpty) {
      return Scaffold(
        appBar: AppBar(
            title: Text(MasarenLocalizations.of(context, 'profile.title'))),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(MasarenLocalizations.of(context, 'profile.loadError'),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: Text(MasarenLocalizations.of(context, 'common.retry')),
              ),
            ],
          ),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final p = _personnel;
    final isMe = widget.userId == widget.currentUser.id;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: FloatingShapes(shapeCount: 5)),
          RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              children: [
                ProfileHero(
                  title: _displayName,
                  subtitle: _roleLabel(context, _role),
                  kind: 'individual',
                  icon: Icons.person_outline,
                  imageUrl: p?.avatarUrl,
                  coverUrl: p?.coverUrl,
                  badge: p == null
                      ? null
                      : ProfilePill(
                          label: p.professionalRank,
                          icon: Icons.workspace_premium_outlined,
                          color: ProfileColors.gold),
                  onShare: () => copyProfileLink(context, widget.userId,
                      MasarenLocalizations.of(context, 'profile.linkCopied'),
                      verified: _personnel?.emailVerified == true),
                  stats: p == null
                      ? const []
                      : [
                          ProfileStat(
                              p.impactScore.toInt().toString(),
                              MasarenLocalizations.of(
                                  context, 'organization.impact'),
                              icon: Icons.insights_outlined),
                          ProfileStat(p.trustScore.toInt().toString(),
                              MasarenLocalizations.of(context, 'profile.trust'),
                              icon: Icons.verified_user_outlined),
                          ProfileStat(
                              p.currentReach.toInt().toString(),
                              MasarenLocalizations.of(
                                  context, 'personnel.metric.reach'),
                              icon: Icons.visibility_outlined),
                        ],
                ),
                if (!isMe)
                  ProfileActionBar(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _message,
                          icon: const Icon(Icons.chat_bubble_outline, size: 16),
                          label: Text(
                              MasarenLocalizations.of(
                                  context, 'profile.message'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          style: profilePrimaryStyle(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _follow,
                          icon: Icon(
                              _following ? Icons.check : Icons.person_add_alt_1,
                              size: 16),
                          label: Text(
                              MasarenLocalizations.of(
                                  context,
                                  _following
                                      ? 'action.following'
                                      : 'action.follow'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          style: profileSecondaryStyle(context),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 6),

                if (_bio != null && _bio!.isNotEmpty) ...[
                  ProfileSectionHeader(
                      title: MasarenLocalizations.of(
                          context, 'institution.about')),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: profilePanel(context),
                    child: Text(_bio!,
                        style:
                            TextStyle(color: cs.onSurfaceVariant, height: 1.5)),
                  ),
                ],
                // ── Posts ──
                SectionTitle(
                    title: MasarenLocalizations.of(context, 'profile.posts')),
                if (_posts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                          MasarenLocalizations.of(context, 'profile.noPosts'),
                          style: TextStyle(color: cs.onSurfaceVariant)),
                    ),
                  ),
                ..._posts.map((p) => Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      child: InkWell(
                        onTap: () => _openPost(p),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.text,
                                  style: TextStyle(
                                      color: cs.onSurface, height: 1.4)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.favorite,
                                      size: 16,
                                      color: p.likedByMe
                                          ? Colors.redAccent
                                          : cs.onSurfaceVariant),
                                  const SizedBox(width: 4),
                                  Text('${p.likes}',
                                      style: TextStyle(
                                          color: cs.onSurfaceVariant)),
                                  const SizedBox(width: 16),
                                  Icon(Icons.mode_comment_outlined,
                                      size: 16, color: cs.onSurfaceVariant),
                                  const SizedBox(width: 4),
                                  Text('${p.comments}',
                                      style: TextStyle(
                                          color: cs.onSurfaceVariant)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    )),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
