import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/models.dart';
import 'package:masaren/services/google_web_login.dart';

const List<String> _audiences = [
  'STUDENT',
  'PROFESSIONAL',
  'VOLUNTEER',
  'ORGANIZATION',
  'ATHLETE',
  'SPORTS',
  'GOVERNMENT',
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
  final _confirm = TextEditingController();
  final _phone = TextEditingController();
  final _nationalId = TextEditingController();
  final _university = TextEditingController();
  final _universityId = TextEditingController();
  String _role = 'INDIVIDUAL';
  String _audience = 'STUDENT';
  bool _consent = false;
  bool _isTester = false;
  bool _busy = false;
  bool _googleBusy = false;
  String? _error;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _fullName.dispose();
    _password.dispose();
    _confirm.dispose();
    _phone.dispose();
    _nationalId.dispose();
    _university.dispose();
    _universityId.dispose();
    super.dispose();
  }

  String _roleLabel(String value) {
    switch (value) {
      case 'INDIVIDUAL':
        return MasarenLocalizations.of(context, 'profile.individual');
      case 'ORGANIZATION':
        return MasarenLocalizations.of(context, 'profile.organization');
      case 'CLUB':
        return MasarenLocalizations.of(context, 'register.role.club');
      case 'FEDERATION':
        return MasarenLocalizations.of(context, 'register.role.federation');
      case 'INSTITUTION':
        return MasarenLocalizations.of(context, 'register.role.institution');
      case 'UNIVERSITY':
        return MasarenLocalizations.of(context, 'register.role.university');
      case 'RESEARCHER':
        return MasarenLocalizations.of(context, 'register.role.researcher');
      default:
        return value;
    }
  }

  String _audienceLabel(String value) => MasarenLocalizations.of(
        context,
        'register.audience.${value.toLowerCase()}',
      );

  Future<void> _google() async {
    setState(() {
      _googleBusy = true;
      _error = null;
    });
    final url = Uri.parse(
      '${api.baseUrl}/mobile-auth.html${_isTester ? "?tester=1" : ""}',
    );
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = MasarenLocalizations.of(context, 'register.googleError'),
        );
      }
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  Future<void> _googleWeb(String credential) async {
    if (_googleBusy) return;
    setState(() {
      _googleBusy = true;
      _error = null;
    });
    try {
      final data = await AuthApi.googleLogin(
        credential,
        isTester: _isTester,
        locale: Localizations.localeOf(context).languageCode,
      );
      final token = data['access_token'] as String? ?? '';
      if (token.isEmpty) throw Exception('No access token returned.');
      api.setToken(token);
      final user = await AuthApi.me();
      if (mounted) widget.onRegistered(token, user);
    } on ApiException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.statusCode == 0
              ? MasarenLocalizations.of(context, 'register.networkError')
              : (e.message ??
                  MasarenLocalizations.of(context, 'register.failed')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = MasarenLocalizations.of(
            context,
            'register.networkError',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) {
      return MasarenLocalizations.of(context, 'register.emailRequired');
    }
    final emailRe = RegExp(r'^[\w-]+(\.[\w-]+)*@([\w-]+\.)+[a-zA-Z]{2,}$');
    if (!emailRe.hasMatch(v.trim())) {
      return MasarenLocalizations.of(context, 'register.emailInvalid');
    }
    return null;
  }

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) {
      return MasarenLocalizations.of(context, 'register.nameRequired');
    }
    if (v.trim().length < 2) {
      return MasarenLocalizations.of(context, 'register.nameShort');
    }
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) {
      return MasarenLocalizations.of(context, 'register.passwordRequired');
    }
    if (v.length < 8) {
      return MasarenLocalizations.of(context, 'register.passwordShort');
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(v)) {
      return MasarenLocalizations.of(context, 'register.passwordLetter');
    }
    if (!RegExp(r'[0-9]').hasMatch(v)) {
      return MasarenLocalizations.of(context, 'register.passwordNumber');
    }
    return null;
  }

  String? _validateConfirm(String? v) {
    if (v == null || v.isEmpty) {
      return MasarenLocalizations.of(context, 'register.confirmRequired');
    }
    if (v != _password.text) {
      return MasarenLocalizations.of(context, 'register.passwordMismatch');
    }
    return null;
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_consent) {
      setState(
        () =>
            _error = MasarenLocalizations.of(context, 'register.termsRequired'),
      );
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
        'is_tester': _isTester,
        'consent': _consent,
        'university': _university.text.trim(),
        'university_id': _universityId.text.trim(),
      };
      final registered = await AuthApi.register(body);
      if (registered['email_verification_required'] == true && mounted) {
        await _showVerificationDialog(
          registered['verification_email_sent'] == true,
        );
      }
      try {
        var token = registered['access_token'] as String? ?? '';
        if (token.isEmpty) {
          final login = await AuthApi.login(_email.text.trim(), _password.text);
          token = login['access_token'] as String? ?? '';
        }
        if (token.isEmpty) throw Exception('Login failed after registration');
        api.setToken(token);
        final user = await AuthApi.me();
        widget.onRegistered(token, user);
      } catch (e) {
        if (mounted) {
          setState(
            () => _error = MasarenLocalizations.of(
              context,
              'register.autoLoginFailed',
            ),
          );
        }
      }
    } on ApiException catch (e) {
      final msg = e.message ?? '';
      if (msg.toLowerCase().contains('already') ||
          msg.toLowerCase().contains('exists')) {
        setState(
          () => _error = MasarenLocalizations.of(context, 'register.exists'),
        );
      } else {
        setState(
          () => _error = msg.isNotEmpty
              ? msg
              : MasarenLocalizations.of(context, 'register.failed'),
        );
      }
    } catch (e) {
      setState(
        () =>
            _error = MasarenLocalizations.of(context, 'register.networkError'),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showVerificationDialog(bool sent) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(MasarenLocalizations.of(ctx, 'verify.title')),
        content: Text(
          sent
              ? MasarenLocalizations.of(
                  ctx,
                  'verify.registerSentBody',
                ).replaceAll('{email}', _email.text.trim())
              : MasarenLocalizations.of(ctx, 'verify.registerUnsentBody'),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(MasarenLocalizations.of(ctx, 'verify.continue')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(MasarenLocalizations.of(context, 'register.appBarTitle')),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: dark
                ? const [AppColors.darkBg, Color(0xFF06121F)]
                : const [Colors.white, Color(0xFFF4F9FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      BrandLogo(height: 130, forceWhite: dark),
                      const SizedBox(height: 8),
                      Text(
                        MasarenLocalizations.of(context, 'register.subtitle'),
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _fullName,
                        decoration: InputDecoration(
                          labelText:
                              '${MasarenLocalizations.of(context, 'register.name')} *',
                        ),
                        validator: _validateName,
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _email,
                        decoration: InputDecoration(
                          labelText:
                              '${MasarenLocalizations.of(context, 'register.email')} *',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        decoration: InputDecoration(
                          labelText:
                              '${MasarenLocalizations.of(context, 'register.password')} *',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppColors.muted,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        obscureText: _obscurePassword,
                        validator: _validatePassword,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirm,
                        decoration: InputDecoration(
                          labelText:
                              '${MasarenLocalizations.of(context, 'register.confirmPassword')} *',
                        ),
                        obscureText: true,
                        validator: _validateConfirm,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phone,
                        decoration: InputDecoration(
                          labelText: MasarenLocalizations.of(
                            context,
                            'register.phone',
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nationalId,
                        decoration: InputDecoration(
                          labelText: MasarenLocalizations.of(
                            context,
                            'register.nationalId',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _role,
                        decoration: InputDecoration(
                          labelText: MasarenLocalizations.of(
                            context,
                            'register.role',
                          ),
                        ),
                        items: const [
                          'INDIVIDUAL',
                          'ORGANIZATION',
                          'CLUB',
                          'FEDERATION',
                          'INSTITUTION',
                          'UNIVERSITY',
                          'RESEARCHER',
                        ]
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(_roleLabel(value)),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _role = v!),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _audience,
                        decoration: InputDecoration(
                          labelText: MasarenLocalizations.of(
                            context,
                            'register.audience',
                          ),
                        ),
                        items: _audiences
                            .map(
                              (a) => DropdownMenuItem(
                                value: a,
                                child: Text(_audienceLabel(a)),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _audience = v!),
                      ),
                      const SizedBox(height: 12),
                      if (_audience == 'STUDENT') ...[
                        TextFormField(
                          controller: _university,
                          decoration: InputDecoration(
                            labelText: MasarenLocalizations.of(
                              context,
                              'register.university',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _universityId,
                          decoration: InputDecoration(
                            labelText: MasarenLocalizations.of(
                              context,
                              'register.universityId',
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _consent,
                        onChanged: (v) => setState(() => _consent = v ?? false),
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          MasarenLocalizations.of(context, 'register.consent'),
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        activeColor: cs.primary,
                      ),
                      CheckboxListTile(
                        value: _isTester,
                        onChanged: (v) =>
                            setState(() => _isTester = v ?? false),
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          MasarenLocalizations.of(context, 'register.tester'),
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          MasarenLocalizations.of(
                            context,
                            'register.testerHint',
                          ),
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                        activeColor: cs.primary,
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
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.redAccent,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),
                      _busy
                          ? const CircularProgressIndicator()
                          : gradientButton(
                              label: MasarenLocalizations.of(
                                context,
                                'register.create',
                              ),
                              onPressed: _register,
                            ),
                      if (kIsWeb) ...[
                        const SizedBox(height: 12),
                        GoogleSignInButton(
                          onCredential: _googleWeb,
                          dark: dark,
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _googleBusy ? null : _google,
                          icon: _googleBusy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.g_mobiledata, size: 22),
                          label: Text(
                            MasarenLocalizations.of(context, 'register.google'),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            foregroundColor: cs.onSurface,
                            backgroundColor: dark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.white,
                            side: BorderSide(color: cs.outlineVariant),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          MasarenLocalizations.of(
                            context,
                            'register.backToSignIn',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
