import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:masaren/core/theme/masaren_theme.dart';
import 'package:masaren/core/logging/ui_logger.dart';
import 'package:masaren/services/api_service.dart';
import 'package:masaren/di/injection.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final GoogleSignIn _google = GoogleSignIn(scopes: ['email', 'profile']);
  bool _obscure = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await getIt<ApiService>().register({
        'full_name': _nameCtrl.text,
        'email': _emailCtrl.text,
        'password': _passwordCtrl.text,
        'phone': '',
        'location': '',
      });
      UiLogger.instance.tap('register:success');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration successful!')));
      context.pushReplacement('/login');
    } catch (e) {
      UiLogger.instance.error('register', e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration failed: ${e.toString()}')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _googleSignIn() async {
    UiLogger.instance.tap('register:google');
    try {
      final account = await _google.signIn();
      if (account == null) return;
      if (_nameCtrl.text.isEmpty) _nameCtrl.text = account.displayName ?? '';
      if (_emailCtrl.text.isEmpty) _emailCtrl.text = account.email;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google account linked. Finish your details below.')));
      }
    } catch (e) {
      UiLogger.instance.error('google', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google sign-in is not available on this device. Use email instead.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MasarenTheme.canvas,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_add, size: 56, color: MasarenTheme.gold),
                const SizedBox(height: 16),
                Text('Create Account', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: MasarenTheme.gold)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _googleSignIn,
                    icon: const Icon(Icons.g_mobiledata_rounded, size: 24, color: MasarenTheme.brand),
                    label: const Text('Continue with Google'),
                    style: OutlinedButton.styleFrom(foregroundColor: MasarenTheme.ink, side: const BorderSide(color: MasarenTheme.line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: TextStyle(color: MasarenTheme.muted))), Expanded(child: Divider())]),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person)),
                  validator: (v) => v != null && v.trim().isNotEmpty ? null : 'Name is required',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v != null && v.contains('@') ? null : 'Enter a valid email',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscure = !_obscure)),
                  ),
                  validator: (v) => v != null && v.length >= 6 ? null : 'Password must be at least 6 characters',
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity, 
                  child: _isLoading 
                    ? const CircularProgressIndicator() 
                    : ElevatedButton(onPressed: _submit, child: const Text('Register'))
                ),
                const SizedBox(height: 16),
                TextButton(onPressed: () => context.pushReplacement('/login'), child: const Text('Already have an account? Sign in')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}




