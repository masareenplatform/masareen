import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedGradientBackground extends StatefulWidget {
  final Widget child;
  final List<Color>? colors;

  const AnimatedGradientBackground({
    super.key,
    required this.child,
    this.colors,
  });

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors ??
        const [
          Color(0xFF0D1B3E),
          Color(0xFF2E1A47),
          Color(0xFF0E3B43),
        ];

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final t = _animation.value;
        final color1 = Color.lerp(colors[0], colors[1], t)!;
        final color2 = Color.lerp(colors[1], colors[2], t)!;
        final color3 = Color.lerp(colors[2], colors[0], t)!;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft + Alignment(0, sin(t * pi) * 0.3),
              end: Alignment.bottomRight + Alignment(sin(t * pi) * 0.3, 0),
              colors: [color1, color2, color3],
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}

class FloatingShapes extends StatefulWidget {
  final int shapeCount;
  final Color? baseColor;

  const FloatingShapes({
    super.key,
    this.shapeCount = 6,
    this.baseColor,
  });

  @override
  State<FloatingShapes> createState() => _FloatingShapesState();
}

class _FloatingShapesState extends State<FloatingShapes>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_ShapeData> _shapes;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _shapes = List.generate(widget.shapeCount, (_) => _ShapeData.random(_random));
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.baseColor ?? Colors.white;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Stack(
          children: List.generate(_shapes.length, (i) {
            final shape = _shapes[i];
            final progress = (_controller.value + shape.offset) % 1.0;
            final y = shape.startY + sin(progress * 2 * pi) * shape.amplitude;
            final x = shape.startX + cos(progress * 2 * pi * 0.7) * 15;
            final rotation = progress * 2 * pi * shape.rotationSpeed;

            return Positioned(
              left: x,
              top: y,
              child: Transform.rotate(
                angle: rotation,
                child: Opacity(
                  opacity: shape.opacity,
                  child: _buildShape(shape.type, shape.size, color),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildShape(int type, double size, Color color) {
    final c = color.withOpacity(1);

    switch (type) {
      case 0:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
          ),
        );
      case 1:
        return Container(
          width: size,
          height: size * 0.6,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(size * 0.15),
          ),
        );
      default:
        return CustomPaint(
          size: Size(size, size),
          painter: _HexagonPainter(color: c),
        );
    }
  }
}

class _ShapeData {
  final int type;
  final double size;
  final double startX;
  final double startY;
  final double offset;
  final double amplitude;
  final double opacity;
  final double rotationSpeed;

  _ShapeData({
    required this.type,
    required this.size,
    required this.startX,
    required this.startY,
    required this.offset,
    required this.amplitude,
    required this.opacity,
    required this.rotationSpeed,
  });

  factory _ShapeData.random(Random random) {
    return _ShapeData(
      type: random.nextInt(3),
      size: 40 + random.nextDouble() * 80,
      startX: random.nextDouble() * 400,
      startY: random.nextDouble() * 800,
      offset: random.nextDouble(),
      amplitude: 20 + random.nextDouble() * 40,
      opacity: 0.03 + random.nextDouble() * 0.05,
      rotationSpeed: 0.3 + random.nextDouble() * 0.7,
    );
  }
}

class _HexagonPainter extends CustomPainter {
  final Color color;
  _HexagonPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (int i = 0; i < 6; i++) {
      final angle = (pi / 3) * i - pi / 2;
      final point = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ShimmerWidget extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerWidget({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerWidget> createState() => _ShimmerWidgetState();
}

class _ShimmerWidgetState extends State<ShimmerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[200]!;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: const Alignment(-1.0, 0),
              end: const Alignment(1.0, 0),
              colors: [baseColor, highlightColor, baseColor],
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value,
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CountUpNumber extends StatefulWidget {
  final double target;
  final Duration duration;
  final TextStyle? style;
  final String prefix;
  final String suffix;

  const CountUpNumber({
    super.key,
    required this.target,
    this.duration = const Duration(milliseconds: 1500),
    this.style,
    this.prefix = '',
    this.suffix = '',
  });

  @override
  State<CountUpNumber> createState() => _CountUpNumberState();
}

class _CountUpNumberState extends State<CountUpNumber>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = Tween<double>(begin: 0, end: widget.target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(CountUpNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      _animation = Tween<double>(begin: 0, end: widget.target).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Text(
          '$widget.prefix${_formatNumber(_animation.value)}$widget.suffix',
          style: widget.style,
        );
      },
    );
  }
}

class SlideInWidget extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Offset slideOffset;

  const SlideInWidget({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.slideOffset = const Offset(0, 0.1),
  });

  @override
  State<SlideInWidget> createState() => _SlideInWidgetState();
}

class _SlideInWidgetState extends State<SlideInWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.slideOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _startAnimation();
  }

  Future<void> _startAnimation() async {
    if (widget.delay > Duration.zero) {
      await Future.delayed(widget.delay);
    }
    if (mounted) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: widget.child,
          ),
        );
      },
    );
  }
}

class ScaleInWidget extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const ScaleInWidget({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  @override
  State<ScaleInWidget> createState() => _ScaleInWidgetState();
}

class _ScaleInWidgetState extends State<ScaleInWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _startAnimation();
  }

  Future<void> _startAnimation() async {
    if (widget.delay > Duration.zero) {
      await Future.delayed(widget.delay);
    }
    if (mounted) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: widget.child,
          ),
        );
      },
    );
  }
}

class PulsingWidget extends StatefulWidget {
  final Widget child;
  final double minScale;
  final double maxScale;

  const PulsingWidget({
    super.key,
    required this.child,
    this.minScale = 0.97,
    this.maxScale = 1.03,
  });

  @override
  State<PulsingWidget> createState() => _PulsingWidgetState();
}

class _PulsingWidgetState extends State<PulsingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _animation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
