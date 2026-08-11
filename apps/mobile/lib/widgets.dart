import 'package:flutter/material.dart';
import 'package:masaren/theme.dart';

class BrandLogo extends StatelessWidget {
  final double height;
  final bool forceWhite;
  const BrandLogo({super.key, this.height = 120, this.forceWhite = false});

  @override
  Widget build(BuildContext context) {
    final dark = forceWhite || Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      dark ? 'assets/images/masaren_logo_white.png' : 'assets/images/masaren_logo_navy.png',
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Text(
        'MASAREEN',
        style: TextStyle(
          fontSize: height * 0.3,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
          letterSpacing: 3,
        ),
      ),
    );
  }
}

class AppAvatar extends StatelessWidget {
  final String name;
  final String? url;
  final double size;
  final VoidCallback? onTap;
  const AppAvatar(
      {super.key, required this.name, this.url, this.size = 44, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final child = url != null && url!.isNotEmpty
        ? CircleAvatar(
            radius: size / 2,
            backgroundImage: NetworkImage(url!),
            backgroundColor: cs.surfaceContainerHighest,
          )
        : Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: brandGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: size * 0.4,
                ),
              ),
            ),
          );
    if (onTap == null) return child;
    return GestureDetector(onTap: onTap, child: child);
  }
}

class ImpactChip extends StatelessWidget {
  final String label;
  final Color color;
  const ImpactChip({super.key, required this.label, this.color = AppColors.azure});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Chip(
      label: Text(label, style: TextStyle(fontSize: 12, color: cs.onSurface)),
      visualDensity: VisualDensity.compact,
      avatar: Icon(Icons.verified, size: 14, color: color),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionTitle({super.key, required this.title, this.action, this.onAction});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
      child: Row(
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: cs.onSurface)),
          const Spacer(),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Text(action!, style: TextStyle(color: cs.primary, fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

Widget gradientButton({
  required String label,
  required VoidCallback onPressed,
  bool outline = false,
}) {
  return SizedBox(
    width: double.infinity,
    height: 50,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: outline ? null : brandGradient,
        borderRadius: BorderRadius.circular(14),
        border: outline ? Border.all(color: AppColors.azure) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: outline ? AppColors.azure : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void showEnlargedImage(BuildContext context, String url) {
  Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: InteractiveViewer(
          child: Center(child: Image.network(url, fit: BoxFit.contain)),
        ),
      ),
    ),
  );
}

String timeAgo(String? iso) {
  if (iso == null) return '';
  try {
    final t = DateTime.parse(iso).toLocal();
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${t.day}/${t.month}/${t.year}';
  } catch (_) {
    return '';
  }
}

class StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;
  const StatTile(
      {super.key, required this.value, required this.label, this.color});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color ?? cs.onSurface,
                 fontWeight: FontWeight.w600,
                 fontSize: 18)),
         const SizedBox(height: 2),
         Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
       ],
     );
   }
 }

class ErrorView extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;
  const ErrorView({super.key, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: cs.outline),
            const SizedBox(height: 16),
            Text('Something went wrong',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (message != null && message!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.outline, fontSize: 13)),
              ),
            if (onRetry != null)
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }
}
