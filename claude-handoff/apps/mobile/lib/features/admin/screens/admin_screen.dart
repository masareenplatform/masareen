import 'package:flutter/material.dart';
import 'package:masaren/services/api_service.dart';
import 'package:masaren/di/injection.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final ApiService _api = getIt<ApiService>();

  void _handleApproval(String id, String verdict) async {
    try {
      await _api.approveVerification(id, verdict, "Approved via Mobile Admin");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verdict $verdict submitted for $id')));
      setState(() {}); // Refresh list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Approval Panel')),
      body: FutureBuilder<List<String>>(
        future: _api.getPendingApprovals(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No pending approvals.'));
          }

          final pendingIds = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pendingIds.length,
            itemBuilder: (context, index) {
              final id = pendingIds[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  title: Text('Evidence ID: $id'),
                  subtitle: const Text('Requires HITL Approval'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () => _handleApproval(id, 'APPROVED'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: () => _handleApproval(id, 'REJECTED'),
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




