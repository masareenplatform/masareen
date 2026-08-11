import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/models.dart';
import 'package:masaren/widgets.dart';

class CoursesScreen extends StatefulWidget {
  final User user;
  const CoursesScreen({super.key, required this.user});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  List<Course> _items = [];
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
      _items = await AuthApi.courses();
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
    final sdg = TextEditingController();
    final lessons = TextEditingController();
    final created = await showDialog<Course>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('New course'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: sdg, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'SDG')),
            TextField(controller: lessons, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Lessons')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (title.text.trim().isEmpty) return;
              Navigator.pop(
                  c,
                  Course(
                      id: '',
                      title: title.text.trim(),
                      sdg: int.tryParse(sdg.text),
                      lessons: int.tryParse(lessons.text) ?? 0));
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (created == null) return;
    try {
      final c = await AuthApi.createCourse({
        'title': created.title,
        'sdg': created.sdg,
        'lessons': created.lessons,
      });
      _items.insert(0, c);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _enroll(Course c) async {
    try {
      await AuthApi.enrollCourse(c.id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Enrolled in ${c.title}')));
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
      appBar: AppBar(title: const Text('Courses')),
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
                      const SectionTitle(title: 'Learning & capacity building'),
                      if (_items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No courses yet.',
                              style: TextStyle(color: AppColors.muted)),
                        ),
                      ..._items.map((c) => Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(Icons.school,
                                        color: AppColors.accent),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(c.title,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800)),
                                        Text(
                                            '${c.lessons} lessons · ${c.level}'
                                            '${c.sdg != null ? " · SDG ${c.sdg}" : ""}',
                                            style: const TextStyle(
                                                color: AppColors.muted,
                                                fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => _enroll(c),
                                    child: const Text('Enroll'),
                                  ),
                                ],
                              ),
                            ),
                          )),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}
