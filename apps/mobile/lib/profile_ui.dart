import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:masaren/services/share_policy.dart';

Future<void> copyProfileLink(
    BuildContext context, String id, String confirmation,
    {required bool verified}) async {
  await SharePolicy.copyProfile(context,
      allowed: verified, id: id, confirmation: confirmation);
}

Future<void> copyProfileText(
    BuildContext context, String text, String confirmation) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(confirmation)));
}

class ProfileColors {
  static const night = Color(0xFF0B1714);
  static const forest = Color(0xFF123B33);
  static const emerald = Color(0xFF146B59);
  static const gold = Color(0xFFC7A15A);
  static const sand = Color(0xFFF4EFE4);
  static const paper = Color(0xFFFBFAF7);
  static const mist = Color(0xFFE8EFEA);
  static const slate = Color(0xFF5B6B65);
  static const rose = Color(0xFFA8514A);
  static const petrol = Color(0xFF1E3A44);
  static const graphite = Color(0xFF202B27);
}

class ProfileTone {
  final Color start;
  final Color end;
  final Color accent;
  final Color soft;
  const ProfileTone(this.start, this.end, this.accent, this.soft);
}

ProfileTone profileTone(String kind) {
  switch (kind.toLowerCase()) {
    case 'government':
      return const ProfileTone(ProfileColors.night, Color(0xFF153C3A),
          ProfileColors.gold, Color(0xFFEAF0EC));
    case 'sports':
    case 'player':
      return const ProfileTone(ProfileColors.night, Color(0xFF243A2E),
          ProfileColors.gold, Color(0xFFEDF1E9));
    case 'media':
      return const ProfileTone(ProfileColors.night, ProfileColors.petrol,
          Color(0xFF9BC7C9), Color(0xFFE8F0F0));
    case 'organization':
    case 'institution':
      return const ProfileTone(ProfileColors.forest, ProfileColors.emerald,
          ProfileColors.gold, Color(0xFFE8EFEA));
    case 'university':
      return const ProfileTone(ProfileColors.night, Color(0xFF2F5D50),
          ProfileColors.gold, Color(0xFFE8EFEA));
    default:
      return const ProfileTone(ProfileColors.night, Color(0xFF294B40),
          ProfileColors.gold, Color(0xFFEAF0EC));
  }
}

class ProfileStat {
  final String value;
  final String label;
  final IconData? icon;
  const ProfileStat(this.value, this.label, {this.icon});
}

class ProfileHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final String kind;
  final IconData icon;
  final String? imageUrl;
  final String? coverUrl;
  final Widget? badge;
  final List<ProfileStat> stats;
  final VoidCallback? onBack;
  final VoidCallback? onShare;
  final bool showChrome;
  final Widget? trailing;

  const ProfileHero({
    super.key,
    required this.title,
    required this.subtitle,
    this.kind = 'individual',
    this.icon = Icons.person_outline,
    this.imageUrl,
    this.coverUrl,
    this.badge,
    this.stats = const [],
    this.onBack,
    this.onShare,
    this.showChrome = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final tone = profileTone(kind);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: ProfileColors.night.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [tone.start, tone.end],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            if (coverUrl != null && coverUrl!.isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  coverUrl!,
                  fit: BoxFit.cover,
                  opacity: const AlwaysStoppedAnimation(0.2),
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            Positioned(
              top: -50,
              right: rtl ? null : -40,
              left: rtl ? -40 : null,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: tone.accent.withValues(alpha: 0.22), width: 1),
                ),
              ),
            ),
            Positioned(
              bottom: -70,
              left: rtl ? null : -50,
              right: rtl ? -50 : null,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tone.accent.withValues(alpha: 0.06),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showChrome)
                    Row(
                      children: [
                        _HeroButton(
                          icon: rtl
                              ? Icons.arrow_forward_ios_rounded
                              : Icons.arrow_back_ios_new_rounded,
                          onTap: onBack ?? () => Navigator.maybePop(context),
                        ),
                        const Spacer(),
                        if (trailing != null) trailing!,
                        if (onShare != null)
                          _HeroButton(
                              icon: Icons.ios_share_rounded, onTap: onShare!),
                      ],
                    ),
                  SizedBox(height: showChrome ? 18 : 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 86,
                        height: 86,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                              color: tone.accent.withValues(alpha: 0.8),
                              width: 1.5),
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: imageUrl != null && imageUrl!.isNotEmpty
                              ? Image.network(
                                  imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _HeroIcon(icon: icon, tone: tone),
                                )
                              : _HeroIcon(icon: icon, tone: tone),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 23,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.68),
                                fontSize: 12.5,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (badge != null) ...[
                              const SizedBox(height: 10),
                              badge!,
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (stats.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.09)),
                      ),
                      child: Row(
                        children: [
                          for (var i = 0; i < stats.length; i++) ...[
                            if (i > 0)
                              Container(
                                width: 1,
                                height: 28,
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            Expanded(child: _HeroStat(stat: stats[i])),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroIcon extends StatelessWidget {
  final IconData icon;
  final ProfileTone tone;
  const _HeroIcon({required this.icon, required this.tone});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withValues(alpha: 0.06),
      alignment: Alignment.center,
      child: Icon(icon, color: tone.accent, size: 34),
    );
  }
}

class _HeroButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeroButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.09),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final ProfileStat stat;
  const _HeroStat({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (stat.icon != null) ...[
              Icon(stat.icon, size: 13, color: ProfileColors.gold),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                stat.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          stat.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 9.5,
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class ProfilePill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  const ProfilePill({super.key, required this.label, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final tone = color ?? ProfileColors.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: tone),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: tone, fontSize: 10.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration profilePanel(BuildContext context, {double radius = 20}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: dark ? const Color(0xFF15201C) : ProfileColors.paper,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
        color: dark ? const Color(0xFF2E3B36) : const Color(0xFFE4E7E1)),
    boxShadow: [
      BoxShadow(
        color: ProfileColors.night.withValues(alpha: dark ? 0.2 : 0.04),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

class ProfileSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const ProfileSectionHeader(
      {super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 3,
            height: 18,
            margin: const EdgeInsetsDirectional.only(end: 9),
            decoration: BoxDecoration(
              color: ProfileColors.gold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!,
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 11.5)),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class ProfileActionBar extends StatelessWidget {
  final List<Widget> children;
  const ProfileActionBar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(children: children),
    );
  }
}

ButtonStyle profilePrimaryStyle({Color? color}) => FilledButton.styleFrom(
      backgroundColor: color ?? ProfileColors.forest,
      foregroundColor: Colors.white,
      elevation: 0,
      minimumSize: const Size.fromHeight(44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
    );

ButtonStyle profileSecondaryStyle(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return OutlinedButton.styleFrom(
    foregroundColor: dark ? Colors.white : ProfileColors.forest,
    minimumSize: const Size.fromHeight(44),
    side: BorderSide(
        color: dark ? const Color(0xFF2E3B36) : const Color(0xFFD8DED8)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
  );
}
