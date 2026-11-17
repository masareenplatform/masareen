import 'dart:async';

import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlatformPulseBanner extends StatefulWidget {
  const PlatformPulseBanner({super.key});

  @override
  State<PlatformPulseBanner> createState() => _PlatformPulseBannerState();
}

class _PlatformPulseBannerState extends State<PlatformPulseBanner> {
  Timer? _timer;
  Timer? _hideTimer;
  Announcement? _announcement;
  Event? _event;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 6), _load);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final announcements = await AuthApi.announcements();
      for (final a in announcements) {
        if (a.dismissed) continue;
        if (prefs.getBool('next_pulse_seen_${a.id}') == true) continue;
        _announcement = a;
        break;
      }
      if (_announcement == null) {
        final events = await AuthApi.events();
        final now = DateTime.now();
        events.sort((a, b) => a.startsAt.compareTo(b.startsAt));
        for (final e in events) {
          final at = DateTime.tryParse(e.startsAt);
          if (at == null || at.isBefore(now)) continue;
          if (at.isAfter(now.add(const Duration(days: 45)))) continue;
          if (prefs.getBool('next_pulse_seen_event_${e.id}') == true) continue;
          _event = e;
          break;
        }
      }
      if (!mounted) return;
      if (_announcement == null && _event == null) return;
      setState(() => _visible = true);
      _hideTimer = Timer(const Duration(seconds: 12), _dismiss);
    } catch (_) {}
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    setState(() => _visible = false);
    final prefs = await SharedPreferences.getInstance();
    if (_announcement != null) {
      await prefs.setBool('next_pulse_seen_${_announcement!.id}', true);
    }
    if (_event != null) {
      await prefs.setBool('next_pulse_seen_event_${_event!.id}', true);
    }
  }

  Future<void> _open() async {
    final a = _announcement;
    final e = _event;
    if (a == null && e == null) return;
    await _dismiss();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(a?.title ?? e?.title ?? 'MASAREEN'),
        content: Text(
          a?.body ?? '${e?.description ?? ''}\n\n${_formatDate(e?.startsAt)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? raw) {
    final at = DateTime.tryParse(raw ?? '');
    if (at == null) return '';
    final local = at.toLocal();
    return '${local.year}/${local.month}/${local.day}  '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEvent = _event != null && _announcement == null;
    final title = _announcement?.title ?? _event?.title ?? '';
    final body =
        _announcement?.body ?? (isEvent ? _formatDate(_event?.startsAt) : '');
    return IgnorePointer(
      ignoring: !_visible,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        offset: _visible ? Offset.zero : const Offset(0, -1.2),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 260),
          opacity: _visible ? 1 : 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _open,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.38),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: cs.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(
                            isEvent
                                ? Icons.event_available_outlined
                                : Icons.auto_awesome_outlined,
                            size: 20,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEvent ? 'Platform event' : 'From MASAREEN',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w800,
                                  color: cs.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (body.isNotEmpty)
                                Text(
                                  body,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _dismiss,
                          icon: Icon(
                            Icons.close,
                            size: 18,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PulseSurveyHost extends StatefulWidget {
  const PulseSurveyHost({super.key});

  @override
  State<PulseSurveyHost> createState() => _PulseSurveyHostState();
}

class _PulseSurveyHostState extends State<PulseSurveyHost> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 16), _maybeShow);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _maybeShow() async {
    if (!mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt('next_survey_prompt_at') ?? 0;
      if (DateTime.now().millisecondsSinceEpoch - last <
          const Duration(days: 3).inMilliseconds) {
        return;
      }
      final survey = await AuthApi.pulseSurvey();
      if (survey == null || !mounted) return;
      await prefs.setInt(
        'next_survey_prompt_at',
        DateTime.now().millisecondsSinceEpoch,
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _SurveySheet(survey: survey),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _SurveySheet extends StatefulWidget {
  final Map<String, dynamic> survey;
  const _SurveySheet({required this.survey});

  @override
  State<_SurveySheet> createState() => _SurveySheetState();
}

class _SurveySheetState extends State<_SurveySheet> {
  String? _answer;
  bool _busy = false;
  bool _done = false;
  String? _error;

  Future<void> _submit() async {
    if (_answer == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await AuthApi.answerPulseSurvey(
        widget.survey['id'].toString(),
        _answer!,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _done = true;
      });
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '+${result['reward_mrc'] ?? widget.survey['reward_mrc']} MRC added to your wallet',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final options = (widget.survey['options'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    final reward = widget.survey['reward_mrc'] ?? 0;
    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: _done
                ? Column(
                    key: const ValueKey('done'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.4, end: 1),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutBack,
                        builder: (_, value, child) =>
                            Transform.scale(scale: value, child: child),
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: cs.primary.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 42,
                            color: cs.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Thank you',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your answer helps shape MASAREEN. Reward: $reward MRC',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  )
                : Column(
                    key: const ValueKey('form'),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: cs.secondary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: cs.secondary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              'EMA · +$reward MRC',
                              style: TextStyle(
                                color: cs.secondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.survey['title']?.toString() ?? 'Quick question',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.survey['question']?.toString() ?? '',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13.5,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (final option in options)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => setState(() => _answer = option),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: _answer == option
                                    ? cs.primary.withValues(alpha: 0.12)
                                    : cs.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _answer == option
                                      ? cs.primary
                                      : cs.outlineVariant,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _answer == option
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    size: 19,
                                    color: _answer == option
                                        ? cs.primary
                                        : cs.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      option,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _error!,
                            style: TextStyle(color: cs.error, fontSize: 11.5),
                          ),
                        ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _answer == null || _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Send answer'),
                      ),
                      const SizedBox(height: 2),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Maybe later'),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
