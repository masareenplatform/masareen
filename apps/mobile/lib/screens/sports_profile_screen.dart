import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/models.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/screens/interview_screen.dart';
import 'package:masaren/screens/player_showcase_screen.dart';
import 'package:masaren/widgets/animations.dart';

const Color _greenField = Color(0xFF1B5E20);
const Color _greenPitch = Color(0xFF2E7D32);
const Color _gold = Color(0xFFFFD54F);

class SportsProfileScreen extends StatefulWidget {
  final String orgId;
  final User currentUser;
  const SportsProfileScreen(
      {super.key, required this.orgId, required this.currentUser});

  @override
  State<SportsProfileScreen> createState() => _SportsProfileScreenState();
}

class _SportsProfileScreenState extends State<SportsProfileScreen>
    with SingleTickerProviderStateMixin {
  // ── data ──────────────────────────────────────────────────────────────
  Map<String, dynamic>? _org;
  List<dynamic> _squad = [];
  List<dynamic> _fixtures = [];
  List<dynamic> _results = [];
  List<dynamic> _news = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  bool _following = false;

  // ── tabs ──────────────────────────────────────────────────────────────
  late TabController _tabCtrl;
  static const _tabs = [
    'Squad',
    'Fixtures',
    'Results',
    'News',
    'About',
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── data loading ──────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final orgData = await api.get('/api/v1/orgs/${widget.orgId}');
      final squadRes = await api.get('/api/v1/orgs/${widget.orgId}/squad');
      final fixRes = await api.get('/api/v1/orgs/${widget.orgId}/fixtures');
      final resRes = await api.get('/api/v1/orgs/${widget.orgId}/results');
      final newsRes = await api.get('/api/v1/posts',
          {'author_id': widget.orgId, 'limit': 20});
      if (mounted) {
        setState(() {
          _org = orgData as Map<String, dynamic>;
          _squad = squadRes is List ? squadRes : [];
          _fixtures = fixRes is List ? fixRes : [];
          _results = resRes is List ? resRes : [];
          _news = newsRes is List ? newsRes : [];
        });
      }
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _follow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await api.post('/api/v1/orgs/${widget.orgId}/follow');
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

  void _scheduleInterview() {
    final roomId = 'match-${widget.orgId}-${DateTime.now().millisecondsSinceEpoch}';
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => InterviewScreen(
        roomId: roomId,
        userName: widget.currentUser.fullName,
        isInitiator: true,
      ),
    ));
  }

  // ── helpers ───────────────────────────────────────────────────────────
  String _str(dynamic v, [String fallback = '']) =>
      v?.toString() ?? fallback;
  String _num(dynamic v, [String fallback = '0']) {
    if (v == null) return fallback;
    if (v is num) return v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
    return v.toString();
  }

  Map<String, dynamic> get _stats => {
        'wins': _org?['wins'] ?? 0,
        'draws': _org?['draws'] ?? 0,
        'losses': _org?['losses'] ?? 0,
        'points': _org?['points'] ?? 0,
      };

  // ══════════════════════════════════════════════════════════════════════
  //  Build
  // ══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _org == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorView(message: _error ?? 'Team not found', onRetry: () => _load()),
      );
    }

    final org = _org!;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: FloatingShapes(shapeCount: 4, baseColor: const Color(0xFF2E7D32))),
          CustomScrollView(
        slivers: [
          _buildHeroHeader(cs, dark, org),
          SliverToBoxAdapter(child: _buildStatsBar(cs, dark)),
          SliverToBoxAdapter(child: _buildActions(cs)),
          SliverToBoxAdapter(child: _buildTabBar(cs, dark)),
          SliverToBoxAdapter(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildTabContent(cs, dark, org),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    ],
  ),
    );
  }

  // ── Hero Header ───────────────────────────────────────────────────────
  Widget _buildHeroHeader(ColorScheme cs, bool dark, Map<String, dynamic> org) {
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      stretch: true,
      backgroundColor: _greenField,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Stadium gradient background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_greenField, _greenPitch, Color(0xFF388E3C)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Pattern overlay (grass stripes)
            Positioned.fill(
              child: Opacity(
                opacity: 0.08,
                child: CustomPaint(painter: _GrassPatternPainter()),
              ),
            ),
            // Dark gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Team info
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Team badge
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.surface,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: org['logo_url'] != null
                            ? ClipOval(
                                child: Image.network(
                                  org['logo_url'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.sports_soccer,
                                    size: 36,
                                    color: _greenPitch,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.sports_soccer,
                                size: 36,
                                color: _greenPitch,
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _str(org['name'], 'Unknown Team'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (org['league'] != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _gold.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: _gold.withValues(alpha: 0.5)),
                                    ),
                                    child: Text(
                                      _str(org['league']),
                                      style: const TextStyle(
                                        color: _gold,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 6),
                                if (org['division'] != null)
                                  Text(
                                    _str(org['division']),
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        _HeaderAction(
          icon: Icons.share_outlined,
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Team link copied'))),
        ),
      ],
    );
  }

  // ── Stats Bar ─────────────────────────────────────────────────────────
  Widget _buildStatsBar(ColorScheme cs, bool dark) {
    final items = [
      _StatItem('W', _num(_stats['wins']), AppColors.accent),
      _StatItem('D', _num(_stats['draws']), AppColors.amber),
      _StatItem('L', _num(_stats['losses']), AppColors.warm),
      _StatItem('PTS', _num(_stats['points']), cs.primary),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Row(
        children: List.generate(items.length, (i) {
          final item = items[i];
          return Expanded(
            child: SlideInWidget(
              delay: Duration(milliseconds: i * 100),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: glassDecoration(dark),
                child: Column(
                  children: [
                    CountUpNumber(
                      target: double.tryParse(item.value) ?? 0,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: item.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: item.color.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Action Buttons ────────────────────────────────────────────────────
  Widget _buildActions(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 42,
              child: FilledButton.icon(
                onPressed: _busy ? null : _follow,
                icon: Icon(
                  _following ? Icons.check_circle_outline : Icons.person_add_outlined,
                  size: 18,
                ),
                label: Text(_following ? 'Following' : 'Follow'),
                style: FilledButton.styleFrom(
                  backgroundColor: _following ? AppColors.accent : cs.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 42,
              child: OutlinedButton.icon(
                onPressed: _scheduleInterview,
                icon: const Icon(Icons.videocam_outlined, size: 18),
                label: const Text('Match Interview'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _greenPitch,
                  side: const BorderSide(color: _greenPitch),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 42,
            width: 42,
            child: OutlinedButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile link copied'))),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.share_outlined, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab Bar ───────────────────────────────────────────────────────────
  Widget _buildTabBar(ColorScheme cs, bool dark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface2.withValues(alpha: 0.6) : cs.surfaceContainerLow.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabCtrl,
        isScrollable: true,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.muted,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        indicator: BoxDecoration(
          gradient: const LinearGradient(colors: [_greenField, _greenPitch]),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerHeight: 0,
        tabs: _tabs.map((t) => Tab(text: t)).toList(),
      ),
    );
  }

  // ── Tab Content ───────────────────────────────────────────────────────
  Widget _buildTabContent(ColorScheme cs, bool dark, Map<String, dynamic> org) {
    switch (_tabCtrl.index) {
      case 0:
        return _SquadTab(squad: _squad, currentUser: widget.currentUser);
      case 1:
        return _FixturesTab(fixtures: _fixtures);
      case 2:
        return _ResultsTab(results: _results);
      case 3:
        return _NewsTab(news: _news);
      case 4:
        return _AboutTab(org: org);
      default:
        return const SizedBox.shrink();
    }
  }
}

// ── Supporting models & widgets ─────────────────────────────────────────

class _StatItem {
  final String label;
  final String value;
  final Color color;
  _StatItem(this.label, this.value, this.color);
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderAction({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(right: 8),
        decoration: const BoxDecoration(
          color: Colors.black38,
          shape: BoxShape.circle,
        ),
        child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 20), onPressed: onTap),
      );
}

// ── Grass pattern painter ───────────────────────────────────────────────

class _GrassPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;
    final stripeH = size.height / 14;
    for (var i = 0; i < 14; i += 2) {
      final y = i * stripeH;
      canvas.drawRect(
          Rect.fromLTWH(0, y, size.width, stripeH), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB: Squad
// ═══════════════════════════════════════════════════════════════════════════

class _SquadTab extends StatelessWidget {
  final List<dynamic> squad;
  final User currentUser;
  const _SquadTab({required this.squad, required this.currentUser});

  Color _positionColor(String pos) {
    switch (pos.toUpperCase()) {
      case 'GK':
        return AppColors.amber;
      case 'DEF':
        return AppColors.azure;
      case 'MID':
        return AppColors.accent;
      case 'FWD':
        return AppColors.warm;
      default:
        return AppColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (squad.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: Text('No squad data available.',
              style: TextStyle(color: AppColors.muted)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(14),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.72,
        ),
        itemCount: squad.length,
        itemBuilder: (_, i) {
          final p = squad[i] as Map<String, dynamic>;
          final pos = (p['position'] ?? 'MF').toString().toUpperCase();
          final jersey = p['jersey_number'] ?? p['number'] ?? '';
          final name = (p['name'] ?? p['full_name'] ?? 'Player').toString();
          final photo = p['photo_url'] ?? p['avatar_url'];

          return SlideInWidget(
            delay: Duration(milliseconds: i * 80),
            child: GestureDetector(
            onTap: () {
              final playerId = p['id'] ?? p['user_id'] ?? '';
              if (playerId.toString().isNotEmpty) {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PlayerShowcaseScreen(
                    playerId: playerId.toString(),
                    currentUser: currentUser,
                  ),
                ));
              }
            },
            child: Container(
              decoration: glassDecoration(
                  Theme.of(context).brightness == Brightness.dark),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Player photo / jersey area
                  Expanded(
                    flex: 3,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: photo != null
                              ? Image.network(photo, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: cs.surfaceContainerLow,
                                    child: const Icon(Icons.person, size: 32),
                                  ))
                              : Container(
                                  color: cs.surfaceContainerLow,
                                  child: const Icon(Icons.person, size: 32),
                                ),
                        ),
                        // Jersey number
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              jersey.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        // Position badge
                        Positioned(
                          bottom: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _positionColor(pos),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              pos,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Name
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB: Fixtures
// ═══════════════════════════════════════════════════════════════════════════

class _FixturesTab extends StatelessWidget {
  final List<dynamic> fixtures;
  const _FixturesTab({required this.fixtures});

  @override
  Widget build(BuildContext context) {
    if (fixtures.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: Text('No upcoming fixtures.',
              style: TextStyle(color: AppColors.muted)),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      itemCount: fixtures.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final f = fixtures[i] as Map<String, dynamic>;
        final opponent = (f['opponent'] ?? f['away_team'] ?? 'TBD').toString();
        final date = (f['date'] ?? f['match_date'] ?? '').toString();
        final time = (f['time'] ?? f['kick_off'] ?? '').toString();
        final venue = (f['venue'] ?? f['location'] ?? '').toString();
        final isHome = f['is_home'] ?? true;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: glassDecoration(
              Theme.of(context).brightness == Brightness.dark),
          child: Row(
            children: [
              // Date block
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_greenField, _greenPitch]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      date.length >= 10 ? date.substring(8, 10) : '??',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      date.length >= 7
                          ? _monthShort(date.substring(5, 7))
                          : '???',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHome ? 'vs $opponent' : '@ $opponent',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [if (time.isNotEmpty) time, if (venue.isNotEmpty) venue]
                          .join('  ·  '),
                      style:
                          const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isHome
                      ? _greenPitch.withValues(alpha: 0.15)
                      : AppColors.warm.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isHome ? 'HOME' : 'AWAY',
                  style: TextStyle(
                    color: isHome ? _greenPitch : AppColors.warm,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _monthShort(String m) {
    const months = {
      '01': 'JAN', '02': 'FEB', '03': 'MAR', '04': 'APR',
      '05': 'MAY', '06': 'JUN', '07': 'JUL', '08': 'AUG',
      '09': 'SEP', '10': 'OCT', '11': 'NOV', '12': 'DEC',
    };
    return months[m] ?? '???';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB: Results
// ═══════════════════════════════════════════════════════════════════════════

class _ResultsTab extends StatelessWidget {
  final List<dynamic> results;
  const _ResultsTab({required this.results});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: Text('No results yet.',
              style: TextStyle(color: AppColors.muted)),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final r = results[i] as Map<String, dynamic>;
        final opponent = (r['opponent'] ?? r['away_team'] ?? 'TBD').toString();
        final date = (r['date'] ?? r['match_date'] ?? '').toString();
        final homeScore = r['home_score'] ?? r['score_for'];
        final awayScore = r['away_score'] ?? r['score_against'];
        final isHome = r['is_home'] ?? true;
        final won = r['result']?.toString().toUpperCase() == 'W' ||
            (isHome && (homeScore ?? 0) > (awayScore ?? 0)) ||
            (!isHome && (awayScore ?? 0) > (homeScore ?? 0));
        final drawn = r['result']?.toString().toUpperCase() == 'D' ||
            (homeScore == awayScore);

        Color resultColor;
        if (won) {
          resultColor = AppColors.accent;
        } else if (drawn) {
          resultColor = AppColors.amber;
        } else {
          resultColor = AppColors.warm;
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: glassDecoration(
              Theme.of(context).brightness == Brightness.dark),
          child: Row(
            children: [
              // Result badge
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: resultColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    won ? 'W' : (drawn ? 'D' : 'L'),
                    style: TextStyle(
                      color: resultColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHome ? 'vs $opponent' : '@ $opponent',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date.length >= 10 ? date.substring(0, 10) : date,
                      style:
                          const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Score
              Text(
                '${homeScore ?? '-'} : ${awayScore ?? '-'}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB: News
// ═══════════════════════════════════════════════════════════════════════════

class _NewsTab extends StatelessWidget {
  final List<dynamic> news;
  const _NewsTab({required this.news});

  @override
  Widget build(BuildContext context) {
    if (news.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: Text('No news posts from this club.',
              style: TextStyle(color: AppColors.muted)),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      itemCount: news.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final n = news[i] as Map<String, dynamic>;
        final text = (n['text'] ?? '').toString();
        final date = (n['created_at'] ?? n['createdAt'] ?? '').toString();
        final likes = n['likes'] ?? 0;
        final comments = (n['comments'] is List)
            ? (n['comments'] as List).length
            : (n['comments'] ?? 0);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: glassDecoration(
              Theme.of(context).brightness == Brightness.dark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.favorite_outline,
                      size: 14, color: AppColors.muted),
                  const SizedBox(width: 3),
                  Text('$likes',
                      style:
                          const TextStyle(fontSize: 12, color: AppColors.muted)),
                  const SizedBox(width: 14),
                  const Icon(Icons.comment_outlined,
                      size: 14, color: AppColors.muted),
                  const SizedBox(width: 3),
                  Text('$comments',
                      style:
                          const TextStyle(fontSize: 12, color: AppColors.muted)),
                  const Spacer(),
                  Text(
                    date.length >= 10 ? date.substring(0, 10) : '',
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB: About
// ═══════════════════════════════════════════════════════════════════════════

class _AboutTab extends StatelessWidget {
  final Map<String, dynamic> org;
  const _AboutTab({required this.org});

  @override
  Widget build(BuildContext context) {
    final infoItems = [
      _AboutInfo(Icons.stadium, 'Stadium', org['stadium'] ?? org['venue'] ?? 'Not specified'),
      _AboutInfo(Icons.people, 'Capacity',
          org['capacity'] != null ? org['capacity'].toString() : 'Not specified'),
      _AboutInfo(Icons.emoji_events, 'League', org['league'] ?? 'Not specified'),
      _AboutInfo(Icons.category, 'Division', org['division'] ?? 'Not specified'),
      _AboutInfo(Icons.flag, 'Country', org['country'] ?? 'Not specified'),
      _AboutInfo(Icons.calendar_today, 'Founded', org['founded'] ?? 'Not specified'),
    ];

    final trophies = org['trophies'] is List
        ? List<dynamic>.from(org['trophies'])
        : <dynamic>[];

    final bio = (org['bio'] ?? org['about'] ?? org['description'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bio.isNotEmpty) ...[
            const SectionTitle(title: 'About'),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              padding: const EdgeInsets.all(16),
              decoration: glassDecoration(
                  Theme.of(context).brightness == Brightness.dark),
              child: Text(bio,
                  style: const TextStyle(color: AppColors.muted, height: 1.5)),
            ),
          ],
          const SectionTitle(title: 'Club Information'),
          ...infoItems.map((item) => Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                padding: const EdgeInsets.all(12),
                decoration: glassDecoration(
                    Theme.of(context).brightness == Brightness.dark),
                child: Row(
                  children: [
                    Icon(item.icon, color: _greenPitch, size: 20),
                    const SizedBox(width: 12),
                    Text('${item.label}: ',
                        style:
                            const TextStyle(color: AppColors.muted, fontSize: 13)),
                    Expanded(
                      child: Text(
                        item.value,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )),
          if (trophies.isNotEmpty) ...[
            const SectionTitle(title: 'Trophies'),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: trophies.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final t = trophies[i];
                  final title = t is Map ? (t['name'] ?? t['title'] ?? '') : t.toString();
                  final year = t is Map ? (t['year'] ?? '').toString() : '';
                  return Container(
                    width: 80,
                    padding: const EdgeInsets.all(10),
                    decoration: glassDecoration(
                        Theme.of(context).brightness == Brightness.dark),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.emoji_events,
                            color: _gold, size: 26),
                        const SizedBox(height: 4),
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w700)),
                        if (year.isNotEmpty)
                          Text(year,
                              style: const TextStyle(
                                  fontSize: 9, color: AppColors.muted)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AboutInfo {
  final IconData icon;
  final String label;
  final String value;
  _AboutInfo(this.icon, this.label, this.value);
}


