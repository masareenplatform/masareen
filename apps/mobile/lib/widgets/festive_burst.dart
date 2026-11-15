import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Small, non-blocking celebration used after positive actions.
class FestiveBurst {
  static Future<void> show(
    BuildContext context, {
    String message = '',
    IconData icon = Icons.celebration,
    Color color = const Color(0xFFC19A4B),
  }) async {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    final done = Completer<void>();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _Burst(
        message: message,
        icon: icon,
        color: color,
        onDone: () {
          if (entry.mounted) entry.remove();
          if (!done.isCompleted) done.complete();
        },
      ),
    );
    overlay.insert(entry);
    await done.future.timeout(const Duration(milliseconds: 1400),
        onTimeout: () {});
  }
}

class _Burst extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color color;
  final VoidCallback onDone;
  const _Burst(
      {required this.message,
      required this.icon,
      required this.color,
      required this.onDone});

  @override
  State<_Burst> createState() => _BurstState();
}

class _BurstState extends State<_Burst> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final random = math.Random(DateTime.now().millisecondsSinceEpoch);
    _particles = List.generate(22, (i) {
      final angle = (math.pi * 2 * i / 22) + random.nextDouble() * .3;
      return _Particle(
        angle: angle,
        distance: 80 + random.nextDouble() * 110,
        size: 4 + random.nextDouble() * 6,
        color: [
          const Color(0xFF0E6B5C),
          const Color(0xFFC19A4B),
          const Color(0xFF2C6E8F),
          const Color(0xFFE36A4A),
          const Color(0xFF6A4CB0),
        ][i % 5],
        rotation: random.nextDouble() * math.pi,
      );
    });
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 950))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(_controller.value);
          final opacity = _controller.value < .7
              ? 1.0
              : (1 - (_controller.value - .7) / .3).clamp(0.0, 1.0);
          return Opacity(
            opacity: opacity,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ConfettiPainter(
                        particles: _particles, progress: t),
                  ),
                ),
                Center(
                  child: Transform.scale(
                    scale: .65 + .35 * t,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: widget.color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: widget.color.withValues(alpha: .35),
                                  blurRadius: 28,
                                  spreadRadius: 6)
                            ],
                          ),
                          child: Icon(widget.icon,
                              color: Colors.white, size: 38),
                        ),
                        if (widget.message.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: .72),
                                borderRadius: BorderRadius.circular(99)),
                            child: Text(widget.message,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Particle {
  final double angle;
  final double distance;
  final double size;
  final Color color;
  final double rotation;
  const _Particle(
      {required this.angle,
      required this.distance,
      required this.size,
      required this.color,
      required this.rotation});
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint();
    for (final p in particles) {
      final distance = p.distance * progress;
      final gravity = 90 * progress * progress;
      final point = Offset(
        center.dx + math.cos(p.angle) * distance,
        center.dy + math.sin(p.angle) * distance + gravity,
      );
      paint.color = p.color.withValues(alpha: 1 - progress * .6);
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(p.rotation + progress * 3);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset.zero, width: p.size, height: p.size * .55),
              const Radius.circular(1.5)),
          paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
