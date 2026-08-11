import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/models.dart';
import 'package:masaren/theme.dart';
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
  String? _error;

  Future<void> _google() async {
    final url = Uri.parse('http://41.33.197.134:8088/login?google=1');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _login() async {
    setState(() => _busy = true);
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
    return Scaffold(
      body: Stack(
        children: [
          AnimatedGradientBackground(
            colors: const [
              Color(0xFF0D1B3E),
              Color(0xFF2E1A47),
              Color(0xFF0E3B43),
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
                      child: const BrandLogo(height: 140, forceWhite: true),
                    ),
                    const SizedBox(height: 8),
                    SlideInWidget(
                      delay: const Duration(milliseconds: 350),
                      slideOffset: const Offset(0, 0.1),
                      child: Text('Prove impact. Scale change.',
                          style: TextStyle(color: AppColors.azure, fontSize: 15)),
                    ),
                    const SizedBox(height: 28),
                    SlideInWidget(
                      delay: const Duration(milliseconds: 500),
                      slideOffset: const Offset(0, 0.1),
                      child: _buildForm(),
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

  Widget _buildForm() {
    return Column(
      children: [
        TextField(
          controller: _email,
          decoration: InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined, color: AppColors.azure.withOpacity(0.7)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: AppColors.darkLine),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: AppColors.darkLine),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: AppColors.azure),
            ),
            labelStyle: TextStyle(color: AppColors.azure.withOpacity(0.7)),
            hintStyle: TextStyle(color: AppColors.azure.withOpacity(0.5)),
          ),
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.lock_outline, color: AppColors.azure.withOpacity(0.7)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: AppColors.darkLine),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: AppColors.darkLine),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: AppColors.azure),
            ),
            labelStyle: TextStyle(color: AppColors.azure.withOpacity(0.7)),
            hintStyle: TextStyle(color: AppColors.azure.withOpacity(0.5)),
          ),
          obscureText: true,
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 10),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ),
        const SizedBox(height: 4),
        _busy
            ? const SizedBox(
                width: 48, height: 48,
                child: Center(child: CircularProgressIndicator(color: AppColors.azure)),
              )
            : gradientButton(label: 'Sign in', onPressed: _login),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _google,
          icon: const Icon(Icons.g_mobiledata, size: 22),
          label: const Text('Continue with Google'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            foregroundColor: Colors.white,
            backgroundColor: Colors.white.withOpacity(0.08),
            side: const BorderSide(color: AppColors.darkLine),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 14),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/register'),
          child: Text('Create an account',
              style: TextStyle(color: AppColors.azure.withOpacity(0.8))),
        ),
      ],
    );
  }
}
