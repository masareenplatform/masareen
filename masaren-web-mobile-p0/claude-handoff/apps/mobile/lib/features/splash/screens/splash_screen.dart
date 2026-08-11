import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:masaren/di/injection.dart';
import 'package:masaren/services/api_service.dart';
import 'package:masaren/core/settings/app_settings.dart';
import 'package:masaren/core/theme/masaren_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  late final Animation<double> _scale = Tween<double>(begin: 0.6, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
  late final Animation<double> _opacity = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _route();
  }

  Future<void> _route() async {
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    final token = await getIt<ApiService>().currentUserId();
    final seen = (await getIt<FlutterSecureStorage>().read(key: AppSettings.onboardingSeenKey)) == '1';
    if (token.isNotEmpty) {
      context.go('/home');
    } else if (!seen) {
      context.go('/onboarding');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [MasarenTheme.brand, MasarenTheme.green], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scale,
                child: FadeTransition(
                  opacity: _opacity,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 24, offset: const Offset(0, 8))]),
                    child: Image.asset('assets/images/masaren_logo_white_256.png', width: 72, height: 72),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              FadeTransition(
                opacity: _opacity,
                child: const Text('MASAREEN', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              ),
              FadeTransition(
                opacity: _opacity,
                child: const Text('Impact, verified.', style: TextStyle(color: Colors.white70, fontSize: 15)),
              ),
              const SizedBox(height: 40),
              const SizedBox(width: 34, height: 34, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
            ],
          ),
        ),
      ),
    );
  }
}



