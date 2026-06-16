// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageGerman => 'German';

  @override
  String get settingsCompactView => 'Compact View';

  @override
  String get settingsCompactViewSubtitle => 'Smaller cards, more tools per row';

  @override
  String get settingsSystemNotifications => 'System Notifications';

  @override
  String get settingsSystemNotificationsSubtitle =>
      'Enable or disable system notifications';

  @override
  String get settingsSortBy => 'Sort by';

  @override
  String get settingsSortRecent => 'Recent';

  @override
  String get settingsSortDefaultOrder => 'Default order';

  @override
  String get settingsSortName => 'Name';
}
