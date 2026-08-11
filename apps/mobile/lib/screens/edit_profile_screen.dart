import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profile saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
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
          const Center(
            child: Text('Use the camera icon on your profile to change avatar',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _bio,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Bio',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _country,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Country'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _city,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'City'),
          ),
          const SizedBox(height: 24),
          gradientButton(label: 'Save changes', onPressed: _save),
        ],
      ),
    );
  }
}
