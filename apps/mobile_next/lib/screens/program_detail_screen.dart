import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/screens/task_detail_screen.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/widgets/animations.dart';

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

  Future<void> _toggleEnroll() async {
    final p = _program;
    if (p == null || _busy) return;
    setState(() => _busy = true);
    try {
      if (p.enrolledByMe) {
        await AuthApi.leaveProgram(p.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(MasarenLocalizations.of(context, 'program.left'))));
        }
      } else {
        await AuthApi.enrollProgram(p.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text(MasarenLocalizations.of(context, 'program.joined'))));
        }
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(MasarenLocalizations.of(context, 'common.failed')
                .replaceAll('{error}', '$e'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showMembers() async {
    try {
      final members = await AuthApi.programMembers(widget.programId);
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (c) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          builder: (_, controller) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  MasarenLocalizations.of(context, 'program.membersTitle'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              Expanded(
                child: members.isEmpty
                    ? Center(
                        child: Text(
                            MasarenLocalizations.of(
                                context, 'program.noMembers'),
                            style: const TextStyle(color: AppColors.muted)))
                    : ListView.builder(
                        controller: controller,
                        itemCount: members.length,
                        itemBuilder: (_, i) {
                          final m = members[i];
                          return ListTile(
                            leading: AppAvatar(
                                name: m['name']?.toString() ?? 'M',
                                url: m['picture']?.toString(),
                                size: 36),
                            title: Text(m['name']?.toString() ?? 'Member'),
                            subtitle: Text(
                                MasarenLocalizations.of(
                                        context, 'program.roleLabel')
                                    .replaceAll('{role}',
                                        m['program_role'] ?? 'MEMBER'),
                                style: const TextStyle(
                                    color: AppColors.muted, fontSize: 12)),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(MasarenLocalizations.of(context, 'common.failed')
                .replaceAll('{error}', '$e'))));
      }
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
        body: ErrorView(
            message:
                _error ?? MasarenLocalizations.of(context, 'program.notFound'),
            onRetry: _load),
      );
    }
    final p = _program!;
    final tasks = (_data!['tasks'] as List?) ?? [];
    final projects = (_data!['projects'] as List?) ?? [];
    final verifiedTasks =
        tasks.where((t) => (t['status'] ?? '') == 'VERIFIED').length;
    final taskPct = tasks.isEmpty ? 0.0 : verifiedTasks / tasks.length;
    final location = [p.country, p.governorate]
        .whereType<String>()
        .where((v) => v.isNotEmpty)
        .join(', ');
    return Scaffold(
      appBar: AppBar(title: Text(p.title)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                            label: Text(
                                MasarenLocalizations.of(context, 'program.sdg')
                                    .replaceAll('{sdg}', '${p.sdg}'),
                                style:
                                    const TextStyle(color: AppColors.accent))),
                      if (p.members != null)
                        Chip(
                            label: Text(
                                MasarenLocalizations.of(
                                        context, 'program.membersCount')
                                    .replaceAll('{count}', '${p.members}'),
                                style:
                                    const TextStyle(color: AppColors.azure))),
                      if (p.projectsCount > 0)
                        Chip(
                            label: Text(MasarenLocalizations.of(
                                    context, 'program.projectsCount')
                                .replaceAll('{count}', '${p.projectsCount}'))),
                      if (p.tasksCount > 0)
                        Chip(
                            label: Text(MasarenLocalizations.of(
                                    context, 'program.tasksCount')
                                .replaceAll('{count}', '${p.tasksCount}'))),
                      Chip(
                          label: Text(_statusLabel(context, p.status),
                              style: const TextStyle(color: Colors.white))),
                    ],
                  ),
                  if (location.isNotEmpty || p.startDate != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined,
                            size: 16, color: AppColors.muted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            [
                              location,
                              if (p.startDate != null)
                                '${p.startDate!.split('T').first}'
                                    '${p.endDate != null ? ' - ${p.endDate!.split('T').first}' : ''}',
                            ].where((v) => v.isNotEmpty).join('  ·  '),
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (tasks.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                                value: taskPct,
                                minHeight: 6,
                                backgroundColor: AppColors.darkSurface2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                            MasarenLocalizations.of(context, 'program.progress')
                                .replaceAll('{done}', '$verifiedTasks')
                                .replaceAll('{total}', '${tasks.length}'),
                            style: const TextStyle(
                                color: AppColors.accent, fontSize: 12)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  gradientButton(
                    label: p.enrolledByMe
                        ? MasarenLocalizations.of(context, 'program.leave')
                        : (_busy
                            ? MasarenLocalizations.of(
                                context, 'program.joining')
                            : MasarenLocalizations.of(context, 'program.join')),
                    onPressed: _busy ? () {} : _toggleEnroll,
                  ),
                ],
              ),
            ),
            if (projects.isNotEmpty) ...[
              SectionTitle(
                  title: MasarenLocalizations.of(context, 'program.projects')),
              ...projects.asMap().entries.map((entry) => SlideInWidget(
                    delay: Duration(milliseconds: 50 * entry.key),
                    child: _projectCard(entry.value as Map<String, dynamic>),
                  )),
            ],
            if (tasks.isNotEmpty) ...[
              SectionTitle(
                  title: MasarenLocalizations.of(
                      context, 'program.tasksEvidence')),
              ...tasks.asMap().entries.map((entry) => SlideInWidget(
                    delay: Duration(milliseconds: 50 * entry.key),
                    child: _taskCard(entry.value as Map<String, dynamic>),
                  )),
            ],
            if (p.members != null && p.members! > 0) ...[
              SectionTitle(
                  title:
                      MasarenLocalizations.of(context, 'program.membersTitle'),
                  action: MasarenLocalizations.of(context, 'program.viewAll'),
                  onAction: () => _showMembers()),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _statusLabel(BuildContext context, String? status) {
    final value = (status ?? 'OPEN').toUpperCase();
    final key = switch (value) {
      'OPEN' => 'program.status.open',
      'ACTIVE' => 'program.status.active',
      'PLANNED' => 'program.status.planned',
      'PAUSED' => 'program.status.paused',
      'VERIFIED' => 'program.status.verified',
      'IN_PROGRESS' => 'program.status.inProgress',
      'SUBMITTED' => 'program.status.submitted',
      'PENDING' => 'program.status.pending',
      'COMPLETED' => 'program.status.completed',
      'REJECTED' => 'program.status.rejected',
      _ => 'program.status.open',
    };
    return MasarenLocalizations.of(context, key);
  }

  Widget _projectCard(Map<String, dynamic> x) {
    final goal = (x['goal'] is num) ? (x['goal'] as num).toDouble() : 0.0;
    final raised = (x['raised'] is num) ? (x['raised'] as num).toDouble() : 0.0;
    final pct = goal > 0 ? (raised / goal).clamp(0.0, 1.0) : 0.0;
    final joined = x['joined'] == true;
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
                  child: Text(
                      x['title']?.toString() ??
                          MasarenLocalizations.of(
                              context, 'program.projectFallback'),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                Text(
                    MasarenLocalizations.of(context, 'program.membersCount')
                        .replaceAll('{count}', '${x['members'] ?? 0}'),
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12)),
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
            Text(
                MasarenLocalizations.of(context, 'program.fundingEgp')
                    .replaceAll('{raised}', '${raised.toInt()}')
                    .replaceAll('{goal}', '${goal.toInt()}'),
                style: const TextStyle(color: AppColors.muted, fontSize: 11)),
            if (!_isProjectOwner(x)) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: Icon(joined ? Icons.exit_to_app : Icons.login, size: 16),
                onPressed: () => _toggleProject(x, joined),
                label: Text(MasarenLocalizations.of(context,
                    joined ? 'program.leaveProject' : 'program.joinProject')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isProjectOwner(Map<String, dynamic> x) {
    final author = x['author'];
    return author is Map && author['id']?.toString() == AuthApi.userId;
  }

  Future<void> _toggleProject(Map<String, dynamic> x, bool joined) async {
    final id = x['id']?.toString();
    if (id == null) return;
    try {
      if (joined) {
        await AuthApi.leaveProject(id);
      } else {
        await AuthApi.joinProject(id);
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(MasarenLocalizations.of(context, 'common.failed')
                .replaceAll('{error}', '$e'))));
      }
    }
  }

  Widget _taskCard(Map<String, dynamic> t) {
    final status = (t['status'] ?? 'OPEN').toString().toUpperCase();
    final done = status == 'VERIFIED';
    final submitted = status == 'SUBMITTED';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(
            done
                ? Icons.check_circle
                : submitted
                    ? Icons.pending_actions
                    : Icons.task_alt,
            color: done
                ? AppColors.accent
                : submitted
                    ? AppColors.amber
                    : AppColors.azure),
        title: Text(t['title']?.toString() ??
            MasarenLocalizations.of(context, 'program.taskFallback')),
        subtitle: Text(
          [
            _statusLabel(context, status),
            if (t['assignee_name'] != null)
              MasarenLocalizations.of(context, 'program.assignedTo')
                  .replaceAll('{name}', '${t['assignee_name']}'),
            if (t['due_at'] != null)
              MasarenLocalizations.of(context, 'program.due').replaceAll(
                  '{date}', t['due_at'].toString().split('T').first),
          ].join(' - '),
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (t['evidence_required'] == true)
              Tooltip(
                  message: MasarenLocalizations.of(
                      context, 'program.evidenceRequired'),
                  child: const Icon(Icons.photo_camera_outlined,
                      color: AppColors.azure, size: 18)),
            Icon(directionalChevronIcon(context), size: 18),
          ],
        ),
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => TaskDetailScreen(
                  taskId: t['id'].toString(), title: t['title']?.toString())));
          _load();
        },
      ),
    );
  }
}
