import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/models.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/widgets/animations.dart';

class LoginScreen extends StatefulWidget {
  final void Function(String token, User user) onAuthenticated;
  const LoginScreen({super.key, required this.onAuthenticated});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscurePassword = true;
  bool _googleBusy = false;
  String? _error;
  String? _notice;

  Future<void> _google() async {
    setState(() {
      _googleBusy = true;
      _error = null;
      _notice = 'Complete sign in in your browser, then return to the app.';
    });
    final url = Uri.parse('${api.baseUrl}/mobile-auth.html');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open Google sign in. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  String? _validate() {
    final email = _email.text.trim();
    if (email.isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w-]+(\.[\w-]+)*@([\w-]+\.)+[a-zA-Z]{2,}$').hasMatch(email)) {
      return 'Enter a valid email address';
    }
    if (_password.text.isEmpty) return 'Password is required';
    return null;
  }

  Future<void> _login() async {
    final invalid = _validate();
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final data = await AuthApi.login(_email.text.trim(), _password.text);
      final token = data['access_token'] as String? ?? '';
      api.setToken(token);
      final user = await AuthApi.me();
      widget.onAuthenticated(token, user);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          AnimatedGradientBackground(
            colors: dark
                ? const [
                    Color(0xFF0D1B3E),
                    Color(0xFF2E1A47),
                    Color(0xFF0E3B43),
                  ]
                : const [
                    Color(0xFFF6FAFF),
                    Color(0xFFEAF3FF),
                    Color(0xFFF3FBF5),
                  ],
            child: const SizedBox.expand(),
          ),
          const Positioned.fill(child: FloatingShapes(shapeCount: 8)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SlideInWidget(
                      delay: const Duration(milliseconds: 200),
                      slideOffset: const Offset(0, 0.15),
                      child: BrandLogo(height: 140, forceWhite: dark),
                    ),
                    const SizedBox(height: 8),
                    SlideInWidget(
                      delay: const Duration(milliseconds: 350),
                      slideOffset: const Offset(0, 0.1),
                      child: Text('Prove impact. Scale change.',
                          style: TextStyle(
                              color: dark ? AppColors.azure : AppColors.muted,
                              fontSize: 15)),
                    ),
                    const SizedBox(height: 28),
                    SlideInWidget(
                      delay: const Duration(milliseconds: 500),
                      slideOffset: const Offset(0, 0.1),
                      child: _buildForm(dark),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(bool dark) {
    final cs = Theme.of(context).colorScheme;
    final fill = dark ? Colors.white.withOpacity(0.08) : Colors.white;
    final border = dark ? AppColors.darkLine : cs.outlineVariant;
    return Column(
      children: [
        TextField(
          controller: _email,
          decoration: InputDecoration(
            labelText: MasarenLocalizations.of(context, 'login.email'),
            prefixIcon: Icon(Icons.email_outlined, color: cs.primary.withOpacity(0.8)),
            filled: true,
            fillColor: fill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: cs.primary),
            ),
            labelStyle: TextStyle(color: cs.onSurfaceVariant),
            hintStyle: TextStyle(color: cs.onSurfaceVariant),
          ),
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(color: cs.onSurface),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          decoration: InputDecoration(
            labelText: MasarenLocalizations.of(context, 'login.password'),
            prefixIcon: Icon(Icons.lock_outline, color: cs.primary.withOpacity(0.8)),
            filled: true,
            fillColor: fill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: cs.primary),
            ),
            labelStyle: TextStyle(color: cs.onSurfaceVariant),
            hintStyle: TextStyle(color: cs.onSurfaceVariant),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: cs.onSurfaceVariant,
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          obscureText: _obscurePassword,
          style: TextStyle(color: cs.onSurface),
        ),
        const SizedBox(height: 10),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_error!,
                style: TextStyle(color: cs.error, fontSize: 13)),
          ),
        if (_notice != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_notice!,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.primary, fontSize: 12)),
          ),
        const SizedBox(height: 4),
        _busy
            ? const SizedBox(
                width: 48, height: 48,
                child: Center(child: CircularProgressIndicator(color: AppColors.azure)),
              )
            : gradientButton(
                label: MasarenLocalizations.of(context, 'login.signIn'),
                onPressed: _login),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _googleBusy ? null : _google,
          icon: _googleBusy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.g_mobiledata, size: 22),
          label: const Text('Continue with Google'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            foregroundColor: cs.onSurface,
            backgroundColor: dark ? Colors.white.withOpacity(0.08) : Colors.white,
            side: BorderSide(color: border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 14),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/register'),
          child: Text(
              "${MasarenLocalizations.of(context, 'login.noAccount')} ${MasarenLocalizations.of(context, 'login.register')}",
              style: TextStyle(color: cs.primary)),
        ),
      ],
    );
  }
}
