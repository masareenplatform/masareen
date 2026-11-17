// ignore_for_file: use_build_context_synchronously
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/models.dart';
import 'package:masaren/theme.dart';

class CallsScreen extends StatefulWidget {
  final User user;
  const CallsScreen({super.key, required this.user});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  List<Map<String, dynamic>> _rooms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await AuthApi.calls();
      if (mounted) setState(() => _rooms = rows);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _create() async {
    final title = TextEditingController();
    final reward = TextEditingController(text: '0');
    DateTime? when;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Schedule a call'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 14),
                TextField(
                    controller: reward,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'MRC reward per participant')),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                        context: ctx,
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)));
                    if (d == null) return;
                    final t = await showTimePicker(
                        context: ctx, initialTime: TimeOfDay.now());
                    if (t == null) return;
                    setState(() => when =
                        DateTime(d.year, d.month, d.day, t.hour, t.minute));
                  },
                  icon: const Icon(Icons.event_outlined),
                  label: Text(when == null
                      ? 'Schedule (optional)'
                      : when.toString().substring(0, 16)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Create')),
          ],
        ),
      ),
    );
    if (result != true) return;
    try {
      final room = await AuthApi.createCall({
        'title': title.text.trim(),
        'reward_mrc': double.tryParse(reward.text) ?? 0,
        if (when != null) 'scheduled_at': when!.toUtc().toIso8601String(),
      });
      if (!mounted) return;
      _open(room);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _open(Map<String, dynamic> room) async {
    try {
      await AuthApi.joinCall(room['id'].toString());
    } catch (_) {}
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            CallRoomScreen(roomId: room['id'].toString(), user: widget.user)));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Calls & rooms')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.video_call_outlined),
        label: const Text('Schedule call'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: _rooms.isEmpty
                    ? [
                        const SizedBox(height: 100),
                        Icon(Icons.video_call_outlined,
                            size: 54, color: cs.outline),
                        const SizedBox(height: 12),
                        Center(
                            child: Text('No calls scheduled yet.',
                                style: TextStyle(color: cs.onSurfaceVariant))),
                      ]
                    : _rooms.map((r) {
                        final live = r['status'] == 'LIVE';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  (live ? AppColors.warm : cs.primary)
                                      .withValues(alpha: .12),
                              child: Icon(
                                  live
                                      ? Icons.videocam
                                      : Icons.schedule_outlined,
                                  color: live ? AppColors.warm : cs.primary),
                            ),
                            title: Text(r['title']?.toString() ?? 'Call',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            subtitle: Text(
                                '${r['host_name'] ?? ''} | ${live ? 'Live now' : (r['scheduled_at']?.toString() ?? 'Instant room')}'
                                '${(r['reward_mrc'] ?? 0) > 0 ? ' | ${r['reward_mrc']} MRC reward' : ''}'),
                            trailing: FilledButton(
                                onPressed: () => _open(r),
                                child: Text(live ? 'Join' : 'Open')),
                          ),
                        );
                      }).toList(),
              ),
            ),
    );
  }
}

class CallRoomScreen extends StatefulWidget {
  final String roomId;
  final User user;
  const CallRoomScreen({super.key, required this.roomId, required this.user});

  @override
  State<CallRoomScreen> createState() => _CallRoomScreenState();
}

class _CallRoomScreenState extends State<CallRoomScreen> {
  final _local = RTCVideoRenderer();
  final _remote = RTCVideoRenderer();
  RTCPeerConnection? _pc;
  MediaStream? _stream;
  Timer? _poll;
  String? _remoteId;
  String? _after;
  bool _mic = true;
  bool _cam = true;
  bool _connected = false;
  bool _hasRemoteDescription = false;
  final List<RTCIceCandidate> _pendingIce = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _start().catchError((Object e) {
      if (mounted) setState(() => _error = e.toString());
    });
  }

  Future<void> _start() async {
    await _local.initialize();
    await _remote.initialize();
    final config = await AuthApi.joinCall(widget.roomId);
    final ice = (config['ice_servers'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    _stream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': 'user'},
    });
    _local.srcObject = _stream;
    _pc = await createPeerConnection({
      'iceServers': ice.isEmpty
          ? [
              {'urls': 'stun:stun.l.google.com:19302'},
            ]
          : ice,
    });
    for (final track in _stream!.getTracks()) {
      await _pc!.addTrack(track, _stream!);
    }
    _pc!.onIceCandidate = (c) {
      if (c.candidate != null && _remoteId != null) {
        AuthApi.sendCallSignal(widget.roomId, _remoteId!, 'ice', c.toMap());
      }
    };
    _pc!.onTrack = (e) {
      if (e.streams.isNotEmpty) _remote.srcObject = e.streams[0];
      if (mounted) setState(() => _connected = true);
    };
    _poll = Timer.periodic(const Duration(milliseconds: 1400), (_) => _check());
    _check();
    if (mounted) setState(() {});
  }

  Future<void> _setRemote(RTCSessionDescription description) async {
    await _pc?.setRemoteDescription(description);
    _hasRemoteDescription = true;
    for (final candidate in _pendingIce) {
      await _pc?.addCandidate(candidate);
    }
    _pendingIce.clear();
  }

  Future<void> _check() async {
    try {
      final room = await AuthApi.callRoom(widget.roomId);
      final parts = (room['participants'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((p) =>
              p['left_at'] == null && p['user_id'].toString() != widget.user.id)
          .toList();
      if (parts.isNotEmpty && _remoteId == null) {
        _remoteId = parts.first['user_id'].toString();
        if (widget.user.id.compareTo(_remoteId!) < 0) await _offer();
      }
      final signals = await AuthApi.callSignals(widget.roomId, after: _after);
      for (final s in signals) {
        _after = s['id'].toString();
        final payload = Map<String, dynamic>.from(s['payload'] as Map? ?? {});
        if (s['type'] == 'offer') {
          _remoteId ??= s['from_user'].toString();
          await _setRemote(
              RTCSessionDescription(payload['sdp']?.toString() ?? '', 'offer'));
          final answer = await _pc!.createAnswer();
          await _pc!.setLocalDescription(answer);
          await AuthApi.sendCallSignal(widget.roomId, s['from_user'].toString(),
              'answer', {'sdp': answer.sdp, 'type': answer.type});
        } else if (s['type'] == 'answer') {
          _remoteId ??= s['from_user'].toString();
          await _setRemote(RTCSessionDescription(
              payload['sdp']?.toString() ?? '', 'answer'));
        } else if (s['type'] == 'ice' && payload['candidate'] != null) {
          final candidate = RTCIceCandidate(
              payload['candidate']?.toString(),
              payload['sdpMid']?.toString(),
              (payload['sdpMLineIndex'] as num?)?.toInt());
          if (_hasRemoteDescription) {
            await _pc?.addCandidate(candidate);
          } else {
            _pendingIce.add(candidate);
          }
        }
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _offer() async {
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    if (_remoteId != null) {
      await AuthApi.sendCallSignal(widget.roomId, _remoteId!, 'offer',
          {'sdp': offer.sdp, 'type': offer.type});
    }
  }

  Future<void> _leave() async {
    _poll?.cancel();
    try {
      await AuthApi.leaveCall(widget.roomId);
    } catch (_) {}
    await _pc?.close();
    await _stream?.dispose();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _poll?.cancel();
    _pc?.close();
    _stream?.dispose();
    _local.dispose();
    _remote.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
          title: Text(_connected ? 'Call connected' : 'Connecting...'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white),
      body: Column(
        children: [
          Expanded(
            child: Stack(children: [
              Positioned.fill(
                child: RTCVideoView(_remote,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
              ),
              Positioned(
                right: 16,
                bottom: 16,
                width: 120,
                height: 170,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: RTCVideoView(_local,
                      mirror: true,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                ),
              ),
              if (_error != null)
                Positioned(
                  left: 16,
                  right: 16,
                  top: 16,
                  child: Material(
                    color: Colors.red.shade900,
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Camera or microphone could not start. Check browser permissions and HTTPS.',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton.filledTonal(
                    onPressed: () {
                      for (final t in _stream?.getAudioTracks() ?? []) {
                        t.enabled = !_mic;
                      }
                      setState(() => _mic = !_mic);
                    },
                    icon: Icon(_mic ? Icons.mic : Icons.mic_off),
                  ),
                  IconButton.filledTonal(
                    onPressed: () {
                      for (final t in _stream?.getVideoTracks() ?? []) {
                        t.enabled = !_cam;
                      }
                      setState(() => _cam = !_cam);
                    },
                    icon: Icon(_cam ? Icons.videocam : Icons.videocam_off),
                  ),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: _leave,
                    icon: const Icon(Icons.call_end),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
