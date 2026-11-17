import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:masaren/widgets.dart';

class VoiceRecording {
  final String path;
  final String name;
  final Duration duration;
  const VoiceRecording(
      {required this.path, required this.name, required this.duration});
}

Future<VoiceRecording?> showVoiceRecorder(BuildContext context) {
  return showModalBottomSheet<VoiceRecording>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _VoiceRecorderSheet(),
  );
}

class _VoiceRecorderSheet extends StatefulWidget {
  const _VoiceRecorderSheet();

  @override
  State<_VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends State<_VoiceRecorderSheet> {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _ampSub;
  Timer? _timer;
  bool _recording = false;
  bool _paused = false;
  bool _starting = false;
  double _amplitude = 0;
  Duration _duration = Duration.zero;
  String? _path;
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    _ampSub?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        throw Exception('Microphone permission is required to record a voice note.');
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/masareen_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: path,
      );
      _path = path;
      setState(() {
        _recording = true;
        _paused = false;
        _duration = Duration.zero;
      });
      _ampSub?.cancel();
      _ampSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 140))
          .listen((amp) {
        if (!mounted) return;
        final normalized = ((amp.current + 50) / 50).clamp(0.0, 1.0);
        setState(() => _amplitude = normalized);
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_recording || _paused) return;
        setState(() => _duration += const Duration(seconds: 1));
        if (_duration.inSeconds >= 300) _finish();
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _togglePause() async {
    if (!_recording) return;
    if (_paused) {
      await _recorder.resume();
      setState(() => _paused = false);
    } else {
      await _recorder.pause();
      setState(() => _paused = true);
    }
  }

  Future<void> _finish() async {
    if (!_recording) return;
    _timer?.cancel();
    _ampSub?.cancel();
    final path = await _recorder.stop() ?? _path;
    if (!mounted) return;
    setState(() {
      _recording = false;
      _paused = false;
    });
    if (path == null) {
      setState(() => _error = 'The recording could not be saved.');
      return;
    }
    final file = File(path);
    if (!await file.exists() || await file.length() == 0) {
      setState(() => _error = 'The recording is empty. Try again.');
      return;
    }
    if (!mounted) return;
    Navigator.pop(
        context,
        VoiceRecording(
            path: path,
            name: 'voice-note-${_duration.inSeconds}s.m4a',
            duration: _duration));
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    _ampSub?.cancel();
    if (_recording) await _recorder.cancel();
    if (mounted) Navigator.pop(context);
  }

  String get _time {
    final m = _duration.inMinutes.toString().padLeft(2, '0');
    final s = (_duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bars = List.generate(22, (i) {
      final phase = (i * 0.7 + _amplitude * 9).remainder(6.0);
      final height = _recording ? 8.0 + (phase / 6) * 42 : 8.0;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 4,
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: _recording
              ? cs.primary.withValues(alpha: .55 + _amplitude * .45)
              : cs.outlineVariant,
          borderRadius: BorderRadius.circular(3),
        ),
      );
    });
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 14, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.graphic_eq, color: cs.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Voice note',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              IconButton(
                  onPressed: _cancel, icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
              'Echo cancellation, noise suppression and auto gain are on. Tap the mic, speak, then send.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, height: 1.4, color: cs.onSurfaceVariant)),
          const SizedBox(height: 18),
          SizedBox(
            height: 58,
            child: Row(
                mainAxisAlignment: MainAxisAlignment.center, children: bars),
          ),
          const SizedBox(height: 12),
          Text(_time,
              style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()])),
          if (_recording)
            Text(_paused ? 'Paused' : 'Recording · noise filtered',
                style: TextStyle(fontSize: 11, color: cs.primary)),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: cs.error)),
            ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_recording)
                _RoundAction(
                  icon: _starting ? Icons.hourglass_top : Icons.mic,
                  label: 'Record',
                  color: cs.primary,
                  onTap: _starting ? null : _start,
                )
              else ...[
                _RoundAction(
                  icon: _paused ? Icons.play_arrow : Icons.pause,
                  label: _paused ? 'Resume' : 'Pause',
                  color: cs.secondary,
                  onTap: _togglePause,
                ),
                const SizedBox(width: 28),
                _RoundAction(
                  icon: Icons.send,
                  label: 'Send',
                  color: cs.primary,
                  onTap: _finish,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _RoundAction(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Clickable(
          onTap: onTap,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
                color: color, shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: color.withValues(alpha: .25),
                      blurRadius: 18,
                      spreadRadius: 3)
                ]),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
