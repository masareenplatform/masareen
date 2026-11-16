import 'dart:async';

import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/models.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';

class WebMessengerDock extends StatefulWidget {
  final User user;
  const WebMessengerDock({super.key, required this.user});

  @override
  State<WebMessengerDock> createState() => _WebMessengerDockState();
}

class _WebMessengerDockState extends State<WebMessengerDock> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  List<Conversation> _conversations = [];
  List<ChatMessage> _messages = [];
  Conversation? _active;
  Timer? _poll;
  Timer? _toastTimer;
  bool _open = false;
  bool _loadingThread = false;
  bool _sending = false;
  Conversation? _toastConversation;
  String? _toastText;
  int _lastUnread = 0;

  bool get _ar => Localizations.localeOf(context).languageCode == 'ar';
  String _t(String en, String ar) => _ar ? ar : en;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 12), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _toastTimer?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final rows = await AuthApi.conversations();
      if (!mounted) return;
      final unread = rows.fold<int>(0, (sum, c) => sum + c.unreadCount);
      if (!silent || unread > _lastUnread) {
        final fresh = rows.where((c) => c.unreadCount > 0).toList();
        if (fresh.isNotEmpty && unread > _lastUnread) {
          _showToast(fresh.first);
        }
      }
      _lastUnread = unread;
      setState(() => _conversations = rows);
    } catch (_) {}
  }

  Future<void> _openConversation(Conversation conversation) async {
    setState(() {
      _active = conversation;
      _open = true;
      _loadingThread = true;
      _messages = [];
    });
    await _loadThread(conversation.id);
  }

  Future<void> _loadThread(String id, {bool silent = false}) async {
    try {
      final thread = await AuthApi.conversation(id);
      if (!mounted || _active?.id != id) return;
      setState(() {
        _messages = thread.messages;
        _loadingThread = false;
      });
      if (!silent) _scrollToEnd();
    } catch (_) {
      if (mounted) setState(() => _loadingThread = false);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic);
      }
    });
  }

  Future<void> _send() async {
    final active = _active;
    final text = _controller.text.trim();
    if (active == null || text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final message = await AuthApi.sendMessage(active.id, text);
      if (!mounted) return;
      _controller.clear();
      setState(() => _messages = [..._messages, message]);
      _scrollToEnd();
      _load(silent: true);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showToast(Conversation conversation) {
    setState(() {
      _toastConversation = conversation;
      _toastText = conversation.lastMessage ?? _t('New message', 'رسالة جديدة');
    });
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _toastConversation = null);
    });
  }

  void _closePanel() {
    setState(() {
      _open = false;
      _active = null;
      _messages = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final unread = _conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_toastConversation != null && !_open)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                    offset: Offset(22 * (1 - value), 0), child: child),
              ),
              child: _ToastCard(
                conversation: _toastConversation!,
                text: _toastText ?? '',
                onTap: () => _openConversation(_toastConversation!),
              ),
            ),
          ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              alignment: Alignment.bottomRight,
              scale: Tween(begin: .94, end: 1.0).animate(animation),
              child: child,
            ),
          ),
          child: _open
              ? _panel(context)
              : _chatHead(context, unread),
        ),
      ],
    );
  }

  Widget _chatHead(BuildContext context, int unread) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          setState(() => _open = true);
          _load();
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: brandGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: cs.primary.withValues(alpha: .35),
                      blurRadius: 24,
                      offset: const Offset(0, 8)),
                ],
                border: Border.all(
                    color: cs.surface, width: 3),
              ),
              child: const Icon(Icons.chat_bubble_rounded,
                  color: Colors.white, size: 26),
            ),
            if (unread > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warm,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: cs.surface, width: 2),
                  ),
                  child: Text(unread > 99 ? '99+' : '$unread',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _panel(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = _active;
    return Container(
      width: 360,
      height: 520,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: .24),
              blurRadius: 40,
              offset: const Offset(0, 16)),
        ],
        border: Border.all(color: cs.outlineVariant.withValues(alpha: .7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
            decoration: BoxDecoration(
              gradient: brandGradient,
              border: Border(
                  bottom: BorderSide(
                      color: Colors.white.withValues(alpha: .12))),
            ),
            child: Row(
              children: [
                if (active != null)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _active = null;
                        _messages = [];
                      });
                      _load(silent: true);
                    },
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    visualDensity: VisualDensity.compact,
                  )
                else
                  const Icon(Icons.forum_rounded,
                      color: Colors.white, size: 21),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          active?.peer.name ?? _t('Chats', 'المحادثات'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800)),
                      Text(
                          active != null
                              ? _t('Active now', 'متصل الآن')
                              : _t('Messenger', 'ماسنجر'),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: .68),
                              fontSize: 10)),
                    ],
                  ),
                ),
                Clickable(
                  onTap: () async {
                    final peer = await showModalBottomSheet<Author>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (_) => const _NewChatSheet(),
                    );
                    if (peer == null) return;
                    try {
                      final c = await AuthApi.openConversation(peer.id);
                      if (mounted) _openConversation(c);
                    } catch (_) {}
                  },
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .14),
                        shape: BoxShape.circle),
                    child: const Text('+',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 7),
                Clickable(
                  onTap: _closePanel,
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .14),
                        shape: BoxShape.circle),
                    child: const Text('×',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            height: 1,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: active == null
                ? _conversationList(cs)
                : _threadView(cs, active),
          ),
        ],
      ),
    );
  }

  Widget _conversationList(ColorScheme cs) {
    if (_conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.forum_outlined, size: 42, color: cs.outline),
              const SizedBox(height: 10),
              Text(_t('No conversations yet.', 'لا توجد محادثات بعد.'),
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: _conversations.length,
      separatorBuilder: (_, __) => Divider(
          height: 1, color: cs.outlineVariant.withValues(alpha: .5)),
      itemBuilder: (_, index) {
        final c = _conversations[index];
        final unread = c.unreadCount > 0;
        return InkWell(
          onTap: () => _openConversation(c),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AppAvatar(
                        name: c.peer.name, url: c.peer.avatarUrl, size: 42),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            border: Border.all(color: cs.surface, width: 2)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.peer.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: unread
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: cs.onSurface)),
                      const SizedBox(height: 2),
                      Text(c.lastMessage ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: textDirectionFor(c.lastMessage),
                          style: TextStyle(
                              fontSize: 11,
                              color: unread
                                  ? cs.onSurface
                                  : cs.onSurfaceVariant,
                              fontWeight:
                                  unread ? FontWeight.w600 : FontWeight.w400)),
                    ],
                  ),
                ),
                if (unread)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: AppColors.warm,
                        borderRadius: BorderRadius.circular(99)),
                    child: Text('${c.unreadCount}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _threadView(ColorScheme cs, Conversation active) {
    return Column(
      children: [
        Expanded(
          child: _loadingThread
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: _messages.length,
                  itemBuilder: (_, index) {
                    final m = _messages[index];
                    return Align(
                      alignment: m.mine
                          ? AlignmentDirectional.centerEnd
                          : AlignmentDirectional.centerStart,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 7),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 8),
                        constraints: const BoxConstraints(maxWidth: 270),
                        decoration: BoxDecoration(
                          color: m.mine
                              ? cs.primary
                              : cs.surfaceContainerLow,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(14),
                            topRight: const Radius.circular(14),
                            bottomLeft: Radius.circular(m.mine ? 14 : 4),
                            bottomRight: Radius.circular(m.mine ? 4 : 14),
                          ),
                        ),
                        child: Text(m.body,
                            textDirection: textDirectionFor(m.body),
                            style: TextStyle(
                                color: m.mine ? cs.onPrimary : cs.onSurface,
                                fontSize: 12.5,
                                height: 1.35)),
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 10),
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(
                top: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: .6))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _send(),
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: _t('Write a message...', 'اكتب رسالة...'),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded, size: 17),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToastCard extends StatelessWidget {
  final Conversation conversation;
  final String text;
  final VoidCallback onTap;

  const _ToastCard({
    required this.conversation,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: .18),
                  blurRadius: 28,
                  offset: const Offset(0, 10)),
            ],
            border: Border.all(color: cs.outlineVariant.withValues(alpha: .6)),
          ),
          child: Row(
            children: [
              AppAvatar(
                  name: conversation.peer.name,
                  url: conversation.peer.avatarUrl,
                  size: 36),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(conversation.peer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800)),
                    Text(text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textDirection: textDirectionFor(text),
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewChatSheet extends StatefulWidget {
  const _NewChatSheet();

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> {
  final _search = TextEditingController();
  Timer? _debounce;
  bool _busy = false;
  List<Author> _users = [];

  @override
  void dispose() {
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _run(String value) async {
    if (value.trim().length < 2) {
      setState(() => _users = []);
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await AuthApi.search(value.trim());
      if (mounted) setState(() => _users = result.users.take(20).toList());
    } catch (_) {
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            18, 8, 18, MediaQuery.viewInsetsOf(context).bottom + 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _search,
              autofocus: true,
              decoration: const InputDecoration(
                  hintText: 'Search people...',
                  prefixIcon: Icon(Icons.search)),
              onChanged: (value) {
                _debounce?.cancel();
                _debounce =
                    Timer(const Duration(milliseconds: 300), () => _run(value));
              },
            ),
            const SizedBox(height: 10),
            if (_busy)
              const LinearProgressIndicator(minHeight: 2)
            else if (_users.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Search for someone to message.',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _users
                      .map((u) => ListTile(
                            leading: AppAvatar(
                                name: u.name, url: u.avatarUrl, size: 38),
                            title: Text(u.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            subtitle: Text(u.role ?? ''),
                            onTap: () => Navigator.pop(context, u),
                          ))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
