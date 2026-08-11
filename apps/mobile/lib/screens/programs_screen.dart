import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/theme.dart';
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
    setState(() => _loading = true);
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

  void _create() {
    final cs = Theme.of(context).colorScheme;
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final sdgCtrl = TextEditingController();
    bool busy = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.5,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline, color: cs.primary, size: 22),
                    const SizedBox(width: 10),
                    Text('New program',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: cs.onSurface,
                        )),
                    const Spacer(),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () async {
                              final t = titleCtrl.text.trim();
                              if (t.isEmpty) return;
                              setSheetState(() => busy = true);
                              try {
                                final s = int.tryParse(sdgCtrl.text) ?? 0;
                                final p = await AuthApi.createProgram({
                                  'title': t,
                                  'description': descCtrl.text.trim().isNotEmpty
                                      ? descCtrl.text.trim()
                                      : null,
                                  'sdg_goals': s > 0 ? [s] : [],
                                  'organization_id': widget.user.id,
                                });
                                _items.insert(0, p);
                                if (mounted) setState(() {});
                                if (ctx.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text('Failed: $e')));
                                }
                              } finally {
                                if (ctx.mounted) setSheetState(() => busy = false);
                              }
                            },
                      child: busy
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Create'),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: cs.outlineVariant),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    TextField(
                      controller: titleCtrl,
                      style: TextStyle(color: cs.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Title',
                        labelStyle: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      minLines: 1,
                      style: TextStyle(color: cs.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Description',
                        labelStyle: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: sdgCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: cs.onSurface),
                      decoration: InputDecoration(
                        labelText: 'SDG (1–17)',
                        labelStyle: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Programs'),
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
                      const SectionTitle(title: 'Impact programs'),
                      if (_items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text('No programs yet.',
                                style: TextStyle(color: cs.onSurfaceVariant)),
                          ),
                        ),
                      ..._items
                          .map((p) => _ProgramCard(
                                p: p,
                                onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => ProgramDetailScreen(
                                            programId: p.id))),
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
  final VoidCallback onTap;
  const _ProgramCard({required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: brandGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.hub, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.title,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                            fontSize: 15)),
                    if (p.description != null)
                      Text(p.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (p.sdg != null)
                          Text('SDG ${p.sdg}',
                              style: TextStyle(
                                  color: cs.secondary, fontSize: 12)),
                        if (p.members != null) ...[
                          const SizedBox(width: 12),
                          Text('${p.members} members',
                              style: TextStyle(
                                  color: cs.onSurfaceVariant, fontSize: 12)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.outline),
            ],
          ),
        ),
      ),
    );
  }
}
