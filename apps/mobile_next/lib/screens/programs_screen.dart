import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/screens/create_program_screen.dart';
import 'package:masaren/widgets/entity_status.dart';
import 'package:masaren/widgets/smart_image.dart';
import 'package:masaren/widgets/stacked_avatars.dart';
import 'package:masaren/profile_router.dart';
import 'package:masaren/models.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/screens/program_detail_screen.dart';

class ProgramsScreen extends StatefulWidget {
  final User user;
  const ProgramsScreen({super.key, required this.user});

  @override
  State<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends State<ProgramsScreen> {
  List<Program> _items = [];
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
      _items = await AuthApi.programs();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<Program>(
        MaterialPageRoute(
            builder: (_) => CreateProgramScreen(user: widget.user)));
    if (created != null) {
      setState(() => _items.insert(0, created));
    }
  }
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(MasarenLocalizations.of(context, 'programs.title')),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: cs.primary),
            onPressed: _create,
          ),
        ],
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
                              context, 'programs.impact')),
                      if (_items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              MasarenLocalizations.of(
                                  context, 'programs.empty'),
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ),
                        ),
                      ..._items.map((p) => _ProgramCard(
                            p: p,
                            currentUser: widget.user,
                            onTap: () async {
                              await Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => ProgramDetailScreen(
                                          programId: p.id)));
                              _load();
                            },
                          )),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  final Program p;
  final User currentUser;
  final VoidCallback onTap;
  const _ProgramCard(
      {required this.p, required this.currentUser, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final author = p.author;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SmartImage(
                url: p.coverUrl,
                width: 52,
                height: 52,
                borderRadius: BorderRadius.circular(14),
                fallbackIcon: Icons.hub,
                accent: cs.primary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(p.title,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface,
                                  fontSize: 15)),
                        ),
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
                            author: author, currentUser: currentUser),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
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
                    ],
                    if (p.description != null)
                      Text(p.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 13)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        StackedAvatars(
                            people: p.membersPreview,
                            total: p.members ?? 0,
                            size: 20),
                        if (p.membersPreview.isNotEmpty ||
                            (p.members ?? 0) > 0)
                          const SizedBox(width: 6),
                        if (p.sdg != null)
                          Text(
                              MasarenLocalizations.of(context, 'programs.sdg')
                                  .replaceAll('{sdg}', '${p.sdg}'),
                              style:
                                  TextStyle(color: cs.secondary, fontSize: 12)),
                        if (p.members != null) ...[
                          const SizedBox(width: 12),
                          Text(
                              MasarenLocalizations.of(
                                      context, 'programs.memberCount')
                                  .replaceAll('{count}', '${p.members}'),
                              style: TextStyle(
                                  color: cs.onSurfaceVariant, fontSize: 12)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(directionalChevronIcon(context), color: cs.outline),
            ],
          ),
        ),
      ),
    );
  }
}
