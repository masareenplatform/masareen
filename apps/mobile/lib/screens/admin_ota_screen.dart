import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/widgets.dart';

/// Lets admins (and AI agents through the same API) publish an OTA release
/// by writing version/build/url/notes to platform_settings. No redeploy needed.
class AdminOtaScreen extends StatefulWidget {
  final User user;
  const AdminOtaScreen({super.key, required this.user});

  @override
  State<AdminOtaScreen> createState() => _AdminOtaScreenState();
}

class _AdminOtaScreenState extends State<AdminOtaScreen> {
  final _version = TextEditingController();
  final _build = TextEditingController();
  final _url =
      TextEditingController(text: 'https://masareen.com/downloads/masareen.apk');
  final _notes = TextEditingController();
  String _platform = 'android';
  bool _force = false;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _manifest;

  String _t(String key, [String? fallback]) {
    final value = MasarenLocalizations.of(context, key);
    return value == key ? (fallback ?? key) : value;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _version.dispose();
    _build.dispose();
    _url.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await AuthApi.adminSettings();
      final manifest =
          Map<String, dynamic>.from(data['manifest'] as Map? ?? {});
      _applyPlatform(manifest);
      if (mounted) setState(() => _manifest = manifest);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyPlatform(Map<String, dynamic> manifest) {
    final data = Map<String, dynamic>.from(
        manifest[_platform] as Map? ?? <String, dynamic>{});
    _version.text = data['version']?.toString() ?? '';
    _build.text = data['build']?.toString() ?? '';
    _url.text = data['url']?.toString() ??
        'https://masareen.com/downloads/masareen.apk';
    _notes.text = data['notes']?.toString() ?? '';
    _force = manifest['force'] == true;
  }

  void _selectPlatform(String platform) {
    if (_manifest == null) return;
    setState(() {
      _platform = platform;
      _applyPlatform(_manifest!);
    });
  }

  Future<void> _publish() async {
    final version = _version.text.trim();
    final build = int.tryParse(_build.text.trim());
    final url = _url.text.trim();
    if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version)) {
      _snack(_t('ota.invalidVersion', 'Use a version like 0.4.4.'));
      return;
    }
    if (build == null || build < 1) {
      _snack(_t('ota.invalidBuild', 'Build must be a whole number.'));
      return;
    }
    if (!url.startsWith('https://')) {
      _snack(_t('ota.invalidUrl', 'Use a secure https:// download URL.'));
      return;
    }
    setState(() => _busy = true);
    try {
      final response = await AuthApi.publishOta(
        platform: _platform,
        version: version,
        build: build,
        url: url,
        notes: _notes.text.trim(),
        force: _force,
      );
      final manifest =
          Map<String, dynamic>.from(response['manifest'] as Map? ?? {});
      if (mounted) {
        setState(() => _manifest = manifest);
        _snack(_t('ota.published',
            'Update published. Clients will see it on their next check.'));
      }
    } catch (e) {
      if (mounted) {
        _snack(_t('common.failed').replaceAll('{error}', '$e'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final live = _manifest == null
        ? null
        : Map<String, dynamic>.from(
            _manifest!['android'] as Map? ?? <String, dynamic>{});
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('ota.title', 'App updates (OTA)')),
        actions: [
          IconButton(onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(message: _error, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    Text(
                        _t('ota.intro',
                            'Publish a new build without redeploying the Worker. Android clients download and install the APK in place; iOS clients open the download page.'),
                        style: TextStyle(
                            color: cs.onSurfaceVariant, height: 1.45)),
                    const SizedBox(height: 14),
                    if (live != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(
                            '${_t('ota.current', 'Live on Android')}: v${live['version']} (${live['build']})'
                            '${_manifest!['force'] == true ? ' Â· ${_t('ota.forced', 'forced')}' : ''}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 12.5)),
                      ),
                    const SizedBox(height: 16),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                            value: 'android',
                            label: Text(_t('ota.android', 'Android')),
                            icon: const Icon(Icons.android, size: 16)),
                        ButtonSegment(
                            value: 'ios',
                            label: Text(_t('ota.ios', 'iOS')),
                            icon: const Icon(Icons.phone_iphone, size: 16)),
                      ],
                      selected: {_platform},
                      onSelectionChanged: (selected) =>
                          _selectPlatform(selected.first),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _version,
                            decoration: InputDecoration(
                                labelText: _t('ota.version', 'Version'),
                                hintText: '0.4.4'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _build,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                                labelText: _t('ota.build', 'Build'),
                                hintText: '9'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _url,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                          labelText: _t('ota.url', 'Download URL'),
                          hintText:
                              'https://masareen.com/downloads/masareen.apk'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notes,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: InputDecoration(
                          labelText: _t('ota.notes', 'What changed?'),
                          hintText: _t('ota.notesHint',
                              'Fixes, improvements, new features...')),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _force,
                      onChanged: (value) => setState(() => _force = value),
                      title: Text(_t('ota.force', 'Require this update'),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                          _t('ota.forceHint',
                              'Clients cannot dismiss the update prompt.'),
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 12)),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _busy ? null : _publish,
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.system_update_alt, size: 18),
                      label: Text(_t('ota.publish', 'Publish update')),
                    ),
                    const SizedBox(height: 12),
                    Text(
                        _t('ota.agentHint',
                            'Agents can call POST /api/v1/admin/ota with the same fields.'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 11.5)),
                  ],
                ),
    );
  }
}
