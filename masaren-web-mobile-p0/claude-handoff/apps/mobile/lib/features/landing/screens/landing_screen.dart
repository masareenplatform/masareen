import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const kBrand = Color(0xFF2563EB);
const kAccent = Color(0xFF16A34A);

class _CountUp extends StatefulWidget {
  final int end;
  final String suffix;
  final String label;
  const _CountUp({required this.end, this.suffix = '', required this.label});
  @override
  State<_CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<_CountUp> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Column(
        children: [
          Text('${(widget.end * _a.value).round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}${widget.suffix}',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 4),
          Text(widget.label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }
}

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const features = [
      ('Impact Discovery', 'A social feed of verified impact, ranked by outcomes.'),
      ('POAI Verification', 'Every claim scored, audited and traced.'),
      ('Programs & Tasks', 'Launch and complete real programs end-to-end.'),
      ('Evidence & GPS', 'Geo-tagged proof for undeniable impact.'),
      ('MASAREEN Coin', 'An impact economy with transparent fees.'),
      ('Impact Ads', 'Promote verified programs, fraud-resistant.'),
    ];
    const compare = [
      'POAI verified, auditable impact',
      'Real-world outcomes, not vanity metrics',
      'SDG & Egypt 2030 alignment built-in',
      'Brokerage & coin economy for impact',
      'Programs, tasks & evidence workflows',
    ];
    const sdgs = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17];
    const egypt2030 = [
      ('Decent Living', 'Lift communities via verified programs.'),
      ('Digital Egypt', 'Transparent, data-driven impact.'),
      ('Green Economy', 'Climate action at the core of every SDG.'),
      ('Human Capital', 'Skills, health and education by outcomes.'),
    ];

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top bar
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Row(
                  children: [
                    Image.asset('assets/images/masaren_logo_48.png', width: 34, height: 34),
                    const SizedBox(width: 8),
                    const Text('MASAREEN', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
                    const Spacer(),
                    TextButton(onPressed: () => context.go('/login'), child: const Text('Sign in', style: TextStyle(color: Colors.white))),
                    ElevatedButton(
                      onPressed: () => context.go('/login'),
                      style: ElevatedButton.styleFrom(backgroundColor: kAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      child: const Text('Get the app'),
                    ),
                  ],
                ),
              ),
            ),
            // Hero
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [kBrand, kAccent], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('The professional network for', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
                  const Text('real-world impact.', style: TextStyle(color: Color(0xFFEAFFF0), fontSize: 30, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  const Text('Prove, track and scale change that actually happened. POAI checks the claims, and it lines up with the UN goals and Egypt Vision 2030.',
                      style: TextStyle(color: Colors.white70, fontSize: 15)),
                  const SizedBox(height: 18),
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    ElevatedButton.icon(
                      onPressed: () => context.go('/login'),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Download for Android'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: kBrand, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                    OutlinedButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Open web app', style: TextStyle(color: Colors.white)),
                    ),
                  ]),
                  const SizedBox(height: 26),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: const [
                    _CountUp(end: 128000, label: 'Verified actions'),
                    _CountUp(end: 8400, suffix: '+', label: 'Alpha members'),
                    _CountUp(end: 17, label: 'SDGs tracked'),
                    _CountUp(end: 36, label: 'Countries'),
                  ]),
                ],
              ),
            ),
            // Why MASAREEN
            _Section(title: 'Why MASAREEN', child: ListView.separated(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              itemCount: compare.length, separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => ListTile(
                leading: const Icon(Icons.verified_rounded, color: kAccent),
                title: Text(compare[i], style: const TextStyle(color: Colors.white, fontSize: 14)),
              ),
            )),
            // Features
            _Section(title: 'Everything impact teams need', child: GridView.count(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, childAspectRatio: 1.4,
              children: features.map((f) => Container(
                margin: const EdgeInsets.all(6), padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF16294F), borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f.$1, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(f.$2, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ]),
              )).toList(),
            )),
            // SDG + Egypt 2030
            _Section(title: 'Aligned with UN SDGs & Egypt Vision 2030', child: Column(children: [
              Wrap(spacing: 8, runSpacing: 8, children: sdgs.map((n) => Container(
                width: 40, height: 40, decoration: BoxDecoration(gradient: const LinearGradient(colors: [kBrand, kAccent]), borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text('$n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
              )).toList()),
              const SizedBox(height: 12),
              GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, childAspectRatio: 2.2,
                children: egypt2030.map((e) => Container(margin: const EdgeInsets.all(6), padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF16294F), borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.$1, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                    Text(e.$2, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                  ]))).toList()),
            ])),
            // Download CTA
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [kBrand, kAccent])),
              padding: const EdgeInsets.all(28),
              child: Column(children: [
                const Text('Join the alpha. Download MASAREEN.', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text('Free during alpha. Enable “Install unknown apps” for your browser, then tap the APK.', style: TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
                const SizedBox(height: 14),
                ElevatedButton.icon(onPressed: () => context.go('/login'), icon: const Icon(Icons.download_rounded), label: const Text('Download APK (Android)'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: kBrand, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ]),
            ),
            const Padding(padding: EdgeInsets.all(16), child: Text('© 2026 MASAREEN · POAI Verification · Aligned with UN SDGs & Egypt Vision 2030', style: TextStyle(color: Colors.white38, fontSize: 11))),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}



