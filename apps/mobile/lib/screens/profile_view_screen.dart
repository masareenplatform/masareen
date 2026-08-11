import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/models.dart';
import 'package:masaren/screens/post_detail_screen.dart';
import 'package:masaren/widgets/animations.dart';

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
      } catch (_) {
        // personnel failed — try getUser as fallback
        try {
          final user = await AuthApi.getUser(widget.userId);
          _displayName = user.fullName;
          _role = user.role;
          _bio = user.bio;
        } catch (_) {
          // both failed — try to get name from feed
          try {
            final posts = await AuthApi.feed(authorId: widget.userId);
            if (posts.isNotEmpty) {
              _displayName = posts.first.author.name;
            }
          } catch (_) {
            // everything failed — show generic
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
      await AuthApi.followPersonnel(widget.userId);
      if (mounted) {
        setState(() => _following = !_following);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_following ? 'Following' : 'Unfollowed')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(_error!,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
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
      appBar: AppBar(
        title: Text(_displayName),
        actions: [
          if (!isMe)
            TextButton(
              onPressed: _busy ? null : _follow,
              child: Text(_following ? 'Following' : 'Follow',
                  style: TextStyle(color: cs.primary)),
            ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: FloatingShapes(shapeCount: 5)),
          RefreshIndicator(
          onRefresh: _load,
          child: ListView(
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, cs.primary.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  ScaleInWidget(
                    child: AppAvatar(name: _displayName, url: p?.avatarUrl, size: 90),
                  ),
                  const SizedBox(height: 12),
                  Text(_displayName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                  if (_role.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(_role,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                  if (p != null) ...[
                    const SizedBox(height: 14),
                    SlideInWidget(
                      delay: const Duration(milliseconds: 200),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _StatValue(
                              value: p.impactScore.toInt().toString(),
                              label: 'Impact',
                              numericValue: p.impactScore.toDouble()),
                          Container(
                              width: 1,
                              height: 28,
                              color: Colors.white30),
                          _StatValue(
                              value: p.trustScore.toInt().toString(),
                              label: 'Trust',
                              numericValue: p.trustScore.toDouble()),
                          Container(
                              width: 1,
                              height: 28,
                              color: Colors.white30),
                          _StatValue(
                              value: p.professionalRank,
                              label: 'Rank'),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Bio ──
            if (_bio != null && _bio!.isNotEmpty) ...[
              const SectionTitle(title: 'About'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_bio!,
                        style: TextStyle(
                            color: cs.onSurfaceVariant, height: 1.5)),
                  ),
                ),
              ),
            ],

            // ── Posts ──
            const SectionTitle(title: 'Posts'),
            if (_posts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text('No posts yet.',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ),
              ),
            ..._posts.map((p) => Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => PostDetailScreen(
                            post: p,
                            currentUser: widget.currentUser,
                            onChanged: (_) {}))),
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

class _StatValue extends StatelessWidget {
  final String value;
  final String label;
  final double? numericValue;
  const _StatValue({required this.value, required this.label, this.numericValue});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          if (numericValue != null)
            CountUpNumber(
              target: numericValue!,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            )
          else
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}
