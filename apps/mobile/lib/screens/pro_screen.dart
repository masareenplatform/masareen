import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/screens/payments_screen.dart';

class ProScreen extends StatefulWidget {
  final User user;
  const ProScreen({super.key, required this.user});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  List<Map<String, dynamic>> _plans = [];
  Map<String, dynamic>? _me;
  Wallet? _wallet;
  bool _loading = true;
  String? _error;
  String? _busyPlan;

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
      final results = await Future.wait([
        AuthApi.proPlans(),
        AuthApi.proMe(),
        AuthApi.wallet(widget.user.id),
      ]);
      _plans = results[0] as List<Map<String, dynamic>>;
      _me = results[1] as Map<String, dynamic>;
      _wallet = results[2] as Wallet;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  String _loc(String key) => MasarenLocalizations.of(context, key);

  Map<String, dynamic>? get _active {
    final s = _me?['subscription'];
    return s is Map ? Map<String, dynamic>.from(s) : null;
  }

  Future<void> _subscribe(String plan) async {
    setState(() => _busyPlan = plan);
    try {
      await AuthApi.subscribePro(plan);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_loc('pro.subscribed'))));
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message ?? _loc('pro.failed'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_loc('pro.failed').replaceAll('{error}', '$e'))));
      }
    } finally {
      if (mounted) setState(() => _busyPlan = null);
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_loc('pro.cancel')),
        content: Text(_loc('pro.cancelConfirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_loc('action.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(_loc('pro.cancel'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AuthApi.cancelPro();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_loc('pro.cancelled'))));
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_loc('pro.failed').replaceAll('{error}', '$e'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_loc('pro.title'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                            onPressed: _load,
                            child: Text(_loc('common.retry'))),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _header(cs),
                      const SizedBox(height: 20),
                      Text(_loc('pro.choosePlan'),
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface)),
                      const SizedBox(height: 10),
                      ..._plans.map((p) => _planCard(cs, p)),
                      if (_active != null) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _cancel,
                          icon: Icon(Icons.cancel_outlined, color: cs.error),
                          label: Text(_loc('pro.cancel'),
                              style: TextStyle(color: cs.error)),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _header(ColorScheme cs) {
    final active = _active;
    final expires = DateTime.tryParse(active?['expires_at']?.toString() ?? '');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withValues(alpha: 0.65)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.workspace_premium,
                  color: Colors.white, size: 30),
              SizedBox(width: 10),
              Text('MASAREEN Pro',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          Text(_loc('pro.subtitle'),
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(active != null ? Icons.verified : Icons.lock_outline,
                  color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  active == null
                      ? _loc('pro.free')
                      : '${_loc('pro.active')}${expires == null ? '' : ' · ${_loc('pro.activeUntil').replaceAll('{date}', MaterialLocalizations.of(context).formatMediumDate(expires.toLocal()))}'}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.token, color: Colors.white70, size: 18),
              const SizedBox(width: 6),
              Text(
                '${_wallet?.balance.toStringAsFixed(2) ?? '0'} MRC',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PaymentsScreen(user: widget.user)));
                  await _load();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: Text(_loc('pro.topUp')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _planCard(ColorScheme cs, Map<String, dynamic> plan) {
    final id = plan['id']?.toString() ?? '';
    final price = (plan['price_mrc'] as num?)?.toDouble() ?? 0;
    final active = _active?['plan'] == id;
    final busy = _busyPlan == id || _busyPlan != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: active
            ? cs.primary.withValues(alpha: 0.12)
            : cs.surfaceContainerHigh.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color:
                active ? cs.primary : cs.outlineVariant.withValues(alpha: 0.4),
            width: active ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_loc('pro.plan.$id'),
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface)),
              if (active) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(_loc('pro.currentPlan'),
                      style: TextStyle(
                          color: cs.onPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              ],
              const Spacer(),
              Text('${price.toStringAsFixed(0)} MRC',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: cs.primary)),
            ],
          ),
          const SizedBox(height: 8),
          ..._features(id).map((key) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 16, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_loc(key),
                            style: TextStyle(
                                fontSize: 13, color: cs.onSurfaceVariant))),
                  ],
                ),
              )),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: busy ? null : () => _subscribe(id),
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(active ? _loc('pro.renew') : _loc('pro.subscribe')),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _features(String id) {
    final common = [
      'pro.feature.verified',
      'pro.feature.analytics',
      'pro.feature.badge',
      'pro.feature.priority',
      'pro.feature.support',
    ];
    if (id == 'yearly') common.add('pro.feature.yearly');
    return common;
  }
}
