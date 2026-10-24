import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/models.dart';

class EventsScreen extends StatefulWidget {
  final User user;
  const EventsScreen({super.key, required this.user});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  List<Event> _items = [];
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
      _items = await AuthApi.events();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<DateTime?> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _create() async {
    final title = TextEditingController();
    final description = TextEditingController();
    final location = TextEditingController();
    final link = TextEditingController();
    final sdg = TextEditingController();
    final capacity = TextEditingController();
    DateTime? starts;
    bool online = false;
    String? error;

    final created = await showDialog<Event>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialog) => AlertDialog(
          title: const Text('New event'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title *'),
                ),
                TextField(
                  controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await _pickDateTime();
                          if (picked != null) setDialog(() => starts = picked);
                        },
                        icon: const Icon(Icons.event, size: 18),
                        label: Text(starts == null
                            ? 'Pick date & time *'
                            : '${starts!.toString().substring(0, 16)}'),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: online,
                  onChanged: (v) => setDialog(() => online = v),
                  title: const Text('Online event'),
                ),
                if (online)
                  TextField(
                    controller: link,
                    decoration: const InputDecoration(labelText: 'Meeting link *'),
                  )
                else
                  TextField(
                    controller: location,
                    decoration: const InputDecoration(labelText: 'Venue *'),
                  ),
                TextField(
                  controller: sdg,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'SDG (1-17)'),
                ),
                TextField(
                  controller: capacity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Capacity (optional)'),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (title.text.trim().length < 3) {
                  setDialog(() => error = 'Title must be at least 3 characters');
                  return;
                }
                if (starts == null) {
                  setDialog(() => error = 'Pick a start date and time');
                  return;
                }
                if (online && link.text.trim().isEmpty) {
                  setDialog(() => error = 'Add the meeting link');
                  return;
                }
                if (!online && location.text.trim().isEmpty) {
                  setDialog(() => error = 'Add the venue');
                  return;
                }
                Navigator.pop(
                  c,
                  Event(
                    id: '',
                    title: title.text.trim(),
                    description: description.text.trim(),
                    startsAt: starts!.toUtc().toIso8601String(),
                    location: online ? null : location.text.trim(),
                    isOnline: online,
                    linkUrl: online ? link.text.trim() : null,
                    sdg: int.tryParse(sdg.text.trim()),
                    capacity: int.tryParse(capacity.text.trim()),
                  ),
                );
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (created == null) return;
    try {
      final e = await AuthApi.createEvent({
        'title': created.title,
        'description': created.description,
        'starts_at': created.startsAt,
        'is_online': created.isOnline,
        'location': created.location,
        'link_url': created.linkUrl,
        'sdg': created.sdg,
        'capacity': created.capacity,
      });
      _items.insert(0, e);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _join(Event e) async {
    try {
      final r = await AuthApi.joinEvent(e.id);
      final updated = Event(
        id: e.id,
        title: e.title,
        description: e.description,
        startsAt: e.startsAt,
        endsAt: e.endsAt,
        location: e.location,
        isOnline: e.isOnline,
        linkUrl: e.linkUrl,
        sdg: e.sdg,
        capacity: e.capacity,
        attendeesCount: (r['attendees_count'] is num)
            ? (r['attendees_count'] as num).toInt()
            : e.attendeesCount,
        attending: r['attending'] == true,
        authorName: e.authorName,
        createdAt: e.createdAt,
      );
      final i = _items.indexWhere((x) => x.id == e.id);
      if (i >= 0) _items[i] = updated;
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  String _when(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final local = d.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${months[local.month - 1]} ${local.day}, ${local.year} · $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
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
                      const SectionTitle(title: 'Events & meetups'),
                      if (_items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No events yet. Create the first one.',
                              style: TextStyle(color: AppColors.muted)),
                        ),
                      ..._items.map((e) => Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 52,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          color: AppColors.accent.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Icon(
                                            e.isOnline ? Icons.language : Icons.event,
                                            color: AppColors.accent),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(e.title,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w800)),
                                            Text(
                                                '${_when(e.startsAt)}'
                                                '${e.sdg != null ? " · SDG ${e.sdg}" : ""}',
                                                style: const TextStyle(
                                                    color: AppColors.muted, fontSize: 12)),
                                            Text(
                                                e.isOnline
                                                    ? 'Online${e.linkUrl != null ? " · link available" : ""}'
                                                    : (e.location ?? ''),
                                                style: const TextStyle(
                                                    color: AppColors.muted, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (e.description != null && e.description!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: Text(e.description!,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: Colors.white70, fontSize: 13)),
                                    ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text('${e.attendeesCount} going',
                                          style: const TextStyle(
                                              color: AppColors.muted, fontSize: 12)),
                                      const Spacer(),
                                      if (e.attending && e.linkUrl != null)
                                        TextButton.icon(
                                          onPressed: () async {
                                            final uri = Uri.tryParse(e.linkUrl!);
                                            if (uri != null) {
                                              await launchUrl(uri,
                                                  mode: LaunchMode.externalApplication);
                                            }
                                          },
                                          icon: const Icon(Icons.open_in_new, size: 16),
                                          label: const Text('Join online'),
                                        ),
                                      TextButton(
                                        onPressed: () => _join(e),
                                        child: Text(e.attending ? 'Going' : 'Join'),
                                      ),
                                    ],
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
