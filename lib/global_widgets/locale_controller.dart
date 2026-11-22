import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import '../core/services/user_settings_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController extends ChangeNotifier {
  static final LocaleController instance = LocaleController._();
  LocaleController._();

  static const String _key = 'locale';
  static const _supportedLocales = [Locale('ar'), Locale('en')];
  Locale _locale = const Locale('ar');

  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';
  bool get isRTL => isArabic;

  Future<void> loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    _locale = saved == null
        ? const Locale('ar')
        : resolveSupportedLocale(Locale(saved), _supportedLocales);
    await initializeDateFormatting(_locale.languageCode);
    Intl.defaultLocale = _locale.languageCode;
    notifyListeners();
  }

  static Locale resolveSupportedLocale(
    Locale? locale,
    Iterable<Locale> supportedLocales,
  ) {
    if (locale != null) {
      for (final supported in supportedLocales) {
        if (supported.languageCode == locale.languageCode) return supported;
      }
    }
    for (final supported in supportedLocales) {
      if (supported.languageCode == 'ar') return supported;
    }
    return supportedLocales.first;
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    await initializeDateFormatting(locale.languageCode);
    Intl.defaultLocale = locale.languageCode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.languageCode);
    await UserSettingsSync.instance.push({'locale': locale.languageCode});
  }

  Future<void> toggleLocale() async {
    await setLocale(isArabic ? const Locale('en') : const Locale('ar'));
  }
}
