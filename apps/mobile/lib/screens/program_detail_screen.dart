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
      final data = await api.get('/api/v1/programs/${widget.programId}');
      _program = Program.fromJson(data as Map<String, dynamic>);
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
      _program = await AuthApi.enrollProgram(_program!.id,
          userId: AuthApi.userId);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Enrolled')));
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
          appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _program == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorView(message: _error ?? 'Not found', onRetry: () => _load()),
      );
    }
    final p = _program!;
    return Scaffold(
      appBar: AppBar(title: Text(p.title)),
      body: ListView(
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
                const SizedBox(height: 6),
                if (p.description != null)
                  Text(p.description!,
                      style: const TextStyle(color: AppColors.muted, height: 1.5)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    if (p.sdg != null)
                      Chip(
                          label: Text('SDG ${p.sdg}',
                              style: const TextStyle(color: AppColors.accent))),
                    if (p.members != null)
                      Chip(
                          label: Text('${p.members} members',
                              style: const TextStyle(color: AppColors.azure))),
                    Chip(
                        label: Text(p.status ?? '',
                            style: const TextStyle(color: Colors.white))),
                  ],
                ),
                const SizedBox(height: 18),
                gradientButton(
                  label: _busy ? 'Enrolling…' : 'Enroll in program',
                  onPressed: _busy ? () {} : _enroll,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
