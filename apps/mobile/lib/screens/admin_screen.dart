import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/models.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/widgets/animations.dart';
import 'package:masaren/screens/ads_screen.dart';
import 'package:masaren/screens/wallet_screen.dart';
import 'package:intl/intl.dart';

class AdminScreen extends StatefulWidget {
  final User user;
  const AdminScreen({super.key, required this.user});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _isAdmin = false;
  bool _loading = true;
  String? _error;
  int _tab = 0;

  // Overview stats
  Map<String, dynamic>? _stats;
  // Review queue
  List<Map<String, dynamic>> _reviews = [];
  bool _reviewsLoading = false;
  // Users
  List<Map<String, dynamic>> _users = [];
  bool _usersLoading = false;
  String _userSearch = '';
  // Submissions
  List<Map<String, dynamic>> _submissions = [];
  bool _submissionsLoading = false;
  // Exchange rate
  Map<String, dynamic>? _rate;
  final _rateCtl = TextEditingController();

  static const _purple = Color(0xFF8B5CF6);
  static const _green = Color(0xFF22C55E);
  static const _amber = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _isAdmin = widget.user.role.toUpperCase().contains('ADMIN');
    if (_isAdmin) {
      _loadStats();
      _loadReviews();
      _loadUsers();
      _loadSubmissions();
      _loadRate();
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      _stats = await AuthApi.adminStats();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadReviews() async {
    setState(() => _reviewsLoading = true);
    try {
      _reviews = await AuthApi.reviewQueue();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _reviewsLoading = false);
    }
  }

  Future<void> _loadUsers() async {
    setState(() => _usersLoading = true);
    try {
      _users = await AuthApi.adminUsers(_userSearch);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _usersLoading = false);
    }
  }

  Future<void> _loadSubmissions() async {
    setState(() => _submissionsLoading = true);
    try {
      _submissions = await AuthApi.adminSubmissions();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submissionsLoading = false);
    }
  }

  Future<void> _loadRate() async {
    try {
      _rate = await AuthApi.coinRate('EGP');
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _submitVerdict(String reviewId, String verdict, String? comments) async {
    try {
      await AuthApi.submitVerdict(reviewId, verdict, comments);
      _reviews.removeWhere((r) => r['id'] == reviewId);
      if (mounted) setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Review $verdict')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _setRate() async {
    final v = double.tryParse(_rateCtl.text);
    if (v == null || v <= 0) return;
    try {
      await AuthApi.setCoinRate('EGP', v);
      _rate = {'rate_to_mrc': v};
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Rate updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  void _showVerdictDialog(Map<String, dynamic> review) {
    final ctl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        title: Text('Review: ${review['entity_type']}',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              review['entity_preview']?['text'] ??
                  review['entity_preview']?['name'] ??
                  review['entity_id'],
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctl,
              decoration: InputDecoration(
                labelText: 'Admin comments (optional)',
                labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitVerdict(review['id'], 'REJECTED', ctl.text);
            },
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700),
            child: const Text('Reject'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitVerdict(review['id'], 'APPROVED', ctl.text);
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: const Center(
          child: Text('Admin access required.',
              style: TextStyle(color: AppColors.muted)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        bottom: TabBar(
          onTap: (i) => setState(() => _tab = i),
          indicatorColor: cs.primary,
          labelColor: cs.primary,
          unselectedLabelColor: cs.onSurfaceVariant,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Verification'),
            Tab(text: 'Users'),
            Tab(text: 'Platform'),
            Tab(text: 'Settings'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _stats == null
              ? ErrorView(message: _error, onRetry: _loadStats)
              : _buildTab(),
    );
  }

  Widget _buildTab() {
    final cs = Theme.of(context).colorScheme;
    switch (_tab) {
      case 0:
        return _buildOverview(cs);
      case 1:
        return _buildVerification(cs);
      case 2:
        return _buildUsers(cs);
      case 3:
        return _buildPlatform(cs);
      case 4:
        return _buildSettings(cs);
      default:
        return _buildOverview(cs);
    }
  }

  Widget _buildOverview(cs) {
    if (_loading && _stats == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final s = _stats ?? {};
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionTitle(title: 'Platform Statistics'),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _KpiCard(
              icon: Icons.people,
              label: 'Total Users',
              value: '${s['total_users'] ?? '-'}',
              color: AppColors.azure,
            ),
            _KpiCard(
              icon: Icons.feed,
              label: 'Total Posts',
              value: '${s['total_posts'] ?? '-'}',
              color: AppColors.accent,
            ),
            _KpiCard(
              icon: Icons.description,
              label: 'Submissions',
              value: '${s['total_submissions'] ?? '-'}',
              color: _purple,
            ),
            _KpiCard(
              icon: Icons.pending,
              label: 'Pending Reviews',
              value: '${s['pending_reviews'] ?? '-'}',
              color: _amber,
            ),
            _KpiCard(
              icon: Icons.check_circle,
              label: 'Approved Today',
              value: '${s['approved_today'] ?? '-'}',
              color: _green,
            ),
            _KpiCard(
              icon: Icons.cancel,
              label: 'Rejected Today',
              value: '${s['rejected_today'] ?? '-'}',
              color: AppColors.warm,
            ),
          ],
        ),
        const SizedBox(height: 24),
        const SectionTitle(title: 'Recent Activity'),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Platform is running normally. ${_reviews.length} items in review queue.',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerification(cs) {
    if (_reviewsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 64, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No pending reviews.',
                style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadReviews,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _reviews.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final r = _reviews[i];
        final confidence = (r['confidence_score'] as num?)?.toDouble();
        final preview = r['entity_preview'] as Map<String, dynamic>?;
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _confidenceColor(confidence),
              child: Text(
                confidence != null ? '${(confidence * 100).toInt()}%' : '-',
                style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            title: Text(
              preview?['text']?.substring(0, (preview!['text'] as String).length.clamp(0, 80)) ??
                  preview?['name'] ??
                  r['entity_id'],
              style: TextStyle(color: cs.onSurface),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${r['entity_type']} · ${_formatDate(r['created_at'])}',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => _submitVerdict(r['id'], 'REJECTED', null),
                ),
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () => _submitVerdict(r['id'], 'APPROVED', null),
                ),
              ],
            ),
            onTap: () => _showVerdictDialog(r),
          ),
        );
      },
    );
  }

  Widget _buildUsers(cs) {
    if (_usersLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search users...',
              hintStyle: TextStyle(color: cs.onSurfaceVariant),
              prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
            ),
            style: TextStyle(color: cs.onSurface),
            onChanged: (v) {
              _userSearch = v;
              Future.delayed(const Duration(milliseconds: 500), () {
                if (_userSearch == v) _loadUsers();
              });
            },
          ),
        ),
        Expanded(
          child: _users.isEmpty
              ? Center(
                  child: Text('No users found.',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                )
              : ListView.separated(
                  itemCount: _users.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: cs.outlineVariant),
                  itemBuilder: (_, i) {
                    final u = _users[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.azure,
                        child: Text(
                          (u['full_name'] as String?)?.substring(0, 1).toUpperCase() ??
                              '?',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                      title: Text(u['full_name'] ?? 'Unknown',
                          style: TextStyle(color: cs.onSurface)),
                      subtitle: Text(
                        '${u['email'] ?? ''} · ${u['role'] ?? 'USER'}',
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                      ),
                      trailing: u['verified'] == true
                          ? const Icon(Icons.verified,
                              color: Colors.blue, size: 20)
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPlatform(cs) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionTitle(title: 'Platform Controls'),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MRC to EGP exchange rate',
                    style: TextStyle(
                        color: cs.onSurface, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                    'Current: ${_rate?['rate_to_mrc'] ?? '-'} MRC per EGP',
                    style: TextStyle(color: cs.onSurfaceVariant)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _rateCtl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: cs.onSurface),
                        decoration: InputDecoration(
                          labelText: 'New rate',
                          labelStyle: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _setRate,
                      child: const Text('Set'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.campaign, color: AppColors.azure),
          title: const Text('Ads campaigns',
              style: TextStyle(color: Colors.white)),
          subtitle: const Text('Manage platform advertising',
              style: TextStyle(color: AppColors.muted)),
          trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AdsScreen(user: widget.user))),
        ),
        ListTile(
          leading: const Icon(Icons.token, color: AppColors.accent),
          title: const Text('Coin wallets',
              style: TextStyle(color: Colors.white)),
          subtitle: const Text('Inspect MASAREEN Coin',
              style: TextStyle(color: AppColors.muted)),
          trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => WalletScreen(user: widget.user))),
        ),
        ListTile(
          leading: const Icon(Icons.description, color: _purple),
          title: const Text('Submissions',
              style: TextStyle(color: Colors.white)),
          subtitle: Text('${_submissions.length} total submissions',
              style: TextStyle(color: AppColors.muted)),
          trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
          onTap: () => setState(() => _tab = 1),
        ),
      ],
    );
  }

  Widget _buildSettings(cs) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionTitle(title: 'Settings'),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.notifications, color: cs.onSurfaceVariant),
                title: Text('Push notifications',
                    style: TextStyle(color: cs.onSurface)),
                trailing: Switch(
                  value: true,
                  onChanged: (v) {},
                  activeColor: AppColors.azure,
                ),
              ),
              ListTile(
                leading: Icon(Icons.security, color: cs.onSurfaceVariant),
                title: Text('Two-factor auth',
                    style: TextStyle(color: cs.onSurface)),
                trailing: const Icon(Icons.chevron_right,
                    color: AppColors.muted),
              ),
              ListTile(
                leading: Icon(Icons.bug_report, color: cs.onSurfaceVariant),
                title: Text('Debug mode',
                    style: TextStyle(color: cs.onSurface)),
                trailing: Switch(
                  value: false,
                  onChanged: (v) {},
                  activeColor: AppColors.azure,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _confidenceColor(double? confidence) {
    if (confidence == null) return AppColors.muted;
    if (confidence >= 0.8) return _green;
    if (confidence >= 0.5) return _amber;
    return AppColors.warm;
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('MMM d, HH:mm').format(dt);
    } catch (_) {
      return dateStr.substring(0, dateStr.length.clamp(0, 10));
    }
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
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
        ],
      ),
    );
  }
}
