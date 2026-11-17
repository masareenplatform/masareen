import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';

class AppUpdateChannel {
  final String id;
  final String name;
  final String version;
  final int build;
  final String url;
  final String notes;

  const AppUpdateChannel({
    required this.id,
    required this.name,
    required this.version,
    required this.build,
    required this.url,
    required this.notes,
  });

  factory AppUpdateChannel.fromJson(Map<String, dynamic> j) => AppUpdateChannel(
    id: j['id']?.toString() ?? '',
    name: j['name']?.toString() ?? 'MASAREEN',
    version: j['version']?.toString() ?? '',
    build: (j['build'] as num?)?.toInt() ?? 0,
    url: j['url']?.toString() ?? '',
    notes: j['notes']?.toString() ?? '',
  );
}

class AppUpdateInfo {
  final String version;
  final int build;
  final String url;
  final String notes;
  final int minimumBuild;
  final String otaAppId;
  final bool force;
  final List<AppUpdateChannel> channels;

  const AppUpdateInfo({
    required this.version,
    required this.build,
    required this.url,
    required this.notes,
    required this.minimumBuild,
    required this.otaAppId,
    this.force = false,
    this.channels = const [],
  });
}

/// OTA update flow for builds distributed outside the stores.
///
/// Android: checks /api/app/version, downloads the new APK from R2 and opens
/// the package installer. Android updates the app in place, preserving data.
/// iOS: native code cannot self-install; the manifest is used to prompt and
/// open the download/TestFlight page. Dart-only patches are handled by
/// Shorebird (see shorebird.yaml and the platform guide).
class AppUpdater {
  static Future<AppUpdateInfo?> check() async {
    if (!Platform.isAndroid && !Platform.isIOS) return null;
    final info = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(info.buildNumber) ?? 0;
    final data = await api.get('/api/app/version');
    if (data is! Map) return null;
    final platform = data[Platform.isAndroid ? 'android' : 'ios'];
    if (platform is! Map) return null;
    final build = (platform['build'] as num?)?.toInt() ?? 0;
    if (build <= currentBuild) return null;
    final ota = data['ota'];
    return AppUpdateInfo(
      version: platform['version']?.toString() ?? '',
      build: build,
      url: platform['url']?.toString() ?? '',
      notes: platform['notes']?.toString() ?? '',
      minimumBuild: (data['minimumBuild'] as num?)?.toInt() ?? 0,
      otaAppId: ota is Map ? (ota['appId']?.toString() ?? '') : '',
      force: data['force'] == true,
      channels: (data['channels'] is List)
          ? (data['channels'] as List)
                .whereType<Map>()
                .map(
                  (e) =>
                      AppUpdateChannel.fromJson(Map<String, dynamic>.from(e)),
                )
                .where((c) => c.build > 0 && c.url.isNotEmpty)
                .toList()
          : const [],
    );
  }

  static String _t(BuildContext context, String key, [String? fallback]) {
    final value = MasarenLocalizations.of(context, key);
    return value == key ? (fallback ?? key) : value;
  }

  static Future<void> checkAndPrompt(
    BuildContext context, {
    bool silent = true,
  }) async {
    try {
      final update = await check();
      if (!context.mounted) return;
      if (update == null) {
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _t(
                  context,
                  'update.upToDate',
                  'You already have the latest version.',
                ),
              ),
            ),
          );
        }
        return;
      }
      var selected = update;
      if (Platform.isAndroid && update.channels.length > 1) {
        final choice = await _chooseChannel(context, update);
        if (choice == null || !context.mounted) return;
        selected = choice;
      }
      final body = [
        _t(
          context,
          'update.body',
          'A new version ({version}) is ready. Updating keeps your data and does not require the app store.',
        ).replaceAll('{version}', selected.version),
        if (selected.notes.isNotEmpty) '\n${selected.notes}',
        if (Platform.isIOS)
          '\n${_t(context, 'update.iosHint', 'On iOS, open the download page to install the new build; Dart-only patches apply automatically on the next launch.')}',
      ].join('\n');
      final go = await showDialog<bool>(
        context: context,
        barrierDismissible: !selected.force,
        builder: (c) => PopScope(
          canPop: !selected.force,
          child: AlertDialog(
            title: Text(_t(context, 'update.title', 'Update available')),
            content: Text(body),
            actions: [
              if (!selected.force)
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: Text(_t(context, 'update.later', 'Later')),
                ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(_t(context, 'update.now', 'Update now')),
              ),
            ],
          ),
        ),
      );
      if (go != true || !context.mounted) return;
      if (Platform.isAndroid) {
        await _installAndroid(context, selected);
      } else {
        await _openIos(context, selected);
      }
    } catch (e) {
      if (!silent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(context, 'common.failed').replaceAll('{error}', '$e'),
            ),
          ),
        );
      }
    }
  }

  static Future<AppUpdateInfo?> _chooseChannel(
    BuildContext context,
    AppUpdateInfo update,
  ) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final chosen = await showDialog<AppUpdateChannel>(
      context: context,
      barrierDismissible: !update.force,
      builder: (c) => SimpleDialog(
        title: Text(isArabic ? 'اختر إصدار MASAREEN' : 'Choose MASAREEN'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
            child: Text(
              isArabic
                  ? 'الإصدار الرسمي أو الإصدار التجريبي بالتصميم الجديد. يمكنك تثبيت الاثنين معاً.'
                  : 'Install the production app, the experimental visual direction, or both side by side.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Theme.of(c).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final channel in update.channels)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, channel),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        c,
                      ).colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      channel.id == 'next'
                          ? Icons.auto_awesome_outlined
                          : Icons.verified_outlined,
                      color: Theme.of(c).colorScheme.primary,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          channel.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${channel.version} · build ${channel.build}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(c).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (channel.notes.isNotEmpty)
                          Text(
                            channel.notes,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Theme.of(c).colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(c).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          if (!update.force)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text(isArabic ? 'لاحقاً' : 'Later'),
              ),
            ),
        ],
      ),
    );
    if (chosen == null) return null;
    return AppUpdateInfo(
      version: chosen.version,
      build: chosen.build,
      url: chosen.url,
      notes: chosen.notes,
      minimumBuild: update.minimumBuild,
      otaAppId: update.otaAppId,
      force: update.force,
    );
  }

  static Future<void> _installAndroid(
    BuildContext context,
    AppUpdateInfo update,
  ) async {
    if (update.url.isEmpty) return;
    try {
      final status = await Permission.requestInstallPackages.status;
      if (status.isDenied) {
        await Permission.requestInstallPackages.request();
      }
    } catch (_) {}
    if (!context.mounted) return;

    final progress = ValueNotifier<double>(0);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          content: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (_, value, __) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t(
                    context,
                    'update.downloading',
                    'Downloading the update...',
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: value <= 0 ? null : value),
              ],
            ),
          ),
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/masareen-${update.version}.apk');
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(update.url));
      final response = await client.send(request);
      final total = response.contentLength ?? 0;
      final sink = file.openWrite();
      var received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) progress.value = (received / total).clamp(0.0, 1.0);
      }
      await sink.close();
    } finally {
      client.close();
      progress.dispose();
    }
    if (context.mounted &&
        Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    final result = await OpenFilex.open(file.path);
    if (context.mounted && result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              context,
              'update.installHint',
              'Allow installing apps from MASAREEN when Android asks, then open the downloaded file.',
            ),
          ),
        ),
      );
    }
  }

  static Future<void> _openIos(
    BuildContext context,
    AppUpdateInfo update,
  ) async {
    final uri = Uri.tryParse(update.url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              context,
              'update.iosManual',
              'Open masareen.com to install the new build.',
            ),
          ),
        ),
      );
    }
  }
}
