import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/widgets/animations.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;
  final String? title;
  const TaskDetailScreen({super.key, required this.taskId, this.title});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  Map<String, dynamic>? _task;
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
      _task = await AuthApi.taskById(widget.taskId);
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _isAssignee {
    final assignee = _task?['assignee_id']?.toString();
    return assignee != null && assignee == AuthApi.userId;
  }

  bool get _isOwner {
    final author = _task?['author_id']?.toString();
    return author != null && author == AuthApi.userId;
  }

  Future<void> _setStatus(String status) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      _task = await AuthApi.updateTaskStatus(widget.taskId, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(MasarenLocalizations.of(context, 'task.updated'))));
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(
              widget.title ?? MasarenLocalizations.of(context, 'task.title'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(message: _error, onRetry: _load)
              : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final t = _task!;
    final status = (t['status'] ?? 'OPEN').toString().toUpperCase();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SlideInWidget(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t['title']?.toString() ??
                              MasarenLocalizations.of(context, 'task.title'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                      _statusChip(context, status),
                    ],
                  ),
                  if (t['description'] != null) ...[
                    const SizedBox(height: 10),
                    Text(t['description'].toString(),
                        style: const TextStyle(
                            color: AppColors.muted, height: 1.5)),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (t['assignee_name'] != null)
                        Chip(
                            avatar: const Icon(Icons.person_outline,
                                size: 16, color: AppColors.azure),
                            label: Text(t['assignee_name'].toString())),
                      if (t['due_at'] != null)
                        Chip(
                            avatar: const Icon(Icons.event_outlined,
                                size: 16, color: AppColors.azure),
                            label:
                                Text(t['due_at'].toString().split('T').first)),
                      if (t['location'] != null)
                        Chip(
                            avatar: const Icon(Icons.place_outlined,
                                size: 16, color: AppColors.azure),
                            label: Text(t['location'].toString())),
                      if (t['evidence_required'] == true)
                        Chip(
                            avatar: const Icon(Icons.photo_camera_outlined,
                                size: 16, color: AppColors.accent),
                            label: Text(MasarenLocalizations.of(
                                context, 'task.evidenceRequired'))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_isAssignee && status == 'OPEN')
          gradientButton(
            label: MasarenLocalizations.of(context, 'task.start'),
            onPressed: _busy ? () {} : () => _setStatus('IN_PROGRESS'),
          ),
        if (_isAssignee && status == 'IN_PROGRESS')
          gradientButton(
            label: MasarenLocalizations.of(context, 'task.submit'),
            onPressed: _busy ? () {} : () => _setStatus('SUBMITTED'),
          ),
        if (_isOwner && status == 'SUBMITTED')
          gradientButton(
            label: MasarenLocalizations.of(context, 'task.verify'),
            onPressed: _busy ? () {} : () => _setStatus('VERIFIED'),
          ),
        if ((_isOwner || _isAssignee) && status == 'VERIFIED')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified, color: AppColors.accent, size: 18),
                const SizedBox(width: 6),
                Text(
                  MasarenLocalizations.of(context, 'task.verifiedNote'),
                  style: const TextStyle(color: AppColors.accent),
                ),
              ],
            ),
          ),
        if (!_isOwner && !_isAssignee)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              MasarenLocalizations.of(context, 'task.notAssigned'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
      ],
    );
  }

  Widget _statusChip(BuildContext context, String status) {
    final color = switch (status) {
      'VERIFIED' => AppColors.accent,
      'SUBMITTED' => AppColors.amber,
      'IN_PROGRESS' => AppColors.azure,
      _ => AppColors.muted,
    };
    final label = switch (status) {
      'VERIFIED' => MasarenLocalizations.of(context, 'program.status.verified'),
      'SUBMITTED' =>
        MasarenLocalizations.of(context, 'program.status.submitted'),
      'IN_PROGRESS' =>
        MasarenLocalizations.of(context, 'program.status.inProgress'),
      _ => MasarenLocalizations.of(context, 'program.status.open'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}
