import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'di/injection.dart';
import 'router/app_router.dart';
import 'core/theme/masaren_theme.dart';
import 'core/i18n/app_locale.dart';
import 'core/settings/app_settings.dart';
import 'core/logging/ui_logger.dart';

final getIt = GetIt.instance;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  await AppSettings.instance.init();
  await UiLogger.instance.init();
  runApp(const MasarenApp());
}

class MasarenApp extends StatelessWidget {
  const MasarenApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    return ValueListenableBuilder<Locale>(
      valueListenable: AppLocale.currentLocale,
      builder: (context, locale, child) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: settings.themeMode,
          builder: (context, mode, _) {
            return MaterialApp.router(
              title: 'MASAREEN',
              debugShowCheckedModeBanner: false,
              locale: locale,
              theme: MasarenTheme.light,
              darkTheme: MasarenTheme.dark,
              themeMode: mode,
              routerConfig: AppRouter.router,
              builder: (context, child) => Directionality(
                textDirection: locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                child: child!,
              ),
            );
          },
        );
      },
    );
  }
}



