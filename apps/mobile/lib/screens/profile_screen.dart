import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/models.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/screens/post_detail_screen.dart';
import 'package:masaren/screens/edit_profile_screen.dart';
import 'package:masaren/screens/personnel_profile_screen.dart';
import 'package:masaren/screens/settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final User user;
  final VoidCallback onLogout;
  final VoidCallback? onToggleTheme;
  final VoidCallback? onMenu;
  const ProfileScreen({
    super.key,
    required this.user,
    required this.onLogout,
    this.onToggleTheme,
    this.onMenu,
  });

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late User _user;
  List<Post> _posts = [];
  bool _busy = false;
  bool _loadingPosts = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic);
    _fadeController.forward();
    _refresh();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> refresh() => _refresh();

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      _user = await AuthApi.me();
      _posts = await AuthApi.feed(authorId: _user.id);
    } catch (_) {}
    if (mounted) {
      setState(() => _busy = false);
      _loadingPosts = false;
    }
  }

  Future<void> _upload(String kind) async {
    if (_busy) return;
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1280, imageQuality: 82);
    if (xfile == null) return;
    setState(() => _busy = true);
    try {
      final bytes = await xfile.readAsBytes();
      final ct = xfile.mimeType ?? 'image/jpeg';
      if (kind == 'avatar') {
        final url = await AuthApi.uploadAvatar(bytes, xfile.name, ct);
        _user = _user.copyWith(avatarUrl: url);
      } else {
        final url = await AuthApi.uploadCover(bytes, xfile.name, ct);
        _user = _user.copyWith(coverUrl: url);
      }
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(MasarenLocalizations.of(
                context,
                kind == 'avatar'
                    ? 'profile.uploadAvatar'
                    : 'profile.uploadCover'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                MasarenLocalizations.of(context, 'profile.uploadFailed')
                    .replaceAll('{error}', e.toString()))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _roleLabel(BuildContext context, String? roleType) {
    final key = switch (roleType) {
      'MEDIA' => 'profile.mediaInstitution',
      'GOVERNMENT' => 'profile.government',
      'SPORTS' => 'profile.sports',
      'ORGANIZATION' => 'profile.organization',
      'INDIVIDUAL' => 'profile.individual',
      _ => null,
    };
    if (key == null) return roleType ?? '';
    return MasarenLocalizations.of(context, key);
  }

  String _postKindLabel(BuildContext context, String? kind) {
    final key = switch (kind?.toUpperCase()) {
      'RECOGNITION' => 'post.recognition',
      'STORY' => 'post.story',
      'NEWS' => 'post.news',
      'VIDEO' => 'post.video',
      'EVIDENCE' => 'post.evidence',
      'ANNOUNCEMENT' => 'post.announcement',
      'SYNERGY' => 'post.synergy',
      'OPPORTUNITY' => 'post.opportunity',
      'PROGRAM' => 'post.program',
      'INTERVIEW' => 'post.interview',
      'TRENDING' => 'post.trending',
      _ => null,
    };
    if (key == null) return kind ?? '';
    return MasarenLocalizations.of(context, key);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final u = _user;
    final roleLabel = _roleLabel(context, u.roleType);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: cs.primary,
        backgroundColor: cs.surface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          slivers: [
            _buildSliverAppBar(context, cs, dark, u, roleLabel),
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 28),
                    _buildUserInfo(context, cs, u, roleLabel),
                    const SizedBox(height: 20),
                    _buildEditButton(context, cs),
                    const SizedBox(height: 10),
                    _buildProfessionalButton(context, cs),
                    const SizedBox(height: 24),
                    _buildStatsRow(context, cs, dark),
                    const SizedBox(height: 8),
                    SectionTitle(
                        title:
                            MasarenLocalizations.of(context, 'profile.about')),
                    _buildAboutCard(context, cs, dark, u),
                    if (u.city != null || u.country != null) ...[
                      const SizedBox(height: 8),
                      _buildLocationChips(context, cs, dark, u),
                    ],
                    SectionTitle(
                        title:
                            MasarenLocalizations.of(context, 'profile.skills')),
                    _buildSkillsSection(context, cs, dark, u),
                    SectionTitle(
                        title: MasarenLocalizations.of(
                            context, 'profile.myPosts')),
                    _buildPostsSection(context, cs, dark, u),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, ColorScheme cs, bool dark,
      User u, String roleLabel) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      stretch: true,
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      leading: const SizedBox.shrink(),
      actions: [
        if (widget.onMenu != null)
          IconButton(
            tooltip: MasarenLocalizations.of(context, 'nav.more'),
            icon: const Icon(Icons.menu_open),
            onPressed: widget.onMenu,
          ),
        IconButton(
          tooltip: MasarenLocalizations.of(context, 'settings.title'),
          icon: const Icon(Icons.settings_outlined),
          onPressed: () async {
            await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    SettingsScreen(user: _user, onLogout: widget.onLogout)));
            _refresh();
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            u.coverUrl != null
                ? Image.network(
                    u.coverUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _coverGradient(cs, dark),
                  )
                : _coverGradient(cs, dark),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    cs.surface.withValues(alpha: 0.6),
                    cs.surface,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.paddingOf(context).top + 28,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.30),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 12,
              child: Clickable(
                onTap: () => _upload('cover'),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.surface.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.photo_camera_outlined,
                      size: 18, color: cs.onSurface),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: !Navigator.of(context).canPop()
                  ? const SizedBox.shrink()
                  : Container(
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(directionalBackIcon(context),
                            size: 18, color: cs.onSurface),
                        onPressed: () => Navigator.maybePop(context),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfo(
      BuildContext context, ColorScheme cs, User u, String roleLabel) {
    return Column(
      children: [
        Center(
          child: _buildAvatarWithBorder(cs, u),
        ),
        const SizedBox(height: 16),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                u.fullName,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              if (u.emailVerified) ...[
                const SizedBox(width: 6),
                Icon(Icons.verified_rounded, color: cs.primary, size: 22),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            u.email,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.primaryContainer,
                  cs.primaryContainer.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: cs.primary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.workspace_premium_rounded,
                    size: 14, color: cs.onPrimaryContainer),
                const SizedBox(width: 6),
                Text(
                  roleLabel,
                  style: TextStyle(
                    color: cs.onPrimaryContainer,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarWithBorder(ColorScheme cs, User u) {
    return Clickable(
      onTap: () => _upload('avatar'),
      child: Stack(
        children: [
          Container(
            width: 108,
            height: 108,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [cs.primary, cs.secondary, cs.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: cs.surface, width: 3),
              ),
              child: ClipOval(
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: u.avatarUrl != null && u.avatarUrl!.isNotEmpty
                      ? Image.network(
                          u.avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _avatarFallback(cs, u),
                        )
                      : _avatarFallback(cs, u),
                ),
              ),
            ),
          ),
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: brandGradient,
                shape: BoxShape.circle,
                border: Border.all(color: cs.surface, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(ColorScheme cs, User u) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildEditButton(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton.icon(
          onPressed: () async {
            final updated = await Navigator.of(context).push<User>(
                MaterialPageRoute(
                    builder: (_) => EditProfileScreen(user: _user)));
            if (updated != null) {
              setState(() => _user = updated);
            }
          },
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: Text(
            MasarenLocalizations.of(context, 'profile.edit'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: cs.primary,
            side: BorderSide(color: cs.outlineVariant, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfessionalButton(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PersonnelProfileScreen(
                  userId: _user.id, currentUser: _user))),
          icon: const Icon(Icons.workspace_premium_outlined, size: 18),
          label: Text(
            MasarenLocalizations.of(context, 'profile.openProfessional'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, ColorScheme cs, bool dark) {
    final stats = [
      _StatData(
        value: _user.pmsScore.toInt().toString(),
        label: MasarenLocalizations.of(context, 'profile.impactScore'),
        icon: Icons.analytics_outlined,
        gradient: [cs.primary, cs.primary.withValues(alpha: 0.7)],
      ),
      _StatData(
        value: _posts.length.toString(),
        label: MasarenLocalizations.of(context, 'profile.posts'),
        icon: Icons.article_outlined,
        gradient: [cs.secondary, cs.secondary.withValues(alpha: 0.7)],
      ),
      _StatData(
        value: _user.followersCount?.toString() ?? '0',
        label: MasarenLocalizations.of(context, 'profile.followers'),
        icon: Icons.people_outline_rounded,
        gradient: [cs.tertiary, cs.tertiary.withValues(alpha: 0.7)],
      ),
      _StatData(
        value: MasarenLocalizations.of(
            context, _user.emailVerified ? 'profile.yes' : 'profile.no'),
        label: MasarenLocalizations.of(context, 'profile.verified'),
        icon: Icons.verified_outlined,
        gradient: [
          _user.emailVerified ? cs.secondary : cs.onSurfaceVariant,
          (_user.emailVerified ? cs.secondary : cs.onSurfaceVariant)
              .withValues(alpha: 0.7),
        ],
      ),
    ];

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: stats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) => _buildGlassStatCard(cs, dark, stats[i]),
      ),
    );
  }

  Widget _buildGlassStatCard(ColorScheme cs, bool dark, _StatData stat) {
    return Container(
      width: 82,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: dark
            ? cs.surfaceContainerHigh.withValues(alpha: 0.5)
            : cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: dark ? 0.3 : 0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: stat.gradient[0].withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: stat.gradient
                    .map((c) => c.withValues(alpha: 0.15))
                    .toList(),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(stat.icon, size: 18, color: stat.gradient[0]),
          ),
          const SizedBox(height: 8),
          Text(
            stat.value,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            stat.label,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard(
      BuildContext context, ColorScheme cs, bool dark, User u) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: dark
              ? cs.surfaceContainerHigh.withValues(alpha: 0.5)
              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: dark ? 0.3 : 0.6),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.person_outline_rounded,
                      size: 16, color: cs.onPrimaryContainer),
                ),
                const SizedBox(width: 10),
                Text(
                  MasarenLocalizations.of(context, 'profile.about'),
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              u.bio ?? MasarenLocalizations.of(context, 'profile.noBio'),
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationChips(
      BuildContext context, ColorScheme cs, bool dark, User u) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (u.city != null)
            _buildStyledChip(cs, dark, Icons.location_on_outlined, u.city!),
          if (u.country != null)
            _buildStyledChip(cs, dark, Icons.flag_outlined, u.country!),
        ],
      ),
    );
  }

  Widget _buildStyledChip(
      ColorScheme cs, bool dark, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: dark
            ? cs.surfaceContainerHigh.withValues(alpha: 0.5)
            : cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: dark ? 0.3 : 0.6),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsSection(
      BuildContext context, ColorScheme cs, bool dark, User u) {
    if (u.skills.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: dark
                ? cs.surfaceContainerHigh.withValues(alpha: 0.5)
                : cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: dark ? 0.3 : 0.6),
            ),
          ),
          child: Column(
            children: [
              Icon(Icons.psychology_outlined,
                  size: 28, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
              const SizedBox(height: 8),
              Text(
                MasarenLocalizations.of(context, 'profile.noSkills'),
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: u.skills
            .map((s) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        cs.primaryContainer,
                        cs.primaryContainer.withValues(alpha: 0.6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: cs.primary.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    s,
                    style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildPostsSection(
      BuildContext context, ColorScheme cs, bool dark, User u) {
    if (_loadingPosts) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: dark
                ? cs.surfaceContainerHigh.withValues(alpha: 0.5)
                : cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: dark ? 0.3 : 0.6),
            ),
          ),
          child: Column(
            children: [
              Icon(Icons.post_add_rounded,
                  size: 32, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
              const SizedBox(height: 10),
              Text(
                MasarenLocalizations.of(context, 'profile.noPosts'),
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                MasarenLocalizations.of(context, 'profile.noPostsHint'),
                style: TextStyle(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final post in _posts) ...[
            _buildPostCard(context, cs, dark, u, post),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildPostCard(
      BuildContext context, ColorScheme cs, bool dark, User u, Post p) {
    final media = p.media.isNotEmpty ? p.media.first : null;
    final isVideo = media?.isVideo == true || p.videoHlsUrl != null;
    final thumb = p.videoPosterUrl ??
        media?.posterUrl ??
        (media != null && !media.isVideo ? media.url : null);
    return Material(
      color: dark
          ? cs.surfaceContainerHigh.withValues(alpha: 0.55)
          : cs.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => PostDetailScreen(
                post: p, currentUser: u, onChanged: (_) {}))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (thumb != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      thumb,
                      fit: BoxFit.cover,
                      cacheWidth: 1000,
                      errorBuilder: (_, __, ___) => _postThumbFallback(
                          cs, isVideo ? Icons.videocam : Icons.image_outlined),
                    ),
                    if (isVideo)
                      const Center(
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.play_arrow_rounded,
                              color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.kind != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _postKindLabel(context, p.kind),
                        style: TextStyle(
                          color: cs.onPrimaryContainer,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    p.text,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.favorite_rounded,
                          size: 15, color: cs.primary),
                      const SizedBox(width: 4),
                      Text('${p.likes}',
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 12)),
                      const SizedBox(width: 14),
                      Icon(Icons.chat_bubble_outline_rounded,
                          size: 15, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text('${p.comments}',
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 12)),
                      const SizedBox(width: 14),
                      Icon(Icons.share_outlined,
                          size: 15, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text('${p.shares}',
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 12)),
                      const Spacer(),
                      if (p.createdAt != null)
                        Text(_shortDate(p.createdAt!),
                            style: TextStyle(
                                color: cs.onSurfaceVariant, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _postThumbFallback(ColorScheme cs, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary.withValues(alpha: 0.25), cs.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
          child: Icon(icon, size: 38, color: cs.onPrimaryContainer)),
    );
  }

  String _shortDate(String raw) {
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return '';
    final diff = DateTime.now().difference(parsed);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${parsed.day}/${parsed.month}/${parsed.year % 100}';
  }

  Widget _coverGradient(ColorScheme cs, bool dark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary,
            cs.primary.withValues(alpha: 0.8),
            cs.tertiary.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

class _StatData {
  final String value;
  final String label;
  final IconData icon;
  final List<Color> gradient;
  const _StatData({
    required this.value,
    required this.label,
    required this.icon,
    required this.gradient,
  });
}

