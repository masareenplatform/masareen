import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentViewerScreen extends StatefulWidget {
  final String url;
  final String name;
  const DocumentViewerScreen(
      {super.key, required this.url, required this.name});

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  bool _loading = true;
  String? _error;
  String? _pdfPath;
  String? _docText;
  int? _pages;
  int _page = 0;

  bool get _isPdf {
    final n = widget.name.toLowerCase();
    return n.endsWith('.pdf') || widget.url.toLowerCase().contains('.pdf');
  }

  bool get _isDocx {
    final n = widget.name.toLowerCase();
    return n.endsWith('.docx') || n.endsWith('.doc');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<Uint8List> _download() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null || !uri.isScheme('https') && !uri.isScheme('http')) {
      throw const FormatException('This document URL is not allowed.');
    }
    final response = await http.get(uri).timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      throw Exception('The document could not be downloaded.');
    }
    if (response.bodyBytes.length > 40 * 1024 * 1024) {
      throw Exception('This document is too large to open safely.');
    }
    return response.bodyBytes;
  }

  Future<void> _openPdfExternally() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _load() async {
    try {
      if (_isPdf && kIsWeb) {
        if (mounted) {
          setState(() {
            _loading = false;
            _pdfPath = 'web';
          });
        }
        return;
      }
      final bytes = await _download();
      if (_isPdf) {
        final dir = await getTemporaryDirectory();
        final safeName = widget.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
        final file = File('${dir.path}/masareen_${safeName.isEmpty ? 'document.pdf' : safeName}');
        await file.writeAsBytes(bytes, flush: true);
        if (mounted) setState(() => _pdfPath = file.path);
      } else if (_isDocx) {
        final text = _extractDocx(bytes);
        if (mounted) setState(() => _docText = text);
      } else {
        throw Exception('This file type is not previewable inside the app.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _extractDocx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    ArchiveFile? entry;
    for (final file in archive.files) {
      if (file.name == 'word/document.xml') {
        entry = file;
        break;
      }
    }
    if (entry == null) {
      throw const FormatException('This Word document has no readable text.');
    }
    final xml = XmlDocument.parse(String.fromCharCodes(entry.content as List<int>));
    final buffer = StringBuffer();
    for (final element in xml.descendants.whereType<XmlElement>()) {
      if (element.name.local == 't' && element.name.prefix == 'w') {
        buffer.write(element.innerText);
      } else if (element.name.local == 'p' && element.name.prefix == 'w') {
        buffer.write('\n');
      }
    }
    final cleaned = buffer
        .toString()
        .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    if (cleaned.isEmpty) {
      throw const FormatException('This Word document has no readable text.');
    }
    return cleaned.length > 120000 ? '${cleaned.substring(0, 120000)}\n\n…' : cleaned;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_isPdf && _pdfPath != null && _pages != null)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: Text('${_page + 1} / $_pages',
                    style: TextStyle(
                        fontSize: 11, color: cs.onSurfaceVariant)),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.error)),
                  ),
                )
              : _isPdf && kIsWeb
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.picture_as_pdf_outlined,
                                size: 56, color: cs.primary),
                            const SizedBox(height: 14),
                            Text(widget.name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            Text(
                                'The PDF opens securely in your browser PDF viewer.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 12.5)),
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              onPressed: _openPdfExternally,
                              icon: const Icon(Icons.open_in_new, size: 18),
                              label: const Text('Open PDF'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _isPdf && _pdfPath != null
                  ? PDFView(
                      filePath: _pdfPath!,
                      enableSwipe: true,
                      swipeHorizontal: false,
                      autoSpacing: true,
                      pageFling: true,
                      pageSnap: true,
                      onRender: (pages) {
                        if (mounted) setState(() => _pages = pages);
                      },
                      onPageChanged: (page, total) {
                        if (mounted) setState(() => _page = page ?? 0);
                      },
                    )
                  : _docText != null
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: SelectableText(
                            _docText!,
                            style: TextStyle(
                                fontSize: 14,
                                height: 1.55,
                                color: cs.onSurface),
                          ),
                        )
                      : const SizedBox.shrink(),
    );
  }
}
