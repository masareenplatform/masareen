import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/models.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/screens/interview_screen.dart';
import 'package:masaren/widgets/animations.dart';

const Color _redTone = Color(0xFFCE1126);
const Color _whiteTone = Color(0xFFFFFFFF);
const Color _blackTone = Color(0xFF111111);

class PlayerShowcaseScreen extends StatefulWidget {
  final String playerId;
  final User currentUser;
  const PlayerShowcaseScreen(
      {super.key, required this.playerId, required this.currentUser});

  @override
  State<PlayerShowcaseScreen> createState() => _PlayerShowcaseScreenState();
}

class _PlayerShowcaseScreenState extends State<PlayerShowcaseScreen> {
  // ── data ──────────────────────────────────────────────────────────────
  Map<String, dynamic>? _player;
  List<dynamic> _careerStats = [];
  List<dynamic> _timeline = [];
  List<dynamic> _achievements = [];
  List<dynamic> _related = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  bool _following = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final playerData = await api.get('/api/v1/players/${widget.playerId}');
      final career = await api.get('/api/v1/players/${widget.playerId}/career');
      final timelineRes =
          await api.get('/api/v1/players/${widget.playerId}/timeline');
      final achRes =
          await api.get('/api/v1/players/${widget.playerId}/achievements');
      final relRes =
          await api.get('/api/v1/players/${widget.playerId}/related');
      if (mounted) {
        setState(() {
          _player = playerData as Map<String, dynamic>;
          _careerStats = career is List ? career : [];
          _timeline = timelineRes is List ? timelineRes : [];
          _achievements = achRes is List ? achRes : [];
          _related = relRes is List ? relRes : [];
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
      await api.post('/api/v1/players/${widget.playerId}/follow');
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

  void _requestInterview() {
    final roomId =
        'player-${widget.playerId}-${DateTime.now().millisecondsSinceEpoch}';
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

  double _parseNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String _num(dynamic v, [String fallback = '0']) {
    if (v == null) return fallback;
    if (v is num) {
      return v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
    }
    return v.toString();
  }

  Color get _posColor {
    final pos = (_player?['position'] ?? '').toString().toUpperCase();
    if (pos.contains('GK') || pos.contains('GOAL')) return AppColors.amber;
    if (pos.contains('DEF') || pos.contains('BACK')) return AppColors.azure;
    if (pos.contains('MID') || pos.contains('WING')) return AppColors.accent;
    if (pos.contains('FWD') || pos.contains('FORWARD') || pos.contains('STRIKER'))
      return _redTone;
    return AppColors.muted;
  }

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
    if (_error != null || _player == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(_error ?? 'Player not found',
              style: TextStyle(color: cs.error)),
        ),
      );
    }

    final p = _player!;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: FloatingShapes(shapeCount: 4, baseColor: const Color(0xFFC62828))),
          CustomScrollView(
        slivers: [
          _buildHeroSection(cs, dark, p),
          SliverToBoxAdapter(child: _buildNationalBadge(cs, dark)),
          SliverToBoxAdapter(child: _buildStatsCards(cs, dark, p)),
          SliverToBoxAdapter(child: _buildCareerTable(cs, dark)),
          SliverToBoxAdapter(child: _buildTimelineSection(cs, dark)),
          SliverToBoxAdapter(child: _buildAchievementsSection(cs, dark)),
          SliverToBoxAdapter(child: _buildActions(cs)),
          SliverToBoxAdapter(child: _buildRelatedPlayers(cs, dark)),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    ],
  ),
    );
  }

  // ── Hero Section ──────────────────────────────────────────────────────
  Widget _buildHeroSection(
      ColorScheme cs, bool dark, Map<String, dynamic> p) {
    final jersey = p['jersey_number'] ?? p['number'] ?? '?';
    final name = _str(p['name'], _str(p['full_name'], 'Player'));
    final position = _str(p['position'], 'MF').toUpperCase();

    return SliverAppBar(
      expandedHeight: 340,
      pinned: true,
      stretch: true,
      backgroundColor: _blackTone,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Player photo
            if (p['photo_url'] != null || p['avatar_url'] != null)
              Image.network(
                (p['photo_url'] ?? p['avatar_url']).toString(),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: _blackTone,
                  child: const Icon(Icons.person, size: 80, color: Colors.white24),
                ),
              )
            else
              Container(
                color: _blackTone,
                child: const Icon(Icons.person, size: 80, color: Colors.white24),
              ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    _redTone.withValues(alpha: 0.4),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Player info
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Jersey number
                  Text(
                    '#$jersey',
                    style: TextStyle(
                      color: _redTone.withValues(alpha: 0.6),
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  // Name
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Position badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _posColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      position,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
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
              const SnackBar(content: Text('Profile link copied'))),
        ),
      ],
    );
  }

  // ── National Team Badge ───────────────────────────────────────────────
  Widget _buildNationalBadge(ColorScheme cs, bool dark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _redTone.withValues(alpha: 0.12),
            dark ? AppColors.darkSurface2.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: _redTone.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Egypt flag
          PulsingWidget(
            child: Container(
              width: 48,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: CustomPaint(painter: _EgyptFlagPainter()),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Egyptian National Team',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'World Cup 2026 Qualifier',
                  style: TextStyle(
                    color: _redTone.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.flag, color: _redTone, size: 22),
        ],
      ),
    );
  }

  // ── Player Stats Cards ────────────────────────────────────────────────
  Widget _buildStatsCards(
      ColorScheme cs, bool dark, Map<String, dynamic> p) {
    final stats = [
      _AnimStat('Goals', _num(p['goals'] ?? p['total_goals']), Icons.sports_soccer, _redTone, numericTarget: _parseNum(p['goals'] ?? p['total_goals'])),
      _AnimStat('Assists', _num(p['assists'] ?? p['total_assists']),
          Icons.swap_vert, AppColors.accent, numericTarget: _parseNum(p['assists'] ?? p['total_assists'])),
      _AnimStat('Appearances', _num(p['appearances'] ?? p['caps']),
          Icons.shield, cs.primary, numericTarget: _parseNum(p['appearances'] ?? p['caps'])),
      _AnimStat('Minutes', _num(p['minutes_played'] ?? p['minutes']),
          Icons.access_time, AppColors.amber, numericTarget: _parseNum(p['minutes_played'] ?? p['minutes'])),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Row(
        children: stats
            .map((s) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: glassDecoration(dark),
                    child: Column(
                      children: [
                        Icon(s.icon, size: 18, color: s.color),
                        const SizedBox(height: 6),
                        CountUpNumber(
                          target: s.numericTarget,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: s.color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: s.color.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ── Career Stats Table ────────────────────────────────────────────────
  Widget _buildCareerTable(ColorScheme cs, bool dark) {
    if (_careerStats.isEmpty) {
      return const SizedBox.shrink();
    }
    return SlideInWidget(
      delay: const Duration(milliseconds: 100),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(title: 'Career Statistics'),
          Container(
            width: double.infinity,
            decoration: glassDecoration(dark),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                    _redTone.withValues(alpha: 0.08)),
                columns: const [
                  DataColumn(label: Text('Season',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  DataColumn(label: Text('Team',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      numeric: false),
                  DataColumn(label: Text('Apps',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  DataColumn(label: Text('Goals',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  DataColumn(label: Text('Assists',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  DataColumn(label: Text('Mins',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                ],
                rows: _careerStats.map((s) {
                  final row = s as Map<String, dynamic>;
                  return DataRow(cells: [
                    DataCell(Text(_str(row['season'], '?'),
                        style: const TextStyle(fontSize: 12))),
                    DataCell(Text(_str(row['team'], '?'),
                        style: const TextStyle(fontSize: 12))),
                    DataCell(Text(_num(row['appearances']),
                        style: const TextStyle(fontSize: 12))),
                    DataCell(Text(_num(row['goals']),
                        style: const TextStyle(fontSize: 12, color: _redTone, fontWeight: FontWeight.w700))),
                    DataCell(Text(_num(row['assists']),
                        style: const TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w700))),
                    DataCell(Text(_num(row['minutes']),
                        style: const TextStyle(fontSize: 12))),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  // ── Timeline Section ──────────────────────────────────────────────────
  Widget _buildTimelineSection(ColorScheme cs, bool dark) {
    if (_timeline.isEmpty) {
      return const SizedBox.shrink();
    }
    final icons = <String, IconData>{
      'debut': Icons.sports_soccer,
      'transfer': Icons.swap_horiz,
      'goal': Icons.sports,
      'award': Icons.emoji_events,
      'injury': Icons.medical_services,
      'cap': Icons.flag,
      'contract': Icons.description,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Career Timeline'),
          ...List.generate(_timeline.length, (i) {
            final t = _timeline[i] as Map<String, dynamic>;
            final kind = (t['kind'] ?? t['type'] ?? 'milestone').toString();
            final title = _str(t['title'], 'Milestone');
            final detail = _str(t['detail'] ?? t['description']);
            final date = _str(t['date'] ?? t['happened_at']);
            final isLast = i == _timeline.length - 1;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline line + dot
                  SizedBox(
                    width: 32,
                    child: Column(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _redTone,
                            border: Border.all(
                              color: dark ? AppColors.darkBg : Colors.white,
                              width: 3,
                            ),
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: _redTone.withValues(alpha: 0.3),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Content
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: glassDecoration(dark),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(icons[kind] ?? Icons.circle,
                                  size: 16, color: _redTone),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13)),
                              ),
                            ],
                          ),
                          if (detail.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(detail,
                                style: const TextStyle(
                                    color: AppColors.muted, fontSize: 12)),
                          ],
                          if (date.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(date.length >= 10 ? date.substring(0, 10) : date,
                                style: const TextStyle(
                                    color: AppColors.muted, fontSize: 11)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Achievements Section ──────────────────────────────────────────────
  Widget _buildAchievementsSection(ColorScheme cs, bool dark) {
    if (_achievements.isEmpty) {
      return const SizedBox.shrink();
    }
    return SlideInWidget(
      delay: const Duration(milliseconds: 200),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(title: 'Achievements & Trophies'),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _achievements.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final a = _achievements[i] as Map<String, dynamic>;
                final title = _str(a['title'] ?? a['name']);
                final year = _str(a['year']);

                return Container(
                  width: 100,
                  padding: const EdgeInsets.all(10),
                  decoration: glassDecoration(dark),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _achIcon(a['type'] ?? a['kind']),
                        color: _gold,
                        size: 26,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
      ),
      ),
    );
  }

  IconData _achIcon(dynamic kind) {
    final k = kind?.toString().toLowerCase() ?? '';
    if (k.contains('golden') || k.contains('ball')) return Icons.emoji_events;
    if (k.contains('boot')) return Icons.sports_soccer;
    if (k.contains('title')) return Icons.military_tech;
    if (k.contains('cup')) return Icons.local_drink;
    return Icons.emoji_events;
  }

  // ── Action Buttons ────────────────────────────────────────────────────
  Widget _buildActions(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _follow,
                    icon: Icon(
                      _following
                          ? Icons.check_circle_outline
                          : Icons.person_add_outlined,
                      size: 18,
                    ),
                    label: Text(_following ? 'Following' : 'Follow'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _following ? AppColors.accent : _redTone,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Message feature coming soon'))),
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Send Message'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.onSurface,
                      side: BorderSide(color: cs.outline),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _requestInterview,
              icon: const Icon(Icons.videocam_outlined, size: 18),
              label: const Text('Request Interview'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _redTone,
                side: const BorderSide(color: _redTone),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Related Players ───────────────────────────────────────────────────
  Widget _buildRelatedPlayers(ColorScheme cs, bool dark) {
    if (_related.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Related Egyptian Players'),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: _related.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final rp = _related[i] as Map<String, dynamic>;
              final name = _str(rp['name'] ?? rp['full_name'], 'Player');
              final photo = rp['photo_url'] ?? rp['avatar_url'];
              final jersey = rp['jersey_number'] ?? rp['number'] ?? '';

              return GestureDetector(
                onTap: () {
                  final pid = rp['id'] ?? rp['user_id'] ?? '';
                  if (pid.toString().isNotEmpty) {
                    Navigator.of(context).pushReplacement(MaterialPageRoute(
                      builder: (_) => PlayerShowcaseScreen(
                        playerId: pid.toString(),
                        currentUser: widget.currentUser,
                      ),
                    ));
                  }
                },
                child: Container(
                  width: 90,
                  padding: const EdgeInsets.all(8),
                  decoration: glassDecoration(dark),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 24,
                        backgroundImage:
                            photo != null ? NetworkImage(photo.toString()) : null,
                        backgroundColor: cs.surfaceContainerLow,
                        child: photo == null
                            ? Icon(Icons.person, size: 20, color: cs.onSurfaceVariant)
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                      if (jersey.toString().isNotEmpty)
                        Text(
                          '#$jersey',
                          style: TextStyle(
                            fontSize: 9,
                            color: _redTone.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Supporting models & widgets ─────────────────────────────────────────

class _AnimStat {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final double numericTarget;
  _AnimStat(this.label, this.value, this.icon, this.color, {this.numericTarget = 0});
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

// ── Egyptian Flag Painter ───────────────────────────────────────────────

class _EgyptFlagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stripeH = size.height / 3;

    // Red stripe
    final redPaint = Paint()..color = _redTone;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, stripeH), redPaint);

    // White stripe
    final whitePaint = Paint()..color = _whiteTone;
    canvas.drawRect(
        Rect.fromLTWH(0, stripeH, size.width, stripeH), whitePaint);

    // Black stripe
    final blackPaint = Paint()..color = _blackTone;
    canvas.drawRect(
        Rect.fromLTWH(0, stripeH * 2, size.width, stripeH), blackPaint);

    // Eagle of Saladin (simplified golden emblem in center)
    final eaglePaint = Paint()..color = _gold;
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawCircle(Offset(cx, cy), stripeH * 0.35, eaglePaint);
    final innerPaint = Paint()..color = _redTone;
    canvas.drawCircle(Offset(cx, cy), stripeH * 0.18, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

const Color _gold = Color(0xFFFFD54F);
