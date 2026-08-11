import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/theme.dart';
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
    final title = TextEditingController();
    final desc = TextEditingController();
    final cat = TextEditingController();
    final goal = TextEditingController();
    final created = await showDialog<Project>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('New project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description')),
            TextField(controller: cat, decoration: const InputDecoration(labelText: 'Category')),
            TextField(controller: goal, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Funding goal')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (title.text.trim().isEmpty) return;
              Navigator.pop(
                  c,
                  Project(
                      id: '',
                      title: title.text.trim(),
                      description: desc.text.trim().isNotEmpty ? desc.text.trim() : null,
                      category: cat.text.trim().isNotEmpty ? cat.text.trim() : 'Community',
                      goal: double.tryParse(goal.text) ?? 0));
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (created == null) return;
    try {
      final p = await AuthApi.createProject({
        'title': created.title,
        'description': created.description,
        'category': created.category,
        'goal': created.goal,
      });
      _items.insert(0, p);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _join(Project p) async {
    try {
      final updated = await AuthApi.joinProject(p.id);
      final i = _items.indexWhere((e) => e.id == p.id);
      if (i != -1) {
        _items[i] = updated;
        if (mounted) setState(() {});
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Joined ${p.title}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        backgroundColor: AppColors.azure,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(message: _error, onRetry: () => _load())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    children: [
                      const SectionTitle(title: 'Community & impact projects'),
                      if (_items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No projects yet.',
                              style: TextStyle(color: AppColors.muted)),
                        ),
                      ..._items.map((p) {
                        final pct = p.goal > 0
                            ? (p.raised / p.goal).clamp(0, 1)
                            : 0.0;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(p.title,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16)),
                                    ),
                                    Text(p.category,
                                        style: const TextStyle(
                                            color: AppColors.muted, fontSize: 12)),
                                  ],
                                ),
                                if (p.description != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(p.description!,
                                        style: const TextStyle(
                                            color: AppColors.muted)),
                                  ),
                                const SizedBox(height: 10),
                                LinearProgressIndicator(
                                  value: pct.toDouble(),
                                  backgroundColor: AppColors.darkSurface2,
                                  color: AppColors.accent,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                    '${p.raised.toInt()} / ${p.goal.toInt()} raised · ${p.members} members',
                                    style: const TextStyle(
                                        color: AppColors.muted, fontSize: 12)),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () => _join(p),
                                    child: const Text('Join project'),
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
