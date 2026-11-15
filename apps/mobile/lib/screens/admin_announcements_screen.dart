import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/widgets.dart';

class AdminAnnouncementsScreen extends StatefulWidget {
  final User user;
  const AdminAnnouncementsScreen({super.key, required this.user});

  @override
  State<AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  List<Announcement> _items = [];
  bool _loading = true;
  String? _error;

  String _t(String key, [String? fallback]) {
    final value = MasarenLocalizations.of(context, key);
    return value == key ? (fallback ?? key) : value;
  }

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
      final rows = await AuthApi.adminAnnouncements();
      if (mounted) setState(() => _items = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<Announcement>(
      MaterialPageRoute(
          builder: (_) => AnnouncementEditorScreen(user: widget.user)),
    );
    if (created != null) {
      setState(() => _items.insert(0, created));
    }
  }

  Future<void> _delete(Announcement item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('announcements.deleteTitle', 'Delete announcement?')),
        content: Text(item.title),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(_t('common.delete', 'Delete'))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AuthApi.adminDeleteAnnouncement(item.id);
      if (mounted) setState(() => _items.remove(item));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_t('common.failed').replaceAll('{error}', '$e'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('announcements.title', 'Announcements')),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.campaign_outlined),
        label: Text(_t('announcements.create', 'New announcement')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(message: _error, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(30),
                          child: Text(
                              _t('announcements.empty',
                                  'No announcements yet. Create a promotion, discount or platform update.'),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: cs.onSurfaceVariant)),
                        ),
                      ..._items.map((a) => Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.campaign_outlined,
                                          size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(a.title,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800)),
                                      ),
                                      IconButton(
                                        onPressed: () => _delete(a),
                                        icon: const Icon(Icons.delete_outline,
                                            size: 20),
                                      ),
                                    ],
                                  ),
                                  Text(a.body,
                                      style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          height: 1.4)),
                                  const SizedBox(height: 8),
                                  Text(
                                      '${_t('announcements.audience', 'Audience')}: ${a.activeUntil == null ? _t('announcements.untilHidden', 'active') : _t('announcements.until', 'until {date}').replaceAll('{date}', a.activeUntil!.split('T').first)}',
                                      style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 11.5)),
                                ],
                              ),
                            ),
                          )),
                    ],
                  ),
                ),
    );
  }
}

class AnnouncementEditorScreen extends StatefulWidget {
  final User user;
  const AnnouncementEditorScreen({super.key, required this.user});

  @override
  State<AnnouncementEditorScreen> createState() =>
      _AnnouncementEditorScreenState();
}

class _AnnouncementEditorScreenState extends State<AnnouncementEditorScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _image = TextEditingController();
  final _link = TextEditingController();
  final _cta = TextEditingController(text: 'Learn more');
  final _role = ValueNotifier<String>('STUDENT');
  final _days = TextEditingController(text: '7');
  String _audience = 'ALL';
  String? _userId;
  List<Map<String, dynamic>> _users = [];
  bool _loadingUsers = false;
  bool _notify = true;
  bool _busy = false;

  String _t(String key, [String? fallback]) {
    final value = MasarenLocalizations.of(context, key);
    return value == key ? (fallback ?? key) : value;
  }

  static const _roles = [
    'STUDENT',
    'INDIVIDUAL',
    'ACADEMIC',
    'ORGANIZATION',
    'PROFESSIONAL',
    'VOLUNTEER',
    'JOURNALIST',
    'DONOR',
    'MEDIA',
    'SPORTS',
    'ATHLETE',
    'CLUB',
    'FEDERATION',
    'INSTITUTION',
    'UNIVERSITY',
    'RESEARCHER',
  ];

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _image.dispose();
    _link.dispose();
    _cta.dispose();
    _days.dispose();
    _role.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    if (_users.isNotEmpty || _loadingUsers) return;
    setState(() => _loadingUsers = true);
    try {
      final rows = await AuthApi.adminUsers();
      if (mounted) setState(() => _users = rows);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  Future<void> _publish() async {
    if (_title.text.trim().length < 3 || _body.text.trim().length < 3) {
      _snack(_t('announcements.required',
          'Write a title and message for the announcement.'));
      return;
    }
    if (_audience == 'USER' && (_userId == null || _userId!.isEmpty)) {
      _snack(_t('announcements.pickUser', 'Choose a member to target.'));
      return;
    }
    final days = int.tryParse(_days.text.trim()) ?? 0;
    final until = days > 0
        ? DateTime.now().add(Duration(days: days)).toUtc().toIso8601String()
        : null;
    setState(() => _busy = true);
    try {
      final created = await AuthApi.adminCreateAnnouncement({
        'title': _title.text.trim(),
        'body': _body.text.trim(),
        'image_url': _image.text.trim(),
        'link_url': _link.text.trim(),
        'cta_label': _cta.text.trim(),
        'audience': _audience,
        'audience_value': _audience == 'ALL'
            ? null
            : _audience == 'ROLE'
                ? _role.value
                : _userId,
        'active_until': until,
        'notify': _notify,
      });
      if (mounted) Navigator.pop(context, created);
    } catch (e) {
      if (mounted) {
        _snack(_t('common.failed').replaceAll('{error}', '$e'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar:
          AppBar(title: Text(_t('announcements.create', 'New announcement'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
        children: [
          TextField(
            controller: _title,
            maxLength: 140,
            decoration: InputDecoration(
                labelText: _t('announcements.headline', 'Headline'),
                hintText: _t('announcements.headlineHint',
                    'Ramadan offer: 50% off Pro')),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _body,
            minLines: 3,
            maxLines: 8,
            maxLength: 2000,
            decoration: InputDecoration(
                labelText: _t('announcements.message', 'Message'),
                hintText: _t('announcements.messageHint',
                    'Explain the offer and how to claim it.')),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _image,
            keyboardType: TextInputType.url,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
                labelText: _t('announcements.image', 'Image URL (optional)'),
                hintText: 'https://...'),
          ),
          if (_image.text.trim().startsWith('http'))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(_image.text.trim(),
                    height: 130,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _link,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
                labelText: _t('announcements.link', 'Button link (optional)'),
                hintText: 'https://masareen.com/pro'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _cta,
            maxLength: 60,
            decoration: InputDecoration(
                labelText: _t('announcements.cta', 'Button label')),
          ),
          const SizedBox(height: 4),
          Text(_t('announcements.sendTo', 'Send to'),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                  value: 'ALL',
                  label: Text(_t('announcements.everyone', 'Everyone'))),
              ButtonSegment(
                  value: 'ROLE', label: Text(_t('announcements.role', 'Role'))),
              ButtonSegment(
                  value: 'USER',
                  icon: const Icon(Icons.person_outline, size: 16),
                  label: Text(_t('announcements.oneUser', 'One user'))),
            ],
            selected: {_audience},
            onSelectionChanged: (value) {
              setState(() => _audience = value.first);
              if (_audience == 'USER') _loadUsers();
            },
          ),
          if (_audience == 'ROLE') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _role.value,
              decoration:
                  InputDecoration(labelText: _t('announcements.role', 'Role')),
              items: _roles
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (value) =>
                  setState(() => _role.value = value ?? _role.value),
            ),
          ],
          if (_audience == 'USER') ...[
            const SizedBox(height: 12),
            if (_loadingUsers)
              const LinearProgressIndicator()
            else
              DropdownButtonFormField<String>(
                initialValue: _userId,
                decoration: InputDecoration(
                    labelText: _t('announcements.member', 'Member')),
                items: _users
                    .map((u) => DropdownMenuItem(
                          value: u['id'].toString(),
                          child: Text(
                              '${u['name'] ?? u['full_name'] ?? 'Member'} Â· ${u['email'] ?? ''}',
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _userId = value),
              ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _days,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: _t('announcements.days',
                          'Show for days (0 = until removed)')),
                ),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _notify,
            onChanged: (value) => setState(() => _notify = value),
            title: Text(
                _t('announcements.notify', 'Send in-app and push notification'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
                _t('announcements.notifyHint',
                    'Users get a notification in addition to the popup.'),
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _busy ? null : _publish,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.campaign_outlined, size: 18),
            label: Text(_t('announcements.publish', 'Publish announcement')),
          ),
        ],
      ),
    );
  }
}
