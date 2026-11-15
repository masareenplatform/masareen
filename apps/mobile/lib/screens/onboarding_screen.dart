import 'package:flutter/material.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  final _pages = const [
    _OnboardPageData(
      icon: Icons.shield_outlined,
      titleKey: 'onboarding.verifyTitle',
      subtitleKey: 'onboarding.verifySubtitle',
      gradient: [Color(0xFF1A73E8), Color(0xFF4285F4)],
    ),
    _OnboardPageData(
      icon: Icons.route,
      titleKey: 'onboarding.pathsTitle',
      subtitleKey: 'onboarding.pathsSubtitle',
      gradient: [Color(0xFF34A853), Color(0xFF0F9D58)],
    ),
    _OnboardPageData(
      icon: Icons.token,
      titleKey: 'onboarding.coinTitle',
      subtitleKey: 'onboarding.coinSubtitle',
      gradient: [Color(0xFFF4B400), Color(0xFFE37400)],
    ),
    _OnboardPageData(
      icon: Icons.public,
      titleKey: 'onboarding.portableTitle',
      subtitleKey: 'onboarding.portableSubtitle',
      gradient: [Color(0xFFEA4335), Color(0xFFD33426)],
    ),
  ];

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? AppColors.darkBg : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: widget.onComplete,
                child: Text(MasarenLocalizations.of(context, 'onboarding.skip'),
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: p.gradient),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(p.icon, color: Colors.white, size: 56),
                        ),
                        const SizedBox(height: 40),
                        Text(MasarenLocalizations.of(context, p.titleKey),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            )),
                        const SizedBox(height: 16),
                        Text(MasarenLocalizations.of(context, p.subtitleKey),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: cs.onSurfaceVariant,
                            )),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
              child: Row(
                children: [
                  Row(
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 8),
                        width: i == _page ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page ? cs.primary : cs.outlineVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(56, 56),
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero,
                    ),
                    child: Icon(
                      _page < _pages.length - 1
                          ? Icons.arrow_forward
                          : Icons.check,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardPageData {
  final IconData icon;
  final String titleKey;
  final String subtitleKey;
  final List<Color> gradient;
  const _OnboardPageData({
    required this.icon,
    required this.titleKey,
    required this.subtitleKey,
    required this.gradient,
  });
}
