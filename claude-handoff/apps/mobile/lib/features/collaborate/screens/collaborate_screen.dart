import 'package:flutter/material.dart';
import 'package:masaren/core/theme/masaren_theme.dart';
import 'package:masaren/services/api_service.dart';
import 'package:masaren/di/injection.dart';

class CollaborateScreen extends StatefulWidget {
  const CollaborateScreen({super.key});

  @override
  State<CollaborateScreen> createState() => _CollaborateScreenState();
}

class _CollaborateScreenState extends State<CollaborateScreen> {
  final _form = GlobalKey<FormState>();
  final _company = TextEditingController();
  final _email = TextEditingController();
  final _website = TextEditingController();
  final _service = TextEditingController();
  final _desc = TextEditingController();
  String _tier = 'SANDBOX';
  bool _busy = false;
  bool _done = false;
  String _error = '';

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = ''; });
    try {
      await getIt<ApiService>().submitCollaboration({
        'company_name': _company.text,
        'contact_email': _email.text,
        'website': _website.text,
        'service_name': _service.text,
        'service_description': _desc.text,
        'desired_tier': _tier,
      });
      setState(() => _done = true);
    } catch (e) {
      setState(() => _error = 'Submission failed: ${e.toString()}');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return Scaffold(
        appBar: AppBar(title: const Text('Collaborate')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 64, color: MasarenTheme.gold),
              const SizedBox(height: 12),
              const Text('Request received', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Our partnerships team will review and follow up by email.'),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Host on MASAREEN')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _company,
                decoration: const InputDecoration(labelText: 'Company name', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Contact email', border: OutlineInputBorder()),
                validator: (v) => v!.contains('@') ? null : 'Invalid email',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _website,
                decoration: const InputDecoration(labelText: 'Website (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _service,
                decoration: const InputDecoration(labelText: 'Service name', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _desc,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'What does your service do?', border: OutlineInputBorder()),
                validator: (v) => v!.length >= 10 ? null : 'Min 10 characters',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _tier,
                decoration: const InputDecoration(labelText: 'Desired tier', border: OutlineInputBorder()),
                items: const ['SANDBOX', 'STANDARD', 'DEDICATED']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _tier = v ?? 'SANDBOX'),
              ),
              const SizedBox(height: 16),
              if (_error.isNotEmpty) Text(_error, style: const TextStyle(color: Colors.red)),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Submit hosting request'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}




