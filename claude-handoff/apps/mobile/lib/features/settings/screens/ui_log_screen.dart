import 'package:flutter/material.dart';
import 'package:masaren/core/logging/ui_logger.dart';

/// In-app viewer for the UI event log. Shows the most recent events and lets
/// the user export/copy the full log for debugging or E2E forensics.
class UiLogScreen extends StatelessWidget {
  const UiLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final log = UiLogger.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('App log'),
        actions: [
          IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Clear', onPressed: () => log.clear()),
        ],
      ),
      body: StreamBuilder<UiLogEntry>(
        initialData: null,
        stream: log.stream,
        builder: (context, _) {
          final items = log.entries.reversed.toList();
          if (items.isEmpty) {
            return const Center(child: Text('No events logged yet.', style: TextStyle(color: Colors.grey)));
          }
          return ListView.separated(
            reverse: true,
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final e = items[i];
              final color = e.tag == 'ERROR'
                  ? Colors.red
                  : e.tag == 'NAV' || e.tag == 'SCREEN'
                      ? Colors.blue
                      : Colors.green;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 6), decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(e.line, style: const TextStyle(fontSize: 12.5, fontFamily: 'monospace'))),
                ],
              );
            },
          );
        },
      ),
    );
  }
}



