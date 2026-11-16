// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

int _viewCounter = 0;

void clearWebAuthHash() {
  try {
    final clear = js.context['masareenClearAuthHash'];
    if (clear != null) js.context.callMethod('masareenClearAuthHash');
  } catch (_) {}
}

String? readWebAuthToken() {
  String? parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final value = raw.startsWith('#') ? raw.substring(1) : raw;
    final token = Uri.splitQueryString(value)['google_token'];
    return token == null || token.isEmpty ? null : token;
  }

  try {
    final startHash = js.context['masareenStartHash'];
    final fromStart = parse(startHash is String ? startHash : null);
    if (fromStart != null) return fromStart;
    final fromHash = parse(Uri.base.fragment);
    if (fromHash != null) return fromHash;
    return Uri.base.queryParameters['google_token'];
  } catch (_) {
    return null;
  }
}

class GoogleSignInButton extends StatefulWidget {
  final Future<void> Function(String credential) onCredential;
  final bool dark;

  const GoogleSignInButton({
    super.key,
    required this.onCredential,
    this.dark = false,
  });

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  late final String _elementId;
  late final String _viewType;
  late final html.DivElement _container;
  StreamSubscription<html.Event>? _credentialSub;
  Timer? _renderTimer;
  bool _requested = false;

  @override
  void initState() {
    super.initState();
    _elementId = 'masareen-google-${_viewCounter++}';
    _viewType = 'masareen-google-view-${_viewCounter++}';
    _container = html.DivElement()
      ..id = _elementId
      ..style.width = '100%'
      ..style.height = '46px'
      ..style.display = 'flex'
      ..style.justifyContent = 'center'
      ..style.alignItems = 'center';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _container,
    );
    _credentialSub = html.document.on['masareen-google-credential-$_elementId']
        .listen(_handleCredential);
    _scheduleRender();
  }

  void _handleCredential(html.Event event) {
    final detail = (event as dynamic).detail;
    if (detail is String && detail.isNotEmpty) {
      widget.onCredential(detail);
    }
  }

  void _scheduleRender() {
    _renderTimer?.cancel();
    _renderTimer = Timer(const Duration(milliseconds: 250), _render);
  }

  void _render() {
    if (!mounted || _requested) return;
    try {
      final render = js.context['masareenRenderGoogle'];
      if (render == null) {
        _renderTimer = Timer(const Duration(milliseconds: 500), _render);
        return;
      }
      js.context.callMethod('masareenRenderGoogle', [
        _elementId,
        widget.dark,
      ]);
      _requested = true;
    } catch (_) {
      _renderTimer = Timer(const Duration(milliseconds: 500), _render);
    }
  }

  @override
  void dispose() {
    _renderTimer?.cancel();
    _credentialSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Center(
        child: SizedBox(
          width: 320,
          child: HtmlElementView(viewType: _viewType),
        ),
      ),
    );
  }
}
