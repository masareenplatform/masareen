import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:masaren/core/theme/masaren_theme.dart';
import 'package:masaren/core/models/task_model.dart';
import 'package:masaren/services/api_service.dart';
import 'package:masaren/di/injection.dart';

class TaskListScreen extends StatelessWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Color statusColor(String s) {
      if (s == 'Completed') return Colors.green;
      if (s == 'In Progress') return MasarenTheme.gold;
      return Colors.orange;
    }

    Color priorityColor(String p) {
      if (p == 'High') return Colors.red;
      if (p == 'Medium') return MasarenTheme.gold;
      return Colors.grey;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Tasks')),
      body: FutureBuilder<List<TaskModel>>(
        future: getIt<ApiService>().getTasks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No tasks found.'));
          }

          final tasks = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final t = tasks[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: t.status == 'Completed' ? Colors.green : MasarenTheme.gold,
                    child: Icon(t.status == 'Completed' ? Icons.check : Icons.assignment, color: Colors.white),
                  ),
                  title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Row(
                    children: [
                      Chip(label: Text(t.status, style: TextStyle(fontSize: 11, color: statusColor(t.status))), visualDensity: VisualDensity.compact),
                      const SizedBox(width: 6),
                      Chip(label: Text(t.priority, style: TextStyle(fontSize: 11, color: priorityColor(t.priority))), visualDensity: VisualDensity.compact),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/tasks/detail', extra: t),
                ),
              );
            },
          );
        },
      ),
    );
  }
}




