import 'package:flutter/material.dart';
import 'package:masaren/core/theme/masaren_theme.dart';
import 'package:masaren/features/feed/feed_store.dart';
import 'package:masaren/features/feed/screens/feed_screen.dart';
import 'package:masaren/features/opportunities/screens/opportunities_screen.dart';
import 'package:masaren/features/tasks/screens/task_list_screen.dart';
import 'package:masaren/features/notifications/screens/notifications_screen.dart';
import 'package:masaren/features/profile/screens/profile_screen.dart';
import 'package:masaren/features/shell/compose_sheet.dart';
import 'package:masaren/services/api_service.dart';
import 'package:masaren/di/injection.dart';
import 'package:masaren/core/permissions/permission_service.dart';

/// Social-media home shell (Instagram/Facebook/LinkedIn fusion).
///
/// A persistent bottom [NavigationBar] drives a [PageView] with slide
/// transitions between the five primary tabs. The home tab (Feed) is reachable
/// by every role, including admins. A centre compose FAB opens the post
/// composer; secondary MASAREEN tools live behind the drawer.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final PageController _pageController;
  late final ScrollController _feedScroll;
  late final List<Widget> _pages;
  int _index = 0;
  String _creator = 'You';

  static const _destinations = [
    _Tab(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    _Tab(icon: Icons.explore_outlined, activeIcon: Icons.explore_rounded, label: 'Explore'),
    _Tab(icon: Icons.task_alt_outlined, activeIcon: Icons.task_alt_rounded, label: 'Tasks'),
    _Tab(icon: Icons.notifications_outlined, activeIcon: Icons.notifications_rounded, label: 'Alerts'),
    _Tab(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _feedScroll = ScrollController();
    _pages = [
      FeedScreen(scrollController: _feedScroll),
      const OpportunitiesScreen(),
      const TaskListScreen(),
      const NotificationsScreen(),
      const ProfileScreen(),
    ];
    _loadProfile();
    feedStore.load();
    PermissionService.instance.requestAll();
  }

  Future<void> _loadProfile() async {
    try {
      final u = await getIt<ApiService>().getCurrentUser();
      if (mounted) setState(() => _creator = u.fullName.isNotEmpty ? u.fullName : 'You');
    } catch (_) {}
  }

  void _onTap(int i) {
    if (i == _index) {
      if (i == 0) _feedScroll.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
      return;
    }
    _pageController.animateToPage(i, duration: const Duration(milliseconds: 320), curve: Curves.easeInOutCubic);
    setState(() => _index = i);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _feedScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MasarenTheme.canvasOf(context),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onTap,
        elevation: 6,
        height: 64,
        destinations: [
          for (var i = 0; i < _destinations.length; i++)
            NavigationDestination(
              icon: Icon(_destinations[i].icon),
              selectedIcon: Icon(_destinations[i].activeIcon),
              label: _destinations[i].label,
            ),
        ],
      ),
      floatingActionButton: _index == 0
          ? FloatingActionButton(
              onPressed: () => ComposeSheet.show(context, creator: _creator),
              tooltip: 'Create post',
              backgroundColor: Colors.transparent,
              elevation: 6,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [MasarenTheme.brand, MasarenTheme.green],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: MasarenTheme.brand.withOpacity(0.45), blurRadius: 14, offset: const Offset(0, 6)),
                  ],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class _Tab {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _Tab({required this.icon, required this.activeIcon, required this.label});
}



