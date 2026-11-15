import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/screens/messages_screen.dart';
import 'package:masaren/screens/opportunities_screen.dart';
import 'package:masaren/services/app_link_router.dart';
import 'package:masaren/services/notification_service.dart';
import 'package:masaren/services/polling_service.dart';
import 'package:masaren/widgets.dart';

class NotificationsScreen extends StatefulWidget {
  final String userId;
  const NotificationsScreen({super.key, required this.userId});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final items = await AuthApi.notifications(widget.userId);
      var markedRead = false;
      if (items.any((n) => !n.read)) {
        try {
          await AuthApi.markNotificationsRead();
          markedRead = true;
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _items = items
            .map((n) => AppNotification(
                  id: n.id,
                  type: n.type,
                  title: n.title,
                  body: n.body,
                  read: markedRead || n.read,
                  createdAt: n.createdAt,
                  link: n.link,
                  entityType: n.entityType,
                  entityId: n.entityId,
                ))
            .toList();
        _error = null;
        _loading = false;
      });
      if (markedRead) NotificationService.instance.setBadgeCount(0);
      PollingService.instance.refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markAll() async {
    try {
      await AuthApi.markNotificationsRead();
      if (!mounted) return;
      setState(() {
        _items = _items
            .map((n) => AppNotification(
                  id: n.id,
                  type: n.type,
                  title: n.title,
                  body: n.body,
                  read: true,
                  createdAt: n.createdAt,
                  link: n.link,
                  entityType: n.entityType,
                  entityId: n.entityId,
                ))
            .toList();
      });
      NotificationService.instance.setBadgeCount(0);
      PollingService.instance.refresh();
    } catch (_) {}
  }

  Future<void> _open(AppNotification item) async {
    try {
      if (!item.read) await AuthApi.markNotificationRead(item.id);
    } catch (_) {}
    final link = item.link ?? '';
    if (link.isNotEmpty) {
      await AppLinkRouter.handle(link);
      return;
    }
    final type = item.type ?? '';
    if (type == 'message') {
      try {
        final me = await AuthApi.me();
        if (!mounted) return;
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => MessagesScreen(user: me)));
      } catch (_) {}
      return;
    }
    if (type.startsWith('opportunity')) {
      try {
        final me = await AuthApi.me();
        if (!mounted) return;
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => OpportunitiesScreen(user: me)));
      } catch (_) {}
    }
  }

  IconData _icon(String? t) {
    switch (t) {
      case 'like':
        return Icons.favorite;
      case 'comment':
      case 'comment_like':
        return Icons.mode_comment_outlined;
      case 'follow':
        return Icons.person_add_alt_1;
      case 'coin':
        return Icons.token;
      case 'verify':
        return Icons.verified;
      case 'message':
        return Icons.forum_outlined;
      case 'opportunity':
      case 'opportunity_match':
        return Icons.work_outline;
      case 'event':
        return Icons.event_outlined;
      case 'program':
        return Icons.hub_outlined;
      case 'task':
        return Icons.checklist;
      case 'project':
        return Icons.handshake_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(MasarenLocalizations.of(context, 'notifications.title')),
        actions: [
          if (_items.any((n) => !n.read))
            TextButton(
              onPressed: _markAll,
              child: Text(
                  MasarenLocalizations.of(context, 'notifications.markAll')),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(message: _error, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _items.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.55),
                            Icon(Icons.notifications_none,
                                size: 54, color: cs.onSurfaceVariant),
                            const SizedBox(height: 12),
                            Center(
                              child: Text(
                                MasarenLocalizations.of(
                                    context, 'notifications.empty'),
                                style: TextStyle(
                                    color: cs.onSurfaceVariant, fontSize: 14),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: cs.outlineVariant.withValues(alpha: 0.4)),
                          itemBuilder: (_, i) {
                            final n = _items[i];
                            return ListTile(
                              onTap: () => _open(n),
                              tileColor: n.read
                                  ? null
                                  : cs.primaryContainer.withValues(alpha: 0.28),
                              leading: CircleAvatar(
                                backgroundColor:
                                    cs.primary.withValues(alpha: 0.12),
                                child: Icon(_icon(n.type),
                                    color: cs.primary, size: 18),
                              ),
                              title: Text(n.title,
                                  style: TextStyle(
                                      color: cs.onSurface,
                                      fontSize: 14,
                                      fontWeight: n.read
                                          ? FontWeight.w500
                                          : FontWeight.w600)),
                              subtitle: n.body != null
                                  ? Text(n.body!,
                                      style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 12))
                                  : null,
                              trailing: n.createdAt != null
                                  ? Text(timeAgo(n.createdAt, context: context),
                                      style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 11))
                                  : null,
                            );
                          },
                        ),
                ),
    );
  }
}
