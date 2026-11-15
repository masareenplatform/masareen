import 'package:flutter/material.dart';
import 'package:masaren/l10n.dart';

/// Distinguishes government, institutional, media, sports and individual
/// authors at a glance. Government uses a gold bank badge; institutions and
/// media use their own colours so the feed reads like a verified ecosystem.
class RoleBadge extends StatelessWidget {
  final String? role;
  const RoleBadge({super.key, this.role});

  @override
  Widget build(BuildContext context) {
    final raw = (role ?? '').trim().toUpperCase();
    if (raw.isEmpty) return const SizedBox.shrink();

    final spec = _spec(raw);
    String label(String key, String fallback) {
      final value = MasarenLocalizations.of(context, key);
      return value == key ? fallback : value;
    }

    final text = switch (raw) {
      'GOVERNMENT' => label('profile.government', 'Government'),
      'MEDIA' => label('profile.mediaInstitution', 'Media'),
      'SPORTS' ||
      'CLUB' ||
      'FEDERATION' ||
      'ATHLETE' =>
        label('profile.sports', 'Sports'),
      'ORGANIZATION' ||
      'INSTITUTION' =>
        label('profile.organization', 'Organization'),
      'ACADEMIC' || 'STUDENT' => label('profile.role.academic', 'Academic'),
      'JOURNALIST' => label('profile.role.journalist', 'Journalist'),
      'PROFESSIONAL' => label('profile.role.professional', 'Professional'),
      'INDIVIDUAL' ||
      'VOLUNTEER' ||
      'DONOR' =>
        label('profile.individual', 'Individual'),
      _ => raw
          .toLowerCase()
          .split('_')
          .map((e) => e.isEmpty ? e : '${e[0].toUpperCase()}${e.substring(1)}')
          .join(' '),
    };

    return Container(
      margin: const EdgeInsetsDirectional.only(start: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: spec.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: spec.color.withValues(alpha: 0.42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(spec.icon, size: 10, color: spec.color),
          const SizedBox(width: 3),
          Text(text,
              style: TextStyle(
                  color: spec.color,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.1)),
        ],
      ),
    );
  }

  _RoleSpec _spec(String role) {
    switch (role) {
      case 'GOVERNMENT':
        return const _RoleSpec(
            Icons.account_balance_outlined, Color(0xFFB08D2E));
      case 'ORGANIZATION':
      case 'INSTITUTION':
        return const _RoleSpec(Icons.apartment_outlined, Color(0xFF2C6E8F));
      case 'UNIVERSITY':
        return const _RoleSpec(
            Icons.account_balance_outlined, Color(0xFF2F5D50));
      case 'RESEARCHER':
        return const _RoleSpec(Icons.science_outlined, Color(0xFF386A8A));
      case 'MEDIA':
        return const _RoleSpec(Icons.newspaper_outlined, Color(0xFF2F6BD8));
      case 'SPORTS':
      case 'CLUB':
      case 'FEDERATION':
      case 'ATHLETE':
        return const _RoleSpec(Icons.sports_soccer_outlined, Color(0xFF2E7D32));
      case 'ACADEMIC':
      case 'STUDENT':
        return const _RoleSpec(Icons.school_outlined, Color(0xFF6A4CB0));
      case 'PROFESSIONAL':
        return const _RoleSpec(Icons.work_outline, Color(0xFF4B5D67));
      case 'JOURNALIST':
        return const _RoleSpec(
            Icons.record_voice_over_outlined, Color(0xFF2F6BD8));
      default:
        return const _RoleSpec(Icons.person_outline, Color(0xFF65746E));
    }
  }
}

class _RoleSpec {
  final IconData icon;
  final Color color;
  const _RoleSpec(this.icon, this.color);
}
