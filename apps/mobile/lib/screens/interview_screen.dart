import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum _CallState { connecting, waiting, connected, error, ended }

class InterviewScreen extends StatefulWidget {
  final String roomId;
  final String userName;
  final bool isInitiator;

  final String signalingUrl;
  final String? turnUsername;
  final String? turnCredential;

  const InterviewScreen({
    super.key,
    required this.roomId,
    required this.userName,
    required this.isInitiator,
    this.signalingUrl = 'wss://turn.mediahubnetwork.net/ws',
    this.turnUsername,
    this.turnCredential,
  });

  @override
  State<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends State<InterviewScreen>
    with SingleTickerProviderStateMixin {
  // ── WebRTC ──────────────────────────────────────────────────────────
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  // ── Signaling ───────────────────────────────────────────────────────
  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;

  // ── State ───────────────────────────────────────────────────────────
  _CallState _state = _CallState.connecting;
  String? _errorMsg;
  bool _muted = false;
  bool _videoOff = false;
  bool _frontCamera = true;

  // ── Waiting animation ───────────────────────────────────────────────
  late AnimationController _pulseCtrl;

  // ── Helpers ─────────────────────────────────────────────────────────
  RTCPeerConnection get _peer => _pc!;
  MediaStream get _local => _localStream!;

  // ====================================================================
  //  Lifecycle
  // ====================================================================

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _init();
  }

  @override
  void dispose() {
    _cleanup();
    _pulseCtrl.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  // ====================================================================
  //  Init sequence
  // ====================================================================

  Future<void> _init() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      await _openMedia();
      await _createPeerConnection();
      _connectSignaling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _CallState.error;
        _errorMsg = e.toString();
      });
    }
  }

  // ====================================================================
  //  Media
  // ====================================================================

  Future<void> _openMedia() async {
    try {
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': _frontCamera ? 'user' : 'environment',
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
      });
      _localStream = stream;
      _localRenderer.srcObject = stream;
    } catch (e) {
      try {
        final stream = await navigator.mediaDevices.getUserMedia({
          'audio': false,
          'video': {
            'facingMode': _frontCamera ? 'user' : 'environment',
          },
        });
        _localStream = stream;
        _localRenderer.srcObject = stream;
      } catch (e2) {
        if (mounted) setState(() => _state = _CallState.error);
      }
    }
  }

  // ====================================================================
  //  Peer Connection
  // ============================================================================

  Map<String, dynamic> get _iceServers => {
        'iceServers': [
          {'urls': 'stun:stun.mediahubnetwork.net:3478'},
          {
            'urls': 'turn:turn.mediahubnetwork.net:3478',
            'username': widget.turnUsername ?? 'masaren',
            'credential':
                widget.turnCredential ?? 'masaren_turn_secret',
          },
        ],
      };

  Future<void> _createPeerConnection() async {
    final pc = await createPeerConnection(_iceServers);

    _localStream?.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams.first;
      }
    };

    pc.onIceCandidate = (candidate) {
      _send({
        'type': 'candidate',
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    pc.onConnectionState = (state) {
      if (!mounted) return;
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        setState(() {
          _state = _CallState.error;
          _errorMsg = 'Peer connection failed';
        });
      } else if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        setState(() => _state = _CallState.connected);
      }
    };

    pc.onIceConnectionState = (state) {
      if (!mounted) return;
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        setState(() => _state = _CallState.connected);
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          state == RTCIceConnectionState.RTCIceConnectionStateClosed) {
        if (_state == _CallState.connected) {
          setState(() {
            _state = _CallState.error;
            _errorMsg = 'Connection lost';
          });
        }
      }
    };

    _pc = pc;
  }

  // ====================================================================
  //  Offer / Answer
  // ============================================================================

  Future<void> _createOffer() async {
    final offer = await _peer.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true,
    });
    await _peer.setLocalDescription(offer);
    _send({'type': 'offer', 'sdp': offer.sdp});
  }

  Future<void> _handleOffer(String sdp) async {
    final remoteDesc = RTCSessionDescription(sdp, 'offer');
    await _peer.setRemoteDescription(remoteDesc);
    final answer = await _peer.createAnswer();
    await _peer.setLocalDescription(answer);
    _send({'type': 'answer', 'sdp': answer.sdp});
  }

  Future<void> _handleAnswer(String sdp) async {
    await _peer.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
  }

  Future<void> _handleCandidate(
      String candidate, String sdpMid, int sdpMLineIndex) async {
    final ice = RTCIceCandidate(candidate, sdpMid, sdpMLineIndex);
    await _peer.addCandidate(ice);
  }

  // ====================================================================
  //  Signaling (WebSocket)
  // ============================================================================

  void _connectSignaling() {
    final uri = Uri.parse(widget.signalingUrl);
    final channel = WebSocketChannel.connect(uri);
    _ws = channel;
    _wsSub = channel.stream.listen(
      (raw) {
        try {
          final msg = jsonDecode(raw as String) as Map<String, dynamic>;
          _onSignal(msg);
        } catch (_) {}
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _state = _CallState.error;
          _errorMsg = 'Signaling error: $error';
        });
      },
      onDone: () {
        if (!mounted) return;
        if (_state == _CallState.connected) {
          setState(() {
            _state = _CallState.error;
            _errorMsg = 'Disconnected from server';
          });
        }
      },
    );

    // Join room
    _send({
      'type': 'join',
      'roomId': widget.roomId,
      'userName': widget.userName,
    });

    // Initiator creates offer after a short delay
    if (widget.isInitiator) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _state != _CallState.ended) _createOffer();
      });
    }

    if (mounted) {
      setState(() =>
          _state = widget.isInitiator ? _CallState.connecting : _CallState.waiting);
    }
  }

  void _onSignal(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;
    switch (type) {
      case 'offer':
        _handleOffer(msg['sdp'] as String);
        break;
      case 'answer':
        _handleAnswer(msg['sdp'] as String);
        break;
      case 'candidate':
        _handleCandidate(
          msg['candidate'] as String,
          msg['sdpMid'] as String,
          (msg['sdpMLineIndex'] as num).toInt(),
        );
        break;
      case 'leave':
        _hangUp();
        break;
    }
  }

  void _send(Map<String, dynamic> msg) {
    _ws?.sink.add(jsonEncode(msg));
  }

  // ====================================================================
  //  Controls
  // ============================================================================

  void _toggleMute() {
    final audioTracks = _local.getAudioTracks();
    for (final t in audioTracks) {
      t.enabled = _muted; // toggle
    }
    setState(() => _muted = !_muted);
  }

  void _toggleVideo() {
    final videoTracks = _local.getVideoTracks();
    for (final t in videoTracks) {
      t.enabled = _videoOff; // toggle
    }
    setState(() => _videoOff = !_videoOff);
  }

  Future<void> _switchCamera() async {
    final videoTracks = _local.getVideoTracks();
    if (videoTracks.isEmpty) return;
    await Helper.switchCamera(videoTracks.first);
    setState(() => _frontCamera = !_frontCamera);
  }

  void _hangUp() {
    _send({'type': 'leave'});
    setState(() => _state = _CallState.ended);
    _cleanup();
    if (mounted) Navigator.of(context).pop();
  }

  // ====================================================================
  //  Cleanup
  // ====================================================================

  Future<void> _cleanup() async {
    try {
      _localStream?.getTracks().forEach((t) async => await t.stop());
      await _pc?.close();
      await _wsSub?.cancel();
      await _ws?.sink.close();
    } catch (_) {}
  }

  // ====================================================================
  //  Build
  // ====================================================================

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: _state == _CallState.ended,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _hangUp();
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Remote video (full-screen) ───────────────────────────
            if (_state == _CallState.connected)
              Positioned.fill(
                child: RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),

            // ── Waiting / connecting / error overlay ─────────────────
            if (_state != _CallState.connected) _buildOverlay(cs),

            // ── Local PIP ───────────────────────────────────────────
            if (_state == _CallState.connected ||
                _state == _CallState.connecting)
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                right: 16,
                child: _buildPip(cs),
              ),

            // ── Controls ─────────────────────────────────────────────
            if (_state == _CallState.connected ||
                _state == _CallState.connecting ||
                _state == _CallState.waiting)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 24,
                left: 0,
                right: 0,
                child: _buildControls(cs),
              ),
          ],
        ),
      ),
    );
  }

  // ── Overlay (waiting / connecting / error / ended) ──────────────────

  Widget _buildOverlay(ColorScheme cs) {
    return Positioned.fill(
      child: Container(
        color: cs.surface,
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_state == _CallState.waiting) _buildPulsingAvatar(cs),
                if (_state == _CallState.connecting)
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: cs.primary,
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  _stateLabel,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                if (_errorMsg != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      _errorMsg!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.error,
                      ),
                    ),
                  ),
                ],
                if (_state == _CallState.ended) ...[
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _stateLabel {
    switch (_state) {
      case _CallState.connecting:
        return 'Connecting\u2026';
      case _CallState.waiting:
        return 'Waiting for other participant\u2026';
      case _CallState.connected:
        return '';
      case _CallState.error:
        return _errorMsg ?? 'Something went wrong';
      case _CallState.ended:
        return 'Call Ended';
    }
  }

  // ── Pulsing avatar (waiting state) ──────────────────────────────────

  Widget _buildPulsingAvatar(ColorScheme cs) {
    final initials = widget.userName.isNotEmpty
        ? widget.userName
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join()
        : '?';

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        final t = _pulseCtrl.value;
        final scale = 1.0 + t * 0.12;
        final opacity = 0.25 + t * 0.25;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary.withValues(alpha: opacity),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primaryContainer,
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: cs.onPrimaryContainer,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Local PIP window ────────────────────────────────────────────────

  Widget _buildPip(ColorScheme cs) {
    return Container(
      width: 130,
      height: 180,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RTCVideoView(
            _localRenderer,
            mirror: _frontCamera,
            objectFit:
                RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          ),
          if (_videoOff)
            Positioned.fill(
              child: Container(
                color: cs.surfaceContainer,
                child: Icon(
                  Icons.videocam_off_rounded,
                  size: 32,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Control buttons ─────────────────────────────────────────────────

  Widget _buildControls(ColorScheme cs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _circleBtn(
          icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
          label: _muted ? 'Unmute' : 'Mute',
          onTap: _toggleMute,
          cs: cs,
        ),
        _circleBtn(
          icon: Icons.call_end_rounded,
          label: 'End',
          onTap: _hangUp,
          cs: cs,
          bg: cs.error,
          fg: cs.onError,
        ),
        _circleBtn(
          icon: Icons.videocam_off_rounded,
          label: _videoOff ? 'Camera On' : 'Camera Off',
          onTap: _toggleVideo,
          cs: cs,
        ),
        _circleBtn(
          icon: Icons.cameraswitch_rounded,
          label: 'Flip',
          onTap: _switchCamera,
          cs: cs,
        ),
      ],
    );
  }

  Widget _circleBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ColorScheme cs,
    Color? bg,
    Color? fg,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: bg ?? cs.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 24, color: fg ?? cs.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
