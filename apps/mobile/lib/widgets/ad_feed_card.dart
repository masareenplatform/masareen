import 'dart:async';

import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';

class AdFeedCard extends StatefulWidget {
  final Campaign campaign;
  const AdFeedCard({super.key, required this.campaign});

  @override
  State<AdFeedCard> createState() => _AdFeedCardState();
}

class _AdFeedCardState extends State<AdFeedCard> {
  Timer? _timer;
  bool _impressionTracked = false;

  Creative? get _creative => widget.campaign.primaryCreative;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onVisibility(VisibilityInfo info) {
    if (_impressionTracked) return;
    if (info.visibleFraction >= 0.6) {
      _timer ??= Timer(const Duration(milliseconds: 1200), _trackImpression);
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _trackImpression() {
    _timer = null;
    if (_impressionTracked) return;
    _impressionTracked = true;
    unawaited(_sendEvent('impression'));
  }

  Future<void> _sendEvent(String type) async {
    final creative = _creative;
    if (creative?.id == null) return;
    try {
      await AuthApi.recordAdEvent(
        widget.campaign.id,
        type: type,
        creativeId: creative!.id,
      );
    } catch (_) {}
  }

  Future<void> _openCta() async {
    final creative = _creative;
    final cta = creative?.ctaUrl;
    if (creative == null || cta == null || cta.isEmpty) return;
    if (!_impressionTracked) _trackImpression();
    unawaited(_sendEvent('click'));
    final uri = Uri.tryParse(cta);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final creative = _creative;
    if (creative == null) return const SizedBox.shrink();
    final cta = creative.ctaUrl;
    return VisibilityDetector(
      key: ValueKey('ad-${widget.campaign.id}'),
      onVisibilityChanged: _onVisibility,
      child: Card(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      MasarenLocalizations.of(context, 'ads.sponsored'),
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.campaign.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(Icons.more_horiz, size: 18, color: cs.onSurfaceVariant),
                ],
              ),
            ),
            _CreativeMedia(creative: creative),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    creative.title,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (creative.body != null && creative.body!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      creative.body!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (cta != null && cta.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openCta,
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: Text(
                          creative.ctaLabel ??
                              MasarenLocalizations.of(context, 'ads.learnMore'),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreativeMedia extends StatelessWidget {
  final Creative creative;
  const _CreativeMedia({required this.creative});

  @override
  Widget build(BuildContext context) {
    if (creative.isText || creative.mediaUrl == null) {
      return Container(
        height: 130,
        width: double.infinity,
        decoration: const BoxDecoration(gradient: brandGradient),
        child: const Center(
          child: Icon(Icons.auto_awesome, color: Colors.white54, size: 36),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: creative.isVideo
          ? Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  creative.mediaUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: AppColors.darkSurface2),
                ),
                const Center(
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.black54,
                    child:
                        Icon(Icons.play_arrow, color: Colors.white, size: 32),
                  ),
                ),
              ],
            )
          : Image.network(
              creative.mediaUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
    );
  }
}
