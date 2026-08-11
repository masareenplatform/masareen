import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/models.dart';

const List<String> _audiences = [
  'STUDENT',
  'PROFESSIONAL',
  'VOLUNTEER',
  'ORGANIZATION',
];

class RegisterScreen extends StatefulWidget {
  final void Function(String token, User user) onRegistered;
  const RegisterScreen({super.key, required this.onRegistered});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _fullName = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _nationalId = TextEditingController();
  final _universityId = TextEditingController();
  String _role = 'INDIVIDUAL';
  String _audience = 'STUDENT';
  bool _consent = false;
  bool _busy = false;
  String? _error;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _fullName.dispose();
    _password.dispose();
    _phone.dispose();
    _nationalId.dispose();
    _universityId.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final emailRe = RegExp(r'^[\w-]+(\.[\w-]+)*@([\w-]+\.)+[a-zA-Z]{2,}$');
    if (!emailRe.hasMatch(v.trim())) return 'Enter a valid email address';
    return null;
  }

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Full name is required';
    if (v.trim().length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Include at least one uppercase letter';
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Include at least one number';
    return null;
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_consent) {
      setState(() => _error = 'Please accept the terms to continue.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final body = {
        'email': _email.text.trim(),
        'full_name': _fullName.text.trim(),
        'password': _password.text,
        'phone': _phone.text.trim(),
        'national_id': _nationalId.text.trim(),
        'role': _role,
        'audience': _audience,
        if (_audience == 'STUDENT')
          'university_id': _universityId.text.trim(),
      };
      await AuthApi.register(body);
      try {
        final login = await AuthApi.login(_email.text.trim(), _password.text);
        final token = login['access_token'] as String? ?? '';
        if (token.isEmpty) throw Exception('Login failed after registration');
        api.setToken(token);
        final user = await AuthApi.me();
        widget.onRegistered(token, user);
      } catch (e) {
        if (mounted) {
          setState(() => _error = 'Account created but auto-login failed. Please sign in manually.');
        }
      }
    } on ApiException catch (e) {
      final msg = e.message ?? '';
      if (msg.toLowerCase().contains('already') || msg.toLowerCase().contains('exists')) {
        setState(() => _error = 'An account with this email already exists. Please sign in.');
      } else {
        setState(() => _error = msg.isNotEmpty ? msg : 'Registration failed. Please try again.');
      }
    } catch (e) {
      setState(() => _error = 'Network error. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.darkBg, Color(0xFF06121F)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const BrandLogo(height: 130, forceWhite: true),
                    const SizedBox(height: 8),
                    Text('Join the alpha stage',
                        style: TextStyle(color: AppColors.muted, fontSize: 14)),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _fullName,
                      decoration: const InputDecoration(labelText: 'Full Name *'),
                      validator: _validateName,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(labelText: 'Email *'),
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      decoration: InputDecoration(
                        labelText: 'Password *',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: AppColors.muted,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      obscureText: _obscurePassword,
                      validator: _validatePassword,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phone,
                      decoration: const InputDecoration(labelText: 'Phone Number (optional)'),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nationalId,
                      decoration: const InputDecoration(labelText: 'National ID (optional)'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _role,
                      decoration: const InputDecoration(labelText: 'I am a'),
                      items: const [
                        DropdownMenuItem(value: 'INDIVIDUAL', child: Text('Individual')),
                        DropdownMenuItem(value: 'ORGANIZATION', child: Text('Organization')),
                      ],
                      onChanged: (v) => setState(() => _role = v!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _audience,
                      decoration: const InputDecoration(labelText: 'I am a'),
                      items: _audiences
                          .map((a) => DropdownMenuItem(
                              value: a,
                              child: Text(a[0] + a.substring(1).toLowerCase())))
                          .toList(),
                      onChanged: (v) => setState(() => _audience = v!),
                    ),
                    const SizedBox(height: 12),
                    if (_audience == 'STUDENT')
                      TextFormField(
                        controller: _universityId,
                        decoration: const InputDecoration(labelText: 'University ID (optional)'),
                      ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: _consent,
                      onChanged: (v) => setState(() => _consent = v ?? false),
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                          'I agree to the terms and verify my impact.',
                          style: TextStyle(color: AppColors.muted, fontSize: 13)),
                      activeColor: AppColors.azure,
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_error!,
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    _busy
                        ? const CircularProgressIndicator()
                        : gradientButton(label: 'Create account', onPressed: _register),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back to sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
