import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/models.dart';

class EditProfileScreen extends StatefulWidget {
  final User user;
  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _bio;
  late final TextEditingController _country;
  late final TextEditingController _city;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bio = TextEditingController(text: widget.user.bio ?? '');
    _country = TextEditingController(text: widget.user.country ?? '');
    _city = TextEditingController(text: widget.user.city ?? '');
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = await AuthApi.updateProfile({
        'bio': _bio.text.trim(),
        'country': _country.text.trim(),
        'city': _city.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context, updated);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(MasarenLocalizations.of(context, 'profile.saved'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(MasarenLocalizations.of(context, 'profile.saveFailed')
                .replaceAll('{error}', '$e'))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(MasarenLocalizations.of(context, 'profile.edit')),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(MasarenLocalizations.of(context, 'action.save')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: AppAvatar(
                name: widget.user.fullName,
                url: widget.user.avatarUrl,
                size: 88),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(MasarenLocalizations.of(context, 'profile.avatarHint'),
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _bio,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: MasarenLocalizations.of(context, 'profile.bio'),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _country,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
                labelText: MasarenLocalizations.of(context, 'profile.country')),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _city,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
                labelText: MasarenLocalizations.of(context, 'profile.city')),
          ),
          const SizedBox(height: 24),
          gradientButton(
              label: MasarenLocalizations.of(context, 'profile.saveChanges'),
              onPressed: _save),
        ],
      ),
    );
  }
}
