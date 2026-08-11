import 'package:flutter/material.dart';
import 'package:masaren/core/theme/masaren_theme.dart';
import 'package:masaren/core/models/profile_model.dart';
import 'package:masaren/services/api_service.dart';
import 'package:masaren/di/injection.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ImpactPassportScreen extends StatelessWidget {
  const ImpactPassportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Impact Passport')),
      body: FutureBuilder<ProfileModel>(
        future: (() async {
          final uid = await getIt<FlutterSecureStorage>().read(key: 'user_id') ?? '';
          return getIt<ApiService>().getProfile(uid);
        })(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error loading passport: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('No passport data.'));
          }

          final profile = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: MasarenTheme.navy,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.qr_code, size: 80, color: MasarenTheme.navyDark),
                      ),
                      const SizedBox(height: 16),
                      const Text('MASAREEN PASSPORT', style: TextStyle(color: MasarenTheme.gold, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
                      const SizedBox(height: 4),
                      Text(profile.fullName, style: TextStyle(color: Colors.white, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text('ID: ${profile.id}', style: TextStyle(color: Colors.white60, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _Badge(icon: Icons.emoji_events, label: 'Community Champion', desc: 'Led 5 community events', color: MasarenTheme.gold),
                _Badge(icon: Icons.forest, label: 'Environmental Steward', desc: 'Planted 50+ trees', color: Colors.green),
                _Badge(icon: Icons.school, label: 'Skills Builder', desc: 'Completed 10 workshops', color: MasarenTheme.navyLight),
              ],
            ),
          );
        },
      ),
    );
  }

}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String desc;
  final Color color;
  const _Badge({required this.icon, required this.label, required this.desc, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color, child: Icon(icon, color: Colors.white)),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(desc),
      ),
    );
  }
}



