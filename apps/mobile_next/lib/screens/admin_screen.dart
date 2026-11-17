import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/screens/ads_screen.dart';
import 'package:masaren/screens/admin_entity_review_screen.dart';
import 'package:masaren/screens/admin_feedback_screen.dart';
import 'package:masaren/screens/admin_ota_screen.dart';
import 'package:masaren/screens/admin_announcements_screen.dart';
import 'package:masaren/screens/admin_insights_screen.dart';
import 'package:masaren/screens/admin_operations_screen.dart';
import 'package:masaren/screens/admin_wallet_screen.dart';
import 'package:masaren/screens/messages_screen.dart';
import 'package:masaren/screens/wallet_screen.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';

class AdminScreen extends StatefulWidget {
  final User user;
  final int initialTab;
  const AdminScreen({super.key, required this.user, this.initialTab = 0});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _isAdmin = false;
  late int _tab = widget.initialTab.clamp(0, 6);
  String? _statsError;

  Map<String, dynamic>? _stats;
  bool _statsLoading = true;

  List<Map<String, dynamic>> _reports = [];
  Map<String, dynamic> _reportCounts = {};
  bool _reportsLoading = false;
  bool _reportsLoaded = false;
  String _reportStatus = 'OPEN';

  List<Campaign> _ads = [];
  bool _adsLoading = false;
  bool _adsLoaded = false;
  String _adStatus = 'ALL';

  List<Map<String, dynamic>> _inquiries = [];
  bool _inquiriesLoading = false;
  bool _inquiriesLoaded = false;
  String _inquiryStatus = 'ALL';

  List<Map<String, dynamic>> _submissions = [];
  bool _submissionsLoading = false;
  bool _submissionsLoaded = false;
  String _submissionStatus = 'ALL';

  List<Map<String, dynamic>> _users = [];
  bool _usersLoading = false;
  bool _usersLoaded = false;
  String _userSearch = '';
  Timer? _userDebounce;

  List<Map<String, dynamic>> _payments = [];
  bool _paymentsLoading = false;
  bool _paymentsLoaded = false;
  String _paymentStatus = 'ALL';

  Map<String, dynamic>? _rate;
  final _rateCtl = TextEditingController();

  static const _purple = Color(0xFF8B5CF6);
  static const _green = Color(0xFF22C55E);
  static const _amber = Color(0xFFF59E0B);

  static const _reportStatuses = ['OPEN', 'RESOLVED', 'DISMISSED', 'ALL'];
  static const _adStatuses = [
    'ALL',
    'DRAFT',
    'ACTIVE',
    'PAUSED',
    'COMPLETED',
    'REJECTED',
  ];
  static const _inquiryStatuses = [
    'ALL',
    'OPEN',
    'IN_REVIEW',
    'RESOLVED',
    'CLOSED',
  ];
  static const _submissionStatuses = [
    'ALL',
    'SUBMITTED',
    'AI_REVIEW',
    'HUMAN_REVIEW',
    'VERIFIED',
    'REJECTED',
  ];
  static const _paymentStatuses = ['ALL', 'SUCCESS', 'PENDING', 'FAILED'];

  @override
  void initState() {
    super.initState();
    _isAdmin =
        widget.user.isAdmin || widget.user.role.toUpperCase().contains('ADMIN');
    if (_isAdmin) {
      _loadStats();
      _loadRate();
    } else {
      _statsLoading = false;
    }
  }

  @override
  void dispose() {
    _userDebounce?.cancel();
    _rateCtl.dispose();
    super.dispose();
  }

  String _err(Object error) {
    if (error is ApiException) {
      final message = error.message?.trim();
      if (message != null &&
          message.isNotEmpty &&
          message.toLowerCase() != 'null') {
        return message;
      }
    }
    return 'Something went wrong. Pull to refresh and try again.';
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadStats() async {
    setState(() {
      _statsLoading = true;
      _statsError = null;
    });
    try {
      final stats = await AuthApi.adminStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _statsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statsError = _err(error);
        _statsLoading = false;
      });
    }
  }

  Future<void> _loadReports({bool force = false}) async {
    if (_reportsLoading || (_reportsLoaded && !force)) return;
    setState(() => _reportsLoading = true);
    try {
      final page = await AuthApi.adminReportPage(
        status: _reportStatus,
        limit: 150,
      );
      if (!mounted) return;
      setState(() {
        _reports = _asMaps(page['items']);
        _reportCounts = _asMap(page['counts']);
        _reportsLoaded = true;
      });
    } catch (error) {
      _snack(_err(error));
    } finally {
      if (mounted) setState(() => _reportsLoading = false);
    }
  }

  Future<void> _loadAds({bool force = false}) async {
    if (_adsLoading || (_adsLoaded && !force)) return;
    setState(() => _adsLoading = true);
    try {
      final ads = await AuthApi.adminAds(
        status: _adStatus == 'ALL' ? null : _adStatus,
      );
      if (!mounted) return;
      setState(() {
        _ads = ads;
        _adsLoaded = true;
      });
    } catch (error) {
      _snack(_err(error));
    } finally {
      if (mounted) setState(() => _adsLoading = false);
    }
  }

  Future<void> _loadInquiries({bool force = false}) async {
    if (_inquiriesLoading || (_inquiriesLoaded && !force)) return;
    setState(() => _inquiriesLoading = true);
    try {
      final rows = await AuthApi.adminInquiries(
        status: _inquiryStatus == 'ALL' ? null : _inquiryStatus,
      );
      if (!mounted) return;
      setState(() {
        _inquiries = rows;
        _inquiriesLoaded = true;
      });
    } catch (error) {
      _snack(_err(error));
    } finally {
      if (mounted) setState(() => _inquiriesLoading = false);
    }
  }

  Future<void> _loadSubmissions({bool force = false}) async {
    if (_submissionsLoading || (_submissionsLoaded && !force)) return;
    setState(() => _submissionsLoading = true);
    try {
      final rows = await AuthApi.adminSubmissions(
        status: _submissionStatus == 'ALL' ? null : _submissionStatus,
      );
      if (!mounted) return;
      setState(() {
        _submissions = rows;
        _submissionsLoaded = true;
      });
    } catch (error) {
      _snack(_err(error));
    } finally {
      if (mounted) setState(() => _submissionsLoading = false);
    }
  }

  Future<void> _loadUsers({bool force = false}) async {
    if (_usersLoading || (_usersLoaded && !force)) return;
    setState(() => _usersLoading = true);
    try {
      final rows = await AuthApi.adminUsers(_userSearch);
      if (!mounted) return;
      setState(() {
        _users = rows;
        _usersLoaded = true;
      });
    } catch (error) {
      _snack(_err(error));
    } finally {
      if (mounted) setState(() => _usersLoading = false);
    }
  }

  Future<void> _loadPayments({bool force = false}) async {
    if (_paymentsLoading || (_paymentsLoaded && !force)) return;
    setState(() => _paymentsLoading = true);
    try {
      final rows = await AuthApi.adminPayments(
        status: _paymentStatus == 'ALL' ? null : _paymentStatus,
      );
      if (!mounted) return;
      setState(() {
        _payments = rows;
        _paymentsLoaded = true;
      });
    } catch (error) {
      _snack(_err(error));
    } finally {
      if (mounted) setState(() => _paymentsLoading = false);
    }
  }

  Future<void> _loadRate() async {
    try {
      final rate = await AuthApi.coinRate('EGP');
      if (!mounted) return;
      setState(() {
        _rate = rate;
        final value = rate['rate_to_mrc'];
        if (value != null && _rateCtl.text.isEmpty) {
          _rateCtl.text = '$value';
        }
      });
    } catch (_) {}
  }

  void _onTab(int index) {
    setState(() => _tab = index);
    switch (index) {
      case 1:
        _loadReports();
        break;
      case 2:
        _loadAds();
        break;
      case 3:
        _loadInquiries();
        break;
      case 4:
        _loadSubmissions();
        break;
      case 5:
        _loadUsers();
        break;
      case 6:
        _loadPayments();
        break;
    }
  }

  Future<void> _refreshCurrent() async {
    switch (_tab) {
      case 0:
        await _loadStats();
        break;
      case 1:
        await _loadReports(force: true);
        break;
      case 2:
        await _loadAds(force: true);
        break;
      case 3:
        await _loadInquiries(force: true);
        break;
      case 4:
        await _loadSubmissions(force: true);
        break;
      case 5:
        await _loadUsers(force: true);
        break;
      case 6:
        await _loadPayments(force: true);
        break;
    }
    if (mounted) {
      _snack(MasarenLocalizations.of(context, 'admin.refreshDone'));
    }
  }

  Future<void> _resolveReport(
    Map<String, dynamic> report,
    String status, {
    bool hide = false,
  }) async {
    try {
      await AuthApi.resolveReport(
        report['id'].toString(),
        status: status,
        action: hide ? 'HIDE' : 'NONE',
      );
      if (!mounted) return;
      _snack(MasarenLocalizations.of(context, 'admin.refreshDone'));
      await _loadReports(force: true);
      _loadStats();
    } catch (error) {
      _snack(_err(error));
    }
  }

  Future<void> _updateInquiry(
    Map<String, dynamic> inquiry,
    String status,
  ) async {
    try {
      await AuthApi.adminUpdateInquiry(inquiry['id'].toString(), status);
      if (!mounted) return;
      await _loadInquiries(force: true);
      _loadStats();
    } catch (error) {
      _snack(_err(error));
    }
  }

  Future<void> _submissionVerdict(
    Map<String, dynamic> submission,
    String status,
  ) async {
    try {
      await AuthApi.adminSubmissionVerdict(submission['id'].toString(), status);
      if (!mounted) return;
      await _loadSubmissions(force: true);
      _loadStats();
    } catch (error) {
      _snack(_err(error));
    }
  }

  Future<void> _setRate() async {
    final value = double.tryParse(_rateCtl.text.trim());
    if (value == null || value <= 0) return;
    try {
      final rate = await AuthApi.setCoinRate('EGP', value);
      if (!mounted) return;
      setState(() => _rate = rate);
      _snack(MasarenLocalizations.of(context, 'admin.rateUpdated'));
    } catch (error) {
      _snack(_err(error));
    }
  }

  Future<void> _setAdStatus(
    Campaign campaign,
    String status, {
    bool confirm = false,
  }) async {
    if (confirm) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(MasarenLocalizations.of(context, 'admin.rejectAd')),
          content: Text(
            MasarenLocalizations.of(context, 'admin.rejectAdConfirm'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(MasarenLocalizations.of(context, 'action.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(MasarenLocalizations.of(context, 'common.confirm')),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      await AuthApi.setCampaignStatus(campaign.id, status);
      if (!mounted) return;
      await _loadAds(force: true);
      _loadStats();
      if (mounted) {
        _snack(MasarenLocalizations.of(context, 'admin.refreshDone'));
      }
    } catch (error) {
      _snack(_err(error));
    }
  }

  void _onAdminTool(String value) {
    switch (value) {
      case 'test':
        _sendTestNotification();
        break;
      case 'insights':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AdminInsightsScreen(user: widget.user),
          ),
        );
        break;
      case 'operations':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AdminOperationsScreen(user: widget.user),
          ),
        );
        break;
      case 'wallet':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AdminWalletScreen(user: widget.user),
          ),
        );
        break;
      case 'announcements':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AdminAnnouncementsScreen(user: widget.user),
          ),
        );
        break;
      case 'ota':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AdminOtaScreen(user: widget.user)),
        );
        break;
      case 'feedback':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AdminFeedbackScreen(user: widget.user),
          ),
        );
        break;
      case 'entities':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AdminEntityReviewScreen(user: widget.user),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tabs = [
      ('admin.dashboard', Icons.dashboard_outlined),
      ('admin.reports', Icons.flag_outlined),
      ('admin.ads', Icons.campaign_outlined),
      ('admin.inquiries', Icons.support_agent_outlined),
      ('admin.verification', Icons.verified_outlined),
      ('admin.users', Icons.people_outline),
      ('admin.payments', Icons.payments_outlined),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(MasarenLocalizations.of(context, 'admin.title')),
          actions: [
            PopupMenuButton<String>(
              tooltip: MasarenLocalizations.of(context, 'admin.tools'),
              icon: const Icon(Icons.more_vert),
              onSelected: _onAdminTool,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'operations',
                  child: ListTile(
                    leading: const Icon(Icons.monitor_heart_outlined),
                    title: Text(
                      MasarenLocalizations.of(context, 'admin.operations'),
                    ),
                  ),
                ),
                const PopupMenuItem(
                  value: 'insights',
                  child: ListTile(
                    leading: Icon(Icons.query_stats_outlined),
                    title: Text('Reports & analytics'),
                  ),
                ),
                PopupMenuItem(
                  value: 'wallet',
                  child: ListTile(
                    leading: const Icon(Icons.account_balance_wallet_outlined),
                    title: Text(
                      Localizations.localeOf(context).languageCode == 'ar'
                          ? 'مدفوعات MRC'
                          : 'MRC payments',
                    ),
                  ),
                ),
                PopupMenuItem(
                  value: 'announcements',
                  child: ListTile(
                    leading: const Icon(Icons.campaign_outlined),
                    title: Text(
                      MasarenLocalizations.of(context, 'announcements.title'),
                    ),
                  ),
                ),
                PopupMenuItem(
                  value: 'ota',
                  child: ListTile(
                    leading: const Icon(Icons.system_update_alt),
                    title: Text(MasarenLocalizations.of(context, 'ota.title')),
                  ),
                ),
                PopupMenuItem(
                  value: 'feedback',
                  child: ListTile(
                    leading: const Icon(Icons.feedback_outlined),
                    title: Text(
                      MasarenLocalizations.of(context, 'feedback.adminTitle'),
                    ),
                  ),
                ),
                PopupMenuItem(
                  value: 'entities',
                  child: ListTile(
                    leading: const Icon(Icons.fact_check_outlined),
                    title: Text(
                      MasarenLocalizations.of(context, 'admin.entityReview'),
                    ),
                  ),
                ),
                PopupMenuItem(
                  value: 'test',
                  child: ListTile(
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: Text(
                      MasarenLocalizations.of(
                        context,
                        'admin.testNotification',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            IconButton(
              tooltip: MasarenLocalizations.of(context, 'admin.refresh'),
              onPressed: _refreshCurrent,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: TabBar(
            onTap: _onTab,
            isScrollable: true,
            indicatorColor: cs.primary,
            labelColor: cs.primary,
            unselectedLabelColor: cs.onSurfaceVariant,
            tabs: [
              for (final tab in tabs)
                Tab(
                  icon: Icon(tab.$2, size: 18),
                  text: MasarenLocalizations.of(context, tab.$1),
                ),
            ],
          ),
        ),
        body: _buildTab(),
      ),
    );
  }

  Widget _buildTab() {
    switch (_tab) {
      case 0:
        return _buildDashboard();
      case 1:
        return _buildReports();
      case 2:
        return _buildAds();
      case 3:
        return _buildInquiries();
      case 4:
        return _buildVerification();
      case 5:
        return _buildUsers();
      case 6:
        return _buildPayments();
      default:
        return _buildDashboard();
    }
  }

  Widget _buildDashboard() {
    final cs = Theme.of(context).colorScheme;
    if (_statsLoading && _stats == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_stats == null) {
      return ErrorView(
        message:
            _statsError ?? 'Could not load the dashboard. Pull to refresh.',
        onRetry: _loadStats,
      );
    }
    final stats = _stats!;
    final totals = _asMap(stats['totals']);
    final series = _asMaps(stats['series']);
    final topCampaigns = _asMaps(stats['top_campaigns']);
    final recentReports = _asMaps(stats['recent_reports']);
    final recentPayments = _asMaps(stats['recent_payments']);
    final recentInquiries = _asMaps(stats['recent_inquiries']);
    final recentUsers = _asMaps(stats['recent_users']);
    final bySdg = _asMaps(stats['by_sdg']);

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _pulseHero(totals),
          SectionTitle(
            title: MasarenLocalizations.of(context, 'admin.platformStats'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _KpiCard(
                  icon: Icons.people,
                  label: MasarenLocalizations.of(context, 'admin.totalUsers'),
                  value: _fmt(totals['users']),
                  color: AppColors.azure,
                ),
                _KpiCard(
                  icon: Icons.bolt,
                  label: MasarenLocalizations.of(context, 'admin.active24h'),
                  value: _fmt(totals['active_users_24h']),
                  color: _green,
                ),
                _KpiCard(
                  icon: Icons.feed,
                  label: MasarenLocalizations.of(context, 'admin.totalPosts'),
                  value: _fmt(totals['posts']),
                  color: AppColors.accent,
                ),
                _KpiCard(
                  icon: Icons.chat_bubble_outline,
                  label: MasarenLocalizations.of(context, 'admin.comments'),
                  value: _fmt(totals['comments']),
                  color: _purple,
                ),
                _KpiCard(
                  icon: Icons.flag,
                  label: MasarenLocalizations.of(context, 'admin.reportsOpen'),
                  value: _fmt(totals['reports_open']),
                  color: AppColors.warm,
                ),
                _KpiCard(
                  icon: Icons.support_agent,
                  label: MasarenLocalizations.of(
                    context,
                    'admin.inquiriesOpen',
                  ),
                  value: _fmt(totals['inquiries_open']),
                  color: _amber,
                ),
                _KpiCard(
                  icon: Icons.campaign,
                  label: MasarenLocalizations.of(
                    context,
                    'admin.campaignsActive',
                  ),
                  value: _fmt(totals['campaigns_active']),
                  color: AppColors.azure,
                ),
                _KpiCard(
                  icon: Icons.visibility,
                  label: MasarenLocalizations.of(
                    context,
                    'admin.adImpressions',
                  ),
                  value: _fmt(totals['ad_impressions']),
                  color: _purple,
                ),
                _KpiCard(
                  icon: Icons.ads_click,
                  label: MasarenLocalizations.of(context, 'admin.adClicks'),
                  value: _fmt(totals['ad_clicks']),
                  color: AppColors.accent,
                ),
                _KpiCard(
                  icon: Icons.paid_outlined,
                  label: MasarenLocalizations.of(context, 'admin.adSpend'),
                  value: '${_decimal(totals['ad_spend_mrc'])} MRC',
                  color: _green,
                ),
                _KpiCard(
                  icon: Icons.token,
                  label: MasarenLocalizations.of(context, 'admin.coinSupply'),
                  value: '${_decimal(totals['coin_supply_mrc'])} MRC',
                  color: AppColors.azure,
                ),
                _KpiCard(
                  icon: Icons.workspace_premium,
                  label: MasarenLocalizations.of(context, 'admin.proActive'),
                  value: _fmt(totals['pro_active']),
                  color: AppColors.accent,
                ),
                _KpiCard(
                  icon: Icons.account_balance_wallet,
                  label: MasarenLocalizations.of(
                    context,
                    'admin.paymentsSuccess',
                  ),
                  value: '${_decimal(totals['payments_success_egp'])} EGP',
                  color: _green,
                ),
                _KpiCard(
                  icon: Icons.pending_actions,
                  label: MasarenLocalizations.of(
                    context,
                    'admin.submissionsPending',
                  ),
                  value: _fmt(totals['submissions_pending']),
                  color: _amber,
                ),
              ],
            ),
          ),
          SectionTitle(title: MasarenLocalizations.of(context, 'admin.growth')),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
              child: _ActivityChart(series: series),
            ),
          ),
          if (bySdg.isNotEmpty) ...[
            SectionTitle(
              title: MasarenLocalizations.of(context, 'createPost.sdg'),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in bySdg.take(8))
                      Chip(
                        label: Text(
                          'SDG ${item['sdg'] ?? '-'}  ${_fmt(item['count'])}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          SectionTitle(
            title: MasarenLocalizations.of(context, 'admin.topCampaigns'),
          ),
          if (topCampaigns.isEmpty)
            _emptyCard(MasarenLocalizations.of(context, 'admin.noAds'))
          else
            ...topCampaigns
                .take(5)
                .map(
                  (item) =>
                      _AdminCampaignTile(campaign: Campaign.fromJson(item)),
                ),
          SectionTitle(
            title: MasarenLocalizations.of(context, 'admin.recentReports'),
          ),
          _recentReportsCard(recentReports),
          SectionTitle(
            title: MasarenLocalizations.of(context, 'admin.recentPayments'),
          ),
          _recentPaymentsCard(recentPayments),
          SectionTitle(
            title: MasarenLocalizations.of(context, 'admin.recentInquiries'),
          ),
          _recentInquiriesCard(recentInquiries),
          SectionTitle(
            title: MasarenLocalizations.of(context, 'admin.recentUsers'),
          ),
          _recentUsersCard(recentUsers),
          SectionTitle(
            title: MasarenLocalizations.of(context, 'admin.exchangeRate'),
          ),
          _rateCard(cs),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.campaign, color: AppColors.azure),
            title: Text(MasarenLocalizations.of(context, 'admin.adsCampaigns')),
            subtitle: Text(MasarenLocalizations.of(context, 'admin.manageAds')),
            trailing: Icon(directionalChevronIcon(context)),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AdsScreen(user: widget.user)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.token, color: AppColors.accent),
            title: Text(MasarenLocalizations.of(context, 'admin.coinWallets')),
            subtitle: Text(
              MasarenLocalizations.of(context, 'admin.inspectCoin'),
            ),
            trailing: Icon(directionalChevronIcon(context)),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => WalletScreen(user: widget.user),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pulseHero(Map<String, dynamic> totals) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: brandGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            MasarenLocalizations.of(context, 'admin.platformPulse'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            MasarenLocalizations.of(context, 'admin.liveOverview'),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 24,
            runSpacing: 14,
            children: [
              _HeroStat(
                value: _fmt(totals['users']),
                label: MasarenLocalizations.of(context, 'admin.totalUsers'),
              ),
              _HeroStat(
                value: _fmt(totals['active_users_24h']),
                label: MasarenLocalizations.of(context, 'admin.active24h'),
              ),
              _HeroStat(
                value: _fmt(totals['posts']),
                label: MasarenLocalizations.of(context, 'admin.totalPosts'),
              ),
              _HeroStat(
                value: _fmt(totals['reports_open']),
                label: MasarenLocalizations.of(context, 'admin.reportsOpen'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReports() {
    if (_reportsLoading && _reports.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final counts = _reportCounts;
    return RefreshIndicator(
      onRefresh: () => _loadReports(force: true),
      child: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 28),
        children: [
          _filterBar(_reportStatuses, _reportStatus, (value) {
            setState(() => _reportStatus = value);
            _loadReports(force: true);
          }, (value) => _statusText(value)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _countChip('admin.open', counts['open'], AppColors.warm),
                _countChip('admin.resolved', counts['resolved'], _green),
                _countChip(
                  'admin.dismissed',
                  counts['dismissed'],
                  AppColors.muted,
                ),
                _countChip('admin.all', counts['total'], AppColors.azure),
              ],
            ),
          ),
          if (_reports.isEmpty)
            _emptyCard(MasarenLocalizations.of(context, 'admin.noReports'))
          else
            ..._reports.map(_reportCard),
        ],
      ),
    );
  }

  Widget _reportCard(Map<String, dynamic> report) {
    final cs = Theme.of(context).colorScheme;
    final status = (report['status'] ?? 'OPEN').toString().toUpperCase();
    final targetType = (report['target_type'] ?? '').toString();
    final preview = _asMap(report['target_preview']);
    final canAct = status == 'OPEN';
    final canHide = targetType == 'post' || targetType == 'comment';
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusChip(status: status, label: _statusText(status)),
                const SizedBox(width: 8),
                Text(
                  _targetLabel(targetType),
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  _date(report['created_at']),
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              (preview['text'] ?? report['details'] ?? 'No preview').toString(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: cs.onSurface, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              '${MasarenLocalizations.of(context, 'admin.reporter')}: '
              '${report['reporter_name'] ?? report['reporter_email'] ?? '-'}',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
            Text(
              '${MasarenLocalizations.of(context, 'admin.reason')}: '
              '${report['reason'] ?? '-'}',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
            if (report['details'] != null &&
                report['details'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  report['details'].toString(),
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
              ),
            if (canAct) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  TextButton(
                    onPressed: () => _resolveReport(report, 'DISMISSED'),
                    child: Text(
                      MasarenLocalizations.of(context, 'admin.dismiss'),
                    ),
                  ),
                  FilledButton(
                    onPressed: () => _resolveReport(report, 'RESOLVED'),
                    child: Text(
                      MasarenLocalizations.of(context, 'admin.resolve'),
                    ),
                  ),
                  if (canHide)
                    OutlinedButton(
                      onPressed: () =>
                          _resolveReport(report, 'RESOLVED', hide: true),
                      child: Text(
                        MasarenLocalizations.of(context, 'admin.hideContent'),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAds() {
    if (_adsLoading && _ads.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: () => _loadAds(force: true),
      child: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 28),
        children: [
          _filterBar(
            _adStatuses,
            _adStatus,
            (value) {
              setState(() => _adStatus = value);
              _loadAds(force: true);
            },
            (value) => value == 'ALL'
                ? MasarenLocalizations.of(context, 'admin.all')
                : _statusText(value),
          ),
          if (_ads.isEmpty)
            _emptyCard(MasarenLocalizations.of(context, 'admin.noAds'))
          else
            ..._ads.map(_adminAdCard),
        ],
      ),
    );
  }

  Widget _adminAdCard(Campaign campaign) {
    final cs = Theme.of(context).colorScheme;
    final canActivate =
        campaign.status == 'DRAFT' || campaign.status == 'PAUSED';
    final canPause = campaign.status == 'ACTIVE';
    final canReject =
        campaign.status != 'COMPLETED' && campaign.status != 'REJECTED';
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    campaign.name,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusChip(
                  status: campaign.status,
                  label: _statusText(campaign.status),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${MasarenLocalizations.of(context, 'admin.owner')}: '
              '${campaign.ownerName ?? '-'}',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              '${MasarenLocalizations.of(context, 'ads.placement.${campaign.placement}')} · '
              '${MasarenLocalizations.of(context, 'ads.objective.${campaign.objective}')}',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                Text(
                  '${MasarenLocalizations.of(context, 'admin.budgetSpent')}: '
                  '${_decimal(campaign.budget)} / ${_decimal(campaign.spent)} MRC',
                  style: TextStyle(color: cs.onSurface, fontSize: 12),
                ),
                Text(
                  '${_fmt(campaign.impressions)} ${MasarenLocalizations.of(context, 'ads.impressions')} · '
                  '${_fmt(campaign.clicks)} ${MasarenLocalizations.of(context, 'ads.clicks')}',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: campaign.budgetProgress,
                minHeight: 5,
                backgroundColor: cs.surfaceContainerHighest,
                color: AppColors.accent,
              ),
            ),
            if (canActivate || canPause || canReject) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (canActivate)
                    FilledButton(
                      onPressed: () => _setAdStatus(campaign, 'ACTIVE'),
                      child: Text(
                        MasarenLocalizations.of(context, 'ads.activate'),
                      ),
                    ),
                  if (canPause)
                    OutlinedButton(
                      onPressed: () => _setAdStatus(campaign, 'PAUSED'),
                      child: Text(
                        MasarenLocalizations.of(context, 'ads.pause'),
                      ),
                    ),
                  if (canReject)
                    TextButton(
                      onPressed: () =>
                          _setAdStatus(campaign, 'REJECTED', confirm: true),
                      child: Text(
                        MasarenLocalizations.of(context, 'admin.rejectAd'),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInquiries() {
    if (_inquiriesLoading && _inquiries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: () => _loadInquiries(force: true),
      child: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 28),
        children: [
          _filterBar(
            _inquiryStatuses,
            _inquiryStatus,
            (value) {
              setState(() => _inquiryStatus = value);
              _loadInquiries(force: true);
            },
            (value) => value == 'ALL'
                ? MasarenLocalizations.of(context, 'admin.all')
                : _statusText(value),
          ),
          if (_inquiries.isEmpty)
            _emptyCard(MasarenLocalizations.of(context, 'admin.noInquiries'))
          else
            ..._inquiries.map(_inquiryCard),
        ],
      ),
    );
  }

  Widget _inquiryCard(Map<String, dynamic> inquiry) {
    final cs = Theme.of(context).colorScheme;
    final status = (inquiry['status'] ?? 'OPEN').toString().toUpperCase();
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    inquiry['subject']?.toString() ?? '-',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: MasarenLocalizations.of(
                    context,
                    'admin.inquiryStatus',
                  ),
                  onSelected: (value) => _updateInquiry(inquiry, value),
                  itemBuilder: (_) => [
                    for (final value in _inquiryStatuses.where(
                      (v) => v != 'ALL',
                    ))
                      PopupMenuItem(
                        value: value,
                        child: Text(_statusText(value)),
                      ),
                  ],
                  child: _StatusChip(
                    status: status,
                    label: _statusText(status),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${inquiry['org_name'] ?? inquiry['user_name'] ?? '-'} · '
              '${inquiry['type'] ?? inquiry['department'] ?? '-'}',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              inquiry['message']?.toString() ?? '',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: cs.onSurface, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              _date(inquiry['created_at']),
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerification() {
    if (_submissionsLoading && _submissions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: () => _loadSubmissions(force: true),
      child: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 28),
        children: [
          _filterBar(
            _submissionStatuses,
            _submissionStatus,
            (value) {
              setState(() => _submissionStatus = value);
              _loadSubmissions(force: true);
            },
            (value) => value == 'ALL'
                ? MasarenLocalizations.of(context, 'admin.all')
                : _statusText(value),
          ),
          if (_submissions.isEmpty)
            _emptyCard(MasarenLocalizations.of(context, 'admin.noSubmissions'))
          else
            ..._submissions.map(_submissionCard),
        ],
      ),
    );
  }

  Widget _submissionCard(Map<String, dynamic> submission) {
    final cs = Theme.of(context).colorScheme;
    final status = (submission['status'] ?? 'SUBMITTED')
        .toString()
        .toUpperCase();
    final confidence = _decimal(submission['confidence']);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    submission['title']?.toString() ?? '-',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusChip(status: status, label: _statusText(status)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${submission['owner_name'] ?? submission['owner_email'] ?? '-'} · '
              '${MasarenLocalizations.of(context, 'admin.confidence')} $confidence%',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
            if (submission['claim'] != null) ...[
              const SizedBox(height: 6),
              Text(
                submission['claim'].toString(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: cs.onSurface, fontSize: 13),
              ),
            ],
            if (submission['evidence_url'] != null) ...[
              const SizedBox(height: 4),
              Text(
                submission['evidence_url'].toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: cs.primary, fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                FilledButton(
                  onPressed: status == 'VERIFIED'
                      ? null
                      : () => _submissionVerdict(submission, 'VERIFIED'),
                  child: Text(MasarenLocalizations.of(context, 'admin.verify')),
                ),
                OutlinedButton(
                  onPressed: status == 'HUMAN_REVIEW'
                      ? null
                      : () => _submissionVerdict(submission, 'HUMAN_REVIEW'),
                  child: Text(
                    MasarenLocalizations.of(context, 'admin.humanReview'),
                  ),
                ),
                TextButton(
                  onPressed: status == 'REJECTED'
                      ? null
                      : () => _submissionVerdict(submission, 'REJECTED'),
                  child: Text(
                    MasarenLocalizations.of(context, 'admin.rejectSubmission'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendTestNotification() async {
    try {
      await AuthApi.testPush(
        title: 'MASAREEN test notification',
        body:
            'If you can read this, in-app and push notifications are working.',
      );
      if (!mounted) return;
      _snack(MasarenLocalizations.of(context, 'admin.testSent'));
    } catch (e) {
      _snack(_err(e));
    }
  }

  Future<void> _messageUser(Map<String, dynamic> user) async {
    final id = user['id']?.toString();
    if (id == null || id.isEmpty) return;
    try {
      final conversation = await AuthApi.openConversation(id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ChatScreen(conversation: conversation, user: widget.user),
        ),
      );
    } catch (e) {
      _snack(_err(e));
    }
  }

  Future<void> _userActions(Map<String, dynamic> user) async {
    final id = user['id']?.toString();
    if (id == null) return;
    final verified = user['email_verified'] == true;
    final suspended = user['suspended'] == true;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: Text(
                MasarenLocalizations.of(context, 'admin.messageUser'),
              ),
              onTap: () => Navigator.pop(ctx, 'message'),
            ),
            ListTile(
              leading: Icon(verified ? Icons.unpublished : Icons.verified),
              title: Text(
                verified
                    ? MasarenLocalizations.of(context, 'admin.unverify')
                    : MasarenLocalizations.of(context, 'admin.verify'),
              ),
              onTap: () => Navigator.pop(ctx, verified ? 'unverify' : 'verify'),
            ),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: Text(
                'Platform role: ${user['platform_role'] ?? 'member'}',
              ),
              subtitle: const Text('Admin, moderator, support or analyst'),
              onTap: () => Navigator.pop(ctx, 'role'),
            ),
            ListTile(
              leading: const Icon(Icons.science_outlined),
              title: Text(MasarenLocalizations.of(context, 'admin.makeTester')),
              onTap: () => Navigator.pop(ctx, 'tester'),
            ),
            ListTile(
              leading: Icon(
                suspended ? Icons.play_circle_outline : Icons.block,
              ),
              title: Text(
                suspended
                    ? MasarenLocalizations.of(context, 'admin.unsuspend')
                    : MasarenLocalizations.of(context, 'admin.suspend'),
              ),
              onTap: () =>
                  Navigator.pop(ctx, suspended ? 'unsuspend' : 'suspend'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(
                MasarenLocalizations.of(context, 'admin.deleteUser'),
                style: const TextStyle(color: Colors.red),
              ),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;
    if (!mounted) return;
    if (action == 'message') return _messageUser(user);
    if (action == 'role') {
      final role = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Assign platform role'),
          children: [
            for (final entry in const [
              ('ADMIN', 'Platform admin', Icons.shield_outlined),
              ('MODERATOR', 'Moderator', Icons.gavel_outlined),
              ('SUPPORT', 'Support', Icons.support_agent_outlined),
              ('ANALYST', 'Analyst', Icons.insights_outlined),
              ('NONE', 'Remove role', Icons.person_outline),
            ])
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, entry.$1),
                child: ListTile(
                  leading: Icon(entry.$3),
                  title: Text(entry.$2),
                  trailing: user['platform_role'] == entry.$1
                      ? const Icon(Icons.check)
                      : null,
                ),
              ),
          ],
        ),
      );
      if (role == null) return;
      try {
        await AuthApi.adminSetPlatformRole(id, role);
        await _loadUsers(force: true);
        if (mounted) _snack('Platform role updated.');
      } catch (error) {
        _snack(_err(error));
      }
      return;
    }
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(MasarenLocalizations.of(context, 'admin.deleteUser')),
          content: Text(
            MasarenLocalizations.of(context, 'admin.deleteUserHint'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(MasarenLocalizations.of(context, 'action.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(MasarenLocalizations.of(context, 'common.confirm')),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      await AuthApi.adminUserAction(id, action);
      await _loadUsers(force: true);
      _loadStats();
      if (mounted) {
        _snack(MasarenLocalizations.of(context, 'admin.refreshDone'));
      }
    } catch (error) {
      _snack(_err(error));
    }
  }

  Widget _buildUsers() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: MasarenLocalizations.of(context, 'admin.searchUsers'),
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (value) {
              _userSearch = value;
              _userDebounce?.cancel();
              _userDebounce = Timer(const Duration(milliseconds: 450), () {
                _loadUsers(force: true);
              });
            },
          ),
        ),
        Expanded(
          child: _usersLoading && _users.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => _loadUsers(force: true),
                  child: _users.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 80),
                            Center(
                              child: Text(
                                MasarenLocalizations.of(
                                  context,
                                  'admin.noUsers',
                                ),
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 28),
                          itemCount: _users.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: cs.outlineVariant),
                          itemBuilder: (_, index) {
                            final user = _users[index];
                            final name =
                                user['name'] ?? user['full_name'] ?? '-';
                            final role = user['role'] ?? 'USER';
                            final verified = user['email_verified'] == true;
                            return ListTile(
                              onTap: () => _userActions(user),
                              leading: AppAvatar(name: name.toString()),
                              title: Text(
                                name.toString(),
                                style: TextStyle(color: cs.onSurface),
                              ),
                              subtitle: Text(
                                '${user['email'] ?? '-'} · $role'
                                '${user['country'] == null ? '' : ' · ${user['country']}'}',
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (verified)
                                        const Icon(
                                          Icons.verified,
                                          color: Colors.blue,
                                          size: 18,
                                        ),
                                      Text(
                                        _shortDate(
                                          user['last_login_at'] ??
                                              user['created_at'],
                                        ),
                                        style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    tooltip: MasarenLocalizations.of(
                                      context,
                                      'admin.messageUser',
                                    ),
                                    onPressed: () => _messageUser(user),
                                    icon: const Icon(
                                      Icons.chat_bubble_outline,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }

  Widget _buildPayments() {
    if (_paymentsLoading && _payments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: () => _loadPayments(force: true),
      child: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 28),
        children: [
          _filterBar(
            _paymentStatuses,
            _paymentStatus,
            (value) {
              setState(() => _paymentStatus = value);
              _loadPayments(force: true);
            },
            (value) => value == 'ALL'
                ? MasarenLocalizations.of(context, 'admin.all')
                : _statusText(value),
          ),
          if (_payments.isEmpty)
            _emptyCard(MasarenLocalizations.of(context, 'admin.noPayments'))
          else
            ..._payments.map(_paymentCard),
        ],
      ),
    );
  }

  Widget _paymentCard(Map<String, dynamic> payment) {
    final cs = Theme.of(context).colorScheme;
    final status = (payment['status'] ?? 'PENDING').toString().toUpperCase();
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor(status).withValues(alpha: 0.15),
          child: Icon(Icons.payments, color: _statusColor(status), size: 20),
        ),
        title: Text(
          '${_decimal(payment['amount_egp'])} EGP',
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${payment['user_name'] ?? payment['user_email'] ?? '-'} · '
          '${payment['method'] ?? '-'} · ${payment['purpose'] ?? '-'}\n'
          '${_date(payment['created_at'])}',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
        ),
        isThreeLine: true,
        trailing: _StatusChip(status: status, label: _statusText(status)),
      ),
    );
  }

  Widget _recentReportsCard(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return _emptyCard(MasarenLocalizations.of(context, 'admin.noReports'));
    }
    return Card(
      child: Column(
        children: [
          for (final report in rows)
            ListTile(
              dense: true,
              leading: Icon(
                Icons.flag_outlined,
                color: _statusColor((report['status'] ?? 'OPEN').toString()),
              ),
              title: Text(
                (report['target_preview'] is Map
                            ? _asMap(report['target_preview'])['text']
                            : null)
                        ?.toString() ??
                    report['reason']?.toString() ??
                    '-',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${report['reporter_name'] ?? '-'} · ${_date(report['created_at'])}',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: Text(
                _statusText((report['status'] ?? 'OPEN').toString()),
                style: TextStyle(
                  color: _statusColor((report['status'] ?? 'OPEN').toString()),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _recentPaymentsCard(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return _emptyCard(MasarenLocalizations.of(context, 'admin.noPayments'));
    }
    return Card(
      child: Column(
        children: [
          for (final payment in rows)
            ListTile(
              dense: true,
              leading: const Icon(Icons.payments_outlined),
              title: Text(
                '${_decimal(payment['amount_egp'])} EGP · ${payment['status'] ?? '-'}',
              ),
              subtitle: Text(
                '${payment['user_name'] ?? payment['user_email'] ?? '-'} · ${_date(payment['created_at'])}',
                style: const TextStyle(fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _recentInquiriesCard(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return _emptyCard(MasarenLocalizations.of(context, 'admin.noInquiries'));
    }
    return Card(
      child: Column(
        children: [
          for (final inquiry in rows)
            ListTile(
              dense: true,
              leading: const Icon(Icons.support_agent_outlined),
              title: Text(
                inquiry['subject']?.toString() ?? '-',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${inquiry['org_name'] ?? inquiry['user_name'] ?? '-'} · ${_date(inquiry['created_at'])}',
                style: const TextStyle(fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _recentUsersCard(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return _emptyCard(MasarenLocalizations.of(context, 'admin.noUsers'));
    }
    return Card(
      child: Column(
        children: [
          for (final user in rows)
            ListTile(
              dense: true,
              leading: AppAvatar(
                name: (user['name'] ?? '?').toString(),
                size: 34,
              ),
              title: Text(user['name']?.toString() ?? '-'),
              subtitle: Text(
                '${user['email'] ?? '-'} · ${user['role'] ?? '-'}',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: Text(
                _shortDate(user['created_at']),
                style: const TextStyle(fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }

  Widget _rateCard(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              MasarenLocalizations.of(
                context,
                'admin.currentRate',
              ).replaceAll('{rate}', _rate?['rate_to_mrc']?.toString() ?? '-'),
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _rateCtl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: MasarenLocalizations.of(
                        context,
                        'admin.newRate',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _setRate,
                  child: Text(MasarenLocalizations.of(context, 'admin.set')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterBar(
    List<String> values,
    String selected,
    ValueChanged<String> onSelected,
    String Function(String) label,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final value in values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: ChoiceChip(
                label: Text(label(value)),
                selected: selected == value,
                onSelected: (_) => onSelected(value),
              ),
            ),
        ],
      ),
    );
  }

  Widget _countChip(String key, dynamic value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${MasarenLocalizations.of(context, key)} ${_fmt(value)}',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _emptyCard(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            message,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  String _statusText(String status) {
    if (status.toUpperCase() == 'ALL') {
      return MasarenLocalizations.of(context, 'admin.all');
    }
    final key = 'admin.status.${status.toLowerCase()}';
    final value = MasarenLocalizations.of(context, key);
    if (value == key) return status.replaceAll('_', ' ');
    return value;
  }

  String _targetLabel(String type) {
    switch (type.toLowerCase()) {
      case 'post':
        return MasarenLocalizations.of(context, 'admin.targetPost');
      case 'comment':
        return MasarenLocalizations.of(context, 'admin.targetComment');
      case 'user':
        return MasarenLocalizations.of(context, 'admin.targetUser');
      default:
        return type;
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
      case 'VERIFIED':
      case 'RESOLVED':
      case 'SUCCESS':
        return _green;
      case 'PAUSED':
      case 'PENDING':
      case 'IN_REVIEW':
      case 'HUMAN_REVIEW':
      case 'SUBMITTED':
      case 'AI_REVIEW':
        return _amber;
      case 'REJECTED':
      case 'FAILED':
      case 'DISMISSED':
        return AppColors.warm;
      default:
        return AppColors.azure;
    }
  }

  String _date(dynamic value) {
    if (value == null) return '';
    try {
      final date = DateTime.parse(value.toString()).toLocal();
      return DateFormat('d MMM yyyy, HH:mm').format(date);
    } catch (_) {
      final text = value.toString();
      return text.length > 16 ? text.substring(0, 16) : text;
    }
  }

  String _shortDate(dynamic value) {
    if (value == null) return '';
    try {
      final date = DateTime.parse(value.toString()).toLocal();
      return DateFormat('d MMM').format(date);
    } catch (_) {
      return '';
    }
  }

  String _fmt(dynamic value) {
    final number = value is num ? value : num.tryParse('$value') ?? 0;
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toStringAsFixed(0);
  }

  String _decimal(dynamic value) {
    final number = value is num ? value : num.tryParse('$value') ?? 0;
    return number.toStringAsFixed(number == number.roundToDouble() ? 0 : 1);
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final width = ((MediaQuery.sizeOf(context).width - 52) / 3).clamp(
      104.0,
      190.0,
    );
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  const _HeroStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}

class _ActivityChart extends StatelessWidget {
  final List<Map<String, dynamic>> series;
  const _ActivityChart({required this.series});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (series.isEmpty) {
      return Text(
        MasarenLocalizations.of(context, 'admin.noData'),
        style: TextStyle(color: cs.onSurfaceVariant),
      );
    }
    var maxValue = 1.0;
    for (final row in series) {
      for (final key in ['signups', 'posts', 'ad_impressions', 'ad_clicks']) {
        final value = _asNum(row[key]).toDouble();
        if (value > maxValue) maxValue = value;
      }
    }
    final first = series.first['date']?.toString() ?? '';
    final last = series.last['date']?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 130,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final row in series)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _bar(row['signups'], maxValue, AppColors.brand),
                        _bar(row['posts'], maxValue, AppColors.azure),
                        _bar(row['ad_impressions'], maxValue, AppColors.accent),
                        _bar(
                          row['ad_clicks'],
                          maxValue,
                          const Color(0xFF8B5CF6),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              first,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10),
            ),
            const Spacer(),
            Text(
              last,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _legend(context, AppColors.brand, 'admin.signups'),
            _legend(context, AppColors.azure, 'admin.postsSeries'),
            _legend(context, AppColors.accent, 'admin.adImpressionsSeries'),
            _legend(context, const Color(0xFF8B5CF6), 'admin.adClicksSeries'),
          ],
        ),
      ],
    );
  }

  Widget _bar(dynamic value, double maxValue, Color color) {
    final height = math.max(2.0, (_asNum(value) / maxValue) * 110);
    return Container(
      width: 3,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 0.7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _legend(BuildContext context, Color color, String key) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          MasarenLocalizations.of(context, key),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _AdminCampaignTile extends StatelessWidget {
  final Campaign campaign;
  const _AdminCampaignTile({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    campaign.name,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusChip(
                  status: campaign.status,
                  label: _statusLabel(context, campaign.status),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${campaign.ownerName ?? '-'} · ${campaign.impressions} '
              '${MasarenLocalizations.of(context, 'ads.impressions')} · '
              '${campaign.clicks} ${MasarenLocalizations.of(context, 'ads.clicks')}',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: campaign.budgetProgress,
                minHeight: 5,
                backgroundColor: cs.surfaceContainerHighest,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final String label;
  const _StatusChip({required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _statusLabel(BuildContext context, String status) {
  final key = 'admin.status.${status.toLowerCase()}';
  final value = MasarenLocalizations.of(context, key);
  if (value == key) return status.replaceAll('_', ' ');
  return value;
}

Color _colorFor(String status) {
  switch (status.toUpperCase()) {
    case 'ACTIVE':
    case 'VERIFIED':
    case 'RESOLVED':
    case 'SUCCESS':
      return const Color(0xFF22C55E);
    case 'PAUSED':
    case 'PENDING':
    case 'IN_REVIEW':
    case 'HUMAN_REVIEW':
    case 'SUBMITTED':
    case 'AI_REVIEW':
      return const Color(0xFFF59E0B);
    case 'REJECTED':
    case 'FAILED':
    case 'DISMISSED':
      return const Color(0xFFB45345);
    default:
      return const Color(0xFF2C6E8F);
  }
}

Map<String, dynamic> _asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _asMaps(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
    : <Map<String, dynamic>>[];

num _asNum(dynamic value) => value is num ? value : num.tryParse('$value') ?? 0;
