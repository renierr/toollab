import 'dart:ui';

import 'package:intl/date_symbol_data_local.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/settings_service.dart';

/// The app's localizations without a widget tree, e.g. for a headless
/// background run, which has neither localizations nor intl date data.
Future<AppLocalizations> headlessLocalizations() async {
  Locale? locale;
  try {
    locale = (await SettingsService.init()).getLocale();
  } catch (_) {}
  locale ??= PlatformDispatcher.instance.locale;
  AppLocalizations l10n;
  try {
    l10n = lookupAppLocalizations(Locale(locale.languageCode));
  } catch (_) {
    l10n = lookupAppLocalizations(const Locale('en'));
  }
  try {
    await initializeDateFormatting(l10n.localeName);
  } catch (e) {
    errorLog('[headlessLocalizations] date data for ${l10n.localeName}: $e');
  }
  return l10n;
}
