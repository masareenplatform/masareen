import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/models.dart';
import 'package:masaren/screens/payments_screen.dart';
import 'package:masaren/screens/wallet_requests_screen.dart';
import 'package:masaren/screens/pro_screen.dart';

class WalletScreen extends StatefulWidget {
  final User user;
  const WalletScreen({super.key, required this.user});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Wallet? _wallet;
  List<CoinTx> _txs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _wallet = await AuthApi.wallet(widget.user.id);
      _txs = await AuthApi.transactions(widget.user.id);
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showClaimSheet() {
    final cs = Theme.of(context).colorScheme;
    final reward = _wallet?.dailyReward ?? 10;
    final alreadyClaimed = _wallet?.claimedToday ?? false;
    bool busy = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.35,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                child: Row(
                  children: [
                    Icon(Icons.token, color: cs.primary, size: 22),
                    const SizedBox(width: 10),
                    Text(MasarenLocalizations.of(context, 'wallet.claimReward'),
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: cs.onSurface)),
                    const Spacer(),
                    TextButton(
                      onPressed: busy || alreadyClaimed
                          ? null
                          : () async {
                              setSheetState(() => busy = true);
                              try {
                                final res = await AuthApi.claimDailyReward();
                                if (res.isNotEmpty) {
                                  _wallet = Wallet.fromJson(res);
                                }
                                if (ctx.mounted) Navigator.pop(ctx);
                                await _load();
                              } catch (e) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                          content: Text(MasarenLocalizations.of(
                                                  ctx, 'common.failed')
                                              .replaceAll('{error}', '$e'))));
                                }
                              } finally {
                                if (ctx.mounted) {
                                  setSheetState(() => busy = false);
                                }
                              }
                            },
                      child: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(MasarenLocalizations.of(
                              context,
                              alreadyClaimed
                                  ? 'wallet.claimedToday'
                                  : 'wallet.claim')),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: cs.outlineVariant),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.celebration, size: 44, color: cs.primary),
                      const SizedBox(height: 12),
                      Text(
                          '${reward.toStringAsFixed(reward % 1 == 0 ? 0 : 2)} MRC',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface)),
                      const SizedBox(height: 8),
                      Text(
                        MasarenLocalizations.of(
                            context, 'wallet.dailyRewardNote'),
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTransferSheet() {
    final cs = Theme.of(context).colorScheme;
    final recipientCtl = TextEditingController();
    final amountCtl = TextEditingController();
    bool busy = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.45,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz, color: cs.primary, size: 22),
                    const SizedBox(width: 10),
                    Text(
                        MasarenLocalizations.of(
                            context, 'wallet.transferTitle'),
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: cs.onSurface)),
                    const Spacer(),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () async {
                              final amount =
                                  double.tryParse(amountCtl.text) ?? 0;
                              if (amount <= 0 ||
                                  recipientCtl.text.trim().isEmpty) {
                                return;
                              }
                              setSheetState(() => busy = true);
                              try {
                                await AuthApi.transferCoins(
                                    recipientCtl.text.trim(), amount);
                                if (ctx.mounted) Navigator.pop(ctx);
                                await _load();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(MasarenLocalizations.of(
                                              context,
                                              'wallet.transferSuccess'))));
                                }
                              } catch (e) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                          content: Text(MasarenLocalizations.of(
                                                  ctx, 'common.failed')
                                              .replaceAll('{error}', '$e'))));
                                }
                              } finally {
                                if (ctx.mounted) {
                                  setSheetState(() => busy = false);
                                }
                              }
                            },
                      child: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(MasarenLocalizations.of(
                              context, 'wallet.transfer')),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: cs.outlineVariant),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    TextField(
                      controller: recipientCtl,
                      style: TextStyle(color: cs.onSurface),
                      decoration: InputDecoration(
                        hintText: MasarenLocalizations.of(
                            context, 'wallet.recipientId'),
                        prefixIcon: const Icon(Icons.person_outline, size: 20),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountCtl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: cs.onSurface),
                      decoration: InputDecoration(
                        hintText: MasarenLocalizations.of(
                            context, 'wallet.amountMrc'),
                        prefixIcon: const Icon(Icons.token, size: 20),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showConvertSheet() {
    final cs = Theme.of(context).colorScheme;
    final amountCtl = TextEditingController();
    bool busy = false;
    double? rate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          if (rate == null && !busy) {
            AuthApi.getExchangeRate().then((r) {
              if (ctx.mounted) {
                setSheetState(
                    () => rate = (r['rate_to_mrc'] as num?)?.toDouble() ?? 1.0);
              }
            }).catchError((_) {
              if (ctx.mounted) setSheetState(() => rate = 1.0);
            });
          }
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.45,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                  child: Row(
                    children: [
                      Icon(Icons.currency_exchange,
                          color: cs.primary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                          MasarenLocalizations.of(
                              context, 'wallet.convertTitle'),
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: cs.onSurface)),
                      const Spacer(),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () async {
                                final amount =
                                    double.tryParse(amountCtl.text) ?? 0;
                                if (amount <= 0) return;
                                setSheetState(() => busy = true);
                                try {
                                  await AuthApi.convertCoins(amount, 'EGP');
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  await _load();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                MasarenLocalizations.of(context,
                                                    'wallet.convertSuccess'))));
                                  }
                                } catch (e) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                            content: Text(MasarenLocalizations
                                                    .of(ctx, 'common.failed')
                                                .replaceAll('{error}', '$e'))));
                                  }
                                } finally {
                                  if (ctx.mounted) {
                                    setSheetState(() => busy = false);
                                  }
                                }
                              },
                        child: busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : Text(MasarenLocalizations.of(
                                context, 'wallet.convert')),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: cs.outlineVariant),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (rate != null)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 18, color: cs.primary),
                              const SizedBox(width: 10),
                              Text(
                                  MasarenLocalizations.of(
                                          context, 'wallet.exchangeRate')
                                      .replaceAll(
                                          '{rate}', rate!.toStringAsFixed(2)),
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface)),
                            ],
                          ),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.all(14),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: amountCtl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: TextStyle(color: cs.onSurface),
                        decoration: InputDecoration(
                          hintText: MasarenLocalizations.of(
                              context, 'wallet.amountMrc'),
                          prefixIcon: const Icon(Icons.token, size: 20),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (rate != null)
                        Text(
                          MasarenLocalizations.of(context, 'wallet.receive')
                              .replaceAll(
                                  '{amount}',
                                  (rate != null
                                          ? (double.tryParse(amountCtl.text) ??
                                                  0) *
                                              rate!
                                          : 0)
                                      .toStringAsFixed(2)),
                          style: TextStyle(
                              fontSize: 13, color: cs.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(MasarenLocalizations.of(context, 'wallet.coinTitle')),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: cs.primary),
            onPressed: _showClaimSheet,
            tooltip: MasarenLocalizations.of(context, 'wallet.claimReward'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(message: _error, onRetry: () => _load())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Balance card
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              cs.primary,
                              cs.primary.withValues(alpha: 0.7)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.token,
                                  size: 32, color: Colors.white),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _wallet != null
                                  ? _wallet!.balance.toStringAsFixed(2)
                                  : '0',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 42,
                                  fontWeight: FontWeight.w700),
                            ),
                            const Text('MRC',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                    letterSpacing: 2)),
                            const SizedBox(height: 4),
                            Text(
                                MasarenLocalizations.of(
                                    context, 'wallet.coinTitle'),
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Quick actions
                      Row(
                        children: [
                          Expanded(
                              child: _QuickAction(
                            icon: Icons.arrow_downward,
                            label:
                                MasarenLocalizations.of(context, 'wallet.earn'),
                            onTap: _showClaimSheet,
                            cs: cs,
                          )),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _QuickAction(
                            icon: Icons.add_circle_outline,
                            label: MasarenLocalizations.of(
                                context, 'wallet.topUp'),
                            onTap: () async {
                              await Navigator.of(context)
                                  .push(MaterialPageRoute(
                                builder: (_) =>
                                    PaymentsScreen(user: widget.user),
                              ));
                              await _load();
                            },
                            cs: cs,
                          )),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _QuickAction(
                            icon: Icons.swap_horiz,
                            label: MasarenLocalizations.of(
                                context, 'wallet.transfer'),
                            onTap: _showTransferSheet,
                            cs: cs,
                          )),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _QuickAction(
                            icon: Icons.currency_exchange,
                            label: MasarenLocalizations.of(
                                context, 'wallet.convert'),
                            onTap: _showConvertSheet,
                            cs: cs,
                          )),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.receipt_long_outlined),
                          title: const Text('Buy MRC, cash out & invoices'),
                          subtitle: const Text(
                              'Manual InstaPay / bank processing until Paymob is active'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) =>
                                    WalletRequestsScreen(user: widget.user)));
                            await _load();
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          await Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ProScreen(user: widget.user)));
                          await _load();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              cs.primary.withValues(alpha: 0.18),
                              cs.primary.withValues(alpha: 0.05),
                            ]),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: cs.primary.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.workspace_premium,
                                  color: cs.primary, size: 26),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        MasarenLocalizations.of(
                                            context, 'pro.title'),
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: cs.onSurface)),
                                    Text(
                                        MasarenLocalizations.of(
                                            context, 'pro.subtitle'),
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: cs.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                              Icon(directionalChevronIcon(context),
                                  color: cs.primary, size: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text(
                          MasarenLocalizations.of(
                              context, 'wallet.transactionHistory'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          )),
                      const SizedBox(height: 12),

                      if (_txs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                                MasarenLocalizations.of(
                                    context, 'wallet.noTransactions'),
                                style: TextStyle(color: cs.onSurfaceVariant)),
                          ),
                        )
                      else
                        ..._txs.map((t) => _TxTile(tx: t, cs: cs)),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme cs;
  const _QuickAction(
      {required this.icon,
      required this.label,
      required this.onTap,
      required this.cs});

  @override
  Widget build(BuildContext context) {
    return Clickable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: cs.primary, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  final CoinTx tx;
  final ColorScheme cs;
  const _TxTile({required this.tx, required this.cs});

  @override
  Widget build(BuildContext context) {
    final credit =
        tx.type == 'EARN' || tx.type == 'TRANSFER_IN' || tx.type == 'DEPOSIT';
    final typeKey = 'wallet.tx.${tx.type.toLowerCase()}';
    final typeLabel = MasarenLocalizations.of(context, typeKey);
    final title = tx.reference ?? (typeLabel == typeKey ? tx.type : typeLabel);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: credit
                  ? AppColors.accent.withValues(alpha: 0.15)
                  : Colors.redAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              credit ? Icons.arrow_downward : Icons.arrow_upward,
              color: credit ? AppColors.accent : Colors.redAccent,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                Text(timeAgo(tx.createdAt, context: context),
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
          Text(
            '${credit ? '+' : ''}${tx.amount.toStringAsFixed(2)}',
            style: TextStyle(
                color: credit ? AppColors.accent : Colors.redAccent,
                fontWeight: FontWeight.w600,
                fontSize: 15),
          ),
        ],
      ),
    );
  }
}
