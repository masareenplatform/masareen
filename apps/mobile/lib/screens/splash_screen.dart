import 'package:flutter/material.dart';
import 'package:masaren/theme.dart';
import 'package:audioplayers/audioplayers.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _scaleUp;
  final _audio = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _scaleUp = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.elasticOut)),
    );
    _controller.forward();
    _audio.play(AssetSource('sounds/app_startup.wav'), volume: 0.8);
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _audio.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: dark ? AppColors.darkBg : Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeIn.value,
              child: Transform.scale(
                scale: _scaleUp.value,
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                dark ? 'assets/images/masaren_logo_white.png' : 'assets/images/masaren_logo_512.png',
                width: 300,
                height: 300,
                color: dark ? null : null,
                colorBlendMode: dark ? BlendMode.srcIn : null,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.shield,
                  size: 160,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: cs.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
