import 'package:flutter/material.dart';
import 'package:masaren/core/theme/masaren_theme.dart';
import 'package:masaren/core/models/opportunity_model.dart';
import 'package:masaren/services/api_service.dart';
import 'package:masaren/di/injection.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:masaren/core/widgets/spacing.dart';

class OpportunitiesScreen extends StatelessWidget {
  const OpportunitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Opportunities')),
      body: FutureBuilder<List<OpportunityModel>>(
        future: getIt<ApiService>().getOpportunities(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error loading opportunities: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No opportunities found.'));
          }

          final opportunities = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: opportunities.length,
            itemBuilder: (context, index) {
              final opp = opportunities[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 60,
                        decoration: BoxDecoration(
                          color: index % 3 == 0 ? MasarenTheme.gold : MasarenTheme.navyLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(opp.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('Min PMS: ${opp.minPmsScore}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                            constHBox(height: 6),
                            Row(
                              children: [
                                Chip(label: Text(opp.status, style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact, backgroundColor: MasarenTheme.ivory),
                                const SizedBox(width: 8),
                                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text('Due: ${opp.deadline ?? 'N/A'}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              ],
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final userId = await getIt<FlutterSecureStorage>().read(key: 'user_id') ?? "";
                          try {
                            await getIt<ApiService>().applyToOpportunity(opp.id, userId);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Application submitted successfully!')),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Application failed: ${e.toString()}')),
                            );
                          }
                        },
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}




