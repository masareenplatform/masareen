import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:masaren/core/settings/app_settings.dart';
import 'package:masaren/core/theme/masaren_theme.dart';
import 'package:masaren/core/widgets/badges.dart';
import 'package:masaren/di/injection.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _page = PageController();
  int _pageIndex = 0;

  static final _pages = [
    _Slide(
      eyebrow: 'WELCOME',
      title: 'MASAREEN',
      subtitle: 'The impact economy where proof beats promises.',
      body: 'Follow builders, react to real wins, and grow a transparent record of the change you make.',
      gradient: [MasarenTheme.brand, MasarenTheme.green],
      visual: _HeroVisual(),
    ),
    _Slide(
      eyebrow: 'TRUSTED',
      title: 'Verified, not vague',
      subtitle: 'Every claim is scored and audited by POAI.',
      body: 'Evidence is checked by our autonomous verification crew, so badges and scores mean something.',
      gradient: [MasarenTheme.azure, MasarenTheme.green],
      visual: _VerifyVisual(),
    ),
    _Slide(
      eyebrow: 'REWARDS',
      title: 'MASAREEN Coin',
      subtitle: 'Earn, spend and convert with clear fees.',
      body: 'Fund impact, run campaigns and track every transaction on a transparent ledger.',
      gradient: [MasarenTheme.green, MasarenTheme.azure],
      visual: _CoinVisual(),
    ),
    _Slide(
      eyebrow: 'COMMUNITY',
      title: 'Stand out',
      subtitle: 'Collect badges. Build your reputation.',
      body: 'Top Contributor, SDG Champion, 30-Day Streak, show the work and rise in the community.',
      gradient: [const Color(0xFFF59E0B), const Color(0xFFEF4444)],
      visual: _BadgeVisual(),
    ),
  ];

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _markSeen() async {
    AppSettings.instance.onboardingSeen.value = true;
    await getIt<FlutterSecureStorage>().write(key: AppSettings.onboardingSeenKey, value: '1');
  }

  void _finish() async {
    await _markSeen();
    if (mounted) context.go('/login');
  }

  void _register() async {
    await _markSeen();
    if (mounted) context.go('/register');
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _pageIndex == _pages.length - 1;
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _page,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _pageIndex = i),
            itemBuilder: (_, i) => _PageView(slide: _pages[i]),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: TextButton(
              onPressed: _finish,
              child: const Text('Skip', style: TextStyle(color: Colors.white70)),
            ),
          ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.transparent, Colors.black.withOpacity(0.5)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) {
                      final active = i == _pageIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(color: active ? Colors.white : Colors.white38, borderRadius: BorderRadius.circular(999)),
                      );
                    }),
                  ),
                  const SizedBox(height: 18),
                  if (isLast)
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            onPressed: _finish,
                            child: const Text('Get started', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton(
                            onPressed: _register,
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                            child: const Text('Create an account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: () => _page.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOutCubic),
                        child: const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Slide {
  final String eyebrow;
  final String title;
  final String subtitle;
  final String body;
  final List<Color> gradient;
  final Widget visual;
  _Slide({required this.eyebrow, required this.title, required this.subtitle, required this.body, required this.gradient, required this.visual});
}

class _PageView extends StatelessWidget {
  final _Slide slide;
  const _PageView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(colors: slide.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.7, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (_, v, __) => Transform.scale(scale: v, child: slide.visual),
              ),
              const SizedBox(height: 30),
              Text(slide.eyebrow, style: const TextStyle(color: Colors.white70, letterSpacing: 2, fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 8),
              Text(slide.title, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, height: 1.1), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(slide.subtitle, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(slide.body, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hero: logo over a collage of real community portraits.
class _HeroVisual extends StatelessWidget {
  static const _imgs = ['p1.jpg', 'p2.jpg', 'p3.jpg', 'p4.jpg', 'p5.jpg', 'p6.jpg'];
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          height: 200,
          width: 260,
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            physics: const NeverScrollableScrollPhysics(),
            children: _imgs.map((i) => ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset('assets/images/avatars/$i', fit: BoxFit.cover),
            )).toList(),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 24, offset: const Offset(0, 8))]),
          child: Image.asset('assets/images/masaren_logo_white_256.png', width: 60, height: 60),
        ),
      ],
    );
  }
}

class _VerifyVisual extends StatefulWidget {
  @override
  State<_VerifyVisual> createState() => _VerifyVisualState();
}
class _VerifyVisualState extends State<_VerifyVisual> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  late final Animation<double> _o = Tween(begin: 0.15, end: 0.5).animate(_c);
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Stack(alignment: Alignment.center, children: [
        AnimatedBuilder(animation: _o, builder: (_, __) => Container(width: 80 + _o.value * 70, height: 80 + _o.value * 70, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
        Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.verified_rounded, color: MasarenTheme.green, size: 48)),
      ]),
    );
  }
}

class _CoinVisual extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white30)),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 26),
        SizedBox(width: 10),
        Text('1,250 MRC', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _BadgeVisual extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        BadgeMedallion(badge: UserBadge.topContributor, radius: 28),
        const SizedBox(width: 16),
        BadgeMedallion(badge: UserBadge.sdgChampion, radius: 28),
        const SizedBox(width: 16),
        BadgeMedallion(badge: UserBadge.streak, radius: 28),
      ],
    );
  }
}
