import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:masaren/core/theme/masaren_theme.dart';
import 'package:masaren/core/widgets/app_avatar.dart';
import 'package:masaren/core/widgets/badges.dart';
import 'package:masaren/core/models/profile_model.dart';
import 'package:masaren/services/api_service.dart';
import 'package:masaren/di/injection.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:masaren/features/feed/feed_store.dart';
import 'package:masaren/features/feed/widgets/post_media.dart';
import 'package:masaren/core/widgets/spacing.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ProfileModel? _profile;
  bool _loading = true;
  List<dynamic> _suggested = [];
  Map<String, bool> _following = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = await getIt<FlutterSecureStorage>().read(key: 'user_id') ?? '';
      final p = await getIt<ApiService>().getProfile(uid);
      final s = await getIt<ApiService>().suggestedUsers();
      if (mounted) {
        setState(() {
          _profile = p;
          _suggested = s;
          _loading = false;
        });
        for (final u in s) {
          final r = await getIt<ApiService>().isFollowing(u['id']);
          if (mounted) setState(() => _following[u['id']] = r['following'] == true);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow(String id) async {
    final now = !(_following[id] ?? false);
    setState(() => _following[id] = now);
    try {
      await getIt<ApiService>().followUser(id);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final profile = _profile;
    if (profile == null) {
      return const Scaffold(body: Center(child: Text('No profile data available.')));
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _ParallaxHeader(profile: profile, isDark: isDark),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 64),
                Text(profile.fullName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: MasarenTheme.inkOf(context), fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(profile.email, style: TextStyle(color: MasarenTheme.mutedOf(context))),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(child: _StatCard(label: 'Followers', value: profile.followersCount.toString(), icon: Icons.people_alt_rounded)),
                      const SizedBox(width: 10),
                      Expanded(child: _StatCard(label: 'Following', value: profile.followingCount.toString(), icon: Icons.person_add_alt_1_rounded)),
                      const SizedBox(width: 10),
                      Expanded(child: _StatCard(label: 'Badges', value: profile.badgesEarned.toString(), icon: Icons.emoji_events_rounded)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_suggested.isNotEmpty) _PeopleToFollow(suggested: _suggested, following: _following, onToggle: _toggleFollow),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text('Posts', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: MasarenTheme.inkOf(context), fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.settings_outlined), tooltip: 'Settings', onPressed: () => context.go('/settings')),
                    ],
                  ),
                ),
                const Divider(),
                _PostsList(),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await getIt<ApiService>().logout();
                        if (context.mounted) context.go('/login');
                      },
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sign Out'),
                      style: OutlinedButton.styleFrom(foregroundColor: MasarenTheme.accent),
                    ),
                  ),
                ),
                constHBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cover photo with a parallax avatar that tilts as you drag (3D feel).
class _ParallaxHeader extends StatefulWidget {
  final ProfileModel profile;
  final bool isDark;
  const _ParallaxHeader({required this.profile, required this.isDark});

  @override
  State<_ParallaxHeader> createState() => _ParallaxHeaderState();
}

class _ParallaxHeaderState extends State<_ParallaxHeader> {
  double _dx = 0, _dy = 0;

  @override
  Widget build(BuildContext context) {
    final cover = widget.profile.coverUrl;
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: MasarenTheme.brand,
      flexibleSpace: FlexibleSpaceBar(
        background: GestureDetector(
          onPanUpdate: (e) => setState(() {
            _dx = (_dx + e.delta.dx / 30).clamp(-0.25, 0.25);
            _dy = (_dy + e.delta.dy / 30).clamp(-0.25, 0.25);
          }),
          onPanEnd: (_) => setState(() => _dx = _dy = 0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              cover.startsWith('http')
                  ? Image.network(cover, fit: BoxFit.cover)
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [MasarenTheme.brand, MasarenTheme.green], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      ),
                    ),
              Container(color: Colors.black.withOpacity(0.15)),
              Align(
                alignment: Alignment.bottomCenter,
                child: Transform.translate(
                  offset: const Offset(0, 46),
                  child: Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(_dx)
                      ..rotateX(_dy),
                    alignment: FractionalOffset.center,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
                      ),
                      child: AppAvatar(url: widget.profile.avatarUrl, name: widget.profile.fullName, radius: 44),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCard({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: MasarenTheme.surfaceOf(context), borderRadius: BorderRadius.circular(16), border: Border.all(color: MasarenTheme.lineOf(context))),
      child: Column(
        children: [
          Icon(icon, color: MasarenTheme.brand, size: 22),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: MasarenTheme.inkOf(context))),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: MasarenTheme.mutedOf(context))),
        ],
      ),
    );
  }
}

class _PeopleToFollow extends StatelessWidget {
  final List<dynamic> suggested;
  final Map<String, bool> following;
  final void Function(String) onToggle;
  const _PeopleToFollow({required this.suggested, required this.following, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('People to follow', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: MasarenTheme.inkOf(context), fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemCount: suggested.length,
            itemBuilder: (_, i) {
              final u = suggested[i];
              final id = u['id'].toString();
              final isF = following[id] ?? false;
              return Container(
                width: 150,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: MasarenTheme.surfaceOf(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: MasarenTheme.lineOf(context))),
                child: Row(children: [
                  AppAvatar(url: u['avatar_url']?.toString(), name: u['full_name']?.toString() ?? '', radius: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Expanded(child: Text(u['full_name']?.toString() ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis, maxLines: 2)),
                      GestureDetector(
                        onTap: () => onToggle(id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(color: isF ? MasarenTheme.line : MasarenTheme.brand, borderRadius: BorderRadius.circular(999)),
                          child: Text(isF ? 'Following' : 'Follow', style: TextStyle(color: isF ? MasarenTheme.ink : Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ]),
                  ),
                ]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PostsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final posts = feedStore.posts;
    if (posts.isEmpty) {
      return const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No posts yet.')));
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: posts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final p = posts[i];
        final type = (p['type'] ?? 'TEXT').toString().toUpperCase();
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ListTile(
              leading: AppAvatar(url: p['creatorAvatar'], name: p['creator']?.toString() ?? '', radius: 20),
              title: Text(p['creator']?.toString() ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.bold, color: MasarenTheme.inkOf(context))),
              subtitle: Text(p['caption']?.toString() ?? p['content']?.toString() ?? 'Shared an update', style: TextStyle(color: MasarenTheme.mutedOf(context), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.more_vert_rounded, color: MasarenTheme.muted),
            ),
            if (type != 'TEXT') PostMedia(post: p, height: 200),
          ]),
        );
      },
    );
  }
}
