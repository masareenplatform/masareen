import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/models.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/profile_router.dart';
import 'package:masaren/screens/course_detail_screen.dart';
import 'package:masaren/screens/create_course_screen.dart';
import 'package:masaren/widgets/entity_status.dart';
import 'package:masaren/widgets/smart_image.dart';
import 'package:masaren/widgets/stacked_avatars.dart';

class CoursesScreen extends StatefulWidget {
  final User user;
  final VoidCallback? onMenu;
  const CoursesScreen({super.key, required this.user, this.onMenu});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  List<Course> _items = [];
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
      _items = await AuthApi.courses();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDetail(Course c) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CourseDetailScreen(course: c, user: widget.user)));
    if (mounted) await _load();
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<Course>(
      MaterialPageRoute(
          builder: (_) => CreateCourseScreen(user: widget.user)),
    );
    if (created == null || !mounted) return;
    setState(() => _items.insert(0, created));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(MasarenLocalizations.of(context, 'courses.created'))));
  }
  final Set<String> _busyIds = {};

  Future<void> _enroll(Course c) async {
    if (_busyIds.contains(c.id)) return;
    _busyIds.add(c.id);
    if (mounted) setState(() {});
    try {
      if (c.enrolledByMe) {
        await AuthApi.unenrollCourse(c.id);
      } else {
        await AuthApi.enrollCourse(c.id);
      }
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(MasarenLocalizations.of(
                  context,
                  c.enrolledByMe
                      ? 'courses.leftToast'
                      : 'courses.enrolledToast')
              .replaceAll('{title}', c.title))));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(MasarenLocalizations.of(context, 'common.failed')
                .replaceAll('{error}', e.toString()))));
      }
    } finally {
      _busyIds.remove(c.id);
      if (mounted) setState(() {});
    }
  }

  String _levelLabel(BuildContext context, String level) {
    final key = 'courses.level.${level.toLowerCase()}';
    final label = MasarenLocalizations.of(context, key);
    return label == key ? level : label;
  }

  String _meta(BuildContext context, Course c) {
    final lessons = MasarenLocalizations.of(context, 'courses.lessonCount')
        .replaceAll('{count}', '${c.lessons}');
    final level = _levelLabel(context, c.level);
    final sdg = c.sdg == null
        ? ''
        : ' · ${MasarenLocalizations.of(context, 'courses.sdgLabel')} ${c.sdg}';
    final duration = c.durationMin > 0
        ? ' · ${MasarenLocalizations.of(context, 'courses.durationLabel').replaceAll('{minutes}', '${c.durationMin}')}'
        : '';
    return '$lessons · $level$sdg$duration';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(MasarenLocalizations.of(context, 'courses.title')),
        actions: [
          if (widget.onMenu != null)
            IconButton(
              tooltip: MasarenLocalizations.of(context, 'nav.more'),
              icon: const Icon(Icons.menu_open),
              onPressed: widget.onMenu,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        backgroundColor: AppColors.azure,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(message: _error, onRetry: () => _load())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    children: [
                      SectionTitle(
                          title: MasarenLocalizations.of(
                              context, 'courses.learning')),
                      if (_items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            MasarenLocalizations.of(context, 'courses.empty'),
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ..._items.map((c) => Card(
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => _openDetail(c),
                              child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  SmartImage(
                                    url: c.thumbnail,
                                    width: 56,
                                    height: 56,
                                    borderRadius: BorderRadius.circular(14),
                                    fallbackIcon: Icons.school_rounded,
                                    accent: cs.primary,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(c.title,
                                                  style: TextStyle(
                                                      color: cs.onSurface,
                                                      fontWeight:
                                                          FontWeight.w800)),
                                            ),
                                            if (c.enrolledByMe)
                                              Icon(Icons.verified_rounded,
                                                  size: 16,
                                                  color: cs.secondary),
                                            EntityStatusChip(
                                                status: c.verificationStatus,
                                                reason: c.rejectionReason),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(_meta(context, c),
                                            style: TextStyle(
                                                color: cs.onSurfaceVariant,
                                                fontSize: 12)),
                                        if (c.author != null) ...[
                                          const SizedBox(height: 5),
                                          InkWell(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            onTap: () => openEntityAuthor(
                                              context,
                                              author: c.author,
                                              currentUser: widget.user,
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 3),
                                              child: Row(
                                                children: [
                                                  AppAvatar(
                                                      name: c.author!.name,
                                                      url: c.author!.avatarUrl,
                                                      size: 18),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      c.author!.name,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: cs.primary,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                        if (c.membersPreview.isNotEmpty ||
                                            c.enrolledCount > 0) ...[
                                          const SizedBox(height: 6),
                                          StackedAvatars(
                                              people: c.membersPreview,
                                              total: c.enrolledCount,
                                              size: 20),
                                        ],
                                      ],
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: _busyIds.contains(c.id)
                                        ? null
                                        : () => _enroll(c),
                                    icon: Icon(
                                        c.enrolledByMe
                                            ? Icons.exit_to_app
                                            : Icons.school_outlined,
                                        size: 16),
                                    label: Text(MasarenLocalizations.of(
                                        context,
                                        c.enrolledByMe
                                            ? 'courses.leave'
                                            : 'courses.enroll')),
                                  ),
                                  Icon(Icons.chevron_right,
                                      size: 18, color: cs.onSurfaceVariant),
                                ],
                              ),
                            ),
                          ))),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}
