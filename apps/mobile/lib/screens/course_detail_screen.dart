import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/profile_router.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/widgets/entity_status.dart';
import 'package:masaren/widgets/smart_image.dart';
import 'package:masaren/widgets/post_media_gallery.dart';
import 'package:masaren/widgets/stacked_avatars.dart';
import 'package:masaren/screens/create_lesson_screen.dart';

class CourseDetailScreen extends StatefulWidget {
  final Course course;
  final User user;
  final ValueChanged<Course>? onChanged;
  const CourseDetailScreen(
      {super.key, required this.course, required this.user, this.onChanged});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  late Course _c = widget.course;
  bool _busy = false;
  List<CourseLesson> _lessons = const [];
  bool _lessonsLoading = true;
  bool _enrolled = false;
  bool _paid = false;
  double _price = 0;

  bool get _isManager =>
      widget.user.isAdmin || _c.author?.id == widget.user.id;

  @override
  void initState() {
    super.initState();
    _enrolled = _c.enrolledByMe;
    _paid = !_c.isFree && _c.priceMrc > 0;
    _price = _c.priceMrc;
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    setState(() => _lessonsLoading = true);
    try {
      final data = await AuthApi.courseLessons(_c.id);
      final list = (data['lessons'] as List? ?? const [])
          .map((e) => CourseLesson.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (!mounted) return;
      setState(() {
        _lessons = list;
        _enrolled = data['enrolled'] == true;
        _paid = data['is_free'] != true;
        _price = (data['price_mrc'] as num?)?.toDouble() ?? _c.priceMrc;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _lessonsLoading = false);
    }
  }

  String _t(String key, [String? fallback]) {
    final value = MasarenLocalizations.of(context, key);
    return value == key ? (fallback ?? key) : value;
  }

  Future<void> _refresh() async {
    try {
      final fresh = await AuthApi.course(_c.id);
      if (!mounted) return;
      setState(() => _c = fresh);
      widget.onChanged?.call(fresh);
    } catch (_) {}
  }

  Future<void> _toggleEnrollment() async {
    if (_busy) return;
    setState(() => _busy = true);
    double charged = 0;
    try {
      if (_c.enrolledByMe) {
        await AuthApi.unenrollCourse(_c.id);
      } else {
        final result = await AuthApi.enrollCourse(_c.id);
        charged = (result['charged'] as num?)?.toDouble() ?? 0;
      }
      final fresh = await AuthApi.course(_c.id);
      if (!mounted) return;
      setState(() => _c = fresh);
      widget.onChanged?.call(fresh);
      await _loadLessons();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(charged > 0
              ? _t('courses.paidToast',
                      'Enrolled. {amount} MRC was deducted from your wallet.')
                  .replaceAll('{amount}', charged.toStringAsFixed(0))
              : _t(
                      _c.enrolledByMe
                          ? 'courses.enrolledToast'
                          : 'courses.leftToast')
                  .replaceAll('{title}', _c.title))));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_t('common.failed').replaceAll('{error}', '$e'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: Text(_t('courses.details'))),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            if (_c.thumbnail != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SmartImage(
                  url: _c.thumbnail,
                  height: 160,
                  borderRadius: BorderRadius.circular(20),
                  fallbackIcon: Icons.school_rounded,
                ),
              ),
            _hero(context, cs, dark),
            if (_c.description != null && _c.description!.trim().isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
                child: SectionTitle(title: _t('courses.about')),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(_c.description!,
                    style: TextStyle(
                        color: cs.onSurfaceVariant,
                        height: 1.55,
                        fontSize: 14)),
              ),
            ],
            const SizedBox(height: 14),
            _curriculum(context, cs),
            const SizedBox(height: 20),
            _enrollmentCard(context, cs),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _t('courses.enrollmentSaved',
                    'Your enrollment is saved to your account.'),
                style: TextStyle(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                    fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _curriculum(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: SectionTitle(
                      title: _t('courses.curriculum', 'Curriculum'))),
              if (_isManager)
                TextButton.icon(
                  onPressed: _addLesson,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(_t('courses.addLesson', 'Add lesson')),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (_lessonsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: LinearProgressIndicator(),
            )
          else if (_lessons.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14)),
              child: Text(
                  _t('courses.noLessons',
                      'Lessons will appear here as the author adds them.'),
                  style: TextStyle(
                      color: cs.onSurfaceVariant, fontSize: 12.5)),
            )
          else
            ...List.generate(_lessons.length, (i) {
              final l = _lessons[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        (l.locked ? AppColors.amber : cs.primary)
                            .withValues(alpha: 0.12),
                    child: l.locked
                        ? const Icon(Icons.lock_outline,
                            size: 16, color: AppColors.amber)
                        : Text('${i + 1}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: cs.primary)),
                  ),
                  title: Text(l.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13.5)),
                  subtitle: Text(
                      '${l.durationMin} ${_t('courses.minutesShort', 'min')}'
                      '${l.isPreview ? ' · ${_t('courses.preview', 'Preview')}' : ''}',
                      style: TextStyle(
                          color: cs.onSurfaceVariant, fontSize: 11.5)),
                  trailing: l.locked
                      ? Text(_t('courses.locked', 'Locked'),
                          style: const TextStyle(
                              color: AppColors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.w700))
                      : const Icon(Icons.play_circle_outline, size: 20),
                  onTap: () {
                    if (l.locked) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(_t('courses.enrollToUnlock',
                              'Enroll in this course to unlock every lesson.'))));
                    } else {
                      _openLesson(l);
                    }
                  },
                  onLongPress: _isManager ? () => _deleteLesson(l) : null,
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _openLesson(CourseLesson lesson) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lesson.title,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
                '${lesson.durationMin} ${_t('courses.minutesShort', 'min')}'
                '${lesson.isPreview ? ' · ${_t('courses.preview', 'Preview')}' : ''}',
                style: TextStyle(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    fontSize: 12)),
            if (_isManager)
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _editLesson(lesson);
                },
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: Text(_t('courses.editLesson', 'Edit lesson')),
              ),
            if (lesson.media.isNotEmpty) ...[
              const SizedBox(height: 10),
              PostMediaGallery(
                media: lesson.media,
                videoId: lesson.id,
                videoHlsUrl: null,
                videoPosterUrl: null,
              ),
            ],
            if (lesson.description != null &&
                lesson.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(lesson.description!, style: const TextStyle(height: 1.45)),
            ],
            if (lesson.content != null && lesson.content!.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  child: SelectableText(lesson.content!,
                      style: const TextStyle(height: 1.55, fontSize: 14)),
                ),
              ),
            ],
            if (lesson.videoUrl != null && lesson.videoUrl!.isNotEmpty) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () async {
                  final uri = Uri.tryParse(lesson.videoUrl!);
                  if (uri != null &&
                      await canLaunchUrl(uri)) {
                    await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                  } else {
                    await Clipboard.setData(
                        ClipboardData(text: lesson.videoUrl!));
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text(_t('courses.linkCopied',
                              'Video link copied.'))));
                    }
                  }
                },
                icon: const Icon(Icons.play_circle_outline),
                label: Text(_t('courses.watchLesson', 'Watch lesson')),
              ),
            ],
            if (lesson.files.isNotEmpty) ...[
              const SizedBox(height: 14),
              for (final file in lesson.files)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.description_outlined, size: 20),
                  title: Text(file.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.download_outlined, size: 18),
                  onTap: () async {
                    final uri = Uri.tryParse(file.url);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                ),
            ],
            if (lesson.links.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final link in lesson.links)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.link, size: 20),
                  title: Text(link.label,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(link.url,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () async {
                    final uri = Uri.tryParse(link.url);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteLesson(CourseLesson lesson) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('courses.deleteLesson', 'Delete lesson?')),
        content: Text(lesson.title),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(_t('common.delete', 'Delete'))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AuthApi.deleteCourseLesson(_c.id, lesson.id);
      await _loadLessons();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_t('common.failed').replaceAll('{error}', '$e'))));
      }
    }
  }

  Future<void> _addLesson() async {
    final saved = await Navigator.of(context).push<CourseLesson>(
      MaterialPageRoute(
          builder: (_) => CreateLessonScreen(
              course: _c, user: widget.user)),
    );
    if (saved != null) await _loadLessons();
  }

  Future<void> _editLesson(CourseLesson lesson) async {
    final saved = await Navigator.of(context).push<CourseLesson>(
      MaterialPageRoute(
          builder: (_) => CreateLessonScreen(
              course: _c, user: widget.user, lesson: lesson)),
    );
    if (saved != null) await _loadLessons();
  }
  Widget _hero(BuildContext context, ColorScheme cs, bool dark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: brandGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.20),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _pill(
                  '${_t('courses.level')}: ${_c.level.isEmpty ? 'Beginner' : _c.level}'),
              if (_c.sdg != null) ...[
                const SizedBox(width: 6),
                _pill('SDG ${_c.sdg}'),
              ],
              const Spacer(),
              if (_c.enrolledByMe)
                _pill(_t('courses.enrolled'), icon: Icons.check_circle),
              EntityStatusChip(
                  status: _c.verificationStatus, reason: _c.rejectionReason),
            ],
          ),
          const SizedBox(height: 14),
          Text(_c.title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.25)),
          if ((_c.provider ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(_c.provider!,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 13)),
          ],
          if (_c.author != null) ...[
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => openEntityAuthor(context,
                  author: _c.author, currentUser: widget.user),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    AppAvatar(
                        name: _c.author!.name,
                        url: _c.author!.avatarUrl,
                        size: 32),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_c.author!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ),
                    Icon(Icons.chevron_right,
                        color: Colors.white.withValues(alpha: 0.8), size: 18),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _stat(Icons.menu_book_outlined,
                  _t('courses.lessonsCount').replaceAll('{count}', '${_c.lessons}')),
              const SizedBox(width: 18),
              _stat(Icons.schedule_outlined,
                  _t('courses.durationMinCount').replaceAll('{count}', '${_c.durationMin}')),
              const SizedBox(width: 18),
              _stat(Icons.people_outline,
                  _t('courses.peopleEnrolled').replaceAll('{count}', '${_c.enrolledCount}')),
            ],
          ),
          if (_c.membersPreview.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                StackedAvatars(
                    people: _c.membersPreview,
                    total: _c.enrolledCount,
                    size: 22),
                const SizedBox(width: 6),
                Text('${_c.enrolledCount}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _enrollmentCard(BuildContext context, ColorScheme cs) {
    final enrolled = _enrolled || _c.enrolledByMe;
    final approved = _c.verificationStatus == 'APPROVED';
    final paid = _paid && !_isManager;
    final showPrice = !enrolled && paid;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: enrolled
            ? cs.secondary.withValues(alpha: 0.10)
            : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: enrolled
                ? cs.secondary.withValues(alpha: 0.45)
                : cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(enrolled ? Icons.verified_rounded : Icons.school_outlined,
                  color: enrolled ? cs.secondary : cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    enrolled
                        ? _t('courses.youAreEnrolled')
                        : _t('courses.enrollNow'),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface)),
              ),
            ],
          ),
          if (!approved) ...[
            const SizedBox(height: 8),
            Text(_t('entity.pendingNote'),
                style: TextStyle(
                    color: cs.onSurfaceVariant, fontSize: 12, height: 1.35)),
          ],
          if (showPrice) ...[
            const SizedBox(height: 8),
            Text(
                _t('courses.paidNote',
                        'One-time payment of {price} MRC unlocks every lesson. The author receives the full amount.')
                    .replaceAll('{price}', _price.toStringAsFixed(0)),
                style: TextStyle(
                    color: cs.onSurfaceVariant, fontSize: 12, height: 1.35)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: enrolled
                ? paid
                    ? OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.verified_rounded, size: 16),
                        label: Text(_t('courses.enrolledLabel', 'Enrolled')),
                      )
                    : OutlinedButton.icon(
                        onPressed:
                            _busy || !approved ? null : _toggleEnrollment,
                        icon: const Icon(Icons.exit_to_app, size: 16),
                        label: Text(_t('courses.leave')),
                      )
                : FilledButton.icon(
                    onPressed: _busy || !approved ? null : _toggleEnrollment,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.school_outlined, size: 16),
                    label: Text(showPrice
                        ? _t('courses.enrollFor', 'Enroll for {price} MRC')
                            .replaceAll(
                                '{price}', _price.toStringAsFixed(0))
                        : _t('courses.enroll')),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 12),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String label) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
