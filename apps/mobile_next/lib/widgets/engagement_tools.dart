import 'package:flutter/material.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';

String _t(BuildContext context, String key, [String? fallback]) {
  final value = MasarenLocalizations.of(context, key);
  return value == key ? (fallback ?? key) : value;
}

/// A horizontal strip of small calculators that makes the feed useful before
/// the first post: impact points, CO2, water and a coin planner.
class ImpactToolsSection extends StatelessWidget {
  const ImpactToolsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            _t(context, 'feed.toolsTitle', 'Tools to grow your impact'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
        SizedBox(
          height: 112,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _ToolCard(
                icon: Icons.bolt_outlined,
                color: AppColors.brand,
                title: _t(context, 'tools.impact', 'Impact points'),
                subtitle: _t(context, 'tools.impactHint',
                    'Estimate points from field work'),
                onTap: () => _showImpactCalculator(context),
              ),
              _ToolCard(
                icon: Icons.eco_outlined,
                color: const Color(0xFF2E7D32),
                title: _t(context, 'tools.co2', 'CO2 saved'),
                subtitle: _t(context, 'tools.co2Hint',
                    'Trees and clean commuting'),
                onTap: () => _showCo2Calculator(context),
              ),
              _ToolCard(
                icon: Icons.water_drop_outlined,
                color: const Color(0xFF2C6E8F),
                title: _t(context, 'tools.water', 'Water saved'),
                subtitle:
                    _t(context, 'tools.waterHint', 'People x days x litres'),
                onTap: () => _showWaterCalculator(context),
              ),
              _ToolCard(
                icon: Icons.toll_outlined,
                color: AppColors.amber,
                title: _t(context, 'tools.coins', 'Coin planner'),
                subtitle: _t(context, 'tools.coinsHint',
                    'Plan your daily reward'),
                onTap: () => _showCoinPlanner(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 168,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 19),
            ),
            const Spacer(),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: cs.onSurface)),
            Text(subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: cs.onSurfaceVariant, fontSize: 10.5, height: 1.2)),
          ],
        ),
      ),
    );
  }
}

/// A short, feature-discovery card injected between feed posts.
class IntroCard extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  final Color color;
  final String cta;
  final VoidCallback onOpen;

  const IntroCard({
    super.key,
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
    required this.cta,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, Colors.black, 0.24)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const Spacer(),
              Text('MASAREEN',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          Text(title,
              textDirection: textDirectionFor(title),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  height: 1.25)),
          const SizedBox(height: 4),
          Text(body,
              textDirection: textDirectionFor(body),
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 12.5,
                  height: 1.4)),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonalIcon(
              onPressed: onOpen,
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: Text(cta),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _sheet(BuildContext context, Widget child) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: child,
      ),
    ),
  );
}

Widget _result(BuildContext context, String label, String value) {
  final cs = Theme.of(context).colorScheme;
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: cs.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
    ),
    child: Column(
      children: [
        Text(label,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: cs.primary,
                fontSize: 28,
                fontWeight: FontWeight.w900)),
      ],
    ),
  );
}

Widget _slider({
  required String label,
  required double value,
  required double min,
  required double max,
  required ValueChanged<double> onChanged,
  String? suffix,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$label: ${value.round()}${suffix ?? ''}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).round().clamp(1, 100),
          onChanged: onChanged),
    ],
  );
}

Future<void> _showImpactCalculator(BuildContext context) async {
  double hours = 8;
  double people = 100;
  bool verified = true;
  await _sheet(
    context,
    StatefulBuilder(
      builder: (context, setSheet) {
        final points = hours * 2 + people * 0.1 + (verified ? 20 : 0);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_t(context, 'tools.impact', 'Impact points'),
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(_t(context, 'tools.impactBody',
                'A quick estimate of the impact points a verified field activity can create.'),
                style: const TextStyle(fontSize: 12.5, height: 1.4)),
            const SizedBox(height: 12),
            _slider(
                label: _t(context, 'tools.hours', 'Hours'),
                value: hours,
                min: 1,
                max: 80,
                onChanged: (v) => setSheet(() => hours = v)),
            _slider(
                label: _t(context, 'tools.people', 'People reached'),
                value: people,
                min: 1,
                max: 2000,
                onChanged: (v) => setSheet(() => people = v)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: verified,
              onChanged: (v) => setSheet(() => verified = v),
              title: Text(_t(context, 'tools.verifiedEvidence',
                  'Verified evidence attached')),
            ),
            _result(
                context,
                _t(context, 'tools.estimatedPoints', 'Estimated impact points'),
                points.toStringAsFixed(0)),
          ],
        );
      },
    ),
  );
}

Future<void> _showCo2Calculator(BuildContext context) async {
  double trees = 20;
  double km = 40;
  await _sheet(
    context,
    StatefulBuilder(
      builder: (context, setSheet) {
        final kg = trees * 21 + km * 0.21;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_t(context, 'tools.co2', 'CO2 saved'),
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(_t(context, 'tools.co2Body',
                'Estimate annual CO2 savings from planting trees and cycling instead of driving.'),
                style: const TextStyle(fontSize: 12.5, height: 1.4)),
            const SizedBox(height: 12),
            _slider(
                label: _t(context, 'tools.trees', 'Trees planted'),
                value: trees,
                min: 0,
                max: 500,
                onChanged: (v) => setSheet(() => trees = v)),
            _slider(
                label: _t(context, 'tools.km', 'Km cycled per week'),
                value: km,
                min: 0,
                max: 500,
                onChanged: (v) => setSheet(() => km = v)),
            _result(
                context,
                _t(context, 'tools.kgCo2', 'Kilograms of CO2 per year'),
                '${kg.toStringAsFixed(0)} kg'),
          ],
        );
      },
    ),
  );
}

Future<void> _showWaterCalculator(BuildContext context) async {
  double people = 100;
  double days = 30;
  double litres = 50;
  await _sheet(
    context,
    StatefulBuilder(
      builder: (context, setSheet) {
        final m3 = people * days * litres / 1000;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_t(context, 'tools.water', 'Water saved'),
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(_t(context, 'tools.waterBody',
                'Estimate the water saved by a conservation or awareness activity.'),
                style: const TextStyle(fontSize: 12.5, height: 1.4)),
            const SizedBox(height: 12),
            _slider(
                label: _t(context, 'tools.people', 'People reached'),
                value: people,
                min: 1,
                max: 2000,
                onChanged: (v) => setSheet(() => people = v)),
            _slider(
                label: _t(context, 'tools.days', 'Days'),
                value: days,
                min: 1,
                max: 365,
                onChanged: (v) => setSheet(() => days = v)),
            _slider(
                label: _t(context, 'tools.litres', 'Litres per person/day'),
                value: litres,
                min: 1,
                max: 200,
                onChanged: (v) => setSheet(() => litres = v)),
            _result(
                context,
                _t(context, 'tools.cubicMetres', 'Cubic metres saved'),
                '${m3.toStringAsFixed(1)} m3'),
          ],
        );
      },
    ),
  );
}

Future<void> _showCoinPlanner(BuildContext context) async {
  double days = 30;
  const daily = 10.0;
  await _sheet(
    context,
    StatefulBuilder(
      builder: (context, setSheet) {
        final coins = days * daily;
        final proDays = (500 / daily).ceil();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_t(context, 'tools.coins', 'Coin planner'),
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
                _t(context, 'tools.coinsBody',
                        'The daily reward is {reward} MRC. Plan how many days you need for a goal.')
                    .replaceAll('{reward}', daily.toStringAsFixed(0)),
                style: const TextStyle(fontSize: 12.5, height: 1.4)),
            const SizedBox(height: 12),
            _slider(
                label: _t(context, 'tools.days', 'Days'),
                value: days,
                min: 1,
                max: 365,
                onChanged: (v) => setSheet(() => days = v)),
            _result(
                context,
                _t(context, 'tools.plannedCoins', 'Coins after this period'),
                '${coins.toStringAsFixed(0)} MRC'),
            const SizedBox(height: 8),
            Text(
                _t(context, 'tools.proIn', 'Pro monthly after {days} days')
                    .replaceAll('{days}', '$proDays'),
                style: const TextStyle(fontSize: 12.5)),
          ],
        );
      },
    ),
  );
}
