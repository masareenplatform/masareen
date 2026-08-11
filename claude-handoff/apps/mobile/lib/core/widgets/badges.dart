import 'package:flutter/material.dart';
import '../../core/theme/masaren_theme.dart';

class UserBadge {
  final String id;
  final String label;
  final IconData icon;
  final List<Color> gradient;

  const UserBadge({
    required this.id,
    required this.label,
    required this.icon,
    required this.gradient,
  });

  static const verified = UserBadge(
    id: 'verified',
    label: 'POAI Verified',
    icon: Icons.verified_rounded,
    gradient: [MasarenTheme.azure, MasarenTheme.green],
  );

  static const topContributor = UserBadge(
    id: 'top',
    label: 'Top Contributor',
    icon: Icons.emoji_events_rounded,
    gradient: [Color(0xFFF59E0B), Color(0xFFEF4444)],
  );

  static const sdgChampion = UserBadge(
    id: 'sdg',
    label: 'SDG Champion',
    icon: Icons.public_rounded,
    gradient: [Color(0xFF8B5CF6), Color(0xFF2563EB)],
  );

  static const earlyAdopter = UserBadge(
    id: 'early',
    label: 'Alpha Pioneer',
    icon: Icons.rocket_launch_rounded,
    gradient: [Color(0xFF10B981), Color(0xFF06B6D4)],
  );

  static const streak = UserBadge(
    id: 'streak',
    label: '30-Day Streak',
    icon: Icons.local_fire_department_rounded,
    gradient: [Color(0xFFFB7185), Color(0xFFF97316)],
  );

  static const curator = UserBadge(
    id: 'curator',
    label: 'Impact Curator',
    icon: Icons.auto_awesome_rounded,
    gradient: [Color(0xFF6366F1), Color(0xFFA855F7)],
  );

  static List<UserBadge> demoFor(String name) {
    final all = [verified, topContributor, sdgChampion, earlyAdopter, streak, curator];
    final hash = name.hashCode.abs();
    final count = 3 + (hash % 3);
    return all.take(count).toList();
  }
}

class BadgeChip extends StatelessWidget {
  final UserBadge badge;
  final double size;
  const BadgeChip({super.key, required this.badge, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: badge.gradient),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(color: badge.gradient.last.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badge.icon, size: size - 8, color: Colors.white),
          const Screws(),
          Text(badge.label, style: TextStyle(color: Colors.white, fontSize: size - 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class Screws extends StatelessWidget {
  const Screws();
  @override
  Widget build(BuildContext context) => const SizedBox(width: 5);
}

class BadgeRow extends StatelessWidget {
  final List<UserBadge> badges;
  final bool wrap;
  const BadgeRow({super.key, required this.badges, this.wrap = true});

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
      return const Text('No badges yet. Share some impact to earn your first one.',
          style: TextStyle(color: MasarenTheme.muted, fontSize: 13));
    }
    final children = badges.map((b) => BadgeChip(badge: b)).toList();
    if (!wrap) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [for (final c in children) Padding(padding: const EdgeInsets.only(right: 8), child: c)]),
      );
    }
    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }
}

class BadgeMedallion extends StatelessWidget {
  final UserBadge badge;
  final double radius;
  const BadgeMedallion({super.key, required this.badge, this.radius = 26});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: badge.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: badge.gradient.last.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Icon(badge.icon, color: Colors.white, size: radius),
    );
  }
}



