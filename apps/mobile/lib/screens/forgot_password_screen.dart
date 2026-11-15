import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _email =
      TextEditingController(text: widget.initialEmail ?? '');
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  String? _validate() {
    final email = _email.text.trim();
    if (email.isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w-]+(\.[\w-]+)*@([\w-]+\.)+[a-zA-Z]{2,}$')
        .hasMatch(email)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  Future<void> _send() async {
    final invalid = _validate();
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthApi.forgotPassword(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not send the reset link. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const loc = MasarenLocalizations.of;
    return Scaffold(
      appBar: AppBar(title: Text(loc(context, 'forgot.title'))),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: _sent ? _success(cs) : _form(cs),
            ),
          ),
        ),
      ),
    );
  }

  Widget _success(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.mark_email_read_outlined,
              color: cs.onPrimaryContainer, size: 36),
        ),
        const SizedBox(height: 20),
        Text(
          MasarenLocalizations.of(context, 'forgot.sentTitle'),
          style: TextStyle(
              color: cs.onSurface, fontSize: 20, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          MasarenLocalizations.of(context, 'forgot.sentBody'),
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        gradientButton(
          label: MasarenLocalizations.of(context, 'forgot.back'),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _form(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.lock_reset_outlined, color: cs.primary, size: 54),
        const SizedBox(height: 16),
        Text(
          MasarenLocalizations.of(context, 'forgot.desc'),
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 22),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _send(),
          decoration: InputDecoration(
            labelText: MasarenLocalizations.of(context, 'login.email'),
            prefixIcon: const Icon(Icons.email_outlined),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: cs.error, fontSize: 13)),
        ],
        const SizedBox(height: 18),
        _busy
            ? const Center(child: CircularProgressIndicator())
            : gradientButton(
                label: MasarenLocalizations.of(context, 'forgot.send'),
                onPressed: _send,
              ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MasarenLocalizations.of(context, 'forgot.back')),
        ),
      ],
    );
  }
}
