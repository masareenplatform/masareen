import 'package:flutter/material.dart';
import 'package:masaren/theme.dart';

class TiyePitchScreen extends StatefulWidget {
  const TiyePitchScreen({super.key});

  @override
  State<TiyePitchScreen> createState() => _TiyePitchScreenState();
}

class _TiyePitchScreenState extends State<TiyePitchScreen> {
  final _controller = PageController();
  int _index = 0;

  static const _slides = [
    _PitchSlide(
      kicker: 'TIYE × MASAREEN',
      title: 'From programs\nto proof.',
      body:
          'A partnership that turns every TIYE program, event and graduate story into verified, portable impact.',
      bullets: [
        'One shared impact engine',
        'Institutional memory that survives every cohort',
        'A new digital home for TIYE entities and alumni',
      ],
      metric: '01',
    ),
    _PitchSlide(
      kicker: 'THE GAP',
      title: 'Impact is real.\nThe proof is scattered.',
      body:
          'Programs live in spreadsheets. Evidence lives in phones. Reports are rebuilt every quarter. Partners cannot see the full story.',
      bullets: [
        'Manual reporting and duplicated effort',
        'Evidence without a trusted chain of custody',
        'Alumni and opportunities disconnected from programs',
      ],
      metric: '02',
    ),
    _PitchSlide(
      kicker: 'THE ENGINE',
      title: 'One place for\nevery relationship.',
      body:
          'MASAREEN connects people, entities, programs, events, evidence, markets and rewards in a single verified graph.',
      bullets: [
        'Verified entity profiles and event hubs',
        'Evidence capture with provenance and review',
        'Calls, opportunities, MRC rewards and reports',
      ],
      metric: '03',
    ),
    _PitchSlide(
      kicker: 'WHAT TIYE UNLOCKS',
      title: 'Your programs,\nmeasurably stronger.',
      body:
          'TIYE gets a branded institutional layer, a living alumni network and a repeatable impact reporting system.',
      bullets: [
        'Co-branded TIYE and ACU profiles',
        'Program and event dashboards with real-time reach',
        'Partner-ready PDF reports and impact passports',
        'A pipeline of talent, projects and funding opportunities',
      ],
      metric: '04',
    ),
    _PitchSlide(
      kicker: 'PILOT · 30 DAYS',
      title: 'Start small.\nProve fast.',
      body:
          'A focused pilot with one TIYE program and one cohort gives us real evidence, real feedback and a clear scale decision.',
      bullets: [
        'Week 1 — activate TIYE entity and program pages',
        'Week 2 — onboard cohort and capture verified evidence',
        'Week 3 — launch opportunities, calls and rewards',
        'Week 4 — publish the first joint impact report',
      ],
      metric: '05',
    ),
    _PitchSlide(
      kicker: 'THE ASK',
      title: 'Build the next\nchapter with us.',
      body:
          'Join the pilot as a founding institutional partner. Bring one program. We will bring the engine, the team and the measurement.',
      bullets: [
        'Founding partner recognition',
        'Co-designed impact framework',
        'Priority access to new modules and insights',
      ],
      metric: '06',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int index) {
    if (index < 0 || index >= _slides.length) return;
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(
        children: [
          const Positioned.fill(child: _PitchBackdrop()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .14),
                          ),
                        ),
                        child: const Text(
                          'M',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'MASAREEN',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.4,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_index + 1} / ${_slides.length}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .55),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: Icon(
                          Icons.close,
                          color: Colors.white.withValues(alpha: .8),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 18, 18),
                  child: Row(
                    children: [
                      for (var i = 0; i < _slides.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsetsDirectional.only(end: 6),
                          width: i == _index ? 22 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _index
                                ? AppColors.gold
                                : Colors.white.withValues(alpha: .2),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      const Spacer(),
                      if (_index > 0)
                        IconButton.outlined(
                          onPressed: () => _go(_index - 1),
                          icon: const Icon(Icons.arrow_back_rounded),
                          style: IconButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: .25),
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _index == _slides.length - 1
                            ? () => Navigator.maybePop(context)
                            : () => _go(_index + 1),
                        icon: Icon(
                          _index == _slides.length - 1
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _PitchSlide slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (_, value, child) => Opacity(
        opacity: value.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - value)),
          child: child,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 70 : 24,
              vertical: wide ? 30 : 14,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              slide.kicker,
                              style: const TextStyle(
                                color: AppColors.gold,
                                fontSize: 10.5,
                                letterSpacing: 2.4,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              slide.title,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: wide ? 54 : 38,
                                height: 1.02,
                                letterSpacing: -1.3,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (wide)
                        Text(
                          slide.metric,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .07),
                            fontSize: 130,
                            height: .8,
                            letterSpacing: -6,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 660),
                    child: Text(
                      slide.body,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .72),
                        fontSize: wide ? 16 : 14,
                        height: 1.65,
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final bullet in slide.bullets)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .055),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .12),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified_outlined,
                                color: AppColors.gold,
                                size: 16,
                              ),
                              const SizedBox(width: 7),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 320,
                                ),
                                child: Text(
                                  bullet,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: .85),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PitchBackdrop extends StatefulWidget {
  const _PitchBackdrop();

  @override
  State<_PitchBackdrop> createState() => _PitchBackdropState();
}

class _PitchBackdropState extends State<_PitchBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final t = _controller.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + t * .3, -1),
              end: Alignment(1, 1 - t * .25),
              colors: const [
                Color(0xFF020504),
                Color(0xFF07130F),
                Color(0xFF0A241C),
                Color(0xFF030807),
              ],
            ),
          ),
          child: CustomPaint(painter: _OrbitPainter(t)),
        );
      },
    );
  }
}

class _OrbitPainter extends CustomPainter {
  final double t;
  _OrbitPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .85, size.height * .18);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.gold.withValues(alpha: .10);
    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(center, 80 + i * 58 + t * 18, paint);
    }
    final glow = Paint()
      ..color = AppColors.brand.withValues(alpha: .16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);
    canvas.drawCircle(Offset(size.width * .1, size.height * .82), 120, glow);
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) => oldDelegate.t != t;
}

class _PitchSlide {
  final String kicker;
  final String title;
  final String body;
  final List<String> bullets;
  final String metric;
  const _PitchSlide({
    required this.kicker,
    required this.title,
    required this.body,
    required this.bullets,
    required this.metric,
  });
}
