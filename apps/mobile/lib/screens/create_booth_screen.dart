import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/models.dart';

class CreateBoothScreen extends StatefulWidget {
  final String eventId;
  final User user;
  const CreateBoothScreen(
      {super.key, required this.eventId, required this.user});

  @override
  State<CreateBoothScreen> createState() => _CreateBoothScreenState();
}

class _CreateBoothScreenState extends State<CreateBoothScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _label = TextEditingController();
  final _price = TextEditingController();
  String _cta = 'QUOTE';
  String? _coverUrl;
  String? _coverPath;
  final List<String> _tour = [];
  bool _uploading = false;
  bool _tourUploading = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _label.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 1800, imageQuality: 84);
    if (picked == null) return;
    setState(() {
      _coverPath = picked.path;
      _uploading = true;
      _error = null;
    });
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last.toLowerCase();
      final url = await AuthApi.uploadMedia(
          bytes,
          picked.name,
          ext == 'png'
              ? 'image/png'
              : ext == 'webp'
                  ? 'image/webp'
                  : 'image/jpeg');
      if (mounted) setState(() => _coverUrl = url);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickTour() async {
    final picked = await ImagePicker().pickMultiImage(
        maxWidth: 2200, imageQuality: 88, limit: 12 - _tour.length);
    if (picked.isEmpty) return;
    setState(() => _tourUploading = true);
    try {
      for (final image in picked.take(12 - _tour.length)) {
        final bytes = await image.readAsBytes();
        final ext = image.name.split('.').last.toLowerCase();
        final url = await AuthApi.uploadMedia(
            bytes,
            image.name,
            ext == 'png'
                ? 'image/png'
                : ext == 'webp'
                    ? 'image/webp'
                    : 'image/jpeg');
        if (mounted) setState(() => _tour.add(url));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _tourUploading = false);
    }
  }
  Future<void> _save() async {
    if (_title.text.trim().length < 3) {
      setState(() => _error = 'Add a booth title with at least 3 characters.');
      return;
    }
    if (_description.text.trim().length < 10) {
      setState(() => _error =
          'Describe what visitors can see, try or request at this booth.');
      return;
    }
    if (_uploading) {
      setState(() => _error = 'Wait for the cover photo to finish uploading.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthApi.createEventBooth(widget.eventId, {
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'cover_url': _coverUrl,
        'cta_type': _cta,
        'cta_label': _label.text.trim(),
        if (_tour.isNotEmpty) 'tour': _tour,
        'trial_price_mrc': double.tryParse(_price.text.trim()) ?? 0,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = e is ApiException ? (e.message ?? '$e') : e.toString());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Open a digital booth'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Create'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF0E6B5C), Color(0xFF2C6E8F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('A booth visitors can act on',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 6),
                Text(
                    'Show the offer, add a real cover, and give visitors one clear action: quote, trial, booking or contact.',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 12.5, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            maxLength: 120,
            decoration: const InputDecoration(
                labelText: 'Booth title',
                helperText: 'The product or experience visitors will see.'),
          ),
          TextField(
            controller: _description,
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Booth description',
              helperText: 'Offer, proof, audience and what makes it useful.',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _cta,
            decoration: const InputDecoration(labelText: 'Visitor action'),
            items: const ['QUOTE', 'TRIAL', 'BOOK', 'CONTACT']
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => _cta = v ?? _cta),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _label,
            decoration: const InputDecoration(
                labelText: 'Button label',
                helperText: 'What the visitor taps, e.g. Book a fleet trial.'),
          ),
          if (_cta == 'TRIAL') ...[
            const SizedBox(height: 10),
            TextField(
              controller: _price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Trial price in MRC',
                  helperText: 'Use 0 for a free trial.'),
            ),
          ],
          const SizedBox(height: 18),
          Text('Cover photo',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          InkWell(
            onTap: _uploading ? null : _pickCover,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: _coverPath != null
                  ? Image.file(File(_coverPath!),
                      fit: BoxFit.cover, width: double.infinity)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _uploading
                            ? const CircularProgressIndicator(strokeWidth: 2)
                            : Icon(Icons.add_photo_alternate_outlined,
                                size: 34, color: cs.primary),
                        const SizedBox(height: 6),
                        Text(
                            _uploading
                                ? 'Uploading photo...'
                                : 'Choose a booth cover from your device',
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        Text('No links needed',
                            style: TextStyle(
                                fontSize: 10.5,
                                color: cs.onSurfaceVariant.withValues(alpha: .7))),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Text('360° booth tour',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(
              'Add 2-12 photos captured around the booth. Visitors can drag through them as an immersive tour.',
              style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _tourUploading ? null : _pickTour,
            icon: _tourUploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.threesixty, size: 20),
            label: Text(_tourUploading
                ? 'Uploading tour...'
                : _tour.isEmpty
                    ? 'Capture / add 360° tour photos'
                    : 'Add more tour photos ()'),
          ),
          if (_tour.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _tour.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.network(_tour[i],
                            width: 92, height: 64, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => _tour.removeAt(i)),
                          child: const CircleAvatar(
                              radius: 9,
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.close,
                                  size: 12, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!,
                  style: TextStyle(color: cs.error, fontSize: 12.5)),
            ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy || _uploading ? null : _save,
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Create booth'),
          ),
        ],
      ),
    );
  }
}
