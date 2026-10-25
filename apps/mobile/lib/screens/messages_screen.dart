import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/screens/profile_view_screen.dart';
import 'package:masaren/widgets.dart';

class MessagesScreen extends StatefulWidget {
  final User user;
  const MessagesScreen({super.key, required this.user});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Conversation> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await AuthApi.conversations();
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _openChat(Conversation c) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatScreen(conversation: c, user: widget.user)));
    _load();
  }

  Future<void> _newMessage() async {
    final peer = await showModalBottomSheet<Author>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _NewMessageSheet(),
    );
    if (peer == null) return;
    try {
      final c = await AuthApi.openConversation(peer.id);
      if (!mounted) return;
      await _openChat(c);
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
    final loc = (String key) => MasarenLocalizations.of(context, key);
    return Scaffold(
      appBar: AppBar(title: Text(loc('messages.title'))),
      floatingActionButton: FloatingActionButton(
        onPressed: _newMessage,
        tooltip: loc('messages.newMessage'),
        child: const Icon(Icons.edit_outlined),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(message: _error, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _items.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 120),
                          Icon(Icons.forum_outlined,
                              size: 56, color: cs.outline),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(loc('messages.empty'),
                                style: TextStyle(color: cs.onSurfaceVariant)),
                          ),
                        ])
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: cs.outlineVariant),
                          itemBuilder: (_, i) {
                            final c = _items[i];
                            return ListTile(
                              leading: AppAvatar(
                                  name: c.peer.name,
                                  url: c.peer.avatarUrl,
                                  size: 46),
                              title: Row(children: [
                                Expanded(
                                  child: Text(c.peer.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                ),
                                if (c.lastMessageAt != null)
                                  Text(timeAgo(c.lastMessageAt),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: cs.onSurfaceVariant)),
                              ]),
                              subtitle: Text(c.lastMessage ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: c.unreadCount > 0
                                          ? cs.onSurface
                                          : cs.onSurfaceVariant,
                                      fontWeight: c.unreadCount > 0
                                          ? FontWeight.w600
                                          : FontWeight.normal)),
                              trailing: c.unreadCount > 0
                                  ? Badge(label: Text('${c.unreadCount}'))
                                  : null,
                              onTap: () => _openChat(c),
                            );
                          },
                        ),
                ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final Conversation conversation;
  final User user;
  const ChatScreen({super.key, required this.conversation, required this.user});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctl = TextEditingController();
  final _scroll = ScrollController();
  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final thread = await AuthApi.conversation(widget.conversation.id);
      if (!mounted) return;
      setState(() {
        _messages = thread.messages;
        _loading = false;
      });
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _ctl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final m = await AuthApi.sendMessage(widget.conversation.id, text);
      _ctl.clear();
      if (!mounted) return;
      setState(() => _messages = [..._messages, m]);
      _scrollToEnd();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final peer = widget.conversation.peer;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ProfileViewScreen(
                  userId: peer.id, currentUser: widget.user))),
          child: Row(children: [
            AppAvatar(name: peer.name, url: peer.avatarUrl, size: 34),
            const SizedBox(width: 10),
            Expanded(
                child: Text(peer.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ),
      ),
      body: Column(children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      return Align(
                        alignment: m.mine
                            ? AlignmentDirectional.centerEnd
                            : AlignmentDirectional.centerStart,
                        child: Container(
                          constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.78),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: m.mine
                                ? cs.primary
                                : cs.surfaceContainerHighest,
                            borderRadius: BorderRadiusDirectional.only(
                              topStart: const Radius.circular(16),
                              topEnd: const Radius.circular(16),
                              bottomStart: Radius.circular(m.mine ? 16 : 4),
                              bottomEnd: Radius.circular(m.mine ? 4 : 16),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.body,
                                  style: TextStyle(
                                      color:
                                          m.mine ? cs.onPrimary : cs.onSurface,
                                      height: 1.35)),
                              if (m.createdAt != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(timeAgo(m.createdAt),
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: (m.mine
                                                  ? cs.onPrimary
                                                  : cs.onSurfaceVariant)
                                              .withValues(alpha: 0.7))),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: cs.outlineVariant)),
            ),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctl,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: MasarenLocalizations.of(
                        context, 'messages.placeholder'),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _NewMessageSheet extends StatefulWidget {
  const _NewMessageSheet();

  @override
  State<_NewMessageSheet> createState() => _NewMessageSheetState();
}

class _NewMessageSheetState extends State<_NewMessageSheet> {
  final _ctl = TextEditingController();
  List<Author> _people = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _search(String value) async {
    final q = value.trim();
    if (q.length < 2) return;
    setState(() => _loading = true);
    try {
      final result = await AuthApi.search(q);
      if (!mounted) return;
      setState(() {
        _people = result.users;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(MasarenLocalizations.of(context, 'messages.newMessage'),
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
          controller: _ctl,
          autofocus: true,
          onChanged: _search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: MasarenLocalizations.of(context, 'search.hint'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_error!, style: TextStyle(color: cs.error)),
          ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 340),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _people.length,
            itemBuilder: (_, i) {
              final p = _people[i];
              return ListTile(
                leading: AppAvatar(name: p.name, url: p.avatarUrl, size: 38),
                title: Text(p.name),
                subtitle: p.handle == null ? null : Text('@${p.handle}'),
                onTap: () => Navigator.pop(context, p),
              );
            },
          ),
        ),
      ]),
    );
  }
}
