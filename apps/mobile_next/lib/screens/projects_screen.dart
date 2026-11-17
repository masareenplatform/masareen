import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/screens/create_project_screen.dart';
import 'package:masaren/widgets/entity_status.dart';
import 'package:masaren/widgets/smart_image.dart';
import 'package:masaren/widgets/stacked_avatars.dart';
import 'package:masaren/profile_router.dart';
import 'package:masaren/models.dart';
import 'package:masaren/widgets.dart';

class ProjectsScreen extends StatefulWidget {
  final User user;
  const ProjectsScreen({super.key, required this.user});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  List<Project> _items = [];
  final Set<String> _busyIds = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _items = await AuthApi.projects();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<Project>(
        MaterialPageRoute(
            builder: (_) => CreateProjectScreen(user: widget.user)));
    if (created != null) {
      setState(() => _items.insert(0, created));
    }
  }
  Future<void> _join(Project project, bool joined) async {
    if (_busyIds.contains(project.id)) return;
    setState(() => _busyIds.add(project.id));
    try {
      final updated = joined
          ? await AuthApi.leaveProject(project.id)
          : await AuthApi.joinProject(project.id);
      final index = _items.indexWhere((p) => p.id == project.id);
      if (index != -1) setState(() => _items[index] = updated);
    } catch (e) {
      if (mounted) {
        final message = e is ApiException
            ? (e.message ?? '$e')
            : e.toString();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(project.id));
    }
  }
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
          title: Text(MasarenLocalizations.of(context, 'projects.title'))),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(message: _error, onRetry: () => _load())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    children: [
                      SectionTitle(
                          title: MasarenLocalizations.of(
                              context, 'projects.community')),
                      if (_items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            MasarenLocalizations.of(context, 'projects.empty'),
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ..._items.map((p) {
                        final pct =
                            p.goal > 0 ? (p.raised / p.goal).clamp(0, 1) : 0.0;
                        final author = p.author;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (p.cover != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: SmartImage(
                                      url: p.cover,
                                      height: 140,
                                      borderRadius: BorderRadius.circular(14),
                                      fallbackIcon: Icons.handshake_outlined,
                                    ),
                                  ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(p.title,
                                          style: TextStyle(
                                              color: cs.onSurface,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16)),
                                    ),
                                    Text(p.category,
                                        style: TextStyle(
                                            color: cs.secondary, fontSize: 12)),
                                    EntityStatusChip(
                                        status: p.verificationStatus,
                                        reason: p.rejectionReason),
                                  ],
                                ),
                                if (author != null) ...[
                                  const SizedBox(height: 4),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () => openEntityAuthor(context,
                                        author: author,
                                        currentUser: widget.user),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 3),
                                      child: Row(
                                        children: [
                                          AppAvatar(
                                              name: author.name,
                                              url: author.avatarUrl,
                                              size: 18),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              author.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  color: cs.primary,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ] else if (p.ownerName != null &&
                                    p.ownerName!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.person_outline_rounded,
                                          size: 14, color: cs.onSurfaceVariant),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          p.ownerName!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              color: cs.onSurfaceVariant,
                                              fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (p.projectType != 'COMMUNITY') ...[
                                  const SizedBox(height: 7),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      _ProjectTag(
                                          icon: Icons.school_outlined,
                                          label: MasarenLocalizations.of(
                                                  context,
                                                  'projects.type.${p.projectType}')
                                              .replaceAll(
                                                  'projects.type.', '')),
                                      if ((p.academicYear ?? '').isNotEmpty)
                                        _ProjectTag(
                                            icon: Icons.calendar_today_outlined,
                                            label: p.academicYear!),
                                      if ((p.supervisor ?? '').isNotEmpty)
                                        _ProjectTag(
                                            icon: Icons.person_pin_outlined,
                                            label: p.supervisor!),
                                    ],
                                  ),
                                  if ((p.studentNames ?? '').isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 5),
                                      child: Text(p.studentNames!,
                                          style: TextStyle(
                                              color: cs.onSurfaceVariant,
                                              fontSize: 12)),
                                    ),
                                ],
                                if (p.description != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(p.description!,
                                        style: TextStyle(
                                            color: cs.onSurfaceVariant)),
                                  ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    StackedAvatars(
                                        people: p.membersPreview,
                                        total: p.members,
                                        size: 20),
                                    const SizedBox(width: 6),
                                    Text('${p.members}',
                                        style: TextStyle(
                                            color: cs.onSurfaceVariant,
                                            fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: pct.toDouble(),
                                  backgroundColor: cs.surfaceContainerHighest,
                                  color: cs.primary,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                    MasarenLocalizations.of(
                                            context, 'projects.progress')
                                        .replaceAll(
                                            '{raised}', '${p.raised.toInt()}')
                                        .replaceAll(
                                            '{goal}', '${p.goal.toInt()}')
                                        .replaceAll(
                                            '{members}', '${p.members}'),
                                    style: TextStyle(
                                        color: cs.onSurfaceVariant,
                                        fontSize: 12)),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: TextButton.icon(
                                    onPressed: _busyIds.contains(p.id)
                                        ? null
                                        : () => _join(p, p.joined),
                                    icon: Icon(
                                        p.joined
                                            ? Icons.exit_to_app
                                            : Icons.login,
                                        size: 16),
                                    label: Text(MasarenLocalizations.of(
                                        context,
                                        p.joined
                                            ? 'projects.leaveProject'
                                            : 'projects.joinProject')),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}

class _ProjectTag extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ProjectTag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: cs.primary),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: cs.primary)),
        ],
      ),
    );
  }
}
