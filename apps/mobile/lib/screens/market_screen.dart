import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/models.dart';
import 'package:masaren/theme.dart';

class MarketScreen extends StatefulWidget {
  final User user;
  const MarketScreen({super.key, required this.user});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  List<Map<String, dynamic>> _markets = [];
  Map<String, dynamic>? _advantage;
  bool _loading = true;
  String? _error;
  String _filter = 'ALL';

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
        AuthApi.marketList(),
        AuthApi.marketAdvantage(),
      ]);
      if (!mounted) return;
      setState(() {
        _markets = results[0] as List<Map<String, dynamic>>;
        _advantage = results[1] as Map<String, dynamic>;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _visible {
    if (_filter == 'ALL') return _markets;
    return _markets.where((m) {
      final type = (m['entity_type'] ?? '').toString();
      final role = (m['entity_role'] ?? '').toString().toUpperCase();
      final institution = ['UNIVERSITY', 'INSTITUTION', 'ORGANIZATION',
              'MEDIA', 'GOVERNMENT', 'CORPORATE']
          .contains(role);
      if (_filter == 'PEOPLE') return type == 'USER' && !institution;
      if (_filter == 'INSTITUTIONS') return type == 'USER' && institution;
      return type == _filter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final visible = _visible;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Impact Market'),
        actions: [
          IconButton(
              onPressed: _load,
              tooltip: 'Refresh market',
              icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF0E6B5C), Color(0xFF174B43)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Your impact advantage',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(
                                '${_advantage?['discount_percent'] ?? 0}% off platform services',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text(
                                'Pro yearly: ${_advantage?['pro_yearly_price_mrc'] ?? 4500} MRC instead of 4500 MRC · holdings value ${_advantage?['holdings_value_mrc'] ?? 0} MRC',
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11.5,
                                    height: 1.4)),
                            const SizedBox(height: 8),
                            Text(
                                'Trading fees are 1.5%. 70% stays with the platform, 30% rewards the entity owner.',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: .65),
                                    fontSize: 10.5)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final f in const [
                              ('ALL', 'All'),
                              ('PEOPLE', 'People'),
                              ('INSTITUTIONS', 'Institutions'),
                              ('EVENT', 'Events'),
                              ('PROGRAM', 'Programs'),
                              ('PROJECT', 'Projects'),
                            ])
                              Padding(
                                padding: const EdgeInsets.only(right: 7),
                                child: ChoiceChip(
                                  label: Text(f.$2),
                                  selected: _filter == f.$1,
                                  onSelected: (_) =>
                                      setState(() => _filter = f.$1),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (visible.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text('No markets in this category yet.',
                                style: TextStyle(
                                    color: cs.onSurfaceVariant, fontSize: 12)),
                          ),
                        )
                      else
                        ...visible.map((m) => _MarketRow(
                              market: m,
                              onTap: () async {
                                await Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => MarketDetailScreen(
                                            marketId: m['id'].toString(),
                                            user: widget.user)));
                                _load();
                              },
                            )),
                    ],
                  ),
                ),
    );
  }
}

class _MarketRow extends StatelessWidget {
  final Map<String, dynamic> market;
  final VoidCallback onTap;
  const _MarketRow({required this.market, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final change = (market['change_percent'] as num?)?.toDouble() ?? 0;
    final up = change >= 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(12)),
                child: Text((market['symbol'] ?? 'M').toString(),
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: cs.primary)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((market['name'] ?? 'Entity').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                        '${market['entity_type']} · impact ${market['impact_score']} · cap ${market['market_cap_mrc']} MRC',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10.5, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${market['price_mrc']} MRC',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800)),
                  Text('${up ? '+' : ''}${change.toStringAsFixed(2)}%',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: up ? AppColors.brand : cs.error)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MarketDetailScreen extends StatefulWidget {
  final String marketId;
  final User user;
  const MarketDetailScreen(
      {super.key, required this.marketId, required this.user});

  @override
  State<MarketDetailScreen> createState() => _MarketDetailScreenState();
}

class _MarketDetailScreenState extends State<MarketDetailScreen> {
  Map<String, dynamic>? _market;
  bool _loading = true;
  String? _error;

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
      final data = await AuthApi.marketDetail(widget.marketId);
      if (mounted) setState(() => _market = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _trade(String side) async {
    final market = _market!;
    final controller = TextEditingController(text: '10');
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            18, 14, 18, MediaQuery.of(ctx).viewInsets.bottom + 18),
        child: StatefulBuilder(
          builder: (ctx, setSheet) {
            final shares = int.tryParse(controller.text) ?? 0;
            final price = (market['price_mrc'] as num?)?.toDouble() ?? 0;
            final gross = price * shares;
            final fee = gross * .015;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$side ${market['symbol']}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                    'Current price ${price.toStringAsFixed(2)} MRC · 1.5% brokerage fee',
                    style: TextStyle(
                        fontSize: 11.5,
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  onChanged: (_) => setSheet(() {}),
                  decoration: const InputDecoration(labelText: 'Shares'),
                ),
                const SizedBox(height: 10),
                Text('Total: ${(gross + (side == 'BUY' ? fee : -fee)).toStringAsFixed(2)} MRC',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: shares < 1
                      ? null
                      : () => Navigator.pop(ctx, {'shares': shares}),
                  child: Text('Confirm $side'),
                ),
              ],
            );
          },
        ),
      ),
    );
    controller.dispose();
    if (result == null) return;
    try {
      final res = await AuthApi.tradeMarket(market['id'].toString(),
          side: side, shares: result['shares'] as int);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '$side complete · fee ${res['fee_mrc']} MRC · new price ${res['market']['price_mrc']} MRC')));
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final m = _market;
    if (_loading && m == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (m == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error ?? 'Market not found')),
      );
    }
    final history = (m['history'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => (e['price_mrc'] as num?)?.toDouble() ?? 0)
        .where((e) => e > 0)
        .toList();
    final change = (m['change_percent'] as num?)?.toDouble() ?? 0;
    final up = change >= 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(m['symbol']?.toString() ?? 'Market'),
        actions: [
          IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: [
            Text((m['name'] ?? '').toString(),
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${m['price_mrc']} MRC',
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w900)),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${up ? '+' : ''}${change.toStringAsFixed(2)}%',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: up ? AppColors.brand : cs.error)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 132,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant)),
              child: history.length < 2
                  ? Center(
                      child: Text('Price history builds with the first trades.',
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant)))
                  : CustomPaint(
                      painter: _SparklinePainter(
                          values: history,
                          color: up ? AppColors.brand : cs.error),
                      size: Size.infinite,
                    ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Stat('Impact', '${m['impact_score']}', Icons.trending_up),
                _Stat('Market cap', '${m['market_cap_mrc']} MRC',
                    Icons.account_balance),
                _Stat('Holders', '${m['holders']}', Icons.people_outline),
                _Stat('Trades', '${m['trade_count']}', Icons.swap_horiz),
              ],
            ),
            const SizedBox(height: 12),
            Text(
                'My position: ${m['my_shares']} shares · avg ${m['my_avg_cost']} MRC',
                style: TextStyle(
                    fontSize: 12, color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _trade('BUY'),
                    icon: const Icon(Icons.add_chart),
                    label: const Text('Buy shares'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _trade('SELL'),
                    icon: const Icon(Icons.trending_down),
                    label: const Text('Sell shares'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if ((m['top_holders'] as List? ?? const []).isNotEmpty) ...[
              const Text('Recognised holders',
                  style:
                      TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              ...(m['top_holders'] as List).whereType<Map>().map((h) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                        backgroundColor: cs.primary.withValues(alpha: .12),
                        child: Text((h['name'] ?? 'M').toString().substring(0, 1))),
                    title: Text((h['name'] ?? 'Holder').toString()),
                    trailing: Text('${h['shares']} shares'),
                  )),
            ],
            const SizedBox(height: 8),
            Text(
                'The platform earns 1.5% on every trade, pays 30% of the fee to the entity owner, and keeps 70% to run the market. Prices move with verified impact and real demand.',
                style: TextStyle(
                    fontSize: 11, height: 1.45, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Stat(this.label, this.value, this.icon);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 150,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant)),
      child: Row(
        children: [
          Icon(icon, size: 17, color: cs.primary),
          const SizedBox(width: 7),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w800)),
            Text(label,
                style:
                    TextStyle(fontSize: 9.5, color: cs.onSurfaceVariant)),
          ]),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  _SparklinePainter({required this.values, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final range = math.max(.01, maxV - minV);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - ((values[i] - minV) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.values != values || old.color != color;
}
