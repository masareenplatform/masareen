import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/models.dart';

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
    setState(() => _loading = true);
    try {
      _items = await AuthApi.notifications(widget.userId);
      if (_items.any((n) => !n.read)) {
        try {
          await AuthApi.markNotificationsRead();
        } catch (_) {}
      }
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _icon(String? t) {
    switch (t) {
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.mode_comment_outlined;
      case 'follow':
        return Icons.person_add;
      case 'coin':
        return Icons.token;
      case 'verify':
        return Icons.verified;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(message: _error, onRetry: () => _load())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _items.isEmpty
                      ? const Center(
                          child: Text('No notifications yet.',
                              style: TextStyle(color: AppColors.muted)))
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final n = _items[i];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.azure.withValues(alpha: 0.15),
                                child: Icon(_icon(n.type),
                                    color: AppColors.azure, size: 18),
                              ),
                              title: Text(n.title,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14)),
                              subtitle: n.body != null
                                  ? Text(n.body!,
                                      style: const TextStyle(
                                          color: AppColors.muted, fontSize: 12))
                                  : null,
                              trailing: n.createdAt != null
                                  ? Text(timeAgo(n.createdAt),
                                      style: const TextStyle(
                                          color: AppColors.muted, fontSize: 11))
                                  : null,
                            );
                          },
                        ),
                ),
    );
  }
}
