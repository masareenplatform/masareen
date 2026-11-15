import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/screens/post_detail_screen.dart';

class ResearchHubScreen extends StatefulWidget {
  final User user;
  const ResearchHubScreen({super.key, required this.user});

  @override
  State<ResearchHubScreen> createState() => _ResearchHubScreenState();
}

class _ResearchHubScreenState extends State<ResearchHubScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  static const _stages = [
    'IDEA',
    'LITERATURE',
    'METHODOLOGY',
    'FIELDWORK',
    'ANALYSIS',
    'RESULTS',
    'PUBLISHED',
  ];

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
      final list = await AuthApi.researchStages(limit: 80);
      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ApiException ? e.message : e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _t(String key, String fallback) {
    final value = MasarenLocalizations.of(context, key);
    return value == key ? fallback : value;
  }

  Future<void> _compose() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _ResearchStageSheet(stages: _stages),
    );
    if (created == true) _load();
  }

  Future<void> _openPost(String postId) async {
    if (postId.isEmpty) return;
    try {
      final post = await AuthApi.postById(postId);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PostDetailScreen(
              post: post, currentUser: widget.user, onChanged: (_) {})));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_t('research.title', 'Research stages'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _compose,
        icon: const Icon(Icons.add),
        label: Text(_t('research.share', 'Share stage')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                            onPressed: _load,
                            child: Text(MasarenLocalizations.of(
                                context, 'common.retry'))),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(32),
                          children: [
                            Icon(Icons.science_outlined,
                                size: 42, color: cs.primary),
                            const SizedBox(height: 12),
                            Text(
                                _t('research.empty',
                                    'No research stages yet. Share your first one.'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: cs.onSurfaceVariant, height: 1.5)),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 96),
                          itemCount: _items.length,
                          itemBuilder: (_, index) {
                            final item = _items[index];
                            final postId = (item['post_id'] ?? '').toString();
                            final created = DateTime.tryParse(
                                (item['created_at'] ?? '').toString());
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: postId.isEmpty
                                    ? null
                                    : () => _openPost(postId),
                                child: Padding(
                                  padding: const EdgeInsets.all(15),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 9, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: cs.primary
                                                  .withValues(alpha: 0.09),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                                (item['stage'] ?? 'IDEA')
                                                    .toString(),
                                                style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: cs.primary)),
                                          ),
                                          const Spacer(),
                                          if (created != null)
                                            Text(
                                                DateFormat.yMMMd()
                                                    .format(created.toLocal()),
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        cs.onSurfaceVariant)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text((item['title'] ?? '').toString(),
                                          style: TextStyle(
                                              fontSize: 15.5,
                                              fontWeight: FontWeight.w800,
                                              height: 1.3,
                                              color: cs.onSurface)),
                                      if ((item['summary'] ?? '')
                                          .toString()
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 5),
                                        Text((item['summary'] ?? '').toString(),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontSize: 13,
                                                height: 1.45,
                                                color: cs.onSurfaceVariant)),
                                      ],
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Icon(Icons.person_outline,
                                              size: 15,
                                              color: cs.onSurfaceVariant),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                                (item['researcher_name'] ??
                                                        _t('research.researcher',
                                                            'Researcher'))
                                                    .toString(),
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: cs.onSurface)),
                                          ),
                                          if ((item['institution_id'] ?? '')
                                              .toString()
                                              .isNotEmpty)
                                            Row(
                                              children: [
                                                Icon(Icons.school_outlined,
                                                    size: 14,
                                                    color: cs.primary),
                                                const SizedBox(width: 4),
                                                Text(
                                                    _t('research.linked',
                                                        'Linked'),
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: cs.primary)),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}

class _ResearchStageSheet extends StatefulWidget {
  final List<String> stages;
  const _ResearchStageSheet({required this.stages});

  @override
  State<_ResearchStageSheet> createState() => _ResearchStageSheetState();
}

class _ResearchStageSheetState extends State<_ResearchStageSheet> {
  final _title = TextEditingController();
  final _summary = TextEditingController();
  final _institution = TextEditingController();
  final _project = TextEditingController();
  String _stage = 'IDEA';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _institution.dispose();
    _project.dispose();
    super.dispose();
  }

  String _t(String key, String fallback) {
    final value = MasarenLocalizations.of(context, key);
    return value == key ? fallback : value;
  }

  Future<void> _save() async {
    if (_title.text.trim().length < 3) {
      setState(() =>
          _error = _t('research.titleRequired', 'Add a title for this stage.'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AuthApi.createResearchStage({
        'title': _title.text.trim(),
        'summary': _summary.text.trim(),
        'stage': _stage,
        if (_institution.text.trim().isNotEmpty)
          'institution_id': int.tryParse(_institution.text.trim()),
        if (_project.text.trim().isNotEmpty)
          'project_id': int.tryParse(_project.text.trim()),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e is ApiException ? e.message : e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_t('research.share', 'Share research stage'),
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface)),
            const SizedBox(height: 4),
            Text(
                _t('research.shareBody',
                    'Publish progress to your feed and your institution profile.'),
                style: TextStyle(
                    fontSize: 12.5, height: 1.45, color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              maxLength: 160,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                  labelText: _t('research.stageTitle', 'Stage title')),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _stage,
              decoration:
                  InputDecoration(labelText: _t('research.stage', 'Stage')),
              items: widget.stages
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _stage = v ?? 'IDEA'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _summary,
              minLines: 3,
              maxLines: 8,
              maxLength: 3000,
              textCapitalization: TextCapitalization.sentences,
              decoration:
                  InputDecoration(labelText: _t('research.summary', 'Summary')),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _institution,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText:
                            _t('research.institutionId', 'University ID'),
                        helperText: _t('research.optional', 'Optional')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _project,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: _t('research.projectId', 'Project ID'),
                        helperText: _t('research.optional', 'Optional')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!,
                    style: TextStyle(color: cs.error, fontSize: 12.5)),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_t('research.publish', 'Publish stage')),
            ),
          ],
        ),
      ),
    );
  }
}
