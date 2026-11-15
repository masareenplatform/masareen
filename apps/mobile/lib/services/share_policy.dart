import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';

/// External sharing is a verified-content privilege. Unverified posts, events,
/// booths or profiles stay inside MASAREEN until a host/admin confirms them.
class SharePolicy {
  static bool post(Post post) => post.verifiedContent;

  static bool event(Event event) => event.activityVerified;

  static bool entityStatus(String? status) {
    final value = (status ?? '').toUpperCase();
    return value == 'APPROVED' || value == 'VERIFIED';
  }

  static void deny(BuildContext context) {
    final localized = MasarenLocalizations.of(context, 'share.verifiedOnly');
    final message = localized == 'share.verifiedOnly'
        ? 'Only verified content can be shared outside MASAREEN.'
        : localized;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  static Future<void> copy(
    BuildContext context, {
    required bool allowed,
    required String text,
    required String confirmation,
  }) async {
    if (!allowed) {
      deny(context);
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(confirmation)));
  }

  static Future<void> copyProfile(
    BuildContext context, {
    required bool allowed,
    required String id,
    required String confirmation,
  }) {
    return copy(
      context,
      allowed: allowed,
      text: 'https://masareen.com/u/${Uri.encodeComponent(id)}',
      confirmation: confirmation,
    );
  }
}
