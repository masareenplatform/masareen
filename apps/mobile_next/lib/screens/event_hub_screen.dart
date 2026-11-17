import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/profile_router.dart';
import 'package:masaren/screens/booth_screen.dart';
import 'package:masaren/screens/create_booth_screen.dart';
import 'package:masaren/screens/create_episode_screen.dart';
import 'package:masaren/screens/create_vod_screen.dart';
import 'package:masaren/screens/event_manage_screen.dart';
import 'package:masaren/screens/event_report_screen.dart';
import 'package:masaren/screens/moderators_screen.dart';
import 'package:masaren/screens/evidence_capture_screen.dart';
import 'package:masaren/screens/opportunity_detail_screen.dart';
import 'package:masaren/screens/podcast_screen.dart';
import 'package:masaren/screens/post_detail_screen.dart';
import 'package:masaren/screens/program_detail_screen.dart';
import 'package:masaren/screens/vod_screen.dart';
import 'package:masaren/services/share_policy.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets/animations.dart';
import 'package:masaren/widgets/festive_burst.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/widgets/smart_image.dart';
import 'package:url_launcher/url_launcher.dart';

class EventHubScreen extends StatefulWidget {
  final String eventId;
  final User user;
  const EventHubScreen({super.key, required this.eventId, required this.user});

  @override
  State<EventHubScreen> createState() => _EventHubScreenState();
}

class _EventHubScreenState extends State<EventHubScreen> {
  Map<String, dynamic>? _data;
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
      final data = await AuthApi.eventDetail(widget.eventId);
      if (!mounted) return;
      setState(() => _data = data);
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

  String _date(String? raw) {
    final parsed = DateTime.tryParse(raw ?? '');
    if (parsed == null) return raw ?? '';
    return DateFormat.yMMMd().add_jm().format(parsed.toLocal());
  }

  List<Map<String, dynamic>> _list(String key) => _data?[key] is List
      ? (_data![key] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList()
      : [];

  String _money(num value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      if (success != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(success)));
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      final message =
          e is ApiException ? (e.message ?? e.toString()) : e.toString();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() => _run(() async {
        await AuthApi.joinEvent(widget.eventId);
      });

  Future<void> _confirm(String participantId) => _run(() async {
        await AuthApi.confirmEventParticipant(widget.eventId, participantId);
      }, success: _t('events.confirmed', 'Contribution confirmed.'));

  Future<void> _claimAttendance() async {
    try {
      final result = await AuthApi.claimEventAttendance(widget.eventId);
      if (!mounted) return;
      final reward = (result['reward_mrc'] as num?)?.toDouble() ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(reward > 0
              ? _t('events.attendanceReward', 'Attendance verified. +{mrc} MRC')
                  .replaceAll('{mrc}', _money(reward))
              : _t('events.attendanceAlready',
                  'Attendance reward already claimed.'))));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is ApiException ? (e.message ?? '$e') : '$e')));
    }
  }

  Future<void> _rate() async {
    int stars = 5;
    final review = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(_t('events.rateTitle', 'Rate this event')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return IconButton(
                    onPressed: () => setDialogState(() => stars = i + 1),
                    icon: Icon(
                        i < stars ? Icons.star_rounded : Icons.star_border,
                        color: AppColors.accent,
                        size: 32),
                  );
                }),
              ),
              TextField(
                controller: review,
                maxLines: 3,
                decoration: InputDecoration(
                    labelText: _t('events.reviewLabel', 'Review (optional)')),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(_t('common.cancel', 'Cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(_t('events.submitRating', 'Submit rating'))),
          ],
        ),
      ),
    );
    if (submit == true) {
      await _run(() async {
        await AuthApi.rateEvent(widget.eventId,
            rating: stars, review: review.text.trim());
      }, success: _t('events.rated', 'Thank you for your review.'));
    }
    review.dispose();
  }

  Future<void> _fund() async {
    final amount = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('events.fundTitle', 'Fund this event')),
        content: TextField(
          controller: amount,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
              labelText: _t('events.fundAmount', 'Amount in MRC'),
              suffixText: 'MRC'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_t('common.cancel', 'Cancel'))),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(amount.text.trim());
              if (parsed != null && parsed > 0) {
                Navigator.pop(dialogContext, parsed);
              }
            },
            child: Text(_t('events.fund', 'Fund')),
          ),
        ],
      ),
    );
    amount.dispose();
    if (value == null) return;
    await _run(() async {
      await AuthApi.fundEvent(widget.eventId, value);
    }, success: _t('events.fundedToast', 'Event funded successfully.'));
  }

  Future<void> _addParticipant() async {
    final userId = TextEditingController();
    final roleTitle = TextEditingController();
    final contribution = TextEditingController();
    String role = 'EXHIBITOR';
    const roles = [
      'ORGANIZER',
      'HOST',
      'EXHIBITOR',
      'SPONSOR',
      'SPEAKER',
      'STUDENT',
      'MEDIA',
      'PARTNER',
      'VISITOR',
    ];
    final body = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(_t('events.addContributor', 'Add contributor')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: userId,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: _t('events.memberId', 'Member ID')),
                ),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: InputDecoration(
                      labelText: _t('events.role', 'Event role')),
                  items: roles
                      .map((r) => DropdownMenuItem(
                          value: r, child: Text(_t('events.role.$r', r))))
                      .toList(),
                  onChanged: (v) => setDialogState(() => role = v ?? role),
                ),
                TextField(
                  controller: roleTitle,
                  decoration: InputDecoration(
                      labelText:
                          _t('events.roleTitle', 'Role title (optional)')),
                ),
                TextField(
                  controller: contribution,
                  decoration: InputDecoration(
                      labelText:
                          _t('events.contribution', 'Contribution (optional)')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(_t('common.cancel', 'Cancel'))),
            FilledButton(
              onPressed: () {
                final id = int.tryParse(userId.text.trim());
                if (id == null) return;
                Navigator.pop(dialogContext, {
                  'user_id': id,
                  'role': role,
                  if (roleTitle.text.trim().isNotEmpty)
                    'role_title': roleTitle.text.trim(),
                  if (contribution.text.trim().isNotEmpty)
                    'contribution': contribution.text.trim(),
                });
              },
              child: Text(_t('common.add', 'Add')),
            ),
          ],
        ),
      ),
    );
    userId.dispose();
    roleTitle.dispose();
    contribution.dispose();
    if (body == null) return;
    await _run(() async {
      await AuthApi.addEventParticipant(widget.eventId, body);
    }, success: _t('events.contributorAdded', 'Contributor added.'));
  }

  Future<void> _addMedia() async {
    final title = TextEditingController();
    String type = 'IMAGE';
    String? mediaUrl;
    String? pickedName;
    var uploading = false;
    final types = ['IMAGE', 'VIDEO', 'PODCAST', 'REPORT', 'NEWS'];
    final body = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(_t('events.addMedia', 'Add event media')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: InputDecoration(
                      labelText: _t('events.mediaType', 'Media type')),
                  items: types
                      .map((t) => DropdownMenuItem(
                          value: t, child: Text(_t('events.media.$t', t))))
                      .toList(),
                  onChanged: (v) => setDialogState(() => type = v ?? type),
                ),
                TextField(
                  controller: title,
                  decoration: InputDecoration(
                      labelText: _t('events.mediaTitle', 'Title')),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: uploading
                      ? null
                      : () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.any,
                            withData: false,
                          );
                          final file = result?.files.firstOrNull;
                          if (file == null || file.path == null) return;
                          setDialogState(() {
                            pickedName = file.name;
                            uploading = true;
                          });
                          try {
                            final bytes = await File(file.path!).readAsBytes();
                            final ext =
                                file.name.split('.').last.toLowerCase();
                            String? url;
                            if (type == 'VIDEO' ||
                                ['mp4', 'mov', 'm4v'].contains(ext)) {
                              final uploaded = await AuthApi.uploadVideo(
                                  bytes, file.name, 'video/mp4');
                              url = uploaded['url']?.toString();
                              if (url == null && uploaded['hls_url'] != null) {
                                url = uploaded['hls_url'].toString();
                              }
                            } else if (type == 'PODCAST' ||
                                ['mp3', 'wav', 'm4a', 'aac', 'ogg']
                                    .contains(ext)) {
                              url = await AuthApi.uploadAudio(
                                  bytes,
                                  file.name,
                                  ext == 'wav' ? 'audio/wav' : 'audio/mpeg');
                            } else if (['jpg', 'jpeg', 'png', 'webp', 'gif']
                                .contains(ext)) {
                              url = await AuthApi.uploadMedia(
                                  bytes,
                                  file.name,
                                  ext == 'png'
                                      ? 'image/png'
                                      : ext == 'webp'
                                          ? 'image/webp'
                                          : 'image/jpeg');
                            } else {
                              final uploaded = await AuthApi.uploadFile(
                                  bytes, file.name, 'application/pdf');
                              url = uploaded['url']?.toString();
                            }
                            if (mounted) {
                              setDialogState(() => mediaUrl = url);
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())));
                            }
                          } finally {
                            if (mounted) {
                              setDialogState(() => uploading = false);
                            }
                          }
                        },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(dialogContext)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: .45),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                            mediaUrl != null
                                ? Icons.check_circle
                                : Icons.upload_file,
                            color: Theme.of(dialogContext).colorScheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                              uploading
                                  ? 'Uploading...'
                                  : mediaUrl != null
                                      ? 'File uploaded'
                                      : (pickedName ??
                                          'Choose a file from your device'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text('No links needed',
                    style: TextStyle(fontSize: 10.5)),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(_t('common.cancel', 'Cancel'))),
            FilledButton(
              onPressed: uploading || mediaUrl == null
                  ? null
                  : () {
                      Navigator.pop(dialogContext, {
                        'type': type,
                        if (title.text.trim().isNotEmpty)
                          'title': title.text.trim(),
                        'url': mediaUrl,
                        if (type == 'IMAGE') 'thumbnail_url': mediaUrl,
                      });
                    },
              child: Text(_t('common.add', 'Add')),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    if (body == null) return;
    await _run(() async {
      await AuthApi.addEventMedia(widget.eventId, body);
    }, success: _t('events.mediaAdded', 'Media added.'));
  }
  Future<void> _createBooth() async {
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => CreateBoothScreen(
            eventId: widget.eventId, user: widget.user)));
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('booth.created',
              'Booth created. Activate it with MRC to publish.'))));
      await _load();
    }
  }
  Future<void> _addEvidence(String participantId) async {
    final changed = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
            builder: (_) => EvidenceCaptureScreen(
                  user: widget.user,
                  targetType: 'EVENT',
                  targetId: widget.eventId,
                  participantId: participantId,
                  targetTitle: _t('events.proofTitle', 'Event contribution'),
                )));
    if (changed != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('events.proofSubmitted',
              'Proof submitted for host verification.'))));
      await _load();
    }
  }

  Future<void> _verdict(String participantId, String status) async {
    var override = false;
    final participants = (_data?['participants'] as List?) ?? const [];
    final participant = participants.cast<Map>().firstWhere(
        (p) => p['id'].toString() == participantId,
        orElse: () => const {});
    final flagged = (participant['deepfake_verdict'] ?? '') == 'LIKELY_AI';
    if (status == 'VERIFIED' && flagged) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('AI-generated content flagged'),
          content: const Text(
              'This contribution was flagged as likely AI-generated. Only override after reviewing the original media and source.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Override and verify')),
          ],
        ),
      );
      if (confirmed != true) return;
      override = true;
    }
    await _run(() async {
      await AuthApi.eventParticipantVerdict(widget.eventId, participantId,
          status: status, override: override);
    }, success: _t('events.verdictSaved', 'Verification decision saved.'));
    if (status == 'VERIFIED' && mounted) {
      unawaited(FestiveBurst.show(context,
          message: 'Contribution verified',
          icon: Icons.verified_rounded,
          color: const Color(0xFF0E6B5C)));
    }
  }

  Future<void> _openBooth(String id) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BoothScreen(boothId: id, user: widget.user)));
    if (mounted) _load();
  }

  Future<void> _openReport() async {
    final data = _data;
    if (data == null) return;
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EventReportScreen(event: data)));
  }
  Future<void> _openModerators(String title) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ModeratorsScreen(
              entityType: 'EVENT',
              entityId: widget.eventId,
              entityTitle: title,
              currentUser: widget.user,
            )));
    if (mounted) _load();
  }

  Future<void> _deleteEvent(String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this event?'),
        content: Text(
            '“$title” will be removed from public discovery. The owner and verified participants keep the activity record.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove event')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      await AuthApi.deleteEvent(widget.eventId);
    }, success: 'Event removed from public discovery.');
    if (mounted) Navigator.pop(context);
  }
  Future<void> _openDashboard() async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            EventManageScreen(eventId: widget.eventId, user: widget.user)));
    if (mounted) _load();
  }

  Future<void> _openProgram(String id) async {
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProgramDetailScreen(programId: id)));
    if (mounted) _load();
  }

  Future<void> _openOpportunity(String id) async {
    try {
      final opportunity = await AuthApi.opportunity(id);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OpportunityDetailScreen(
              opportunity: opportunity, user: widget.user)));
      if (mounted) _load();
    } catch (_) {}
  }

  Future<void> _openResearchPost(String postId) async {
    if (postId.isEmpty) return;
    try {
      final post = await AuthApi.postById(postId);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PostDetailScreen(
              post: post, currentUser: widget.user, onChanged: (_) {})));
    } catch (_) {}
  }

  void _share() {
    final title = (_data?['title'] ?? '').toString();
    final url = 'https://masareen.com/events/${widget.eventId}';
    SharePolicy.copy(context,
        allowed: _data?['activity_verified'] == true,
        text: '$title · $url',
        confirmation: _t('events.linkCopied', 'Event link copied.'));
  }

  Future<void> _openMedia(Map<String, dynamic> item) async {
    final url = Uri.tryParse((item['url'] ?? '').toString());
    if (url == null) return;
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading && _data == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: CircularProgressIndicator()));
    }
    if (_data == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error ?? _t('events.notFound', 'Event not found.'),
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                    onPressed: _load, child: Text(_t('common.retry', 'Retry'))),
              ],
            ),
          ),
        ),
      );
    }
    final event = _data!;
    final participants = _list('participants');
    final media = _list('media');
    final booths = _list('booths');
    final ratings = _list('ratings');
    final projects = _list('projects');
    final research = _list('research_stages');
    final opportunities = _list('opportunities');
    final podcastEpisodes = _list('podcast_episodes');
    final vodVideos = _list('vod_videos');
    final program = event['program'] is Map
        ? Map<String, dynamic>.from(event['program'] as Map)
        : null;
    final rep = event['organizer_reputation'] is Map
        ? Map<String, dynamic>.from(event['organizer_reputation'] as Map)
        : null;
    final my = event['my_participation'] is Map
        ? Map<String, dynamic>.from(event['my_participation'] as Map)
        : null;
    final host = event['host'] is Map
        ? Map<String, dynamic>.from(event['host'] as Map)
        : null;
    final attending = event['attending'] == true;
    final canManage = event['can_manage'] == true;
    final canModerate = event['can_moderate'] == true;
    final canRemoveEvent = event['can_remove_event'] == true;
    final canCreateBooth = event['can_create_booth'] == true;
    final companies = participants.where((p) =>
        ['EXHIBITOR', 'SPONSOR', 'PARTNER', 'HOST']
            .contains(p['role'])).toList();
    final title = (event['title'] ?? '').toString();
    final participantGroups = <String, List<Map<String, dynamic>>>{};
    for (final p in participants) {
      participantGroups
          .putIfAbsent((p['role'] ?? 'PARTNER').toString(), () => [])
          .add(p);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (canManage)
            IconButton(
                tooltip: _t('events.dashboard', 'Event dashboard'),
                onPressed: _openDashboard,
                icon: const Icon(Icons.insights_outlined)),
          if (canManage || canModerate)
            IconButton(
                tooltip: 'Impact report',
                onPressed: _openReport,
                icon: const Icon(Icons.assessment_outlined)),
          if (canManage || canModerate)
            IconButton(
                tooltip: 'Moderators',
                onPressed: () => _openModerators(title),
                icon: const Icon(Icons.admin_panel_settings_outlined)),
          if (canRemoveEvent)
            IconButton(
                tooltip: 'Remove event',
                onPressed: () => _deleteEvent(title),
                icon: const Icon(Icons.delete_outline)),
          IconButton(
              tooltip: _t('events.share', 'Share event'),
              onPressed: _share,
              icon: const Icon(Icons.ios_share)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            FadeSlideIn(
              child: Stack(
                children: [
                  SmartImage(
                    url: event['cover_url']?.toString(),
                    height: 220,
                    width: double.infinity,
                    fallbackIcon: Icons.event,
                    accent: cs.primary,
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.72),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _Badge(
                                label: _t(
                                    'events.type.${event['event_type'] ?? 'EVENT'}',
                                    (event['event_type'] ?? 'EVENT')
                                        .toString()),
                                color: AppColors.accent),
                            if (event['activity_verified'] == true)
                              _Badge(
                                  label: _t(
                                      'events.verified', 'Verified activity'),
                                  color: AppColors.brand),
                            if (event['event_type'] == 'PODCAST')
                              _Badge(label: 'PODCAST', color: cs.primary),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 23,
                                height: 1.2,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 5),
                        Text(
                            [
                              _date(event['starts_at']?.toString()),
                              (event['location'] ?? '').toString(),
                            ].where((s) => s.isNotEmpty).join(' · '),
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontSize: 12.5)),
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
                  if ((event['description'] ?? '').toString().isNotEmpty)
                    Text((event['description'] ?? '').toString(),
                        style: TextStyle(
                            fontSize: 14.5, height: 1.6, color: cs.onSurface)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (host != null)
                        _InfoChip(
                            icon: Icons.account_balance_outlined,
                            label:
                                '${_t('events.host', 'Host')}: ${host['name']}'),
                      if (rep != null && rep['total_events'] != null)
                        _InfoChip(
                            icon: Icons.verified_outlined,
                            label:
                                '${rep['verified_events']} ${_t('events.verifiedEvents', 'verified events')}'),
                      if (event['program_title'] != null)
                        _InfoChip(
                            icon: Icons.hub_outlined,
                            label: event['program_title'].toString()),
                      if (event['source_url'] != null)
                        _InfoChip(
                            icon: Icons.public,
                            label: _t('events.source', 'Source')),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!attending)
                        FilledButton.icon(
                            onPressed: _busy ? null : _join,
                            icon: const Icon(Icons.check_circle_outline,
                                size: 18),
                            label: Text(_t('events.join', 'Join event')))
                      else
                        OutlinedButton.icon(
                            onPressed: _busy ? null : _join,
                            icon: const Icon(Icons.check, size: 18),
                            label: Text(_t('events.attending', 'Attending'))),
                      if (attending)
                        OutlinedButton.icon(
                            onPressed: _claimAttendance,
                            icon: const Icon(Icons.qr_code_scanner, size: 18),
                            label: Text(
                                _t('events.claimAttendance', 'Claim 5 MRC'))),
                      if (attending || my != null)
                        OutlinedButton.icon(
                            onPressed: _rate,
                            icon: const Icon(Icons.star_outline, size: 18),
                            label: Text(_t('events.rate', 'Rate'))),
                      if ((event['funding_goal'] as num? ?? 0) > 0)
                        OutlinedButton.icon(
                            onPressed: _fund,
                            icon: const Icon(Icons.volunteer_activism_outlined,
                                size: 18),
                            label: Text(_t('events.fund', 'Fund'))),
                      if (canCreateBooth)
                        OutlinedButton.icon(
                            onPressed: _createBooth,
                            icon:
                                const Icon(Icons.storefront_outlined, size: 18),
                            label: Text(_t('booth.open', 'Open booth'))),
                    ],
                  ),
                  if (my != null &&
                      ['INVITED', 'SUBMITTED', 'UNDER_REVIEW']
                          .contains(my['status'])) ...[
                    const SizedBox(height: 12),
                    _NoticeCard(
                      icon: my['status'] == 'INVITED'
                          ? Icons.mail_outline
                          : Icons.hourglass_top,
                      title: my['status'] == 'INVITED'
                          ? _t('events.invitation', 'You are invited as {role}')
                              .replaceAll('{role}', '${my['role']}')
                          : _t('events.pendingVerification',
                              'Your contribution is awaiting host verification'),
                      action: my['status'] == 'INVITED'
                          ? TextButton(
                              onPressed: () => _confirm(my['id'].toString()),
                              child: Text(_t('events.confirm', 'Confirm')))
                          : TextButton(
                              onPressed: () =>
                                  _addEvidence(my['id'].toString()),
                              child: Text(
                                  _t('events.updateProof', 'Update proof'))),
                    ),
                  ],
                  if (event['activity_verified'] == true) ...[
                    const SizedBox(height: 12),
                    _NoticeCard(
                      icon: Icons.verified,
                      color: AppColors.brand,
                      title: _t('events.verifiedBody',
                          'The host confirmed this activity with evidence.'),
                      subtitle: event['activity_verified_at'] == null
                          ? null
                          : _date(event['activity_verified_at'].toString()),
                    ),
                  ],
                  if (canManage) ...[
                    const SizedBox(height: 12),
                    _Section(
                      title: _t('events.manage', 'Manage event'),
                      icon: Icons.settings_outlined,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                              onPressed: _addParticipant,
                              icon: const Icon(Icons.person_add_alt, size: 17),
                              label: Text(_t(
                                  'events.addContributor', 'Add contributor'))),
                          OutlinedButton.icon(
                              onPressed: _addMedia,
                              icon: const Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 17),
                              label: Text(_t('events.addMedia', 'Add media'))),
                          OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => CreateVodScreen(
                                          eventId: widget.eventId))),
                              icon: const Icon(Icons.video_library_outlined,
                                  size: 17),
                              label: const Text('Add VOD replay')),
                          if (podcastEpisodes.isNotEmpty)
                            OutlinedButton.icon(
                                onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => CreateEpisodeScreen(
                                              showId: podcastEpisodes.first['show_id']
                                                  .toString(),
                                              showTitle: (podcastEpisodes.first[
                                                          'show_title'] ??
                                                      'Event podcast')
                                                  .toString(),
                                              eventId: widget.eventId,
                                            ))),
                                icon: const Icon(Icons.podcasts, size: 17),
                                label: const Text('Add episode')),
                          if (event['can_create_booth'] == true)
                            OutlinedButton.icon(
                                onPressed: _createBooth,
                                icon: const Icon(Icons.storefront_outlined,
                                    size: 17),
                                label: Text(_t(
                                    'booth.create', 'Open a digital booth'))),
                          OutlinedButton.icon(
                              onPressed: _openDashboard,
                              icon:
                                  const Icon(Icons.insights_outlined, size: 17),
                              label: Text(
                                  _t('events.dashboard', 'Event dashboard'))),
                        ],
                      ),
                    ),
                  ],
                  if (companies.isNotEmpty)
                    _Section(
                      title: 'Companies at this event',
                      icon: Icons.business_outlined,
                      child: Column(
                        children: companies.take(10).map((p) {
                          final location = [p['city'], p['country']]
                              .where((v) =>
                                  v != null && v.toString().isNotEmpty)
                              .join(', ');
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: AppAvatar(
                                name: (p['name'] ?? 'C').toString(),
                                url: p['avatar_url']?.toString(),
                                size: 36),
                            title: Text((p['name'] ?? 'Company').toString(),
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                            subtitle: Text(
                                '${p['role_title'] ?? p['role']} · ${location.isEmpty ? 'At this event' : location} · ${p['post_count'] ?? 0} posts',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 10.5,
                                    color: cs.onSurfaceVariant)),
                            trailing: const Icon(Icons.arrow_forward, size: 15),
                            onTap: () => openEntityAuthor(context,
                                author: Author(
                                    id: p['user_id'].toString(),
                                    name: (p['name'] ?? 'Company').toString(),
                                    avatarUrl: p['avatar_url']?.toString(),
                                    role: p['role']?.toString()),
                                currentUser: widget.user),
                          );
                        }).toList(),
                      ),
                    ),
                  if (participants.isNotEmpty)
                    _Section(
                      title: _t('events.contributors', 'Contributors'),
                      icon: Icons.groups_outlined,
                      child: Column(
                        children: participantGroups.entries.map((group) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 10, bottom: 4),
                                child: Text(
                                    _t('events.role.${group.key}', group.key),
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: .4,
                                        color: cs.primary)),
                              ),
                              ...group.value.map((p) => _ParticipantTile(
                                    participant: p,
                                    canVerify: canManage &&
                                        ['SUBMITTED', 'UNDER_REVIEW']
                                            .contains(p['status']) &&
                                        p['user_id'].toString() !=
                                            widget.user.id,
                                    isMine: p['user_id'].toString() ==
                                        widget.user.id,
                                    onOpen: () => openEntityAuthor(context,
                                        author: Author(
                                            id: p['user_id'].toString(),
                                            name: (p['name'] ?? 'Member')
                                                .toString(),
                                            avatarUrl:
                                                p['avatar_url']?.toString(),
                                            role: p['role']?.toString()),
                                        currentUser: widget.user),
                                    onEvidence: () =>
                                        _addEvidence(p['id'].toString()),
                                    onVerify: () => _verdict(
                                        p['id'].toString(), 'VERIFIED'),
                                    onReject: () => _verdict(
                                        p['id'].toString(), 'REJECTED'),
                                  )),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  if (program != null)
                    _Section(
                      title: _t('events.program', 'Linked program'),
                      icon: Icons.hub_outlined,
                      child: _EventRow(
                        icon: Icons.route_outlined,
                        title: (program['title'] ?? '').toString(),
                        subtitle: [
                          (program['organization'] ?? '').toString(),
                          (program['status'] ?? '').toString(),
                        ].where((s) => s.isNotEmpty).join(' · '),
                        onTap: () => _openProgram(program['id'].toString()),
                      ),
                    ),
                  if (projects.isNotEmpty)
                    _Section(
                      title: _t('events.capstones', 'Projects & capstones'),
                      icon: Icons.rocket_launch_outlined,
                      child: Column(
                        children: projects
                            .map((p) => _EventRow(
                                  icon: Icons.workspace_premium_outlined,
                                  title: (p['title'] ?? '').toString(),
                                  subtitle: [
                                    (p['project_type'] ?? '').toString(),
                                    (p['academic_year'] ?? '').toString(),
                                    (p['student_names'] ?? '').toString(),
                                    if ((p['supervisor'] ?? '')
                                        .toString()
                                        .isNotEmpty)
                                      '${_t('projects.supervisor', 'Supervisor')}: ${p['supervisor']}',
                                  ].where((s) => s.isNotEmpty).join(' · '),
                                ))
                            .toList(),
                      ),
                    ),
                  if (research.isNotEmpty)
                    _Section(
                      title: _t('events.researchStages', 'Research stages'),
                      icon: Icons.science_outlined,
                      child: Column(
                        children: research
                            .map((r) => _EventRow(
                                  icon: Icons.science_outlined,
                                  title: (r['title'] ?? '').toString(),
                                  subtitle: [
                                    (r['stage'] ?? '').toString(),
                                    (r['researcher_name'] ?? '').toString(),
                                  ].where((s) => s.isNotEmpty).join(' · '),
                                  trailing: (r['post_id'] ?? '')
                                          .toString()
                                          .isEmpty
                                      ? null
                                      : const Icon(Icons.open_in_new, size: 16),
                                  onTap: () => _openResearchPost(
                                      (r['post_id'] ?? '').toString()),
                                ))
                            .toList(),
                      ),
                    ),
                  if (opportunities.isNotEmpty)
                    _Section(
                      title: _t(
                          'events.opportunitiesLinked', 'Linked opportunities'),
                      icon: Icons.work_outline,
                      child: Column(
                        children: opportunities
                            .map((o) => _EventRow(
                                  icon: Icons.work_outline,
                                  title: (o['title'] ?? '').toString(),
                                  subtitle: [
                                    (o['type'] ?? '').toString(),
                                    (o['location'] ?? '').toString(),
                                    if ((o['deadline'] ?? '')
                                        .toString()
                                        .isNotEmpty)
                                      _date(o['deadline']?.toString()),
                                  ].where((s) => s.isNotEmpty).join(' · '),
                                  onTap: () =>
                                      _openOpportunity(o['id'].toString()),
                                ))
                            .toList(),
                      ),
                    ),
                  if (booths.isNotEmpty)
                    _Section(
                      title: _t('events.booths', 'Interactive booths'),
                      icon: Icons.storefront_outlined,
                      child: SizedBox(
                        height: 218,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: booths.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (_, index) => _BoothCard(
                            booth: booths[index],
                            onTap: () =>
                                _openBooth(booths[index]['id'].toString()),
                          ),
                        ),
                      ),
                    ),
                  if (podcastEpisodes.isNotEmpty)
                    _Section(
                      title: _t('events.podcasts', 'Podcast episodes'),
                      icon: Icons.podcasts,
                      child: Column(
                        children: podcastEpisodes
                            .map((e) => _EventRow(
                                  icon: Icons.play_circle_outline,
                                  title: (e['title'] ?? '').toString(),
                                  subtitle: [
                                    (e['show_title'] ?? '').toString(),
                                    if (e['guests'] is List)
                                      (e['guests'] as List).join(' · '),
                                  ].where((s) => s.isNotEmpty).join(' · '),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => PodcastShowScreen(
                                            showId: e['show_id'].toString(),
                                            user: widget.user)),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  if (vodVideos.isNotEmpty)
                    _Section(
                      title: _t('events.vod', 'VOD & replays'),
                      icon: Icons.video_library_outlined,
                      child: Column(
                        children: vodVideos
                            .map((v) => _EventRow(
                                  icon: Icons.play_circle_outline,
                                  title: (v['title'] ?? '').toString(),
                                  subtitle: [
                                    (v['duration_sec'] as num? ?? 0)
                                        .toInt()
                                        .toString(),
                                    '${v['views'] ?? 0} ${_t('vod.views', 'views')}',
                                  ].join(' · '),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => VodPlayerScreen(
                                            videoId: v['id'].toString(),
                                            user: widget.user)),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  if (media.isNotEmpty)
                    _Section(
                      title: _t('events.media', 'Media & podcasts'),
                      icon: Icons.play_circle_outline,
                      child: Column(
                        children: media
                            .map((m) =>
                                _MediaTile(item: m, onTap: () => _openMedia(m)))
                            .toList(),
                      ),
                    ),
                  if (rep != null && (rep['total_events'] ?? 0) > 0)
                    _Section(
                      title: _t('events.reputation', 'Organizer reputation'),
                      icon: Icons.workspace_premium_outlined,
                      child: Row(
                        children: [
                          Expanded(
                              child: _Stat(
                                  '${rep['verified_events'] ?? 0}',
                                  _t('events.verifiedEvents',
                                      'verified events'))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _Stat('${rep['clients'] ?? 0}',
                                  _t('events.clients', 'clients'))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _Stat('${rep['rating_avg'] ?? 0}',
                                  _t('events.rating', 'rating'))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _Stat('#${rep['rank'] ?? '-'}',
                                  _t('events.rank', 'rank'))),
                        ],
                      ),
                    ),
                  if (ratings.isNotEmpty)
                    _Section(
                      title:
                          '${_t('events.reviews', 'Reviews')} · ${event['rating_avg']} (${event['rating_count']})',
                      icon: Icons.star_outline,
                      child: Column(
                        children:
                            ratings.map((r) => _RatingTile(rating: r)).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _EventRow(
      {required this.icon,
      required this.title,
      this.subtitle = '',
      this.trailing,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: cs.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface)),
                  if (subtitle.isNotEmpty)
                    Text(subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .16),
        border: Border.all(color: color.withValues(alpha: .5)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _Section(
      {required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FadeSlideIn(
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: .6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(title,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface))),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final Color? color;
  const _NoticeCard(
      {required this.icon,
      required this.title,
      this.subtitle,
      this.action,
      this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tone = color ?? cs.primary;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.withValues(alpha: .25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: tone, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: TextStyle(
                          fontSize: 11.5, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  final Map<String, dynamic> participant;
  final bool canVerify;
  final bool isMine;
  final VoidCallback onOpen;
  final VoidCallback onEvidence;
  final VoidCallback onVerify;
  final VoidCallback onReject;
  const _ParticipantTile(
      {required this.participant,
      required this.canVerify,
      required this.isMine,
      required this.onOpen,
      required this.onEvidence,
      required this.onVerify,
      required this.onReject});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = (participant['status'] ?? '').toString();
    final statusColor = status == 'VERIFIED'
        ? AppColors.brand
        : status == 'REJECTED'
            ? cs.error
            : status == 'SUBMITTED' || status == 'UNDER_REVIEW'
                ? AppColors.accent
                : cs.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Clickable(
            onTap: onOpen,
            child: AppAvatar(
                name: (participant['name'] ?? 'Member').toString(),
                url: participant['avatar_url']?.toString(),
                size: 38),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Clickable(
                  onTap: onOpen,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text((participant['name'] ?? '').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface)),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(status,
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: statusColor)),
                      ),
                    ],
                  ),
                ),
                if ((participant['role_title'] ?? '').toString().isNotEmpty)
                  Text(participant['role_title'].toString(),
                      style: TextStyle(
                          fontSize: 11.5, color: cs.onSurfaceVariant)),
                if ((participant['contribution'] ?? '').toString().isNotEmpty)
                  Text(participant['contribution'].toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: cs.onSurfaceVariant)),
                if ((participant['deepfake_verdict'] ?? 'UNSCANNED') !=
                        'UNSCANNED' &&
                    (participant['deepfake_verdict'] ?? '') !=
                        'LIKELY_AUTHENTIC')
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.amber.withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(
                          '${participant['deepfake_verdict']} ${((participant['deepfake_score'] ?? 0) as num).toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.amber)),
                    ),
                  ),
                if (canVerify)
                  Wrap(
                    spacing: 4,
                    children: [
                      TextButton(
                          onPressed: onVerify,
                          child: Text(MasarenLocalizations.of(
                                      context, 'events.verify') ==
                                  'events.verify'
                              ? 'Verify'
                              : MasarenLocalizations.of(
                                  context, 'events.verify'))),
                      TextButton(
                          onPressed: onReject,
                          child: Text(MasarenLocalizations.of(
                                      context, 'events.reject') ==
                                  'events.reject'
                              ? 'Reject'
                              : MasarenLocalizations.of(
                                  context, 'events.reject'))),
                    ],
                  )
                else if (isMine &&
                    ['INVITED', 'SUBMITTED', 'UNDER_REVIEW', 'REJECTED']
                        .contains(status))
                  TextButton(
                      onPressed: onEvidence,
                      child: Text(
                          MasarenLocalizations.of(context, 'events.addProof') ==
                                  'events.addProof'
                              ? 'Add / update proof'
                              : MasarenLocalizations.of(
                                  context, 'events.addProof'))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BoothCard extends StatelessWidget {
  final Map<String, dynamic> booth;
  final VoidCallback onTap;
  const _BoothCard({required this.booth, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final owner = booth['owner'] is Map
        ? Map<String, dynamic>.from(booth['owner'] as Map)
        : const <String, dynamic>{};
    return SizedBox(
      width: 246,
      child: Material(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: cs.outlineVariant.withValues(alpha: .6))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: SmartImage(
                      url: booth['cover_url']?.toString(),
                      height: 100,
                      width: double.infinity,
                      fallbackIcon: Icons.storefront_outlined,
                      accent: cs.primary),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((booth['title'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface)),
                      const SizedBox(height: 2),
                      Text((owner['name'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.visibility_outlined,
                              size: 13, color: cs.onSurfaceVariant),
                          const SizedBox(width: 3),
                          Text('${booth['views'] ?? 0}',
                              style: TextStyle(
                                  fontSize: 10.5, color: cs.onSurfaceVariant)),
                          const SizedBox(width: 10),
                          Icon(Icons.handshake_outlined,
                              size: 13, color: cs.onSurfaceVariant),
                          const SizedBox(width: 3),
                          Text('${booth['leads_count'] ?? 0}',
                              style: TextStyle(
                                  fontSize: 10.5, color: cs.onSurfaceVariant)),
                          const Spacer(),
                          if (booth['active'] != true)
                            Text(
                                MasarenLocalizations.of(
                                            context, 'booth.inactive') ==
                                        'booth.inactive'
                                    ? 'Inactive'
                                    : MasarenLocalizations.of(
                                        context, 'booth.inactive'),
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: cs.error)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const _MediaTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final type = (item['type'] ?? 'MEDIA').toString();
    final icon = type == 'PODCAST'
        ? Icons.podcasts
        : type == 'VIDEO'
            ? Icons.play_circle_outline
            : type == 'NEWS' || type == 'REPORT'
                ? Icons.article_outlined
                : Icons.image_outlined;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SmartImage(
                  url: item['thumbnail_url']?.toString(),
                  width: 64,
                  height: 52,
                  fallbackIcon: icon,
                  accent: cs.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((item['title'] ?? type).toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface)),
                  Text(type,
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: cs.primary)),
                ],
              ),
            ),
            Icon(Icons.open_in_new, size: 16, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _RatingTile extends StatelessWidget {
  final Map<String, dynamic> rating;
  const _RatingTile({required this.rating});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(
              name: (rating['name'] ?? 'Member').toString(),
              url: rating['avatar_url']?.toString(),
              size: 30),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text((rating['name'] ?? '').toString(),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface)),
                    const SizedBox(width: 6),
                    ...List.generate(
                        5,
                        (i) => Icon(
                            i < ((rating['rating'] as num?)?.toInt() ?? 0)
                                ? Icons.star_rounded
                                : Icons.star_border,
                            size: 13,
                            color: AppColors.accent)),
                  ],
                ),
                if ((rating['review'] ?? '').toString().isNotEmpty)
                  Text(rating['review'].toString(),
                      style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface)),
          Text(label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9.5, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
