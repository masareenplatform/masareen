import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// App-wide UI event logger.
///
/// Every meaningful interaction (screen open, tap, navigation, errors) is
/// recorded with a timestamp to an in-memory ring buffer AND appended to a
/// file on disk, so the exact sequence of what happened in the UI can be
/// inspected later (e.g. from the in-app "App log" screen) for debugging and
/// E2E forensics.
class UiLogger {
  static final UiLogger instance = UiLogger._();
  static const int _maxMemory = 500;

  final List<UiLogEntry> _buffer = [];
  final StreamController<UiLogEntry> _stream = StreamController.broadcast();
  File? _file;
  bool _ready = false;

  UiLogger._();

  Stream<UiLogEntry> get stream => _stream.stream;
  List<UiLogEntry> get entries => List.unmodifiable(_buffer);

  Future<void> init() async {
    if (_ready) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File('${dir.path}/MASAREEN_ui_log.txt');
      if (!await _file!.exists()) await _file!.create();
    } catch (_) {
      _file = null;
    }
    _ready = true;
  }

  void log(String tag, String message) {
    final entry = UiLogEntry(
      time: DateTime.now(),
      tag: tag,
      message: message,
    );
    _buffer.add(entry);
    if (_buffer.length > _maxMemory) _buffer.removeAt(0);
    _stream.add(entry);
    _file?.writeAsStringSync('${entry.line}\n', mode: FileMode.append, flush: true);
  }

  void screen(String name) => log('SCREEN', 'open $name');
  void tap(String label) => log('TAP', label);
  void nav(String route) => log('NAV', route);
  void error(String where, Object e) => log('ERROR', '$where: $e');

  Future<String> export() async {
    await init();
    return _file?.readAsStringSync() ?? entries.map((e) => e.line).join('\n');
  }

  void clear() {
    _buffer.clear();
    try {
      _file?.writeAsStringSync('');
    } catch (_) {}
  }
}

class UiLogEntry {
  final DateTime time;
  final String tag;
  final String message;
  UiLogEntry({required this.time, required this.tag, required this.message});
  String get line => '[${time.toIso8601String()}] $tag $message';
}



