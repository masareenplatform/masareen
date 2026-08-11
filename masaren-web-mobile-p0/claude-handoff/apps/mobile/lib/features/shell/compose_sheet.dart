import 'package:flutter/material.dart';
import 'package:masaren/core/theme/masaren_theme.dart';
import 'package:masaren/features/feed/feed_store.dart';

/// Instagram/Facebook-style compose sheet. Authoring a post prepends it to the
/// shared [feedStore] optimistically so it appears at the top of the home feed
/// instantly (the same list the mock-gateway data feeds).
class ComposeSheet extends StatefulWidget {
  final String creator;
  const ComposeSheet({super.key, this.creator = 'You'});

  static Future<void> show(BuildContext context, {String creator = 'You'}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MasarenTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ComposeSheet(creator: creator),
    );
  }

  @override
  State<ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<ComposeSheet> {
  final _ctrl = TextEditingController();
  int _sdg = 0;
  final _sdgs = [0, 1, 2, 3, 4, 6, 7, 13, 14, 15];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _post() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    feedStore.addPost(creator: widget.creator, caption: text, sdg: _sdg);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + kb),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: MasarenTheme.line, borderRadius: BorderRadius.circular(999)),
            ),
          ),
          const SizedBox(height: 12),
          Text('Create a post', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: MasarenTheme.ink, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            maxLines: 4,
            minLines: 3,
            decoration: const InputDecoration(
              hintText: "Share your impact with the community…",
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _sdgs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final s = _sdgs[i];
                final sel = s == _sdg;
                return ChoiceChip(
                  label: Text(s == 0 ? 'General' : 'SDG $s'),
                  selected: sel,
                  onSelected: (_) => setState(() => _sdg = s),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _post,
              icon: const Icon(Icons.send_rounded),
              label: const Text('Post'),
            ),
          ),
        ],
      ),
    );
  }
}



