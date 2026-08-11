import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:masaren/core/theme/masaren_theme.dart';
import 'package:masaren/core/logging/ui_logger.dart';
import 'package:masaren/services/api_service.dart';
import 'package:masaren/di/injection.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final GoogleSignIn _google = GoogleSignIn(scopes: ['email', 'profile']);
  bool _obscure = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await getIt<ApiService>().login(_emailCtrl.text, _passwordCtrl.text);
      UiLogger.instance.tap('login:success');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login Successful!')));
      context.pushReplacement('/home');
    } catch (e) {
      UiLogger.instance.error('login', e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login Failed: ${e.toString()}')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _googleSignIn() async {
    UiLogger.instance.tap('login:google');
    try {
      final account = await _google.signIn();
      if (account == null) return;
      // In production the id token would be exchanged with the gateway. For the
      // alpha build we continue to the details step so the user can finish setup.
      if (mounted) context.pushReplacement('/register');
    } catch (e) {
      UiLogger.instance.error('google', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google sign-in is not available on this device. Use email instead.')),
        );
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
                Image.asset('assets/images/masaren_logo.png', width: 104, height: 104),
                const SizedBox(height: 12),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [MasarenTheme.brand, MasarenTheme.green],
                  ).createShader(bounds),
                  child: Text('MASAREEN', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 40),
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
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email', hintText: 'Email', prefixIcon: Icon(Icons.email)),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v != null && v.contains('@') ? null : 'Enter a valid email',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Password',
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
                    : ElevatedButton(onPressed: _submit, child: const Text('Sign In'))
                ),
                const SizedBox(height: 16),
                TextButton(onPressed: () => context.push('/register'), child: const Text("Don't have an account? Register")),
              ],
            ),
          ),
        ),
      ),
    );
  }
}




