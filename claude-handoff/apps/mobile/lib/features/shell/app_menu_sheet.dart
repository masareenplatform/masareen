import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:masaren/core/theme/masaren_theme.dart';

/// Social-style overflow sheet (the "≡"/"⋯" menu) that exposes the secondary
/// MASAREEN surfaces that don't live on the bottom navigation bar, exactly how
/// Instagram/LinkedIn tuck settings & tools behind a single menu.
class AppMenuSheet extends StatelessWidget {
  const AppMenuSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MasarenTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const AppMenuSheet(),
    );
  }

  static const List<_MenuItem> _items = [
    _MenuItem(icon: Icons.person_outlined, label: 'Profile', route: '/profile'),
    _MenuItem(icon: Icons.dashboard_outlined, label: 'Dashboard', route: '/dashboard'),
    _MenuItem(icon: Icons.groups_outlined, label: 'Programs', route: '/programs'),
    _MenuItem(icon: Icons.verified_user_outlined, label: 'Evidence', route: '/evidence'),
    _MenuItem(icon: Icons.badge_outlined, label: 'Impact Passport', route: '/passport'),
    _MenuItem(icon: Icons.handshake_outlined, label: 'Collaborate', route: '/collaborate'),
    _MenuItem(icon: Icons.account_balance_wallet_outlined, label: 'MASAREEN Coin', route: '/wallet'),
    _MenuItem(icon: Icons.campaign_outlined, label: 'Ads Manager', route: '/ads'),
    _MenuItem(icon: Icons.payment_outlined, label: 'Payments', route: '/payments'),
    _MenuItem(icon: Icons.money_outlined, label: 'Platform Revenue & Fees', route: '/admin/revenue'),
    _MenuItem(icon: Icons.settings_outlined, label: 'Settings', route: '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: MasarenTheme.line, borderRadius: BorderRadius.circular(999)),
              ),
              Text('MASAREEN Tools',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: MasarenTheme.ink, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._items.map((it) => ListTile(
                    leading: Icon(it.icon, color: MasarenTheme.brand),
                    title: Text(it.label, style: const TextStyle(color: MasarenTheme.ink)),
                    trailing: const Icon(Icons.chevron_right, color: MasarenTheme.muted),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onTap: () {
                      Navigator.pop(context);
                      context.push(it.route);
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String route;
  const _MenuItem({required this.icon, required this.label, required this.route});
}



