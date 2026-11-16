// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/screens/gps_history_screen.dart';
import 'package:masaren/services/notification_service.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/theme_provider.dart';
import 'package:masaren/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  final User user;
  final VoidCallback onLogout;
  const SettingsScreen({super.key, required this.user, required this.onLogout});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late User _user = widget.user;
  UserSettings? _settings;
  List<Map<String, dynamic>> _blocked = [];
  bool _loading = true;
  bool _saving = false;
  bool _startupSound = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _t(String key, String fallback) {
    final value = MasarenLocalizations.of(context, key);
    return value == key ? fallback : value;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _startupSound = prefs.getBool('masaren_startup_sound') ?? true;
      final user = await AuthApi.me();
      final settings = await AuthApi.settings();
      List<Map<String, dynamic>> blocked = [];
      try {
        blocked = await AuthApi.blockedUsers();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _user = user;
        _settings = settings;
        _blocked = blocked;
        _error = null;
        _loading = false;
      });
      _configureNotifications(settings);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  void _configureNotifications(UserSettings settings) {
    NotificationService.instance.configure(
      pushEnabled: settings.pushEnabled,
      quietStart: settings.quietStart,
      quietEnd: settings.quietEnd,
    );
  }

  Future<void> _update(Map<String, dynamic> patch) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await AuthApi.updateSettings(patch);
      if (!mounted) return;
      setState(() => _settings = updated);
      _configureNotifications(updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resendVerification() async {
    try {
      final result = await AuthApi.resendVerification();
      final user = await AuthApi.me();
      if (!mounted) return;
      setState(() => _user = user);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['sent'] == false
            ? _t('settings.verifyUnavailable',
                'Email is not configured right now.')
            : _t('settings.verifySent',
                'Confirmation email sent. Check your inbox.')),
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Could not resend email.')));
    } catch (_) {}
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    String? error;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(_t('settings.changePassword', 'Change password')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: current,
                  obscureText: true,
                  decoration: InputDecoration(
                      labelText:
                          _t('settings.currentPassword', 'Current password')),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: next,
                  obscureText: true,
                  decoration: InputDecoration(
                      labelText: _t('settings.newPassword', 'New password')),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirm,
                  obscureText: true,
                  decoration: InputDecoration(
                      labelText:
                          _t('settings.confirmPassword', 'Confirm password')),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!,
                      style: TextStyle(
                          color: Theme.of(ctx).colorScheme.error,
                          fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(_t('settings.cancel', 'Cancel'))),
            FilledButton(
              onPressed: () async {
                if (current.text.isEmpty) {
                  setDialogState(() => error = 'Enter your current password.');
                  return;
                }
                if (next.text.length < 8 ||
                    !RegExp(r'[A-Za-z]').hasMatch(next.text) ||
                    !RegExp(r'[0-9]').hasMatch(next.text)) {
                  setDialogState(() => error =
                      'Use at least 8 characters with letters and numbers.');
                  return;
                }
                if (next.text != confirm.text) {
                  setDialogState(() => error = 'Passwords do not match.');
                  return;
                }
                try {
                  await AuthApi.changePassword(current.text, next.text);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } on ApiException catch (e) {
                  if (ctx.mounted) setDialogState(() => error = e.message);
                } catch (_) {
                  if (ctx.mounted) {
                    setDialogState(() => error = 'Could not change password.');
                  }
                }
              },
              child: Text(_t('settings.save', 'Save')),
            ),
          ],
        ),
      ),
    );
    current.dispose();
    next.dispose();
    confirm.dispose();
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('settings.passwordChanged', 'Password changed.'))));
    }
  }

  Future<void> _deleteAccount() async {
    final password = TextEditingController();
    String? error;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(_t('settings.deleteAccount', 'Delete account')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_t('settings.deleteWarning',
                  'This closes your account and removes your profile details. This cannot be undone.')),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: true,
                decoration: InputDecoration(
                    labelText:
                        _t('settings.currentPassword', 'Current password')),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!,
                    style: TextStyle(
                        color: Theme.of(ctx).colorScheme.error, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(_t('settings.cancel', 'Cancel'))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.warm),
              onPressed: () async {
                if (password.text.isEmpty) {
                  setDialogState(() => error = 'Enter your password.');
                  return;
                }
                try {
                  await AuthApi.deleteAccount(password.text);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } on ApiException catch (e) {
                  if (ctx.mounted) setDialogState(() => error = e.message);
                } catch (_) {
                  if (ctx.mounted) {
                    setDialogState(() => error = 'Could not delete account.');
                  }
                }
              },
              child: Text(_t('settings.delete', 'Delete')),
            ),
          ],
        ),
      ),
    );
    password.dispose();
    if (confirmed == true) _logout();
  }

  void _logout() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    widget.onLogout();
  }

  Future<void> _unblock(Map<String, dynamic> user) async {
    final id = user['id']?.toString() ?? '';
    if (id.isEmpty) return;
    try {
      await AuthApi.toggleBlock(id);
      if (!mounted) return;
      setState(() =>
          _blocked = _blocked.where((u) => u['id']?.toString() != id).toList());
    } catch (_) {}
  }

  Future<void> _pickQuietHours(UserSettings settings) async {
    final start = settings.quietStart ?? 22 * 60;
    final end = settings.quietEnd ?? 7 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: start ~/ 60, minute: start % 60),
      helpText: _t('settings.quietStart', 'Quiet hours start'),
    );
    if (picked == null || !mounted) return;
    final endPicked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: end ~/ 60, minute: end % 60),
      helpText: _t('settings.quietEnd', 'Quiet hours end'),
    );
    if (endPicked == null) return;
    await _update({
      'quiet_start': picked.hour * 60 + picked.minute,
      'quiet_end': endPicked.hour * 60 + endPicked.minute,
    });
  }

  String _timeLabel(int? minutes) {
    if (minutes == null) return _t('settings.off', 'Off');
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_t('settings.title', 'Settings'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _settings == null
              ? ErrorView(message: _error, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      _accountCard(cs),
                      if (_error != null) _errorBanner(cs),
                      _section(
                        cs,
                        _t('settings.notifications', 'Notifications'),
                        [
                          SwitchListTile(
                            value: _settings?.pushEnabled ?? true,
                            onChanged: _saving
                                ? null
                                : (v) => _update({'push_enabled': v}),
                            title:
                                Text(_t('settings.push', 'Push notifications')),
                            subtitle: Text(_t('settings.pushHint',
                                'Alerts for impact, opportunities and messages.')),
                            secondary: const Icon(Icons.notifications_outlined),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.ring_volume_outlined),
                            title: const Text('Send a test notification'),
                            subtitle: const Text(
                                'Checks both the in-app inbox and this device.'),
                            onTap: () async {
                              await NotificationService.instance.showNotification(
                                  99001,
                                  'MASAREEN is ready',
                                  'Notifications are working on this device.',
                                  type: 'system');
                              try {
                                await AuthApi.testPush(
                                    title: 'MASAREEN is ready',
                                    body:
                                        'Your smart notifications are working.');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Test notification sent.')));
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'In-app test shown. Push delivery: $e')));
                                }
                              }
                            },
                          ),
                          SwitchListTile(
                            value: _settings?.emailEnabled ?? true,
                            onChanged: _saving
                                ? null
                                : (v) => _update({'email_enabled': v}),
                            title: Text(
                                _t('settings.emailUpdates', 'Email updates')),
                            subtitle: Text(_t('settings.emailHint',
                                'Important account and activity emails.')),
                            secondary: const Icon(Icons.mail_outline),
                          ),
                          SwitchListTile(
                            value: _settings?.opportunityAlerts ?? true,
                            onChanged: _saving
                                ? null
                                : (v) => _update({'opportunity_alerts': v}),
                            title: Text(_t('settings.opportunityAlerts',
                                'Opportunity alerts')),
                            subtitle: Text(_t('settings.opportunityHint',
                                'Matched marketplace opportunities only.')),
                            secondary: const Icon(Icons.work_outline),
                          ),
                          SwitchListTile(
                            value: _settings?.socialAlerts ?? true,
                            onChanged: _saving
                                ? null
                                : (v) => _update({'social_alerts': v}),
                            title: Text(
                                _t('settings.socialAlerts', 'Social activity')),
                            subtitle: Text(_t('settings.socialHint',
                                'Likes, comments, follows and mentions.')),
                            secondary: const Icon(Icons.favorite_outline),
                          ),
                          SwitchListTile(
                            value: _settings?.messageAlerts ?? true,
                            onChanged: _saving
                                ? null
                                : (v) => _update({'message_alerts': v}),
                            title: Text(
                                _t('settings.messageAlerts', 'Message alerts')),
                            subtitle: Text(_t('settings.messageHint',
                                'New private messages.')),
                            secondary: const Icon(Icons.forum_outlined),
                          ),
                          ListTile(
                            leading: const Icon(Icons.schedule_outlined),
                            title:
                                Text(_t('settings.quietHours', 'Quiet hours')),
                            subtitle: Text(_settings?.quietStart == null
                                ? _t('settings.quietOff',
                                    'Notifications stay on all day.')
                                : '${_timeLabel(_settings?.quietStart)} - ${_timeLabel(_settings?.quietEnd)}'),
                            trailing: Switch(
                              value: _settings?.quietStart != null,
                              onChanged: _saving
                                  ? null
                                  : (v) => _update(v
                                      ? {
                                          'quiet_start': 22 * 60,
                                          'quiet_end': 7 * 60,
                                        }
                                      : {
                                          'quiet_start': null,
                                          'quiet_end': null,
                                        }),
                            ),
                            onTap: _saving || _settings == null
                                ? null
                                : () => _pickQuietHours(_settings!),
                          ),
                          _dropdownTile(
                            cs,
                            icon: Icons.tune,
                            label: _t('settings.digest', 'Digest frequency'),
                            value: _settings?.digestFrequency ?? 'instant',
                            items: const ['instant', 'daily', 'weekly'],
                            labelFor: (v) =>
                                v[0].toUpperCase() + v.substring(1),
                            onChanged: (v) => _update({'digest_frequency': v}),
                          ),
                        ],
                      ),
                      _section(
                        cs,
                        _t('settings.privacy', 'Privacy'),
                        [
                          _dropdownTile(
                            cs,
                            icon: Icons.visibility_outlined,
                            label: _t('settings.profileVisibility',
                                'Profile visibility'),
                            value: _settings?.profileVisibility ?? 'public',
                            items: const ['public', 'followers', 'private'],
                            labelFor: (v) => _t('settings.$v',
                                v[0].toUpperCase() + v.substring(1)),
                            onChanged: (v) =>
                                _update({'profile_visibility': v}),
                          ),
                          _dropdownTile(
                            cs,
                            icon: Icons.chat_bubble_outline,
                            label: _t('settings.messagePrivacy',
                                'Who can message you'),
                            value: _settings?.messagePrivacy ?? 'everyone',
                            items: const ['everyone', 'followers', 'nobody'],
                            labelFor: (v) => _t('settings.$v',
                                v[0].toUpperCase() + v.substring(1)),
                            onChanged: (v) => _update({'message_privacy': v}),
                          ),
                          SwitchListTile(
                            value: _settings?.showEmail ?? false,
                            onChanged: _saving
                                ? null
                                : (v) => _update({'show_email': v}),
                            title: Text(_t(
                                'settings.showEmail', 'Show email on profile')),
                            subtitle: Text(_t('settings.showEmailHint',
                                'Only people who can view your profile will see it.')),
                            secondary: const Icon(Icons.alternate_email),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.location_on_outlined),
                            title: Text(_t('gps.title', 'Location history')),
                            subtitle: Text(_t('gps.hint',
                                'GPS points captured with your posts.')),
                            trailing: Icon(directionalChevronIcon(context)),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    GpsHistoryScreen(user: widget.user),
                              ),
                            ),
                          ),
                        ],
                      ),
                      _blockedSection(cs),
                      _appearanceSection(cs),
                      _dangerSection(cs),
                    ],
                  ),
                ),
    );
  }

  Widget _accountCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              AppAvatar(name: _user.fullName, url: _user.avatarUrl, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_user.fullName,
                        style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 17,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(_user.email,
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 13)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          _user.emailVerified
                              ? Icons.verified
                              : Icons.info_outline,
                          size: 15,
                          color: _user.emailVerified
                              ? AppColors.accent
                              : AppColors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _user.emailVerified
                              ? _t('settings.emailVerified', 'Email verified')
                              : _t('settings.emailNotVerified',
                                  'Email not verified'),
                          style: TextStyle(
                              color: _user.emailVerified
                                  ? AppColors.accent
                                  : cs.onSurfaceVariant,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!_user.emailVerified) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _resendVerification,
              icon: const Icon(Icons.mark_email_unread_outlined, size: 18),
              label: Text(_t('settings.resend', 'Resend confirmation email')),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(42)),
            ),
          ],
          const Divider(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.password_outlined),
            title: Text(_t('settings.changePassword', 'Change password')),
            trailing: Icon(directionalChevronIcon(context)),
            onTap: _changePassword,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.android_outlined),
            title: const Text('Join Android closed testing'),
            subtitle:
                const Text('Install the Play test build and help us launch.'),
            trailing: Icon(directionalChevronIcon(context)),
            onTap: () async {
              try {
                final result = await AuthApi.joinAndroidTesting();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(result['message']?.toString() ??
                        "You're on the Android testing list.")));
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout_outlined),
            title: Text(_t('settings.signOut', 'Sign out')),
            trailing: Icon(directionalChevronIcon(context)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _errorBanner(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: cs.onErrorContainer, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_error!,
                style: TextStyle(color: cs.onErrorContainer, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _section(ColorScheme cs, String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, bottom: 6),
            child: Text(title,
                style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: BorderRadius.circular(18),
              border:
                  Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _dropdownTile(
    ColorScheme cs, {
    required IconData icon,
    required String label,
    required String value,
    required List<String> items,
    required String Function(String) labelFor,
    required ValueChanged<String> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          borderRadius: BorderRadius.circular(12),
          items: items
              .map((v) => DropdownMenuItem(value: v, child: Text(labelFor(v))))
              .toList(),
          onChanged: _saving
              ? null
              : (v) {
                  if (v != null) onChanged(v);
                },
        ),
      ),
    );
  }

  Widget _blockedSection(ColorScheme cs) {
    return _section(
      cs,
      _t('settings.blocked', 'Blocked accounts'),
      [
        if (_blocked.isEmpty)
          ListTile(
            leading: const Icon(Icons.block_outlined),
            title: Text(_t('settings.blockedEmpty', 'No blocked accounts')),
            subtitle: Text(_t('settings.blockedHint',
                'People you block cannot follow or message you.')),
          )
        else
          ..._blocked.map((u) => ListTile(
                leading: AppAvatar(
                    name: (u['name'] ?? u['full_name'] ?? 'User').toString(),
                    url: u['avatar_url']?.toString(),
                    size: 36),
                title: Text((u['name'] ?? u['full_name'] ?? 'User').toString()),
                subtitle: Text((u['handle'] ?? '').toString()),
                trailing: TextButton(
                  onPressed: () => _unblock(u),
                  child: Text(_t('settings.unblock', 'Unblock')),
                ),
              )),
      ],
    );
  }

  Widget _appearanceSection(ColorScheme cs) {
    final theme = Provider.of<ThemeProvider>(context);
    return _section(
      cs,
      _t('settings.appearance', 'App appearance'),
      [
        SwitchListTile(
          value: theme.dark,
          onChanged: (_) => theme.toggle(),
          title: Text(_t('settings.darkMode', 'Dark mode')),
          secondary: Icon(theme.dark
              ? Icons.dark_mode_outlined
              : Icons.light_mode_outlined),
        ),
        SwitchListTile(
          value: _startupSound,
          onChanged: (v) async {
            setState(() => _startupSound = v);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('masaren_startup_sound', v);
          },
          title: Text(_t('settings.startupSound', 'Startup sound')),
          secondary: const Icon(Icons.volume_up_outlined),
        ),
      ],
    );
  }

  Widget _dangerSection(ColorScheme cs) {
    return _section(
      cs,
      _t('settings.danger', 'Danger zone'),
      [
        ListTile(
          leading:
              const Icon(Icons.delete_forever_outlined, color: AppColors.warm),
          title: Text(_t('settings.deleteAccount', 'Delete account'),
              style: const TextStyle(color: AppColors.warm)),
          subtitle: Text(_t('settings.deleteHint',
              'Close your account and remove your profile details.')),
          onTap: _deleteAccount,
        ),
      ],
    );
  }
}
