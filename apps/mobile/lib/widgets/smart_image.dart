import 'package:flutter/material.dart';

/// Network image with a small decode cache, a loading shimmer and a branded
/// fallback. Used for entity covers and post thumbnails so missing images never
/// leave a blank hole.
class SmartImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final IconData fallbackIcon;
  final Color? accent;
  final int? cacheWidth;

  const SmartImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
    this.fallbackIcon = Icons.image_outlined,
    this.accent,
    this.cacheWidth = 900,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = (url ?? '').trim();
    final fallback = _fallback(context);
    if (trimmed.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.network(
        trimmed,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: cacheWidth,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _shimmer(context);
        },
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }

  Widget _shimmer(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surfaceContainerHighest,
            cs.surfaceContainerHigh,
            cs.surfaceContainerHighest,
          ],
        ),
      ),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: cs.primary.withValues(alpha: 0.5)),
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = accent ?? cs.primary;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.22), cs.surfaceContainerHigh],
        ),
      ),
      child: Center(
        child: Icon(fallbackIcon, color: color.withValues(alpha: 0.8), size: 28),
      ),
    );
  }
}
