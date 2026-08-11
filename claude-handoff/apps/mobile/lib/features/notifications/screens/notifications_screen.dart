import 'package:flutter/material.dart';
import 'package:masaren/core/theme/masaren_theme.dart';
import 'package:masaren/features/shell/social_app_bar.dart';

/// Social "Alerts" tab. Lists recent platform + social activity (verifications,
/// likes, comments, opportunities). Client-side for the mock build; swaps to a
/// real `/notifications` endpoint when the gateway is live.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const List<Map<String, dynamic>> _items = [
    {'icon': Icons.verified_user_rounded, 'color': MasarenTheme.green, 'title': 'Your solar microgrid evidence was verified', 'sub': 'POAI Crew · confidence 98%', 'time': '2m'},
    {'icon': Icons.favorite_rounded, 'color': MasarenTheme.like, 'title': 'GreenRoots NGO liked your post', 'sub': 'Coastal Restoration update', 'time': '18m'},
    {'icon': Icons.comment_rounded, 'color': MasarenTheme.brand, 'title': 'Yusuf Rahman commented on your impact story', 'sub': '"Proud of this work!"', 'time': '1h'},
    {'icon': Icons.explore_rounded, 'color': MasarenTheme.azure, 'title': 'New opportunity: Clean Water Fellowship', 'sub': 'Open for applications', 'time': '3h'},
    {'icon': Icons.workspace_premium_rounded, 'color': MasarenTheme.gold, 'title': 'You reached GOLD PMS tier', 'sub': 'Composite score 0.812', 'time': '1d'},
    {'icon': Icons.campaign_rounded, 'color': MasarenTheme.green, 'title': 'Your ad campaign delivered 1,204 impressions', 'sub': 'Budget 5,000 MRC', 'time': '1d'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SocialAppBar(title: 'Alerts'),
      body: Container(
        decoration: MasarenTheme.background,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: MasarenTheme.line),
          itemBuilder: (context, i) {
            final it = _items[i];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: (it['color'] as Color).withOpacity(0.12),
                child: Icon(it['icon'] as IconData, color: it['color'] as Color),
              ),
              title: Text(it['title'] as String, style: const TextStyle(color: MasarenTheme.ink, fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text(it['sub'] as String, style: const TextStyle(color: MasarenTheme.muted, fontSize: 12)),
              trailing: Text('${it['time']}', style: const TextStyle(color: MasarenTheme.muted, fontSize: 12)),
            );
          },
        ),
      ),
    );
  }
}



