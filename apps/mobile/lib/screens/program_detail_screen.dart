import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/models.dart';

class ProgramDetailScreen extends StatefulWidget {
  final String programId;
  const ProgramDetailScreen({super.key, required this.programId});

  @override
  State<ProgramDetailScreen> createState() => _ProgramDetailScreenState();
}

class _ProgramDetailScreenState extends State<ProgramDetailScreen> {
  Program? _program;
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await AuthApi.programDetail(widget.programId);
      _data = data;
      _program = Program.fromJson(data);
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _enroll() async {
    if (_program == null) return;
    setState(() => _busy = true);
    try {
      await AuthApi.enrollProgram(_program!.id, userId: AuthApi.userId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('You joined the program')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _program == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorView(message: _error ?? 'Not found', onRetry: _load),
      );
    }
    final p = _program!;
    final tasks = (_data!['tasks'] as List?) ?? [];
    final projects = (_data!['projects'] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(title: Text(p.title)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            Container(
              height: 120,
              decoration: const BoxDecoration(gradient: brandGradient),
              child: const Center(
                  child: Icon(Icons.hub, size: 48, color: Colors.white)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                  if (p.organization != null) ...[
                    const SizedBox(height: 4),
                    Text(p.organization!,
                        style: const TextStyle(
                            color: AppColors.azure, fontSize: 13)),
                  ],
                  const SizedBox(height: 8),
                  if (p.description != null)
                    Text(p.description!,
                        style: const TextStyle(
                            color: AppColors.muted, height: 1.5)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (p.sdg != null)
                        Chip(
                            label: Text('SDG ${p.sdg}',
                                style:
                                    const TextStyle(color: AppColors.accent))),
                      if (p.members != null)
                        Chip(
                            label: Text('${p.members} members',
                                style:
                                    const TextStyle(color: AppColors.azure))),
                      if (p.projectsCount > 0)
                        Chip(label: Text('${p.projectsCount} projects')),
                      if (p.tasksCount > 0)
                        Chip(label: Text('${p.tasksCount} tasks')),
                      Chip(
                          label: Text(p.status ?? '',
                              style: const TextStyle(color: Colors.white))),
                    ],
                  ),
                  const SizedBox(height: 18),
                  gradientButton(
                    label: p.enrolledByMe
                        ? 'You are a member'
                        : (_busy ? 'Joining...' : 'Join this program'),
                    onPressed: _busy || p.enrolledByMe ? () {} : _enroll,
                  ),
                ],
              ),
            ),
            if (projects.isNotEmpty) ...[
              const SectionTitle(title: 'Projects'),
              ...projects.map((x) => _projectCard(x as Map<String, dynamic>)),
            ],
            if (tasks.isNotEmpty) ...[
              const SectionTitle(title: 'Tasks & evidence'),
              ...tasks.map((t) => _taskCard(t as Map<String, dynamic>)),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _projectCard(Map<String, dynamic> x) {
    final goal = (x['goal'] is num) ? (x['goal'] as num).toDouble() : 0.0;
    final raised = (x['raised'] is num) ? (x['raised'] as num).toDouble() : 0.0;
    final pct = goal > 0 ? (raised / goal).clamp(0.0, 1.0) : 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.handshake, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(x['title']?.toString() ?? 'Project',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                Text('${x['members'] ?? 0} members',
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 12)),
              ],
            ),
            if (x['description'] != null) ...[
              const SizedBox(height: 6),
              Text(x['description'].toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ],
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  backgroundColor: AppColors.darkSurface2),
            ),
            const SizedBox(height: 4),
            Text('${raised.toInt()} / ${goal.toInt()} EGP',
                style:
                    const TextStyle(color: AppColors.muted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _taskCard(Map<String, dynamic> t) {
    final status = (t['status'] ?? 'OPEN').toString().toUpperCase();
    final done = status == 'VERIFIED';
    return Card(
      child: ListTile(
        leading: Icon(done ? Icons.check_circle : Icons.task_alt,
            color: done ? AppColors.accent : AppColors.amber),
        title: Text(t['title']?.toString() ?? 'Task'),
        subtitle: Text(
          [
            status,
            if (t['assignee_name'] != null) 'Assigned to ${t['assignee_name']}',
            if (t['due_at'] != null) 'Due ${t['due_at'].toString().split('T').first}',
          ].join(' - '),
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        trailing: t['evidence_required'] == true
            ? const Tooltip(
                message: 'Evidence required',
                child: Icon(Icons.photo_camera_outlined,
                    color: AppColors.azure))
            : null,
      ),
    );
  }
}
