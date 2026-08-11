import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:masaren/di/injection.dart';
import 'package:masaren/services/api_service.dart';
import 'package:masaren/core/settings/app_settings.dart';
import 'package:masaren/core/theme/masaren_theme.dart';
import 'package:masaren/core/feedback/feedback_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _haptics;
  late bool _sound;
  late bool _reduced;
  late ThemeMode _mode;

  @override
  void initState() {
    super.initState();
    final s = AppSettings.instance;
    _haptics = s.hapticsEnabled.value;
    _sound = s.soundEnabled.value;
    _reduced = s.reducedMotion.value;
    _mode = s.themeMode.value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Container(
        decoration: MasarenTheme.background,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionTitle('Appearance'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Theme', style: TextStyle(fontWeight: FontWeight.w700, color: MasarenTheme.ink)),
                    const SizedBox(height: 10),
                    SegmentedButton<ThemeMode>(
                      selected: {_mode},
                      onSelectionChanged: (set) async {
                        final m = set.first;
                        await AppSettings.instance.setThemeMode(m);
                        setState(() => _mode = m);
                      },
                      segments: const [
                        ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('Light')),
                        ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('Dark')),
                        ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded), label: Text('Auto')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            _SectionTitle('Reactions & feedback'),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.vibration_rounded, color: MasarenTheme.brand),
                    title: const Text('Haptic feedback'),
                    subtitle: const Text('Vibrate on likes & taps'),
                    value: _haptics,
                    onChanged: (v) async {
                      await AppSettings.instance.toggleHaptics(v);
                      setState(() => _haptics = v);
                      if (v) FeedbackService.instance.tap();
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.volume_up_rounded, color: MasarenTheme.brand),
                    title: const Text('Reaction sounds'),
                    subtitle: const Text('Play a pop when you react'),
                    value: _sound,
                    onChanged: (v) async {
                      await AppSettings.instance.toggleSound(v);
                      setState(() => _sound = v);
                      if (v) FeedbackService.instance.success();
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.motion_photos_off_rounded, color: MasarenTheme.brand),
                    title: const Text('Reduce motion'),
                    subtitle: const Text('Calmer, lighter animations'),
                    value: _reduced,
                    onChanged: (v) async {
                      await AppSettings.instance.toggleReducedMotion(v);
                      setState(() => _reduced = v);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SectionTitle('Diagnostics'),
            Card(
              child: ListTile(
                leading: const Icon(Icons.terminal_rounded, color: MasarenTheme.brand),
                title: const Text('App log'),
                subtitle: const Text('See everything that happened in the UI'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.go('/log'),
              ),
            ),
            const SizedBox(height: 18),
            _SectionTitle('Account'),
            Card(
              child: ListTile(
                leading: const Icon(Icons.logout_rounded, color: MasarenTheme.accent),
                title: const Text('Sign out', style: TextStyle(color: MasarenTheme.accent, fontWeight: FontWeight.w600)),
                onTap: () async {
                  await getIt<ApiService>().logout();
                  if (mounted) context.go('/login');
                },
              ),
            ),
            const SizedBox(height: 24),
            Center(child: Text('MASAREEN · v0.1.0', style: TextStyle(color: MasarenTheme.muted, fontSize: 12))),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MasarenTheme.muted, letterSpacing: 1.2)),
      );
}



