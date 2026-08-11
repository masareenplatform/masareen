import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:masaren/core/theme/masaren_theme.dart';

class TaskDetailScreen extends StatelessWidget {
  final Map<String, dynamic>? task;
  const TaskDetailScreen({super.key, this.task});

  @override
  Widget build(BuildContext context) {
    final t = task ?? {'title': 'Unknown Task', 'status': 'N/A', 'priority': 'N/A'};

    return Scaffold(
      appBar: AppBar(title: Text(t['title'] as String)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: MasarenTheme.gold,
                child: const Icon(Icons.assignment, size: 40, color: MasarenTheme.navyDark),
              ),
            ),
            const SizedBox(height: 24),
            Text(t['title'] as String, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            _InfoRow(label: 'Status', value: t['status'] as String),
            const SizedBox(height: 8),
            _InfoRow(label: 'Priority', value: t['priority'] as String),
            const SizedBox(height: 8),
            _InfoRow(label: 'Assigned To', value: 'Current User'),
            const SizedBox(height: 24),
            const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Complete the assigned tasks and submit evidence through the platform.'),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Tasks'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 100, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600))),
        Expanded(child: Text(value)),
      ],
    );
  }
}



