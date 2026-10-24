import 'package:flutter/material.dart';
import 'package:masaren/core/theme/masaren_theme.dart';
import 'package:masaren/features/shell/social_app_bar.dart';
import 'package:masaren/di/injection.dart';
import 'package:masaren/services/api_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SocialAppBar(title: 'Dashboard'),
      body: Container(
        decoration: MasarenTheme.background,
        child: FutureBuilder<Map<String, dynamic>>(
          future: getIt<ApiService>().getDashboardStats(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: MasarenTheme.green));
            } else if (snapshot.hasError) {
              return Center(child: Text('Error loading stats: ${snapshot.error}', style: const TextStyle(color: MasarenTheme.ink)));
            } else if (!snapshot.hasData) {
              return const Center(child: Text('No stats available.', style: TextStyle(color: MasarenTheme.muted)));
            }

            final stats = snapshot.data!;
            final platform = (stats['platform'] as Map<String, dynamic>?) ?? {};
            final me = (stats['me'] as Map<String, dynamic>?) ?? {};
            final userStats = (stats['user_stats'] as Map<String, dynamic>?) ?? {};
            final pms = (stats['pms'] as Map<String, dynamic>?) ?? {};
            final fullName = me['full_name']?.toString() ?? 'Builder';
            final composite = ((pms['composite_score'] as num?) ?? 0) * 100;
            final tier = (pms['tier']?.toString() ?? '-').toUpperCase();

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text('Welcome, $fullName', style: const TextStyle(color: MasarenTheme.ink, fontSize: 22, fontWeight: FontWeight.w800)),
                  Text('Your impact, measured.', style: const TextStyle(color: MasarenTheme.muted, fontSize: 14)),
                  const SizedBox(height: 18),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      children: [
                        _StatCard(icon: Icons.people, label: 'Members', value: _fmt(platform['total_users']), color: MasarenTheme.navyLight),
                        _StatCard(icon: Icons.explore, label: 'Active programs', value: _fmt(platform['active_programs']), color: MasarenTheme.gold),
                        _StatCard(icon: Icons.verified, label: 'Verified tasks', value: _fmt(platform['verified_tasks']), color: MasarenTheme.green),
                        _StatCard(icon: Icons.attach_money, label: 'Impact (USD)', value: _fmt(platform['total_economic_value_usd']), color: MasarenTheme.greenLight),
                        _StatCard(icon: Icons.task_alt, label: 'Your tasks', value: _fmt(userStats['tasks']), color: MasarenTheme.navyLight),
                        _StatCard(icon: Icons.workspace_premium, label: 'PMS tier', value: '$tier\n${composite.round()}', color: MasarenTheme.gold),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static String _fmt(dynamic v) {
    if (v == null) return '0';
    if (v is num) return v.toInt().toString();
    return v.toString();
  }

}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: MasarenTheme.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withOpacity(0.3))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(value, textAlign: TextAlign.center, style: TextStyle(color: MasarenTheme.ink, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: MasarenTheme.muted, fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}



