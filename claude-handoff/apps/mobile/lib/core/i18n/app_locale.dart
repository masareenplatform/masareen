import 'package:flutter/material.dart';

class AppLocale {
  /// Global locale notifier — flip to 'ar' for an elegant RTL Arabic experience.
  static ValueNotifier<Locale> currentLocale = ValueNotifier(const Locale('en'));

  static bool get isArabic => currentLocale.value.languageCode == 'ar';

  static void toggle() {
    currentLocale.value = isArabic ? const Locale('en') : const Locale('ar');
  }

  static const Map<String, Map<String, String>> _translations = {
    'en': {
      'dashboard': 'Dashboard',
      'profile': 'Profile',
      'tasks': 'My Tasks',
      'evidence': 'Evidence',
      'passport': 'Impact Passport',
      'opportunities': 'Opportunities',
      'admin': 'Admin Panel',
      'welcome': 'Welcome back!',
      'active_tasks': 'Active Tasks',
    },
    'ar': {
      'dashboard': 'لوحة التحكم',
      'profile': 'الملف الشخصي',
      'tasks': 'مهامي',
      'evidence': 'الأدلة',
      'passport': 'جواز السفر التأثيري',
      'opportunities': 'الفرص',
      'admin': 'لوحة الإدارة',
      'welcome': 'مرحباً بك مجدداً!',
      'active_tasks': 'المهام النشطة',
    },
  };

  static String translate(String key, String locale) {
    return _translations[locale]?[key] ?? key;
  }
}



