import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/models.dart';
import 'package:masaren/widgets/smart_image.dart';

const _permissionLabels = {
  'remove_comments': 'Remove comments',
  'remove_posts': 'Remove posts',
  'verify_contributions': 'Verify contributions',
  'remove_event': 'Remove the event',
  'manage_booths': 'Manage booths',
};

class ModeratorsScreen extends StatefulWidget {
  final String entityType;
  final String entityId;
  final String entityTitle;
  final User currentUser;
  const ModeratorsScreen({
    super.key,
    required this.entityType,
    required this.entityId,
    required this.entityTitle,
    required this.currentUser,
  });

  @override
  State<ModeratorsScreen> createState() => _ModeratorsScreenState();
}

class _ModeratorsScreenState extends State<ModeratorsScreen> {
  List<Map<String, dynamic>> _moderators = [];
  List<Author> _results = [];
  final _query = TextEditingController();
  bool _loading = true;
  bool _searching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final rows = await AuthApi.entityModerators(
          widget.entityType, widget.entityId);
      if (mounted) setState(() => _moderators = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.length < 2) return;
    setState(() => _searching = true);
    try {
      final result = await AuthApi.search(q);
      if (mounted) setState(() => _results = result.users);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _assign(Author author) async {
    final permissions = <String>{
      'remove_comments',
      'verify_contributions',
    };
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                18, 14, 18, MediaQuery.of(ctx).viewInsets.bottom + 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Moderate ${author.name}',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800)),
                    ),
                    IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close)),
                  ],
                ),
                Text(
                    'These permissions apply only to ${widget.entityTitle}. They do not make this person a platform admin.',
                    style: const TextStyle(fontSize: 12.5, height: 1.4)),
                const SizedBox(height: 10),
                for (final entry in _permissionLabels.entries)
                  CheckboxListTile(
                    value: permissions.contains(entry.key),
                    onChanged: (v) => setSheet(() {
                      if (v == true) {
                        permissions.add(entry.key);
                      } else {
                        permissions.remove(entry.key);
                      }
                    }),
                    title: Text(entry.value),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Assign scoped moderator'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    try {
      await AuthApi.assignEntityModerator(
          widget.entityType, widget.entityId, author.id,
          permissions: permissions.toList());
      _query.clear();
      if (mounted) setState(() => _results = []);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _remove(String userId) async {
    try {
      await AuthApi.removeEntityModerator(
          widget.entityType, widget.entityId, userId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderators'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: cs.primary.withValues(alpha: .16)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Scoped moderation · ${widget.entityType}',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: cs.primary)),
                      const SizedBox(height: 4),
                      Text(widget.entityTitle,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                          'Moderators can act only inside this entity. Platform admins keep separate authority.',
                          style: TextStyle(
                              fontSize: 11.5,
                              height: 1.4,
                              color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _query,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _search(),
                        decoration: const InputDecoration(
                          labelText: 'Find a member',
                          helperText: 'Search by name or @handle.',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _searching ? null : _search,
                      icon: _searching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.person_search),
                    ),
                  ],
                ),
                if (_results.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ..._results.map((a) => Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: cs.primary.withValues(alpha: .12),
                            child: Text(a.name.isEmpty
                                ? '?'
                                : a.name[0].toUpperCase()),
                          ),
                          title: Text(a.name),
                          subtitle: Text(a.handle == null
                              ? a.role ?? 'Member'
                              : '@${a.handle} · ${a.role ?? 'Member'}'),
                          trailing: const Icon(Icons.add_moderator),
                          onTap: () => _assign(a),
                        ),
                      )),
                ],
                const SizedBox(height: 18),
                Text('Current moderators',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurfaceVariant)),
                const SizedBox(height: 6),
                if (_moderators.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('No moderators assigned yet.',
                          style: TextStyle(
                              fontSize: 12.5, color: cs.onSurfaceVariant)),
                    ),
                  )
                else
                  ..._moderators.map((m) {
                    final permissions =
                        (m['permissions'] as List? ?? const []).cast<String>();
                    return Card(
                      child: ListTile(
                        leading: SmartImage(
                          url: m['avatar_url']?.toString(),
                          width: 42,
                          height: 42,
                          borderRadius: BorderRadius.circular(99),
                          fallbackIcon: Icons.person_outline,
                        ),
                        title: Text((m['name'] ?? 'Moderator').toString()),
                        subtitle: Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: permissions
                              .map((p) => Chip(
                                    label: Text(
                                        _permissionLabels[p] ?? p,
                                        style: const TextStyle(fontSize: 9.5)),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ))
                              .toList(),
                        ),
                        trailing: IconButton(
                          tooltip: 'Remove moderator',
                          onPressed: () => _remove(m['user_id'].toString()),
                          icon: Icon(Icons.person_remove_outlined,
                              color: cs.error),
                        ),
                      ),
                    );
                  }),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(_error!,
                        style: TextStyle(color: cs.error, fontSize: 12.5)),
                  ),
              ],
            ),
    );
  }
}
