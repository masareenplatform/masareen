import 'package:flutter/material.dart';
import 'package:masaren/widgets/animations.dart';

class WebAuthLayout extends StatelessWidget {
  final Widget child;
  final String title;
  final String subtitle;
  final bool dark;

  const WebAuthLayout({
    super.key,
    required this.child,
    required this.title,
    required this.subtitle,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Row(
        children: [
          Expanded(
            flex: 6,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: dark
                      ? const [
                          Color(0xFF030807),
                          Color(0xFF0B241D),
                          Color(0xFF06100D),
                        ]
                      : const [
                          Color(0xFF0E6B5C),
                          Color(0xFF0A4A3F),
                          Color(0xFF082C25),
                        ],
                ),
              ),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Stack(
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: .22,
                      child: AnimatedGradientBackground(
                        colors: dark
                            ? const [
                                Color(0xFF030807),
                                Color(0xFF0B241D),
                                Color(0xFF06100D),
                              ]
                            : const [
                                Color(0xFF0E6B5C),
                                Color(0xFF0A4A3F),
                                Color(0xFF082C25),
                              ],
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: ExcludeSemantics(
                      child: FloatingShapes(
                        shapeCount: 10,
                        baseColor: Colors.white.withValues(alpha: .13),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(56, 44, 56, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: .2)),
                                ),
                                child: const Text('M',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 25,
                                        fontWeight: FontWeight.w900)),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('MASAREEN',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 3.4)),
                                  Text('IMPACT INFRASTRUCTURE',
                                      style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: .62),
                                          fontSize: 8,
                                          letterSpacing: 1.5,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ],
                          ),
                          const Spacer(),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 610),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 11, vertical: 5),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.white.withValues(alpha: .13),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: .18)),
                                  ),
                                  child: const Text(
                                    'IMPACT INFRASTRUCTURE  ·  WEB + MOBILE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      letterSpacing: 1.2,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Connecting paths.\nCreating impact.',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 46,
                                    height: 1.05,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'One engine for verified impact, entity markets, newsroom reporting and everything your organisation does on the ground.',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: .8),
                                    fontSize: 15,
                                    height: 1.65,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                const Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _FeaturePill(
                                        icon: Icons.verified_outlined,
                                        label: 'Verified evidence'),
                                    _FeaturePill(
                                        icon: Icons.candlestick_chart_outlined,
                                        label: 'Entity market'),
                                    _FeaturePill(
                                        icon: Icons.newspaper_outlined,
                                        label: 'Newsroom'),
                                    _FeaturePill(
                                        icon: Icons.hub_outlined,
                                        label: 'Every relationship'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              _metric('Entities', 'Real identities'),
                              const SizedBox(width: 28),
                              _metric('Impact', 'Measured, not claimed'),
                              const SizedBox(width: 28),
                              _metric('Market', 'Win-win economics'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Container(
              color: cs.surface,
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 48, vertical: 40),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  height: 1.1)),
                          const SizedBox(height: 8),
                          Text(subtitle,
                              style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 13.5,
                                  height: 1.5)),
                          const SizedBox(height: 28),
                          child,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String value, String label) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18)),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: .62), fontSize: 10.5)),
        ],
      );
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: .15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 7),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
