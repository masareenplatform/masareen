import 'package:flutter/material.dart';
import 'package:masaren/core/theme/masaren_theme.dart';

/// Avatar that shows a real image when available and falls back to the
/// person's initial, so the UI never shows the bare alphabet generator when a
/// photo exists.
///
/// URL schemes:
///  * `asset://<path>`  — a bundled Flutter asset (e.g. `asset://avatars/p1.jpg`)
///  * `http(s)://...`   — a remote image (loads with a graceful fallback)
///  * anything else / null — initials placeholder
class AppAvatar extends StatefulWidget {
  final String? url;
  final String name;
  final double radius;
  const AppAvatar({super.key, this.url, required this.name, this.radius = 22});

  @override
  State<AppAvatar> createState() => _AppAvatarState();
}

class _AppAvatarState extends State<AppAvatar> {
  bool _failed = false;

  @override
  Widget build(BuildContext context) {
    final initial = widget.name.isNotEmpty ? widget.name.trim()[0].toUpperCase() : '?';
    final url = widget.url ?? '';
    final lower = url.toLowerCase();
    final useAsset = lower.startsWith('asset://');
    final useNetwork = lower.startsWith('http');
    final showImage = !_failed && (useAsset || useNetwork);

    final fallback = CircleAvatar(
      radius: widget.radius,
      backgroundColor: MasarenTheme.brand.withOpacity(0.15),
      child: Text(initial,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: widget.radius * 0.8,
              color: MasarenTheme.brand)),
    );

    if (showImage && useAsset) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundImage: AssetImage(url.substring('asset://'.length)),
      );
    }
    if (showImage && useNetwork) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) => setState(() => _failed = true),
        child: _failed
            ? Text(initial,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: widget.radius * 0.8,
                    color: MasarenTheme.brand))
            : null,
      );
    }
    return fallback;
  }
}



