import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/theme.dart';

class FeedbackScreen extends StatefulWidget {
  final User user;
  const FeedbackScreen({super.key, required this.user});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _message = TextEditingController();
  String _type = 'idea';
  int _rating = 4;
  bool _busy = false;

  String _t(String key, [String? fallback]) {
    final value = MasarenLocalizations.of(context, key);
    return value == key ? (fallback ?? key) : value;
  }

  Future<void> _submit() async {
    final text = _message.text.trim();
    if (text.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('feedback.tooShort',
              'Tell us a little more (at least 5 characters).'))));
      return;
    }
    setState(() => _busy = true);
    try {
      await AuthApi.submitFeedback(
          type: _type, message: text, rating: _rating);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('feedback.thanks',
              'Thank you. Your feedback reached the platform team.'))));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_t('common.failed')
                .replaceAll('{error}', '$e'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final types = <(String, String, IconData)>[
      ('idea', _t('feedback.idea', 'Idea'), Icons.lightbulb_outline),
      ('bug', _t('feedback.bug', 'Bug'), Icons.bug_report_outlined),
      ('feature', _t('feedback.feature', 'Feature'), Icons.extension_outlined),
      ('praise', _t('feedback.praise', 'Praise'), Icons.favorite_outline),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(_t('feedback.title', 'Send feedback'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
              _t('feedback.intro',
                  'Help us make MASAREEN better. Your feedback goes directly to the platform team.'),
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.5)),
          const SizedBox(height: 18),
          Text(_t('feedback.type', 'What kind of feedback?'),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in types)
                ChoiceChip(
                  avatar: Icon(type.$3, size: 16),
                  label: Text(type.$2),
                  selected: _type == type.$1,
                  onSelected: (_) => setState(() => _type = type.$1),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(_t('feedback.rating', 'How is your experience?'),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: () => setState(() => _rating = i),
                  icon: Icon(
                      i <= _rating ? Icons.star_rounded : Icons.star_outline,
                      color: AppColors.amber,
                      size: 30),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _message,
            minLines: 5,
            maxLines: 8,
            maxLength: 2000,
            decoration: InputDecoration(
                labelText: _t('feedback.message', 'Your message'),
                hintText: _t('feedback.hint',
                    'What happened? What would you like to see?')),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_outlined, size: 18),
            label: Text(_t('feedback.send', 'Send feedback')),
          ),
          const SizedBox(height: 10),
          Text(_t('feedback.privacy',
              'We read every message. Never include passwords or private keys.'),
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: cs.onSurfaceVariant, fontSize: 11.5)),
          const SizedBox(height: 20),
          Text(
              _t('feedback.account',
                      'Signed in as {email} · {role}')
                  .replaceAll('{email}', widget.user.email)
                  .replaceAll('{role}', widget.user.role),
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: cs.onSurfaceVariant, fontSize: 11.5)),
        ],
      ),
    );
  }
}
