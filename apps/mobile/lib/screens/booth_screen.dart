import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/services/share_policy.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets/animations.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/widgets/smart_image.dart';
import 'package:masaren/screens/booth_tour_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class BoothScreen extends StatefulWidget {
  final String boothId;
  final User user;
  const BoothScreen({super.key, required this.boothId, required this.user});

  @override
  State<BoothScreen> createState() => _BoothScreenState();
}

class _BoothScreenState extends State<BoothScreen> {
  Map<String, dynamic>? _booth;
  List<Map<String, dynamic>> _leads = [];
  bool _loading = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final booth = await AuthApi.booth(widget.boothId);
      List<Map<String, dynamic>> leads = [];
      if (booth['is_owner'] == true || booth['can_manage'] == true) {
        try {
          leads = await AuthApi.boothLeads(widget.boothId);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _booth = booth;
        _leads = leads;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ApiException ? e.message : e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _t(String key, String fallback) {
    final value = MasarenLocalizations.of(context, key);
    return value == key ? fallback : value;
  }

  bool get _owner =>
      _booth?['is_owner'] == true || _booth?['can_manage'] == true;

  Future<void> _submitLead() async {
    final booth = _booth;
    if (booth == null) return;
    final name = TextEditingController(text: widget.user.fullName);
    final email = TextEditingController(text: widget.user.email);
    final phone = TextEditingController(text: widget.user.phone ?? '');
    final message = TextEditingController();
    final type = (booth['cta_type'] ?? 'QUOTE').toString();
    final price = (booth['trial_price_mrc'] as num?)?.toDouble() ?? 0;
    final body = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  type == 'TRIAL'
                      ? _t('booth.bookTrial', 'Book a trial')
                      : type == 'CONTACT'
                          ? _t('booth.contactBooth', 'Contact the exhibitor')
                          : _t('booth.requestQuote', 'Request a quote'),
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w800)),
              if (type == 'TRIAL' && price > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                      _t('booth.trialCharge',
                              'Trial activation costs {mrc} MRC.')
                          .replaceAll('{mrc}', price.toStringAsFixed(0)),
                      style: TextStyle(
                          fontSize: 12.5,
                          color: Theme.of(sheetContext)
                              .colorScheme
                              .onSurfaceVariant)),
                ),
              const SizedBox(height: 14),
              TextField(
                  controller: name,
                  decoration:
                      InputDecoration(labelText: _t('booth.name', 'Name'))),
              TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration:
                      InputDecoration(labelText: _t('booth.email', 'Email'))),
              TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                      labelText: _t('booth.phone', 'Phone (optional)'))),
              TextField(
                  controller: message,
                  maxLines: 4,
                  decoration: InputDecoration(
                      labelText: _t('booth.message',
                          'What do you need? (quantity, market, timeline)'))),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () {
                  if (email.text.trim().isEmpty) return;
                  Navigator.pop(sheetContext, {
                    'type': type,
                    'name': name.text.trim(),
                    'email': email.text.trim(),
                    if (phone.text.trim().isNotEmpty)
                      'phone': phone.text.trim(),
                    if (message.text.trim().isNotEmpty)
                      'message': message.text.trim(),
                  });
                },
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                child: Text(_t('booth.sendRequest', 'Send request')),
              ),
            ],
          ),
        ),
      ),
    );
    name.dispose();
    email.dispose();
    phone.dispose();
    message.dispose();
    if (body == null) return;
    try {
      final result = await AuthApi.submitBoothLead(widget.boothId, body);
      if (!mounted) return;
      final charged = (result['charged'] as num?)?.toDouble() ?? 0;
      final reward = (result['reward_mrc'] as num?)?.toDouble() ?? 0;
      final parts = <String>[_t('booth.requestSent', 'Request sent.')];
      if (charged > 0) {
        parts.add(_t('booth.charged', '{mrc} MRC paid.').replaceAll(
            '{mrc}', charged.toStringAsFixed(charged % 1 == 0 ? 0 : 2)));
      }
      if (reward > 0) {
        parts.add(_t('booth.earned', '+{mrc} MRC earned.').replaceAll(
            '{mrc}', reward.toStringAsFixed(reward % 1 == 0 ? 0 : 2)));
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(parts.join(' '))));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is ApiException ? (e.message ?? '$e') : '$e')));
    }
  }

  Future<void> _activate() async {
    setState(() => _busy = true);
    try {
      await AuthApi.activateBooth(widget.boothId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('booth.activated',
              'Booth activated for 25 MRC and now visible to buyers.'))));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is ApiException ? (e.message ?? '$e') : '$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setLeadStatus(Map<String, dynamic> lead, String status) async {
    try {
      await AuthApi.updateBoothLead(
          widget.boothId, lead['id'].toString(), status);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is ApiException ? (e.message ?? '$e') : '$e')));
    }
  }

  Future<void> _openUrl(String? raw) async {
    final uri = Uri.tryParse(raw ?? '');
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _share() {
    final booth = _booth;
    if (booth == null) return;
    final text =
        '${booth['title']} · ${booth['event']?['title'] ?? 'MASAREEN'} · https://masareen.com/events/${booth['event_id']}';
    SharePolicy.copy(context,
        allowed: booth['event_activity_verified'] == true,
        text: text,
        confirmation: _t('booth.linkCopied', 'Booth link copied.'));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading && _booth == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: CircularProgressIndicator()));
    }
    if (_booth == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? _t('booth.notFound', 'Booth not found.')),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: _load, child: Text(_t('common.retry', 'Retry'))),
            ],
          ),
        ),
      );
    }
    final booth = _booth!;
    final owner = booth['owner'] is Map
        ? Map<String, dynamic>.from(booth['owner'] as Map)
        : const <String, dynamic>{};
    final tour = booth['tour'] is List
        ? (booth['tour'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : <String>[];
    final products = booth['products'] is List
        ? (booth['products'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : const <Map<String, dynamic>>[];
    final active = booth['active'] == true;
    final cta = (booth['cta_type'] ?? 'QUOTE').toString();
    final price = (booth['trial_price_mrc'] as num?)?.toDouble() ?? 0;
    final ctaLabel = (booth['cta_label'] ?? '').toString().isNotEmpty
        ? booth['cta_label'].toString()
        : cta == 'TRIAL'
            ? _t('booth.bookTrial', 'Book a trial')
            : cta == 'CONTACT'
                ? _t('booth.contactBooth', 'Contact')
                : _t('booth.requestQuote', 'Request a quote');

    return Scaffold(
      appBar: AppBar(
        title: Text((booth['title'] ?? '').toString()),
        actions: [
          IconButton(
              onPressed: _share,
              icon: const Icon(Icons.ios_share),
              tooltip: _t('booth.share', 'Share booth')),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 30),
          children: [
            FadeSlideIn(
              child: Stack(
                children: [
                  SmartImage(
                      url: booth['cover_url']?.toString(),
                      height: 210,
                      width: double.infinity,
                      fallbackIcon: Icons.storefront_outlined,
                      accent: cs.primary),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: .72)
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 14,
                    child: Row(
                      children: [
                        AppAvatar(
                            name: (owner['name'] ?? 'Exhibitor').toString(),
                            url: owner['avatar_url']?.toString(),
                            size: 44),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text((owner['name'] ?? '').toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                              Text(booth['event']?['title']?.toString() ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: .75),
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                        if (!active)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: cs.error.withValues(alpha: .18),
                                borderRadius: BorderRadius.circular(999)),
                            child: Text(_t('booth.inactive', 'Inactive'),
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: cs.error)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text((booth['title'] ?? '').toString(),
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: cs.onSurface)),
                      ),
                      Icon(Icons.visibility_outlined,
                          size: 15, color: cs.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text('${booth['views'] ?? 0}',
                          style: TextStyle(
                              fontSize: 11.5, color: cs.onSurfaceVariant)),
                      const SizedBox(width: 10),
                      Icon(Icons.handshake_outlined,
                          size: 15, color: cs.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text('${booth['leads_count'] ?? 0}',
                          style: TextStyle(
                              fontSize: 11.5, color: cs.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if ((booth['description'] ?? '').toString().isNotEmpty)
                    Text(booth['description'].toString(),
                        style: TextStyle(
                            fontSize: 14, height: 1.6, color: cs.onSurface)),
                  if (tour.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => BoothTourScreen(
                                  title: (booth['title'] ?? 'Booth').toString(),
                                  images: tour))),
                      icon: const Icon(Icons.threesixty, size: 20),
                      label: const Text('Explore 360° booth tour'),
                    ),
                  ],
                  if (products.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SectionTitle(
                        title: _t('booth.products', 'Products & services'),
                        icon: Icons.inventory_2_outlined),
                    ...products.map((p) => _ProductTile(product: p)),
                  ],
                  if ((booth['video_url'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => _openUrl(booth['video_url']?.toString()),
                      icon: const Icon(Icons.play_circle_outline),
                      label: Text(_t('booth.watchDemo', 'Watch product demo')),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (!_owner)
                    FilledButton.icon(
                      onPressed: active ? _submitLead : null,
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50)),
                      icon: const Icon(Icons.send_outlined),
                      label: Text(price > 0 && cta == 'TRIAL'
                          ? '$ctaLabel · ${price.toStringAsFixed(price % 1 == 0 ? 0 : 2)} MRC'
                          : ctaLabel),
                    ),
                  if (_owner && !active) ...[
                    _ActivationCard(onActivate: _busy ? null : _activate),
                    const SizedBox(height: 12),
                  ],
                  if (_owner) ...[
                    _SectionTitle(
                        title: _t('booth.analytics', 'Booth analytics'),
                        icon: Icons.insights_outlined),
                    Row(
                      children: [
                        Expanded(
                            child: _Metric('${booth['views'] ?? 0}',
                                _t('booth.views', 'Views'))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _Metric('${booth['interactions'] ?? 0}',
                                _t('booth.interactions', 'Interactions'))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _Metric('${booth['leads_count'] ?? 0}',
                                _t('booth.leads', 'Leads'))),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SectionTitle(
                        title: _t('booth.leadsTitle', 'Incoming leads'),
                        icon: Icons.handshake_outlined),
                    if (_leads.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(_t('booth.noLeads', 'No leads yet.'),
                            style: TextStyle(color: cs.onSurfaceVariant)),
                      )
                    else
                      ..._leads.map((lead) => _LeadTile(
                            lead: lead,
                            onStatus: (status) => _setLeadStatus(lead, status),
                          )),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 7),
          Text(title,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface)),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Map<String, dynamic> product;
  const _ProductTile({required this.product});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.inventory_2_outlined, size: 19, color: cs.primary),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((product['title'] ?? '').toString(),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface)),
                if ((product['description'] ?? '').toString().isNotEmpty)
                  Text(product['description'].toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          if ((product['price_note'] ?? '').toString().isNotEmpty)
            Text(product['price_note'].toString(),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.primary)),
        ],
      ),
    );
  }
}

class _ActivationCard extends StatelessWidget {
  final VoidCallback? onActivate;
  const _ActivationCard({required this.onActivate});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              MasarenLocalizations.of(context, 'booth.activateTitle') ==
                      'booth.activateTitle'
                  ? 'Activate this booth for 25 MRC'
                  : MasarenLocalizations.of(context, 'booth.activateTitle'),
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface)),
          const SizedBox(height: 3),
          Text(
              MasarenLocalizations.of(context, 'booth.activateBody') ==
                      'booth.activateBody'
                  ? 'Your booth becomes searchable and can receive quotes and trial bookings.'
                  : MasarenLocalizations.of(context, 'booth.activateBody'),
              style: TextStyle(
                  fontSize: 12, height: 1.4, color: cs.onSurfaceVariant)),
          const SizedBox(height: 10),
          FilledButton(
              onPressed: onActivate,
              child: Text(MasarenLocalizations.of(context, 'booth.activate') ==
                      'booth.activate'
                  ? 'Activate booth'
                  : MasarenLocalizations.of(context, 'booth.activate'))),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;
  const _Metric(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface)),
          Text(label,
              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _LeadTile extends StatelessWidget {
  final Map<String, dynamic> lead;
  final void Function(String status) onStatus;
  const _LeadTile({required this.lead, required this.onStatus});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = (lead['status'] ?? 'NEW').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant.withValues(alpha: .6)),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text((lead['name'] ?? 'Visitor').toString(),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface)),
              ),
              DropdownButton<String>(
                value: status,
                underline: const SizedBox.shrink(),
                style: TextStyle(fontSize: 11.5, color: cs.primary),
                items: const ['NEW', 'CONTACTED', 'QUALIFIED', 'CLOSED']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) {
                  if (v != null && v != status) onStatus(v);
                },
              ),
            ],
          ),
          Text(
              [
                (lead['type'] ?? '').toString(),
                if ((lead['email'] ?? '').toString().isNotEmpty)
                  lead['email'].toString(),
                if ((lead['phone'] ?? '').toString().isNotEmpty)
                  lead['phone'].toString(),
              ].join(' · '),
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          if ((lead['message'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(lead['message'].toString(),
                  style: TextStyle(
                      fontSize: 12, height: 1.35, color: cs.onSurface)),
            ),
        ],
      ),
    );
  }
}
