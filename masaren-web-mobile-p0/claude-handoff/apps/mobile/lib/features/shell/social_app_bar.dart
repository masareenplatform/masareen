import 'package:flutter/material.dart';
import 'package:masaren/core/theme/masaren_theme.dart';
import 'package:masaren/features/shell/app_menu_sheet.dart';

/// Reusable top app bar for the social shell tabs.
///
/// Facebook-inspired: a clean light surface with a bold brand-blue wordmark,
/// a hairline divider and the overflow menu. Smooth slide transitions between
/// routes are handled in [AppRouter].
class SocialAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showMenu;
  final bool showBack;
  final VoidCallback? onBack;

  const SocialAppBar({
    super.key,
    this.title = 'MASAREEN',
    this.actions,
    this.showMenu = true,
    this.showBack = false,
    this.onBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: MasarenTheme.canvas,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              color: MasarenTheme.ink,
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            )
          : null,
      titleSpacing: showBack ? 0 : 16,
      title: Row(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [MasarenTheme.brand, MasarenTheme.azure],
            ).createShader(bounds),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (actions != null) ...actions!,
        if (showMenu)
          Semantics(
            identifier: 'menu_button',
            label: 'Open navigation menu',
            child: IconButton(
              icon: const Icon(Icons.menu_rounded),
              color: MasarenTheme.ink,
              tooltip: 'Menu',
              key: const Key('menu_button'),
              onPressed: () => AppMenuSheet.show(context),
            ),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: MasarenTheme.line),
      ),
    );
  }
}
