import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:masaren/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

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
      duration: const Duration(milliseconds: 1400),
    );
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.7, curve: Curves.easeOut)),
    );
    _scaleUp = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic)),
    );
    _controller.forward();
    _playStartupSound();
  }

  Future<void> _playStartupSound() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('masaren_startup_sound') == false) return;
      await _audio.play(AssetSource('sounds/app_startup.wav'), volume: 0.6);
    } catch (_) {}
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
    final logoSize =
        (MediaQuery.of(context).size.width * 0.7).clamp(180.0, 300.0);
    return Scaffold(
      backgroundColor: dark ? AppColors.darkBg : Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeIn.value,
              child: Transform.scale(scale: _scaleUp.value, child: child),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                dark
                    ? 'assets/images/masaren_logo_white.png'
                    : 'assets/images/masaren_logo_512.png',
                width: logoSize,
                height: logoSize,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.shield,
                  size: logoSize * 0.55,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 26,
                height: 26,
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
