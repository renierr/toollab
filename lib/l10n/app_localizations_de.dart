// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appearanceTitle => 'Darstellung';

  @override
  String get settingsTheme => 'Design';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Hell';

  @override
  String get settingsThemeDark => 'Dunkel';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsLanguageEnglish => 'Englisch';

  @override
  String get settingsLanguageGerman => 'Deutsch';

  @override
  String get settingsCompactView => 'Kompakte Ansicht';

  @override
  String get settingsCompactViewSubtitle =>
      'Kleinere Karten, mehr Tools pro Zeile';

  @override
  String get settingsSystemNotifications => 'Systembenachrichtigungen';

  @override
  String get settingsSystemNotificationsSubtitle =>
      'Systembenachrichtigungen aktivieren oder deaktivieren';

  @override
  String get settingsSortBy => 'Sortieren nach';

  @override
  String get settingsSortRecent => 'Zuletzt verwendet';

  @override
  String get settingsSortDefaultOrder => 'Standardreihenfolge';

  @override
  String get settingsSortName => 'Name';
}
