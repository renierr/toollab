import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// Title of the appearance settings page
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceTitle;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageGerman.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get settingsLanguageGerman;

  /// No description provided for @settingsCompactView.
  ///
  /// In en, this message translates to:
  /// **'Compact View'**
  String get settingsCompactView;

  /// No description provided for @settingsCompactViewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Smaller cards, more tools per row'**
  String get settingsCompactViewSubtitle;

  /// No description provided for @settingsSystemNotifications.
  ///
  /// In en, this message translates to:
  /// **'System Notifications'**
  String get settingsSystemNotifications;

  /// No description provided for @settingsSystemNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enable or disable system notifications'**
  String get settingsSystemNotificationsSubtitle;

  /// No description provided for @settingsSortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get settingsSortBy;

  /// No description provided for @settingsSortRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get settingsSortRecent;

  /// No description provided for @settingsSortDefaultOrder.
  ///
  /// In en, this message translates to:
  /// **'Default order'**
  String get settingsSortDefaultOrder;

  /// No description provided for @settingsSortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get settingsSortName;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get commonShare;

  /// No description provided for @commonExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get commonExport;

  /// No description provided for @commonImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get commonImport;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get commonRename;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @commonReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get commonReset;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get commonApply;

  /// No description provided for @commonOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get commonOpen;

  /// No description provided for @commonSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get commonSettings;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonBrowseFiles.
  ///
  /// In en, this message translates to:
  /// **'Browse Files'**
  String get commonBrowseFiles;

  /// No description provided for @chipFailedToParseModule.
  ///
  /// In en, this message translates to:
  /// **'Failed to parse module: {error}'**
  String chipFailedToParseModule(Object error);

  /// No description provided for @chipFailedToOpenSharedFile.
  ///
  /// In en, this message translates to:
  /// **'Failed to open shared file: {error}'**
  String chipFailedToOpenSharedFile(Object error);

  /// No description provided for @chipHideVisualizer.
  ///
  /// In en, this message translates to:
  /// **'Hide visualizer'**
  String get chipHideVisualizer;

  /// No description provided for @chipShowVisualizer.
  ///
  /// In en, this message translates to:
  /// **'Show visualizer'**
  String get chipShowVisualizer;

  /// No description provided for @chipLoadAnother.
  ///
  /// In en, this message translates to:
  /// **'Load another'**
  String get chipLoadAnother;

  /// No description provided for @chipModuleArchived.
  ///
  /// In en, this message translates to:
  /// **'Module archived'**
  String get chipModuleArchived;

  /// No description provided for @chipAlreadyInArchive.
  ///
  /// In en, this message translates to:
  /// **'Already in archive'**
  String get chipAlreadyInArchive;

  /// No description provided for @chipArchivedModuleNotFound.
  ///
  /// In en, this message translates to:
  /// **'Archived module not found'**
  String get chipArchivedModuleNotFound;

  /// No description provided for @chipModuleDataNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Module data not available'**
  String get chipModuleDataNotAvailable;

  /// No description provided for @chipDeleteModuleTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Module'**
  String get chipDeleteModuleTitle;

  /// No description provided for @chipDeleteModuleMessage.
  ///
  /// In en, this message translates to:
  /// **'Remove this module from the archive?'**
  String get chipDeleteModuleMessage;

  /// No description provided for @chipSyncedResult.
  ///
  /// In en, this message translates to:
  /// **'Synced: {pulled} pulled, {pushed} pushed'**
  String chipSyncedResult(Object pulled, Object pushed);

  /// No description provided for @chipSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {error}'**
  String chipSyncFailed(Object error);

  /// No description provided for @chipArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive ({count})'**
  String chipArchiveTitle(Object count);

  /// No description provided for @chipSyncTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get chipSyncTooltip;

  /// No description provided for @chipNoArchivedModules.
  ///
  /// In en, this message translates to:
  /// **'No archived modules'**
  String get chipNoArchivedModules;

  /// No description provided for @chipDownloadTooltip.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get chipDownloadTooltip;

  /// No description provided for @chipUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get chipUntitled;

  /// No description provided for @chipMetricChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get chipMetricChannels;

  /// No description provided for @chipMetricPatterns.
  ///
  /// In en, this message translates to:
  /// **'Patterns'**
  String get chipMetricPatterns;

  /// No description provided for @chipMetricOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get chipMetricOrders;

  /// No description provided for @chipMetricInstruments.
  ///
  /// In en, this message translates to:
  /// **'Instruments'**
  String get chipMetricInstruments;

  /// No description provided for @chipMetricBpm.
  ///
  /// In en, this message translates to:
  /// **'BPM'**
  String get chipMetricBpm;

  /// No description provided for @chipMetricSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get chipMetricSpeed;

  /// No description provided for @chipEmptyDropTitle.
  ///
  /// In en, this message translates to:
  /// **'Drop a tracker module'**
  String get chipEmptyDropTitle;

  /// No description provided for @chipEmptyDropSubtitle.
  ///
  /// In en, this message translates to:
  /// **'MOD · XM · IT files'**
  String get chipEmptyDropSubtitle;

  /// No description provided for @chipEmptyTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Tracker module'**
  String get chipEmptyTypeLabel;

  /// No description provided for @chipNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Chiptune playback active'**
  String get chipNotificationTitle;

  /// No description provided for @chipNotificationText.
  ///
  /// In en, this message translates to:
  /// **'ToolLab keeps audio running in background'**
  String get chipNotificationText;

  /// No description provided for @chipPauseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get chipPauseTooltip;

  /// No description provided for @chipPlayTooltip.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get chipPlayTooltip;

  /// No description provided for @chipStopTooltip.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get chipStopTooltip;

  /// No description provided for @chipLoopingTooltip.
  ///
  /// In en, this message translates to:
  /// **'Looping'**
  String get chipLoopingTooltip;

  /// No description provided for @chipLoopOffTooltip.
  ///
  /// In en, this message translates to:
  /// **'Loop off'**
  String get chipLoopOffTooltip;

  /// No description provided for @coreNoToolsFoundToOpen.
  ///
  /// In en, this message translates to:
  /// **'No tools found to open \"{name}\"'**
  String coreNoToolsFoundToOpen(String name);

  /// No description provided for @coreAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get coreAboutTitle;

  /// No description provided for @coreAboutVersion.
  ///
  /// In en, this message translates to:
  /// **'v{version}'**
  String coreAboutVersion(String version);

  /// No description provided for @coreAboutDescription.
  ///
  /// In en, this message translates to:
  /// **'ToolLab is a collection of utility tools for your device. It includes sensors, calculator, device information, NFC tag reading/writing, PDF viewing, note taking, and more — all in one app.'**
  String get coreAboutDescription;

  /// No description provided for @coreAboutDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Disclaimer'**
  String get coreAboutDisclaimer;

  /// No description provided for @coreAboutDisclaimerText.
  ///
  /// In en, this message translates to:
  /// **'This app is provided \"as is\" without warranty of any kind. The developer shall not be held liable for any damages, data loss, or issues arising from the use of this software.'**
  String get coreAboutDisclaimerText;

  /// No description provided for @coreAboutThirdPartyLicenses.
  ///
  /// In en, this message translates to:
  /// **'Third-Party Licenses'**
  String get coreAboutThirdPartyLicenses;

  /// No description provided for @coreMaintenanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Maintenance Settings'**
  String get coreMaintenanceTitle;

  /// No description provided for @coreDatabaseExportedAndroid.
  ///
  /// In en, this message translates to:
  /// **'Database exported to Downloads folder successfully.'**
  String get coreDatabaseExportedAndroid;

  /// No description provided for @coreDatabaseExportedGeneral.
  ///
  /// In en, this message translates to:
  /// **'Database exported to {path} successfully.'**
  String coreDatabaseExportedGeneral(String path);

  /// No description provided for @coreDatabaseExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Database export failed: {error}'**
  String coreDatabaseExportFailed(String error);

  /// No description provided for @coreSettingsExportedAndroid.
  ///
  /// In en, this message translates to:
  /// **'Settings exported to Downloads folder successfully.'**
  String get coreSettingsExportedAndroid;

  /// No description provided for @coreSettingsExportedGeneral.
  ///
  /// In en, this message translates to:
  /// **'Settings exported to {path} successfully.'**
  String coreSettingsExportedGeneral(String path);

  /// No description provided for @coreSettingsExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Settings export failed: {error}'**
  String coreSettingsExportFailed(String error);

  /// No description provided for @coreDangerZoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get coreDangerZoneTitle;

  /// No description provided for @coreDatabaseImportButton.
  ///
  /// In en, this message translates to:
  /// **'Import Database (.db)'**
  String get coreDatabaseImportButton;

  /// No description provided for @coreDatabaseImportDescription.
  ///
  /// In en, this message translates to:
  /// **'Restore a previously exported database. This permanently overwrites all current tool data and settings. This cannot be undone.'**
  String get coreDatabaseImportDescription;

  /// No description provided for @coreDatabaseImportConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Database?'**
  String get coreDatabaseImportConfirmTitle;

  /// No description provided for @coreDatabaseImportConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will permanently overwrite all current data and settings with the contents of the selected backup, and the app will reload. This action cannot be undone.'**
  String get coreDatabaseImportConfirmMessage;

  /// No description provided for @coreDatabaseImportInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid or incompatible database file: {error}'**
  String coreDatabaseImportInvalid(String error);

  /// No description provided for @coreDatabaseImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Database imported successfully. Your data and settings have been restored.'**
  String get coreDatabaseImportSuccess;

  /// No description provided for @coreDatabaseImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Database import failed: {error}'**
  String coreDatabaseImportFailed(String error);

  /// No description provided for @coreTempFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Temp Files'**
  String get coreTempFilesTitle;

  /// No description provided for @coreTempFilesUsage.
  ///
  /// In en, this message translates to:
  /// **'{count} file(s) using {size}'**
  String coreTempFilesUsage(int count, String size);

  /// No description provided for @coreTempFilesCleanUp.
  ///
  /// In en, this message translates to:
  /// **'Clean Up Temp Files'**
  String get coreTempFilesCleanUp;

  /// No description provided for @coreTempFilesCleanedUp.
  ///
  /// In en, this message translates to:
  /// **'Temp files cleaned up'**
  String get coreTempFilesCleanedUp;

  /// No description provided for @coreShortcutsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tool Shortcuts'**
  String get coreShortcutsTitle;

  /// No description provided for @coreShortcutsDirectAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Direct Access Launcher'**
  String get coreShortcutsDirectAccessTitle;

  /// No description provided for @coreShortcutsDirectAccessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add separate home screen icons or app drawer launchers for your favorite tools. Tapping a shortcut will open the app directly inside that tool.'**
  String get coreShortcutsDirectAccessSubtitle;

  /// No description provided for @coreShortcutsAndroidRequired.
  ///
  /// In en, this message translates to:
  /// **'Android OS is required to pin native shortcuts or toggle app drawer icons. Toggles will persist locally but no native icons will be modified.'**
  String get coreShortcutsAndroidRequired;

  /// No description provided for @coreShortcutsSelectTools.
  ///
  /// In en, this message translates to:
  /// **'Select Tools to Configure'**
  String get coreShortcutsSelectTools;

  /// No description provided for @coreShortcutsPinRequested.
  ///
  /// In en, this message translates to:
  /// **'Shortcut requested for {name}! Accept system dialog.'**
  String coreShortcutsPinRequested(String name);

  /// No description provided for @coreShortcutsDrawerDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled App Drawer icon for {name}'**
  String coreShortcutsDrawerDisabled(String name);

  /// No description provided for @coreShortcutsDrawerEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled App Drawer icon for {name} (Updates in a few seconds).'**
  String coreShortcutsDrawerEnabled(String name);

  /// No description provided for @coreSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud Synchronization'**
  String get coreSyncTitle;

  /// No description provided for @coreSyncAcrossDevicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync data across devices'**
  String get coreSyncAcrossDevicesTitle;

  /// No description provided for @coreSyncAcrossDevicesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enabling cloud sync lets you back up your tools data and sync seamlessly to a centralized server.'**
  String get coreSyncAcrossDevicesSubtitle;

  /// No description provided for @coreSyncEnableTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable Synchronization'**
  String get coreSyncEnableTitle;

  /// No description provided for @coreSyncActive.
  ///
  /// In en, this message translates to:
  /// **'Syncing active'**
  String get coreSyncActive;

  /// No description provided for @coreSyncDisabled.
  ///
  /// In en, this message translates to:
  /// **'Syncing disabled'**
  String get coreSyncDisabled;

  /// No description provided for @coreSyncServerCredentials.
  ///
  /// In en, this message translates to:
  /// **'Server Credentials'**
  String get coreSyncServerCredentials;

  /// No description provided for @coreSyncServerBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'Server Base URL'**
  String get coreSyncServerBaseUrl;

  /// No description provided for @coreSyncServerUrlRequired.
  ///
  /// In en, this message translates to:
  /// **'Server URL is required when sync is enabled'**
  String get coreSyncServerUrlRequired;

  /// No description provided for @coreSyncUserId.
  ///
  /// In en, this message translates to:
  /// **'User ID (Optional)'**
  String get coreSyncUserId;

  /// No description provided for @coreSyncUserIdHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your username or user ID (optional)'**
  String get coreSyncUserIdHint;

  /// No description provided for @coreSyncStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Status'**
  String get coreSyncStatusTitle;

  /// No description provided for @coreSyncNeverSynced.
  ///
  /// In en, this message translates to:
  /// **'Never synced'**
  String get coreSyncNeverSynced;

  /// No description provided for @coreSyncLastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synced: {dateTime}'**
  String coreSyncLastSynced(String dateTime);

  /// No description provided for @coreSyncSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get coreSyncSyncing;

  /// No description provided for @coreSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get coreSyncNow;

  /// No description provided for @coreSyncCompleted.
  ///
  /// In en, this message translates to:
  /// **'Sync completed. Pulled: {pulled}, Pushed: {pushed}, Deleted: {deleted}.'**
  String coreSyncCompleted(String pulled, String pushed, String deleted);

  /// No description provided for @coreSyncFailedNoUrl.
  ///
  /// In en, this message translates to:
  /// **'Sync failed. Server URL is empty.'**
  String get coreSyncFailedNoUrl;

  /// No description provided for @coreSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {error}'**
  String coreSyncFailed(String error);

  /// No description provided for @coreSyncSaveConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Save Configuration'**
  String get coreSyncSaveConfiguration;

  /// No description provided for @coreSyncSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved successfully'**
  String get coreSyncSettingsSaved;

  /// No description provided for @coreSyncSettingsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save settings: {error}'**
  String coreSyncSettingsSaveFailed(String error);

  /// No description provided for @coreOverviewSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search tools...'**
  String get coreOverviewSearchHint;

  /// No description provided for @coreOverviewNoToolsFound.
  ///
  /// In en, this message translates to:
  /// **'No tools found'**
  String get coreOverviewNoToolsFound;

  /// No description provided for @coreSettingsDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Overview Settings'**
  String get coreSettingsDialogTitle;

  /// No description provided for @coreSettingsDialogSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Backup and sync tool data to the cloud'**
  String get coreSettingsDialogSyncSubtitle;

  /// No description provided for @coreSettingsDialogMaintenanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Download database backups and settings JSON'**
  String get coreSettingsDialogMaintenanceSubtitle;

  /// No description provided for @coreSettingsDialogShortcutsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pin shortcuts or manage app drawer icons'**
  String get coreSettingsDialogShortcutsSubtitle;

  /// No description provided for @coreSettingsDialogOpenWithSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage default tool associations for shared files'**
  String get coreSettingsDialogOpenWithSubtitle;

  /// No description provided for @coreSettingsDialogAppearanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Theme, compact view, notifications, sorting'**
  String get coreSettingsDialogAppearanceSubtitle;

  /// No description provided for @coreSettingsDialogAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Version, licenses, and app info'**
  String get coreSettingsDialogAboutSubtitle;

  /// No description provided for @coreOpenWithDefaultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Open with Defaults'**
  String get coreOpenWithDefaultsTitle;

  /// No description provided for @coreOpenWithResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset All Defaults?'**
  String get coreOpenWithResetTitle;

  /// No description provided for @coreOpenWithResetContent.
  ///
  /// In en, this message translates to:
  /// **'This will clear all \"always open with\" associations. The chooser dialog will appear next time you open a shared file.'**
  String get coreOpenWithResetContent;

  /// No description provided for @coreOpenWithNoDefaults.
  ///
  /// In en, this message translates to:
  /// **'No default associations set.'**
  String get coreOpenWithNoDefaults;

  /// No description provided for @coreOpenWithAssociationsLabel.
  ///
  /// In en, this message translates to:
  /// **'Default tool associations for shared files:'**
  String get coreOpenWithAssociationsLabel;

  /// No description provided for @coreOpenWithResetButton.
  ///
  /// In en, this message translates to:
  /// **'Reset All Defaults'**
  String get coreOpenWithResetButton;

  /// No description provided for @coreOpenWithResetting.
  ///
  /// In en, this message translates to:
  /// **'Resetting...'**
  String get coreOpenWithResetting;

  /// No description provided for @coreOpenWithCleared.
  ///
  /// In en, this message translates to:
  /// **'Default associations cleared'**
  String get coreOpenWithCleared;

  /// No description provided for @emfStartScanning.
  ///
  /// In en, this message translates to:
  /// **'START SCANNING'**
  String get emfStartScanning;

  /// No description provided for @emfStopScanning.
  ///
  /// In en, this message translates to:
  /// **'STOP SCANNING'**
  String get emfStopScanning;

  /// No description provided for @emfAudioTick.
  ///
  /// In en, this message translates to:
  /// **'AUDIO TICK'**
  String get emfAudioTick;

  /// No description provided for @emfScreenOn.
  ///
  /// In en, this message translates to:
  /// **'SCREEN ON'**
  String get emfScreenOn;

  /// No description provided for @emfCableTriggerThreshold.
  ///
  /// In en, this message translates to:
  /// **'CABLE TRIGGER THRESHOLD'**
  String get emfCableTriggerThreshold;

  /// No description provided for @emfScannerTitle.
  ///
  /// In en, this message translates to:
  /// **'EMF SCANNER'**
  String get emfScannerTitle;

  /// No description provided for @emfPro.
  ///
  /// In en, this message translates to:
  /// **'PRO'**
  String get emfPro;

  /// No description provided for @emfWallCurrentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'WALL CURRENT & CURRENT LOCATOR'**
  String get emfWallCurrentSubtitle;

  /// No description provided for @emfSimulator.
  ///
  /// In en, this message translates to:
  /// **'SIMULATOR'**
  String get emfSimulator;

  /// No description provided for @emfHardwareSensor.
  ///
  /// In en, this message translates to:
  /// **'HARDWARE SENSOR'**
  String get emfHardwareSensor;

  /// No description provided for @emfOpenVirtualSensorToolbox.
  ///
  /// In en, this message translates to:
  /// **'OPEN VIRTUAL SENSOR TOOLBOX (DEVELOPER)'**
  String get emfOpenVirtualSensorToolbox;

  /// No description provided for @emfDeveloperSimulationLab.
  ///
  /// In en, this message translates to:
  /// **'🛠️ DEVELOPER SIMULATION LAB'**
  String get emfDeveloperSimulationLab;

  /// No description provided for @emfExitSim.
  ///
  /// In en, this message translates to:
  /// **'EXIT SIM'**
  String get emfExitSim;

  /// No description provided for @emfSelectFieldScenarioPreset.
  ///
  /// In en, this message translates to:
  /// **'SELECT FIELD SCENARIO PRESET'**
  String get emfSelectFieldScenarioPreset;

  /// No description provided for @emfPresetEarthNormal.
  ///
  /// In en, this message translates to:
  /// **'Earth Normal'**
  String get emfPresetEarthNormal;

  /// No description provided for @emfPresetMainsWire.
  ///
  /// In en, this message translates to:
  /// **'Mains Wire (AC)'**
  String get emfPresetMainsWire;

  /// No description provided for @emfPresetMagnetProximity.
  ///
  /// In en, this message translates to:
  /// **'Magnet Proximity'**
  String get emfPresetMagnetProximity;

  /// No description provided for @emfPresetWalkDrift.
  ///
  /// In en, this message translates to:
  /// **'Walk Drift (Drift)'**
  String get emfPresetWalkDrift;

  /// No description provided for @emfManualVectorAdjustments.
  ///
  /// In en, this message translates to:
  /// **'MANUAL X, Y, Z VECTOR ADJUSTMENTS'**
  String get emfManualVectorAdjustments;

  /// No description provided for @emfManualActive.
  ///
  /// In en, this message translates to:
  /// **'MANUAL ACTIVE'**
  String get emfManualActive;

  /// No description provided for @emfXOffset.
  ///
  /// In en, this message translates to:
  /// **'X Offset'**
  String get emfXOffset;

  /// No description provided for @emfYOffset.
  ///
  /// In en, this message translates to:
  /// **'Y Offset'**
  String get emfYOffset;

  /// No description provided for @emfZOffset.
  ///
  /// In en, this message translates to:
  /// **'Z Offset'**
  String get emfZOffset;

  /// No description provided for @emfThreeAxisVectorReadout.
  ///
  /// In en, this message translates to:
  /// **'3-AXIS VECTOR READOUT'**
  String get emfThreeAxisVectorReadout;

  /// No description provided for @emfLiveSensors.
  ///
  /// In en, this message translates to:
  /// **'LIVE SENSORS'**
  String get emfLiveSensors;

  /// No description provided for @emfPaused.
  ///
  /// In en, this message translates to:
  /// **'PAUSED'**
  String get emfPaused;

  /// No description provided for @fastDropPastingText.
  ///
  /// In en, this message translates to:
  /// **'Pasting text from clipboard...'**
  String get fastDropPastingText;

  /// No description provided for @fastDropPastingImage.
  ///
  /// In en, this message translates to:
  /// **'Pasting image from clipboard...'**
  String get fastDropPastingImage;

  /// No description provided for @fastDropClipboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'No text or image content found in clipboard'**
  String get fastDropClipboardEmpty;

  /// No description provided for @fastDropUploadedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Uploaded successfully!'**
  String get fastDropUploadedSuccessfully;

  /// No description provided for @fastDropUploadingFiles.
  ///
  /// In en, this message translates to:
  /// **'Uploading {count} files...'**
  String fastDropUploadingFiles(int count);

  /// No description provided for @fastDropUploadingFileProgress.
  ///
  /// In en, this message translates to:
  /// **'Uploading {current} of {total}: {name}...'**
  String fastDropUploadingFileProgress(int current, int total, String name);

  /// No description provided for @fastDropSharedFilesUploaded.
  ///
  /// In en, this message translates to:
  /// **'Shared files uploaded successfully!'**
  String get fastDropSharedFilesUploaded;

  /// No description provided for @fastDropDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Drop'**
  String get fastDropDeleteTitle;

  /// No description provided for @fastDropDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{filename}\"?'**
  String fastDropDeleteMessage(String filename);

  /// No description provided for @fastDropDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Deleted successfully'**
  String get fastDropDeletedSuccessfully;

  /// No description provided for @fastDropDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete drop: {error}'**
  String fastDropDeleteFailed(String error);

  /// No description provided for @fastDropDownloadingFile.
  ///
  /// In en, this message translates to:
  /// **'Downloading {filename}...'**
  String fastDropDownloadingFile(String filename);

  /// No description provided for @fastDropDownloadingFileToOpen.
  ///
  /// In en, this message translates to:
  /// **'Downloading {filename} to open...'**
  String fastDropDownloadingFileToOpen(String filename);

  /// No description provided for @fastDropDescriptionUpdated.
  ///
  /// In en, this message translates to:
  /// **'Description updated'**
  String get fastDropDescriptionUpdated;

  /// No description provided for @fastDropRetentionUpdated.
  ///
  /// In en, this message translates to:
  /// **'Retention updated'**
  String get fastDropRetentionUpdated;

  /// No description provided for @fastDropTitle.
  ///
  /// In en, this message translates to:
  /// **'Fast Drop'**
  String get fastDropTitle;

  /// No description provided for @fastDropStatusOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get fastDropStatusOnline;

  /// No description provided for @fastDropStatusOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get fastDropStatusOffline;

  /// No description provided for @fastDropStatusSyncDisabled.
  ///
  /// In en, this message translates to:
  /// **'Sync Disabled'**
  String get fastDropStatusSyncDisabled;

  /// No description provided for @fastDropStatusNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not Configured'**
  String get fastDropStatusNotConfigured;

  /// No description provided for @fastDropRefreshList.
  ///
  /// In en, this message translates to:
  /// **'Refresh List'**
  String get fastDropRefreshList;

  /// No description provided for @fastDropProgressUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading'**
  String get fastDropProgressUploading;

  /// No description provided for @fastDropProgressDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get fastDropProgressDownloading;

  /// No description provided for @fastDropSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'DROPPED FILES'**
  String get fastDropSectionTitle;

  /// No description provided for @fastDropEditRetentionTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Retention Period'**
  String get fastDropEditRetentionTitle;

  /// No description provided for @fastDropEditDescriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Description'**
  String get fastDropEditDescriptionTitle;

  /// No description provided for @fastDropDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Add a description...'**
  String get fastDropDescriptionHint;

  /// No description provided for @fastDropExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires: {date}'**
  String fastDropExpires(String date);

  /// No description provided for @fastDropIndefiniteRetention.
  ///
  /// In en, this message translates to:
  /// **'Indefinite retention'**
  String get fastDropIndefiniteRetention;

  /// No description provided for @fastDropClipboardBadge.
  ///
  /// In en, this message translates to:
  /// **'CLIPBOARD'**
  String get fastDropClipboardBadge;

  /// No description provided for @fastDropUploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded: {date}'**
  String fastDropUploaded(String date);

  /// No description provided for @fastDropAddDescriptionPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Add description...'**
  String get fastDropAddDescriptionPlaceholder;

  /// No description provided for @fastDropPreviewTooltip.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get fastDropPreviewTooltip;

  /// No description provided for @fastDropOpenShare.
  ///
  /// In en, this message translates to:
  /// **'Open / Share'**
  String get fastDropOpenShare;

  /// No description provided for @fastDropDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get fastDropDownload;

  /// No description provided for @fastDropConnectionStatus.
  ///
  /// In en, this message translates to:
  /// **'Connection Status'**
  String get fastDropConnectionStatus;

  /// No description provided for @fastDropRetryConnection.
  ///
  /// In en, this message translates to:
  /// **'Retry Connection'**
  String get fastDropRetryConnection;

  /// No description provided for @fastDropNoDropsTitle.
  ///
  /// In en, this message translates to:
  /// **'No Drops Yet'**
  String get fastDropNoDropsTitle;

  /// No description provided for @fastDropNoDropsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Drag and drop files or paste content from clipboard to save temporarily.'**
  String get fastDropNoDropsSubtitle;

  /// No description provided for @fastDropDownloadingForPreview.
  ///
  /// In en, this message translates to:
  /// **'Downloading file for preview...'**
  String get fastDropDownloadingForPreview;

  /// No description provided for @fastDropPreviewFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load preview:\n{error}'**
  String fastDropPreviewFailed(String error);

  /// No description provided for @fastDropReadFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Error reading file: {error}'**
  String fastDropReadFileFailed(String error);

  /// No description provided for @fastDropPreviewNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Preview not available for this file type.'**
  String get fastDropPreviewNotAvailable;

  /// No description provided for @fastDropOpenWithApp.
  ///
  /// In en, this message translates to:
  /// **'Open with Tool / App'**
  String get fastDropOpenWithApp;

  /// No description provided for @fastDropNotConfiguredTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Server Not Configured'**
  String get fastDropNotConfiguredTitle;

  /// No description provided for @fastDropNotConfiguredBody.
  ///
  /// In en, this message translates to:
  /// **'Fast Drop requires a connection to the backend server. Please configure your Sync Server URL in settings to start dropping files.'**
  String get fastDropNotConfiguredBody;

  /// No description provided for @fastDropConfigureServer.
  ///
  /// In en, this message translates to:
  /// **'Configure Server'**
  String get fastDropConfigureServer;

  /// No description provided for @fastDropSyncDisabledTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud Sync is Disabled'**
  String get fastDropSyncDisabledTitle;

  /// No description provided for @fastDropSyncDisabledBody.
  ///
  /// In en, this message translates to:
  /// **'Fast Drop requires cloud sync to be enabled in settings.'**
  String get fastDropSyncDisabledBody;

  /// No description provided for @fastDropEnableButton.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get fastDropEnableButton;

  /// No description provided for @fastDropConfigureServerBody.
  ///
  /// In en, this message translates to:
  /// **'Configure server URL in Cloud settings first.'**
  String get fastDropConfigureServerBody;

  /// No description provided for @fastDropServerUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Sync Server Unreachable'**
  String get fastDropServerUnreachable;

  /// No description provided for @fastDropAllFiles.
  ///
  /// In en, this message translates to:
  /// **'All Files'**
  String get fastDropAllFiles;

  /// No description provided for @fastDropSelectFilesAndroid.
  ///
  /// In en, this message translates to:
  /// **'Select files to upload'**
  String get fastDropSelectFilesAndroid;

  /// No description provided for @fastDropDropFilesHere.
  ///
  /// In en, this message translates to:
  /// **'Drop files here'**
  String get fastDropDropFilesHere;

  /// No description provided for @fastDropOrClickToBrowse.
  ///
  /// In en, this message translates to:
  /// **'or click to browse'**
  String get fastDropOrClickToBrowse;

  /// No description provided for @fastDropPasteClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste Clipboard'**
  String get fastDropPasteClipboard;

  /// No description provided for @focusAutoStopTimer.
  ///
  /// In en, this message translates to:
  /// **'Auto-stop Timer'**
  String get focusAutoStopTimer;

  /// No description provided for @focusStartPlaybackToEnableTimer.
  ///
  /// In en, this message translates to:
  /// **'Start playback to enable timer'**
  String get focusStartPlaybackToEnableTimer;

  /// No description provided for @focusCustomMinutes.
  ///
  /// In en, this message translates to:
  /// **'Custom: {minutes} min'**
  String focusCustomMinutes(int minutes);

  /// No description provided for @focusSetTimer.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get focusSetTimer;

  /// No description provided for @focusCancelTimer.
  ///
  /// In en, this message translates to:
  /// **'Cancel Timer'**
  String get focusCancelTimer;

  /// No description provided for @focusBreathingGuide.
  ///
  /// In en, this message translates to:
  /// **'Breathing Guide'**
  String get focusBreathingGuide;

  /// No description provided for @focusStartBreathing.
  ///
  /// In en, this message translates to:
  /// **'Start Breathing'**
  String get focusStartBreathing;

  /// No description provided for @focusStopBreathing.
  ///
  /// In en, this message translates to:
  /// **'Stop Breathing'**
  String get focusStopBreathing;

  /// No description provided for @focusSoundLibrary.
  ///
  /// In en, this message translates to:
  /// **'Sound Library'**
  String get focusSoundLibrary;

  /// No description provided for @focusPlayback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get focusPlayback;

  /// No description provided for @focusStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get focusStart;

  /// No description provided for @focusStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get focusStop;

  /// No description provided for @focusNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Focus noise active'**
  String get focusNotificationTitle;

  /// No description provided for @focusNotificationText.
  ///
  /// In en, this message translates to:
  /// **'ToolLab keeps ambient audio running'**
  String get focusNotificationText;

  /// No description provided for @focusNoTimerSet.
  ///
  /// In en, this message translates to:
  /// **'No timer set'**
  String get focusNoTimerSet;

  /// No description provided for @focusStopping.
  ///
  /// In en, this message translates to:
  /// **'Stopping...'**
  String get focusStopping;

  /// No description provided for @focusWillStopIn.
  ///
  /// In en, this message translates to:
  /// **'Will stop in {time}'**
  String focusWillStopIn(String time);

  /// No description provided for @focusPlayingSound.
  ///
  /// In en, this message translates to:
  /// **'Playing {name}'**
  String focusPlayingSound(String name);

  /// No description provided for @focusSelectedSound.
  ///
  /// In en, this message translates to:
  /// **'Selected {name}'**
  String focusSelectedSound(String name);

  /// No description provided for @img2pdfNoImageInClipboard.
  ///
  /// In en, this message translates to:
  /// **'No image found in clipboard'**
  String get img2pdfNoImageInClipboard;

  /// No description provided for @img2pdfFailedReadClipboard.
  ///
  /// In en, this message translates to:
  /// **'Failed to read clipboard: {error}'**
  String img2pdfFailedReadClipboard(String error);

  /// No description provided for @img2pdfSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'PDF Settings'**
  String get img2pdfSettingsTooltip;

  /// No description provided for @img2pdfImagesLabel.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get img2pdfImagesLabel;

  /// No description provided for @img2pdfDropTitle.
  ///
  /// In en, this message translates to:
  /// **'Drop images here'**
  String get img2pdfDropTitle;

  /// No description provided for @img2pdfDropSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Supports PNG, JPEG, WebP, BMP, GIF'**
  String get img2pdfDropSubtitle;

  /// No description provided for @img2pdfBrowseFiles.
  ///
  /// In en, this message translates to:
  /// **'Browse Files'**
  String get img2pdfBrowseFiles;

  /// No description provided for @img2pdfPasteFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste from Clipboard'**
  String get img2pdfPasteFromClipboard;

  /// No description provided for @img2pdfPickFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Pick from Gallery'**
  String get img2pdfPickFromGallery;

  /// No description provided for @img2pdfNoImagesYet.
  ///
  /// In en, this message translates to:
  /// **'No images added yet'**
  String get img2pdfNoImagesYet;

  /// No description provided for @img2pdfNoImagesHint.
  ///
  /// In en, this message translates to:
  /// **'Drop images here or use \"Add More\" to begin'**
  String get img2pdfNoImagesHint;

  /// No description provided for @img2pdfPageNumber.
  ///
  /// In en, this message translates to:
  /// **'Page {page}'**
  String img2pdfPageNumber(int page);

  /// No description provided for @img2pdfPdfSettings.
  ///
  /// In en, this message translates to:
  /// **'PDF Settings'**
  String get img2pdfPdfSettings;

  /// No description provided for @img2pdfPageSize.
  ///
  /// In en, this message translates to:
  /// **'Page Size'**
  String get img2pdfPageSize;

  /// No description provided for @img2pdfFitToImage.
  ///
  /// In en, this message translates to:
  /// **'Fit to Image'**
  String get img2pdfFitToImage;

  /// No description provided for @img2pdfOrientation.
  ///
  /// In en, this message translates to:
  /// **'Orientation'**
  String get img2pdfOrientation;

  /// No description provided for @img2pdfLandscape.
  ///
  /// In en, this message translates to:
  /// **'Landscape'**
  String get img2pdfLandscape;

  /// No description provided for @img2pdfJpegQuality.
  ///
  /// In en, this message translates to:
  /// **'JPEG Quality'**
  String get img2pdfJpegQuality;

  /// No description provided for @img2pdfImageCountSingle.
  ///
  /// In en, this message translates to:
  /// **'1 image'**
  String get img2pdfImageCountSingle;

  /// No description provided for @img2pdfImageCountPlural.
  ///
  /// In en, this message translates to:
  /// **'{count} images'**
  String img2pdfImageCountPlural(int count);

  /// No description provided for @img2pdfAddMore.
  ///
  /// In en, this message translates to:
  /// **'Add More'**
  String get img2pdfAddMore;

  /// No description provided for @img2pdfCreatePdf.
  ///
  /// In en, this message translates to:
  /// **'Create PDF'**
  String get img2pdfCreatePdf;

  /// No description provided for @img2pdfPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get img2pdfPreparing;

  /// No description provided for @img2pdfProcessingImage.
  ///
  /// In en, this message translates to:
  /// **'Processing image {done} of {total}…'**
  String img2pdfProcessingImage(int done, int total);

  /// No description provided for @img2pdfSavingPdf.
  ///
  /// In en, this message translates to:
  /// **'Saving PDF…'**
  String get img2pdfSavingPdf;

  /// No description provided for @img2pdfSavedTo.
  ///
  /// In en, this message translates to:
  /// **'PDF saved to {path}'**
  String img2pdfSavedTo(String path);

  /// No description provided for @img2pdfSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save PDF: {error}'**
  String img2pdfSaveFailed(String error);

  /// No description provided for @img2pdfCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create PDF: {error}'**
  String img2pdfCreateFailed(String error);

  /// No description provided for @imgViewDiscardChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get imgViewDiscardChangesTitle;

  /// No description provided for @imgViewDiscardChangesMessage.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved edits to this image. Leaving will discard them.'**
  String get imgViewDiscardChangesMessage;

  /// No description provided for @imgViewDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get imgViewDiscard;

  /// No description provided for @imgViewKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get imgViewKeepEditing;

  /// No description provided for @imgViewImageCopied.
  ///
  /// In en, this message translates to:
  /// **'Image copied to clipboard'**
  String get imgViewImageCopied;

  /// No description provided for @imgViewHideSettings.
  ///
  /// In en, this message translates to:
  /// **'Hide settings'**
  String get imgViewHideSettings;

  /// No description provided for @imgViewShowSettings.
  ///
  /// In en, this message translates to:
  /// **'Show settings'**
  String get imgViewShowSettings;

  /// No description provided for @imgViewEditImageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit image'**
  String get imgViewEditImageTooltip;

  /// No description provided for @imgViewCloseImage.
  ///
  /// In en, this message translates to:
  /// **'Close image'**
  String get imgViewCloseImage;

  /// No description provided for @imgViewEditImageDrawerTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Image'**
  String get imgViewEditImageDrawerTitle;

  /// No description provided for @imgViewUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get imgViewUndo;

  /// No description provided for @imgViewRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get imgViewRedo;

  /// No description provided for @imgViewCopyToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy to clipboard'**
  String get imgViewCopyToClipboard;

  /// No description provided for @imgViewDropZoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Drop an image here'**
  String get imgViewDropZoneTitle;

  /// No description provided for @imgViewDropZoneSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Supports PNG, JPEG, WebP, BMP, GIF'**
  String get imgViewDropZoneSubtitle;

  /// No description provided for @imgViewTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get imgViewTypeLabel;

  /// No description provided for @imgViewBrowseFiles.
  ///
  /// In en, this message translates to:
  /// **'Browse Files'**
  String get imgViewBrowseFiles;

  /// No description provided for @imgViewPasteFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste from Clipboard'**
  String get imgViewPasteFromClipboard;

  /// No description provided for @imgViewOriginalFileDetails.
  ///
  /// In en, this message translates to:
  /// **'Original File Details'**
  String get imgViewOriginalFileDetails;

  /// No description provided for @imgViewMoreInformation.
  ///
  /// In en, this message translates to:
  /// **'More Information'**
  String get imgViewMoreInformation;

  /// No description provided for @imgViewTransform.
  ///
  /// In en, this message translates to:
  /// **'Transform'**
  String get imgViewTransform;

  /// No description provided for @imgViewCroppingActive.
  ///
  /// In en, this message translates to:
  /// **'Cropping Active. Adjust controls on the image display.'**
  String get imgViewCroppingActive;

  /// No description provided for @imgViewRedactingActive.
  ///
  /// In en, this message translates to:
  /// **'Redacting Active. Adjust controls on the image display.'**
  String get imgViewRedactingActive;

  /// No description provided for @imgViewRotateLeft.
  ///
  /// In en, this message translates to:
  /// **'Rotate 90° Left'**
  String get imgViewRotateLeft;

  /// No description provided for @imgViewRotateRight.
  ///
  /// In en, this message translates to:
  /// **'Rotate 90° Right'**
  String get imgViewRotateRight;

  /// No description provided for @imgViewFlipHorizontal.
  ///
  /// In en, this message translates to:
  /// **'Flip Horizontally'**
  String get imgViewFlipHorizontal;

  /// No description provided for @imgViewFlipVertical.
  ///
  /// In en, this message translates to:
  /// **'Flip Vertically'**
  String get imgViewFlipVertical;

  /// No description provided for @imgViewCrop.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get imgViewCrop;

  /// No description provided for @imgViewRedact.
  ///
  /// In en, this message translates to:
  /// **'Redact'**
  String get imgViewRedact;

  /// No description provided for @imgViewResizeImage.
  ///
  /// In en, this message translates to:
  /// **'Resize Image'**
  String get imgViewResizeImage;

  /// No description provided for @imgViewWidthLabel.
  ///
  /// In en, this message translates to:
  /// **'Width (px)'**
  String get imgViewWidthLabel;

  /// No description provided for @imgViewAspectRatioLocked.
  ///
  /// In en, this message translates to:
  /// **'Aspect ratio locked'**
  String get imgViewAspectRatioLocked;

  /// No description provided for @imgViewAspectRatioUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Aspect ratio unlocked'**
  String get imgViewAspectRatioUnlocked;

  /// No description provided for @imgViewHeightLabel.
  ///
  /// In en, this message translates to:
  /// **'Height (px)'**
  String get imgViewHeightLabel;

  /// No description provided for @imgViewPreviewResize.
  ///
  /// In en, this message translates to:
  /// **'Preview Resize'**
  String get imgViewPreviewResize;

  /// No description provided for @imgViewOutputFormat.
  ///
  /// In en, this message translates to:
  /// **'Output Format'**
  String get imgViewOutputFormat;

  /// No description provided for @imgViewPreserveExif.
  ///
  /// In en, this message translates to:
  /// **'Preserve EXIF Metadata'**
  String get imgViewPreserveExif;

  /// No description provided for @imgViewPreserveExifSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep GPS, camera tags, and date (JPEG only)'**
  String get imgViewPreserveExifSubtitle;

  /// No description provided for @imgViewCompressionQuality.
  ///
  /// In en, this message translates to:
  /// **'Compression Quality: {quality}%'**
  String imgViewCompressionQuality(int quality);

  /// No description provided for @imgViewSaveImage.
  ///
  /// In en, this message translates to:
  /// **'Save Image'**
  String get imgViewSaveImage;

  /// No description provided for @imgViewShareImage.
  ///
  /// In en, this message translates to:
  /// **'Share Image'**
  String get imgViewShareImage;

  /// No description provided for @imgViewDimensions.
  ///
  /// In en, this message translates to:
  /// **'Dimensions'**
  String get imgViewDimensions;

  /// No description provided for @imgViewFileSize.
  ///
  /// In en, this message translates to:
  /// **'File Size'**
  String get imgViewFileSize;

  /// No description provided for @imgViewRedactStyleHeader.
  ///
  /// In en, this message translates to:
  /// **'Redaction Style & Shape'**
  String get imgViewRedactStyleHeader;

  /// No description provided for @imgViewShapeLabel.
  ///
  /// In en, this message translates to:
  /// **'Shape: '**
  String get imgViewShapeLabel;

  /// No description provided for @imgViewShapeRectangle.
  ///
  /// In en, this message translates to:
  /// **'Rectangle'**
  String get imgViewShapeRectangle;

  /// No description provided for @imgViewShapeFreehand.
  ///
  /// In en, this message translates to:
  /// **'Freehand'**
  String get imgViewShapeFreehand;

  /// No description provided for @imgViewRedraw.
  ///
  /// In en, this message translates to:
  /// **'Redraw'**
  String get imgViewRedraw;

  /// No description provided for @imgViewStyleSolid.
  ///
  /// In en, this message translates to:
  /// **'Solid'**
  String get imgViewStyleSolid;

  /// No description provided for @imgViewStylePixelate.
  ///
  /// In en, this message translates to:
  /// **'Pixelate'**
  String get imgViewStylePixelate;

  /// No description provided for @imgViewStyleBlur.
  ///
  /// In en, this message translates to:
  /// **'Blur'**
  String get imgViewStyleBlur;

  /// No description provided for @imgViewColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Color: '**
  String get imgViewColorLabel;

  /// No description provided for @imgViewBlockSize.
  ///
  /// In en, this message translates to:
  /// **'Block Size: {size} px'**
  String imgViewBlockSize(int size);

  /// No description provided for @imgViewBlurRadius.
  ///
  /// In en, this message translates to:
  /// **'Blur Radius: {radius} px'**
  String imgViewBlurRadius(int radius);

  /// No description provided for @imgViewRedactHint.
  ///
  /// In en, this message translates to:
  /// **'Draw a path over the area to redact'**
  String get imgViewRedactHint;

  /// No description provided for @imgViewApplyRedaction.
  ///
  /// In en, this message translates to:
  /// **'Apply Redaction'**
  String get imgViewApplyRedaction;

  /// No description provided for @imgViewCropPresetsHeader.
  ///
  /// In en, this message translates to:
  /// **'Crop Presets'**
  String get imgViewCropPresetsHeader;

  /// No description provided for @imgViewCropPresetFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get imgViewCropPresetFree;

  /// No description provided for @imgViewCropPreset1x1.
  ///
  /// In en, this message translates to:
  /// **'1:1 Square'**
  String get imgViewCropPreset1x1;

  /// No description provided for @imgViewCropPreset16x9.
  ///
  /// In en, this message translates to:
  /// **'16:9 Widescreen'**
  String get imgViewCropPreset16x9;

  /// No description provided for @imgViewCropPreset4x3.
  ///
  /// In en, this message translates to:
  /// **'4:3 Standard'**
  String get imgViewCropPreset4x3;

  /// No description provided for @imgViewCropPreset3x2.
  ///
  /// In en, this message translates to:
  /// **'3:2 Photo'**
  String get imgViewCropPreset3x2;

  /// No description provided for @imgViewApplyCrop.
  ///
  /// In en, this message translates to:
  /// **'Apply Crop'**
  String get imgViewApplyCrop;

  /// No description provided for @imgViewZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get imgViewZoomOut;

  /// No description provided for @imgViewZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get imgViewZoomIn;

  /// No description provided for @imgViewPreviousImage.
  ///
  /// In en, this message translates to:
  /// **'Previous image'**
  String get imgViewPreviousImage;

  /// No description provided for @imgViewNextImage.
  ///
  /// In en, this message translates to:
  /// **'Next image'**
  String get imgViewNextImage;

  /// No description provided for @imgViewGpsTitle.
  ///
  /// In en, this message translates to:
  /// **'GPS Location Information'**
  String get imgViewGpsTitle;

  /// No description provided for @imgViewGpsLatitude.
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get imgViewGpsLatitude;

  /// No description provided for @imgViewGpsLongitude.
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get imgViewGpsLongitude;

  /// No description provided for @imgViewGpsCoordinatesDms.
  ///
  /// In en, this message translates to:
  /// **'Coordinates (DMS)'**
  String get imgViewGpsCoordinatesDms;

  /// No description provided for @imgViewOpenInMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in Maps'**
  String get imgViewOpenInMaps;

  /// No description provided for @imgViewBrowseGallery.
  ///
  /// In en, this message translates to:
  /// **'Browse Gallery'**
  String get imgViewBrowseGallery;

  /// No description provided for @imgViewTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get imgViewTakePhoto;

  /// No description provided for @imgViewExifThumbnailTitle.
  ///
  /// In en, this message translates to:
  /// **'EXIF Embedded Thumbnail'**
  String get imgViewExifThumbnailTitle;

  /// No description provided for @imgViewMetadataDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Metadata & EXIF Info'**
  String get imgViewMetadataDialogTitle;

  /// No description provided for @imgViewNoExifData.
  ///
  /// In en, this message translates to:
  /// **'No EXIF metadata found in this image.'**
  String get imgViewNoExifData;

  /// No description provided for @imgViewSegmentSubject.
  ///
  /// In en, this message translates to:
  /// **'Segment Subject'**
  String get imgViewSegmentSubject;

  /// No description provided for @imgViewSegmentSubjectTooltip.
  ///
  /// In en, this message translates to:
  /// **'Isolate the subject from the background using ML'**
  String get imgViewSegmentSubjectTooltip;

  /// No description provided for @imgViewSegmentSubjectUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Subject segmentation is only supported on Android'**
  String get imgViewSegmentSubjectUnsupported;

  /// No description provided for @imgViewSegmentSubjectFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to segment subject: {error}'**
  String imgViewSegmentSubjectFailed(String error);

  /// No description provided for @imgViewSegmentSubjectDownloading.
  ///
  /// In en, this message translates to:
  /// **'Google Play Services is downloading the required machine learning model. Please wait a minute and try again.'**
  String get imgViewSegmentSubjectDownloading;

  /// No description provided for @imgViewExtractText.
  ///
  /// In en, this message translates to:
  /// **'Extract Text'**
  String get imgViewExtractText;

  /// No description provided for @imgViewExtractTextTooltip.
  ///
  /// In en, this message translates to:
  /// **'Extract text from the image using ML'**
  String get imgViewExtractTextTooltip;

  /// No description provided for @imgViewExtractTextTitle.
  ///
  /// In en, this message translates to:
  /// **'Extracted Text'**
  String get imgViewExtractTextTitle;

  /// No description provided for @imgViewExtractTextNoText.
  ///
  /// In en, this message translates to:
  /// **'No text detected in the image.'**
  String get imgViewExtractTextNoText;

  /// No description provided for @imgViewExtractTextFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to extract text: {error}'**
  String imgViewExtractTextFailed(String error);

  /// No description provided for @imgViewTextCopied.
  ///
  /// In en, this message translates to:
  /// **'Text copied to clipboard'**
  String get imgViewTextCopied;

  /// No description provided for @levelSensorsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sensors not available on this device.'**
  String get levelSensorsUnavailable;

  /// No description provided for @levelCalibratedToZero.
  ///
  /// In en, this message translates to:
  /// **'Surface calibrated to zero.'**
  String get levelCalibratedToZero;

  /// No description provided for @levelCalibrationReset.
  ///
  /// In en, this message translates to:
  /// **'Calibration reset.'**
  String get levelCalibrationReset;

  /// No description provided for @levelMode2Axis.
  ///
  /// In en, this message translates to:
  /// **'2-Axis'**
  String get levelMode2Axis;

  /// No description provided for @levelModeBeam.
  ///
  /// In en, this message translates to:
  /// **'Beam'**
  String get levelModeBeam;

  /// No description provided for @levelRuler.
  ///
  /// In en, this message translates to:
  /// **'Ruler'**
  String get levelRuler;

  /// No description provided for @levelCalibrateRuler.
  ///
  /// In en, this message translates to:
  /// **'Calibrate Ruler'**
  String get levelCalibrateRuler;

  /// No description provided for @levelRotationLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get levelRotationLocked;

  /// No description provided for @levelLockRotation.
  ///
  /// In en, this message translates to:
  /// **'Lock Rot.'**
  String get levelLockRotation;

  /// No description provided for @levelWakeLock.
  ///
  /// In en, this message translates to:
  /// **'Wake Lock'**
  String get levelWakeLock;

  /// No description provided for @levelTolerance.
  ///
  /// In en, this message translates to:
  /// **'TOLERANCE'**
  String get levelTolerance;

  /// No description provided for @levelSetZero.
  ///
  /// In en, this message translates to:
  /// **'Set Zero'**
  String get levelSetZero;

  /// No description provided for @levelRulerCalibration.
  ///
  /// In en, this message translates to:
  /// **'Ruler Calibration'**
  String get levelRulerCalibration;

  /// No description provided for @levelRulerCalibrationHint.
  ///
  /// In en, this message translates to:
  /// **'Hold a physical ruler against the screen edge. Adjust the scale until the markings match exactly.'**
  String get levelRulerCalibrationHint;

  /// No description provided for @levelPitch.
  ///
  /// In en, this message translates to:
  /// **'Pitch'**
  String get levelPitch;

  /// No description provided for @levelRoll.
  ///
  /// In en, this message translates to:
  /// **'Roll'**
  String get levelRoll;

  /// No description provided for @miscCalculatorCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get miscCalculatorCopied;

  /// No description provided for @miscCalculatorSciLabel.
  ///
  /// In en, this message translates to:
  /// **'SCI'**
  String get miscCalculatorSciLabel;

  /// No description provided for @miscCalculatorHistLabel.
  ///
  /// In en, this message translates to:
  /// **'HIST'**
  String get miscCalculatorHistLabel;

  /// No description provided for @miscCalculatorCopyResultTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy result'**
  String get miscCalculatorCopyResultTooltip;

  /// No description provided for @miscCalculatorBackspaceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Backspace'**
  String get miscCalculatorBackspaceTooltip;

  /// No description provided for @miscCalculatorHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get miscCalculatorHistoryTitle;

  /// No description provided for @miscCalculatorNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No calculations yet'**
  String get miscCalculatorNoHistory;

  /// No description provided for @miscBatteryPowerStatus.
  ///
  /// In en, this message translates to:
  /// **'Power Status'**
  String get miscBatteryPowerStatus;

  /// No description provided for @miscBatteryFullyCharged.
  ///
  /// In en, this message translates to:
  /// **'Fully Charged'**
  String get miscBatteryFullyCharged;

  /// No description provided for @miscBatteryCharging.
  ///
  /// In en, this message translates to:
  /// **'Charging'**
  String get miscBatteryCharging;

  /// No description provided for @miscBatteryDischarging.
  ///
  /// In en, this message translates to:
  /// **'Discharging'**
  String get miscBatteryDischarging;

  /// No description provided for @miscBatterySaverActive.
  ///
  /// In en, this message translates to:
  /// **'Saver Active'**
  String get miscBatterySaverActive;

  /// No description provided for @miscDeviceInfoSystemOs.
  ///
  /// In en, this message translates to:
  /// **'System & OS'**
  String get miscDeviceInfoSystemOs;

  /// No description provided for @miscDeviceInfoHardwareSpecs.
  ///
  /// In en, this message translates to:
  /// **'Hardware Specs'**
  String get miscDeviceInfoHardwareSpecs;

  /// No description provided for @miscDeviceInfoDisplayDetails.
  ///
  /// In en, this message translates to:
  /// **'Display Details'**
  String get miscDeviceInfoDisplayDetails;

  /// No description provided for @miscDeviceInfoGeneralSettings.
  ///
  /// In en, this message translates to:
  /// **'General Settings'**
  String get miscDeviceInfoGeneralSettings;

  /// No description provided for @miscMarkdownFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load file: {error}'**
  String miscMarkdownFailedToLoad(String error);

  /// No description provided for @miscMarkdownFailedToRead.
  ///
  /// In en, this message translates to:
  /// **'Failed to read file: {error}'**
  String miscMarkdownFailedToRead(String error);

  /// No description provided for @miscMarkdownOpenTitle.
  ///
  /// In en, this message translates to:
  /// **'Open a Markdown File'**
  String get miscMarkdownOpenTitle;

  /// No description provided for @miscMarkdownDropSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Drag & drop a .md or .txt file here'**
  String get miscMarkdownDropSubtitle;

  /// No description provided for @miscMarkdownTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Markdown'**
  String get miscMarkdownTypeLabel;

  /// No description provided for @nfcEditorFormTitle.
  ///
  /// In en, this message translates to:
  /// **'NDEF Record Creator'**
  String get nfcEditorFormTitle;

  /// No description provided for @nfcTemplatePreset.
  ///
  /// In en, this message translates to:
  /// **'Template Preset'**
  String get nfcTemplatePreset;

  /// No description provided for @nfcTemplateCustomRecord.
  ///
  /// In en, this message translates to:
  /// **'Custom Record'**
  String get nfcTemplateCustomRecord;

  /// No description provided for @nfcTemplateUrlHomepage.
  ///
  /// In en, this message translates to:
  /// **'URL: Homepage Link'**
  String get nfcTemplateUrlHomepage;

  /// No description provided for @nfcTemplateTextNote.
  ///
  /// In en, this message translates to:
  /// **'Text: Plain Note'**
  String get nfcTemplateTextNote;

  /// No description provided for @nfcTemplateMimeJson.
  ///
  /// In en, this message translates to:
  /// **'MIME: JSON Config'**
  String get nfcTemplateMimeJson;

  /// No description provided for @nfcTemplateMimeVcard.
  ///
  /// In en, this message translates to:
  /// **'MIME: vCard Contact'**
  String get nfcTemplateMimeVcard;

  /// No description provided for @nfcRecordType.
  ///
  /// In en, this message translates to:
  /// **'Record Type (NDEF Format)'**
  String get nfcRecordType;

  /// No description provided for @nfcRecordTypeUri.
  ///
  /// In en, this message translates to:
  /// **'Well-known URI (URL)'**
  String get nfcRecordTypeUri;

  /// No description provided for @nfcRecordTypeText.
  ///
  /// In en, this message translates to:
  /// **'Well-known Text'**
  String get nfcRecordTypeText;

  /// No description provided for @nfcRecordTypeMime.
  ///
  /// In en, this message translates to:
  /// **'MIME Media Payload'**
  String get nfcRecordTypeMime;

  /// No description provided for @nfcUriTargetLink.
  ///
  /// In en, this message translates to:
  /// **'URI Target Link'**
  String get nfcUriTargetLink;

  /// No description provided for @nfcUriHelperText.
  ///
  /// In en, this message translates to:
  /// **'Auto-detects common prefixes (https://, http://, mailto:, file://) to save tag space.'**
  String get nfcUriHelperText;

  /// No description provided for @nfcUriRequired.
  ///
  /// In en, this message translates to:
  /// **'URI target link is required'**
  String get nfcUriRequired;

  /// No description provided for @nfcTextContent.
  ///
  /// In en, this message translates to:
  /// **'Text Content'**
  String get nfcTextContent;

  /// No description provided for @nfcTextContentHint.
  ///
  /// In en, this message translates to:
  /// **'Enter note content...'**
  String get nfcTextContentHint;

  /// No description provided for @nfcTextContentRequired.
  ///
  /// In en, this message translates to:
  /// **'Text content is required'**
  String get nfcTextContentRequired;

  /// No description provided for @nfcLanguageCode.
  ///
  /// In en, this message translates to:
  /// **'Language Code'**
  String get nfcLanguageCode;

  /// No description provided for @nfcLanguageCodeHelper.
  ///
  /// In en, this message translates to:
  /// **'Standard BCP 47 language identifier (e.g. en, fr, de, es).'**
  String get nfcLanguageCodeHelper;

  /// No description provided for @nfcLanguageCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Language code is required'**
  String get nfcLanguageCodeRequired;

  /// No description provided for @nfcMimeType.
  ///
  /// In en, this message translates to:
  /// **'MIME Type'**
  String get nfcMimeType;

  /// No description provided for @nfcMimeTypeHelper.
  ///
  /// In en, this message translates to:
  /// **'Official media type (e.g. application/json, text/vcard, image/png).'**
  String get nfcMimeTypeHelper;

  /// No description provided for @nfcMimeTypeRequired.
  ///
  /// In en, this message translates to:
  /// **'A valid MIME type (e.g., type/subtype) is required'**
  String get nfcMimeTypeRequired;

  /// No description provided for @nfcMimePayloadData.
  ///
  /// In en, this message translates to:
  /// **'MIME Payload Data'**
  String get nfcMimePayloadData;

  /// No description provided for @nfcMimePayloadHint.
  ///
  /// In en, this message translates to:
  /// **'Enter JSON, vCard, or custom raw contents...'**
  String get nfcMimePayloadHint;

  /// No description provided for @nfcPayloadRequired.
  ///
  /// In en, this message translates to:
  /// **'Payload data is required'**
  String get nfcPayloadRequired;

  /// No description provided for @nfcGetHex.
  ///
  /// In en, this message translates to:
  /// **'Get Hex'**
  String get nfcGetHex;

  /// No description provided for @nfcWriteTag.
  ///
  /// In en, this message translates to:
  /// **'Write Tag'**
  String get nfcWriteTag;

  /// No description provided for @nfcWriteTagHint.
  ///
  /// In en, this message translates to:
  /// **'Write Tag active only when scanning a writable tag.'**
  String get nfcWriteTagHint;

  /// No description provided for @nfcHexInspectorTitle.
  ///
  /// In en, this message translates to:
  /// **'NDEF Hex Inspector'**
  String get nfcHexInspectorTitle;

  /// No description provided for @nfcHexInspectorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Validate, parse, or generate raw NDEF hex codes.'**
  String get nfcHexInspectorSubtitle;

  /// No description provided for @nfcPasteHexData.
  ///
  /// In en, this message translates to:
  /// **'Paste NDEF Hex Data'**
  String get nfcPasteHexData;

  /// No description provided for @nfcClearInput.
  ///
  /// In en, this message translates to:
  /// **'Clear Input'**
  String get nfcClearInput;

  /// No description provided for @nfcPasteHexToParsePrompt.
  ///
  /// In en, this message translates to:
  /// **'Please paste some NDEF hex data to parse.'**
  String get nfcPasteHexToParsePrompt;

  /// No description provided for @nfcParseHex.
  ///
  /// In en, this message translates to:
  /// **'Parse Hex'**
  String get nfcParseHex;

  /// No description provided for @nfcGeneratedHex.
  ///
  /// In en, this message translates to:
  /// **'Generated NDEF Hex'**
  String get nfcGeneratedHex;

  /// No description provided for @nfcCopyGeneratedHex.
  ///
  /// In en, this message translates to:
  /// **'Copy Generated Hex'**
  String get nfcCopyGeneratedHex;

  /// No description provided for @nfcHexCopied.
  ///
  /// In en, this message translates to:
  /// **'Generated NDEF Hex copied to clipboard.'**
  String get nfcHexCopied;

  /// No description provided for @nfcNoRecordsFound.
  ///
  /// In en, this message translates to:
  /// **'No Records Found'**
  String get nfcNoRecordsFound;

  /// No description provided for @nfcNoRecordsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'NDEF payload is empty or not scanned yet.'**
  String get nfcNoRecordsSubtitle;

  /// No description provided for @nfcNdefRecords.
  ///
  /// In en, this message translates to:
  /// **'NDEF Records ({count})'**
  String nfcNdefRecords(int count);

  /// No description provided for @nfcRecordIndex.
  ///
  /// In en, this message translates to:
  /// **'Record Index:'**
  String get nfcRecordIndex;

  /// No description provided for @nfcLoadIntoEditor.
  ///
  /// In en, this message translates to:
  /// **'Load into Editor'**
  String get nfcLoadIntoEditor;

  /// No description provided for @nfcRecordLoaded.
  ///
  /// In en, this message translates to:
  /// **'Record loaded into Editor Form.'**
  String get nfcRecordLoaded;

  /// No description provided for @nfcCopyPayloadHex.
  ///
  /// In en, this message translates to:
  /// **'Copy Payload Hex'**
  String get nfcCopyPayloadHex;

  /// No description provided for @nfcPayloadHexCopied.
  ///
  /// In en, this message translates to:
  /// **'Payload Hex copied to clipboard.'**
  String get nfcPayloadHexCopied;

  /// No description provided for @nfcRawPayloadHex.
  ///
  /// In en, this message translates to:
  /// **'Raw Payload (Hex):'**
  String get nfcRawPayloadHex;

  /// No description provided for @nfcSubtitleText.
  ///
  /// In en, this message translates to:
  /// **'Well-known Text [{lang} | {encoding}]'**
  String nfcSubtitleText(String lang, String encoding);

  /// No description provided for @nfcSubtitleUri.
  ///
  /// In en, this message translates to:
  /// **'Well-known URI'**
  String get nfcSubtitleUri;

  /// No description provided for @nfcSubtitleCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom / Non-NDEF'**
  String get nfcSubtitleCustom;

  /// No description provided for @nfcStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get nfcStop;

  /// No description provided for @nfcScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get nfcScan;

  /// No description provided for @nfcNoHardware.
  ///
  /// In en, this message translates to:
  /// **'No Hardware'**
  String get nfcNoHardware;

  /// No description provided for @nfcScannerTitle.
  ///
  /// In en, this message translates to:
  /// **'NFC Scanner'**
  String get nfcScannerTitle;

  /// No description provided for @nfcScanningPrompt.
  ///
  /// In en, this message translates to:
  /// **'Approach an NFC tag to scan'**
  String get nfcScanningPrompt;

  /// No description provided for @nfcScannerInactive.
  ///
  /// In en, this message translates to:
  /// **'Scanner is inactive'**
  String get nfcScannerInactive;

  /// No description provided for @nfcCardBrand.
  ///
  /// In en, this message translates to:
  /// **'Card Brand'**
  String get nfcCardBrand;

  /// No description provided for @nfcCardNumber.
  ///
  /// In en, this message translates to:
  /// **'Card Number'**
  String get nfcCardNumber;

  /// No description provided for @nfcCardholderName.
  ///
  /// In en, this message translates to:
  /// **'Cardholder Name'**
  String get nfcCardholderName;

  /// No description provided for @nfcExpirationDate.
  ///
  /// In en, this message translates to:
  /// **'Expiration Date'**
  String get nfcExpirationDate;

  /// No description provided for @nfcApplicationAid.
  ///
  /// In en, this message translates to:
  /// **'Application AID'**
  String get nfcApplicationAid;

  /// No description provided for @nfcUidSerial.
  ///
  /// In en, this message translates to:
  /// **'UID / Serial'**
  String get nfcUidSerial;

  /// No description provided for @nfcTechnologies.
  ///
  /// In en, this message translates to:
  /// **'Technologies'**
  String get nfcTechnologies;

  /// No description provided for @nfcCapacity.
  ///
  /// In en, this message translates to:
  /// **'Capacity'**
  String get nfcCapacity;

  /// No description provided for @nfcWritable.
  ///
  /// In en, this message translates to:
  /// **'Writable'**
  String get nfcWritable;

  /// No description provided for @nfcCardholderLabel.
  ///
  /// In en, this message translates to:
  /// **'CARDHOLDER'**
  String get nfcCardholderLabel;

  /// No description provided for @nfcExpiresLabel.
  ///
  /// In en, this message translates to:
  /// **'EXPIRES'**
  String get nfcExpiresLabel;

  /// No description provided for @nfcPaymentCard.
  ///
  /// In en, this message translates to:
  /// **'Payment Card'**
  String get nfcPaymentCard;

  /// No description provided for @nfcSessionError.
  ///
  /// In en, this message translates to:
  /// **'NFC scan session error: {message}'**
  String nfcSessionError(String message);

  /// No description provided for @nfcTagDetected.
  ///
  /// In en, this message translates to:
  /// **'Tag detected — {label}'**
  String nfcTagDetected(String label);

  /// No description provided for @nfcScanFailed.
  ///
  /// In en, this message translates to:
  /// **'Scan failed: {error}'**
  String nfcScanFailed(String error);

  /// No description provided for @nfcNoActiveTag.
  ///
  /// In en, this message translates to:
  /// **'No active tag. Scan a tag first.'**
  String get nfcNoActiveTag;

  /// No description provided for @nfcTagNotWritable.
  ///
  /// In en, this message translates to:
  /// **'Tag is not writable or NDEF is unsupported.'**
  String get nfcTagNotWritable;

  /// No description provided for @nfcWritingToTag.
  ///
  /// In en, this message translates to:
  /// **'Writing to NFC tag...'**
  String get nfcWritingToTag;

  /// No description provided for @nfcWriteSuccess.
  ///
  /// In en, this message translates to:
  /// **'NDEF record written successfully!'**
  String get nfcWriteSuccess;

  /// No description provided for @nfcWriteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to write: {error}'**
  String nfcWriteFailed(String error);

  /// No description provided for @nfcHexGenerated.
  ///
  /// In en, this message translates to:
  /// **'NDEF hex generated! Copy it below.'**
  String get nfcHexGenerated;

  /// No description provided for @nfcHexGenerateError.
  ///
  /// In en, this message translates to:
  /// **'Error generating hex: {error}'**
  String nfcHexGenerateError(String error);

  /// No description provided for @nfcHexParsed.
  ///
  /// In en, this message translates to:
  /// **'NDEF Hex parsed successfully!'**
  String get nfcHexParsed;

  /// No description provided for @nfcHexParseFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to parse hex: {error}'**
  String nfcHexParseFailed(String error);

  /// No description provided for @nfcNoHardwareInfo.
  ///
  /// In en, this message translates to:
  /// **'NFC hardware scanning is only supported on mobile devices. You can still paste, parse, edit, and generate NDEF hexadecimal configurations locally.'**
  String get nfcNoHardwareInfo;

  /// No description provided for @nfcHexEmulator.
  ///
  /// In en, this message translates to:
  /// **'Hex Emulator'**
  String get nfcHexEmulator;

  /// No description provided for @nfcRecordsParsed.
  ///
  /// In en, this message translates to:
  /// **'{count} records parsed'**
  String nfcRecordsParsed(int count);

  /// No description provided for @notesFailedToLoadSharedFile.
  ///
  /// In en, this message translates to:
  /// **'Failed to load shared file: {error}'**
  String notesFailedToLoadSharedFile(String error);

  /// No description provided for @notesNoteSaved.
  ///
  /// In en, this message translates to:
  /// **'Note saved'**
  String get notesNoteSaved;

  /// No description provided for @notesFailedToSaveNote.
  ///
  /// In en, this message translates to:
  /// **'Failed to save note: {error}'**
  String notesFailedToSaveNote(String error);

  /// No description provided for @notesDeleteNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Note'**
  String get notesDeleteNoteTitle;

  /// No description provided for @notesDeleteNoteMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this note?'**
  String get notesDeleteNoteMessage;

  /// No description provided for @notesNoteDeleted.
  ///
  /// In en, this message translates to:
  /// **'Note deleted'**
  String get notesNoteDeleted;

  /// No description provided for @notesFailedToDeleteNote.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete note: {error}'**
  String notesFailedToDeleteNote(String error);

  /// No description provided for @notesImportedNoteFrom.
  ///
  /// In en, this message translates to:
  /// **'Imported note from \"{name}\"'**
  String notesImportedNoteFrom(String name);

  /// No description provided for @notesFailedToImportDroppedFile.
  ///
  /// In en, this message translates to:
  /// **'Failed to import dropped file: {error}'**
  String notesFailedToImportDroppedFile(String error);

  /// No description provided for @notesViewNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'View Note'**
  String get notesViewNoteTitle;

  /// No description provided for @notesFailedToReadFile.
  ///
  /// In en, this message translates to:
  /// **'Failed to read file: {error}'**
  String notesFailedToReadFile(String error);

  /// No description provided for @notesBackupImportedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Backup imported successfully'**
  String get notesBackupImportedSuccessfully;

  /// No description provided for @notesImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String notesImportFailed(String error);

  /// No description provided for @notesFailedToExportNotes.
  ///
  /// In en, this message translates to:
  /// **'Failed to export notes: {error}'**
  String notesFailedToExportNotes(String error);

  /// No description provided for @notesSyncConfigureServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Configure server URL in Cloud settings first'**
  String get notesSyncConfigureServerUrl;

  /// No description provided for @notesSyncFinished.
  ///
  /// In en, this message translates to:
  /// **'Sync finished. Pulled: {pulled}, Pushed: {pushed}, Deleted: {deleted}.'**
  String notesSyncFinished(int pulled, int pushed, int deleted);

  /// No description provided for @notesSyncFailedEmpty.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: URL or User ID empty'**
  String get notesSyncFailedEmpty;

  /// No description provided for @notesSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {error}'**
  String notesSyncFailed(String error);

  /// No description provided for @notesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search notes...'**
  String get notesSearchHint;

  /// No description provided for @notesSyncWithCloud.
  ///
  /// In en, this message translates to:
  /// **'Sync with Cloud'**
  String get notesSyncWithCloud;

  /// No description provided for @notesImportMarkdownFile.
  ///
  /// In en, this message translates to:
  /// **'Import Markdown file'**
  String get notesImportMarkdownFile;

  /// No description provided for @notesImportJsonBackup.
  ///
  /// In en, this message translates to:
  /// **'Import JSON Backup'**
  String get notesImportJsonBackup;

  /// No description provided for @notesExportJsonBackup.
  ///
  /// In en, this message translates to:
  /// **'Export JSON Backup'**
  String get notesExportJsonBackup;

  /// No description provided for @notesEditorHint.
  ///
  /// In en, this message translates to:
  /// **'Write notes here... (Markdown supported)'**
  String get notesEditorHint;

  /// No description provided for @notesEditorNoPreview.
  ///
  /// In en, this message translates to:
  /// **'Nothing to preview yet'**
  String get notesEditorNoPreview;

  /// No description provided for @notesUnsavedChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsaved Changes'**
  String get notesUnsavedChangesTitle;

  /// No description provided for @notesUnsavedChangesMessage.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Do you want to discard them?'**
  String get notesUnsavedChangesMessage;

  /// No description provided for @notesKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep Editing'**
  String get notesKeepEditing;

  /// No description provided for @notesDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get notesDiscard;

  /// No description provided for @notesExportPdf.
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get notesExportPdf;

  /// No description provided for @notesCreateNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Note'**
  String get notesCreateNoteTitle;

  /// No description provided for @notesEditNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Note'**
  String get notesEditNoteTitle;

  /// No description provided for @notesTabWrite.
  ///
  /// In en, this message translates to:
  /// **'Write'**
  String get notesTabWrite;

  /// No description provided for @notesTabPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get notesTabPreview;

  /// No description provided for @notesToolbarBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get notesToolbarBold;

  /// No description provided for @notesToolbarItalic.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get notesToolbarItalic;

  /// No description provided for @notesToolbarStrikethrough.
  ///
  /// In en, this message translates to:
  /// **'Strikethrough'**
  String get notesToolbarStrikethrough;

  /// No description provided for @notesToolbarH1.
  ///
  /// In en, this message translates to:
  /// **'H1'**
  String get notesToolbarH1;

  /// No description provided for @notesToolbarH2.
  ///
  /// In en, this message translates to:
  /// **'H2'**
  String get notesToolbarH2;

  /// No description provided for @notesToolbarH3.
  ///
  /// In en, this message translates to:
  /// **'H3'**
  String get notesToolbarH3;

  /// No description provided for @notesToolbarList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get notesToolbarList;

  /// No description provided for @notesToolbarTodo.
  ///
  /// In en, this message translates to:
  /// **'Todo'**
  String get notesToolbarTodo;

  /// No description provided for @notesToolbarLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get notesToolbarLink;

  /// No description provided for @notesToolbarCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get notesToolbarCode;

  /// No description provided for @notesToolbarCodeBlock.
  ///
  /// In en, this message translates to:
  /// **'Code Block'**
  String get notesToolbarCodeBlock;

  /// No description provided for @notesUntitledNote.
  ///
  /// In en, this message translates to:
  /// **'Untitled Note'**
  String get notesUntitledNote;

  /// No description provided for @notesExportMd.
  ///
  /// In en, this message translates to:
  /// **'Export MD'**
  String get notesExportMd;

  /// No description provided for @notesUpdatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated: {date}'**
  String notesUpdatedAt(String date);

  /// No description provided for @notesDropZoneUnsupportedFile.
  ///
  /// In en, this message translates to:
  /// **'Only Markdown (.md) or Text (.txt) files are supported'**
  String get notesDropZoneUnsupportedFile;

  /// No description provided for @notesDropZoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Drop Markdown file here'**
  String get notesDropZoneTitle;

  /// No description provided for @notesAddTagHint.
  ///
  /// In en, this message translates to:
  /// **'Add tag...'**
  String get notesAddTagHint;

  /// No description provided for @pdfEditDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get pdfEditDownload;

  /// No description provided for @pdfEditOpenInViewer.
  ///
  /// In en, this message translates to:
  /// **'Open in Viewer'**
  String get pdfEditOpenInViewer;

  /// No description provided for @pdfEditSignTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign: {fileName}'**
  String pdfEditSignTitle(String fileName);

  /// No description provided for @pdfEditSignOpenError.
  ///
  /// In en, this message translates to:
  /// **'Failed to open PDF: {error}'**
  String pdfEditSignOpenError(String error);

  /// No description provided for @pdfEditSignFailed.
  ///
  /// In en, this message translates to:
  /// **'Signing failed: {error}'**
  String pdfEditSignFailed(String error);

  /// No description provided for @pdfEditSignPrevPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get pdfEditSignPrevPage;

  /// No description provided for @pdfEditSignNextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get pdfEditSignNextPage;

  /// No description provided for @pdfEditSignPageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String pdfEditSignPageOf(int current, int total);

  /// No description provided for @pdfEditSignDragHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to position · resize/rotate at the handles'**
  String get pdfEditSignDragHint;

  /// No description provided for @pdfEditSignTapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a signature above'**
  String get pdfEditSignTapHint;

  /// No description provided for @pdfEditSignStamping.
  ///
  /// In en, this message translates to:
  /// **'Stamping signature…'**
  String get pdfEditSignStamping;

  /// No description provided for @pdfEditSignDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Signature Placed'**
  String get pdfEditSignDoneTitle;

  /// No description provided for @pdfEditSignDoneSize.
  ///
  /// In en, this message translates to:
  /// **'Signed PDF size: {size}'**
  String pdfEditSignDoneSize(String size);

  /// No description provided for @pdfEditFlattenTitle.
  ///
  /// In en, this message translates to:
  /// **'Flatten: {fileName}'**
  String pdfEditFlattenTitle(String fileName);

  /// No description provided for @pdfEditFlattenHeadline.
  ///
  /// In en, this message translates to:
  /// **'Flatten PDF to Images'**
  String get pdfEditFlattenHeadline;

  /// No description provided for @pdfEditFlattenDescription.
  ///
  /// In en, this message translates to:
  /// **'Each page will be rendered as an image and embedded into a new PDF. This makes the content non-selectable and prevents text extraction.'**
  String get pdfEditFlattenDescription;

  /// No description provided for @pdfEditFlattenDpi.
  ///
  /// In en, this message translates to:
  /// **'Resolution (DPI): {dpi}'**
  String pdfEditFlattenDpi(int dpi);

  /// No description provided for @pdfEditFlattenDpiHint.
  ///
  /// In en, this message translates to:
  /// **'Higher DPI = larger file size but better quality'**
  String get pdfEditFlattenDpiHint;

  /// No description provided for @pdfEditFlattenJpegQuality.
  ///
  /// In en, this message translates to:
  /// **'JPEG Quality: {quality}%'**
  String pdfEditFlattenJpegQuality(int quality);

  /// No description provided for @pdfEditFlattenJpegQualityHint.
  ///
  /// In en, this message translates to:
  /// **'Higher quality = larger file size'**
  String get pdfEditFlattenJpegQualityHint;

  /// No description provided for @pdfEditFlattenStart.
  ///
  /// In en, this message translates to:
  /// **'Start Flattening'**
  String get pdfEditFlattenStart;

  /// No description provided for @pdfEditFlattenProgress.
  ///
  /// In en, this message translates to:
  /// **'Rendering page {done} of {total}…'**
  String pdfEditFlattenProgress(int done, int total);

  /// No description provided for @pdfEditFlattenPagesTotal.
  ///
  /// In en, this message translates to:
  /// **'{count} pages total'**
  String pdfEditFlattenPagesTotal(int count);

  /// No description provided for @pdfEditFlattenFailed.
  ///
  /// In en, this message translates to:
  /// **'Flatten failed: {error}'**
  String pdfEditFlattenFailed(String error);

  /// No description provided for @pdfEditFlattenDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Flattening Complete'**
  String get pdfEditFlattenDoneTitle;

  /// No description provided for @pdfEditFlattenDoneSize.
  ///
  /// In en, this message translates to:
  /// **'New PDF size: {size}'**
  String pdfEditFlattenDoneSize(String size);

  /// No description provided for @pdfEditMetaTitle2.
  ///
  /// In en, this message translates to:
  /// **'Metadata: {fileName}'**
  String pdfEditMetaTitle2(String fileName);

  /// No description provided for @pdfEditMetaReload.
  ///
  /// In en, this message translates to:
  /// **'Reload metadata'**
  String get pdfEditMetaReload;

  /// No description provided for @pdfEditMetaLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load metadata'**
  String get pdfEditMetaLoadFailed;

  /// No description provided for @pdfEditMetaLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load metadata: {error}'**
  String pdfEditMetaLoadError(String error);

  /// No description provided for @pdfEditMetaRemoveSecurityError.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove security: {error}'**
  String pdfEditMetaRemoveSecurityError(String error);

  /// No description provided for @pdfEditMetaSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String pdfEditMetaSaveFailed(String error);

  /// No description provided for @pdfEditMetaSpecsTitle.
  ///
  /// In en, this message translates to:
  /// **'Document Specifications'**
  String get pdfEditMetaSpecsTitle;

  /// No description provided for @pdfEditMetaFileName.
  ///
  /// In en, this message translates to:
  /// **'File Name'**
  String get pdfEditMetaFileName;

  /// No description provided for @pdfEditMetaFileSize.
  ///
  /// In en, this message translates to:
  /// **'File Size'**
  String get pdfEditMetaFileSize;

  /// No description provided for @pdfEditMetaPageCount.
  ///
  /// In en, this message translates to:
  /// **'Page Count'**
  String get pdfEditMetaPageCount;

  /// No description provided for @pdfEditMetaPdfVersion.
  ///
  /// In en, this message translates to:
  /// **'PDF Version'**
  String get pdfEditMetaPdfVersion;

  /// No description provided for @pdfEditMetaPageDimensions.
  ///
  /// In en, this message translates to:
  /// **'Page Dimensions'**
  String get pdfEditMetaPageDimensions;

  /// No description provided for @pdfEditMetaMetadataTitle.
  ///
  /// In en, this message translates to:
  /// **'Document Metadata'**
  String get pdfEditMetaMetadataTitle;

  /// No description provided for @pdfEditMetaTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get pdfEditMetaTitle;

  /// No description provided for @pdfEditMetaAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get pdfEditMetaAuthor;

  /// No description provided for @pdfEditMetaSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get pdfEditMetaSubject;

  /// No description provided for @pdfEditMetaKeywords.
  ///
  /// In en, this message translates to:
  /// **'Keywords'**
  String get pdfEditMetaKeywords;

  /// No description provided for @pdfEditMetaCreator.
  ///
  /// In en, this message translates to:
  /// **'Creator'**
  String get pdfEditMetaCreator;

  /// No description provided for @pdfEditMetaProducer.
  ///
  /// In en, this message translates to:
  /// **'Producer'**
  String get pdfEditMetaProducer;

  /// No description provided for @pdfEditMetaCreationDate.
  ///
  /// In en, this message translates to:
  /// **'Creation Date'**
  String get pdfEditMetaCreationDate;

  /// No description provided for @pdfEditMetaModDate.
  ///
  /// In en, this message translates to:
  /// **'Modification Date'**
  String get pdfEditMetaModDate;

  /// No description provided for @pdfEditMetaTrapped.
  ///
  /// In en, this message translates to:
  /// **'Trapped'**
  String get pdfEditMetaTrapped;

  /// No description provided for @pdfEditMetaSecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Security & Restrictions'**
  String get pdfEditMetaSecurityTitle;

  /// No description provided for @pdfEditMetaEncrypted.
  ///
  /// In en, this message translates to:
  /// **'Encrypted'**
  String get pdfEditMetaEncrypted;

  /// No description provided for @pdfEditMetaEncryptedYes.
  ///
  /// In en, this message translates to:
  /// **'Yes (Revision {revision})'**
  String pdfEditMetaEncryptedYes(String revision);

  /// No description provided for @pdfEditMetaUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get pdfEditMetaUnknown;

  /// No description provided for @pdfEditMetaRestrictions.
  ///
  /// In en, this message translates to:
  /// **'Restrictions'**
  String get pdfEditMetaRestrictions;

  /// No description provided for @pdfEditMetaPermAllowed.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get pdfEditMetaPermAllowed;

  /// No description provided for @pdfEditMetaPermRestricted.
  ///
  /// In en, this message translates to:
  /// **'Restricted'**
  String get pdfEditMetaPermRestricted;

  /// No description provided for @pdfEditMetaPermPrintLow.
  ///
  /// In en, this message translates to:
  /// **'Printing (Low Resolution)'**
  String get pdfEditMetaPermPrintLow;

  /// No description provided for @pdfEditMetaPermPrintHigh.
  ///
  /// In en, this message translates to:
  /// **'High-Quality Printing'**
  String get pdfEditMetaPermPrintHigh;

  /// No description provided for @pdfEditMetaPermModifyContent.
  ///
  /// In en, this message translates to:
  /// **'Modifying Document Content'**
  String get pdfEditMetaPermModifyContent;

  /// No description provided for @pdfEditMetaPermCopyExtract.
  ///
  /// In en, this message translates to:
  /// **'Content Copying & Extraction'**
  String get pdfEditMetaPermCopyExtract;

  /// No description provided for @pdfEditMetaPermAnnotations.
  ///
  /// In en, this message translates to:
  /// **'Adding/Modifying Annotations'**
  String get pdfEditMetaPermAnnotations;

  /// No description provided for @pdfEditMetaPermForms.
  ///
  /// In en, this message translates to:
  /// **'Filling Interactive Forms'**
  String get pdfEditMetaPermForms;

  /// No description provided for @pdfEditMetaPermAccessibility.
  ///
  /// In en, this message translates to:
  /// **'Accessibility Extraction'**
  String get pdfEditMetaPermAccessibility;

  /// No description provided for @pdfEditMetaPermAssembly.
  ///
  /// In en, this message translates to:
  /// **'Document Assembly'**
  String get pdfEditMetaPermAssembly;

  /// No description provided for @pdfEditMetaRemovePassword.
  ///
  /// In en, this message translates to:
  /// **'Remove Password & Save Copy'**
  String get pdfEditMetaRemovePassword;

  /// No description provided for @pdfEditMetaDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Security Removal Complete'**
  String get pdfEditMetaDoneTitle;

  /// No description provided for @pdfEditExtractTitle.
  ///
  /// In en, this message translates to:
  /// **'Extract Images: {fileName}'**
  String pdfEditExtractTitle(String fileName);

  /// No description provided for @pdfEditExtractSelectionCount.
  ///
  /// In en, this message translates to:
  /// **'{selected} selected / {total} total'**
  String pdfEditExtractSelectionCount(int selected, int total);

  /// No description provided for @pdfEditExtractHideControls.
  ///
  /// In en, this message translates to:
  /// **'Hide controls'**
  String get pdfEditExtractHideControls;

  /// No description provided for @pdfEditExtractShowControls.
  ///
  /// In en, this message translates to:
  /// **'Show controls'**
  String get pdfEditExtractShowControls;

  /// No description provided for @pdfEditExtractSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get pdfEditExtractSelectAll;

  /// No description provided for @pdfEditExtractClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear Selection'**
  String get pdfEditExtractClearSelection;

  /// No description provided for @pdfEditExtractDownloadSelected.
  ///
  /// In en, this message translates to:
  /// **'Download Selected'**
  String get pdfEditExtractDownloadSelected;

  /// No description provided for @pdfEditExtractDownloadAllZip.
  ///
  /// In en, this message translates to:
  /// **'Download All (ZIP)'**
  String get pdfEditExtractDownloadAllZip;

  /// No description provided for @pdfEditExtractEmpty.
  ///
  /// In en, this message translates to:
  /// **'No embedded images found in this PDF'**
  String get pdfEditExtractEmpty;

  /// No description provided for @pdfEditExtractScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning PDF…'**
  String get pdfEditExtractScanning;

  /// No description provided for @pdfEditExtractScanningObjects.
  ///
  /// In en, this message translates to:
  /// **'Scanning PDF objects {done} of {total}…'**
  String pdfEditExtractScanningObjects(int done, int total);

  /// No description provided for @pdfEditExtractPreparingImages.
  ///
  /// In en, this message translates to:
  /// **'Preparing images {done} of {total}…'**
  String pdfEditExtractPreparingImages(int done, int total);

  /// No description provided for @pdfEditExtractImagesFound.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 image found} other{{count} images found}}'**
  String pdfEditExtractImagesFound(int count);

  /// No description provided for @pdfEditExtractFailed.
  ///
  /// In en, this message translates to:
  /// **'Image extraction failed: {error}'**
  String pdfEditExtractFailed(String error);

  /// No description provided for @pdfEditExtractCreatingZip.
  ///
  /// In en, this message translates to:
  /// **'Creating ZIP {done} of {total}…'**
  String pdfEditExtractCreatingZip(int done, int total);

  /// No description provided for @pdfEditExtractZipReady.
  ///
  /// In en, this message translates to:
  /// **'ZIP ready'**
  String get pdfEditExtractZipReady;

  /// No description provided for @pdfEditExtractZipFailed.
  ///
  /// In en, this message translates to:
  /// **'ZIP export failed: {error}'**
  String pdfEditExtractZipFailed(String error);

  /// No description provided for @pdfEditExtractImagePageDimensions.
  ///
  /// In en, this message translates to:
  /// **'Page {page} - {width}x{height}'**
  String pdfEditExtractImagePageDimensions(int page, int width, int height);

  /// No description provided for @pdfEditExtractImageBpp.
  ///
  /// In en, this message translates to:
  /// **'BPP: {value}'**
  String pdfEditExtractImageBpp(String value);

  /// No description provided for @pdfEditExtractImageFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter: {filter}'**
  String pdfEditExtractImageFilter(String filter);

  /// No description provided for @pdfEditExtractPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get pdfEditExtractPreview;

  /// No description provided for @pdfNavPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Password Protected PDF'**
  String get pdfNavPasswordTitle;

  /// No description provided for @pdfNavPasswordMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter password for {fileName}.'**
  String pdfNavPasswordMessage(String fileName);

  /// No description provided for @pdfNavOpenCanceled.
  ///
  /// In en, this message translates to:
  /// **'PDF open canceled. Select another file or try again.'**
  String get pdfNavOpenCanceled;

  /// No description provided for @pdfNavTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'PDFs'**
  String get pdfNavTypeLabel;

  /// No description provided for @pdfNavDropZoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Open a PDF File'**
  String get pdfNavDropZoneTitle;

  /// No description provided for @pdfNavDropZoneSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Drag & drop a .pdf file here'**
  String get pdfNavDropZoneSubtitle;

  /// No description provided for @pdfNavDocumentFallback.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get pdfNavDocumentFallback;

  /// No description provided for @pdfNavBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get pdfNavBookmarks;

  /// No description provided for @pdfNavNoBookmarks.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks available'**
  String get pdfNavNoBookmarks;

  /// No description provided for @pdfNavSearchText.
  ///
  /// In en, this message translates to:
  /// **'Search Text'**
  String get pdfNavSearchText;

  /// No description provided for @pdfNavMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get pdfNavMore;

  /// No description provided for @pdfNavModeView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get pdfNavModeView;

  /// No description provided for @pdfNavModePlaceSignature.
  ///
  /// In en, this message translates to:
  /// **'Place Signature'**
  String get pdfNavModePlaceSignature;

  /// No description provided for @pdfNavModeOrganizePages.
  ///
  /// In en, this message translates to:
  /// **'Organize Pages'**
  String get pdfNavModeOrganizePages;

  /// No description provided for @pdfNavModeFlattenPdf.
  ///
  /// In en, this message translates to:
  /// **'Flatten PDF'**
  String get pdfNavModeFlattenPdf;

  /// No description provided for @pdfNavModeExtractImages.
  ///
  /// In en, this message translates to:
  /// **'Extract Images'**
  String get pdfNavModeExtractImages;

  /// No description provided for @pdfNavModeMetadata.
  ///
  /// In en, this message translates to:
  /// **'Metadata'**
  String get pdfNavModeMetadata;

  /// No description provided for @pdfNavCloseSearch.
  ///
  /// In en, this message translates to:
  /// **'Close Search'**
  String get pdfNavCloseSearch;

  /// No description provided for @pdfNavSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search text...'**
  String get pdfNavSearchHint;

  /// No description provided for @pdfNavPrevMatch.
  ///
  /// In en, this message translates to:
  /// **'Previous Match'**
  String get pdfNavPrevMatch;

  /// No description provided for @pdfNavNextMatch.
  ///
  /// In en, this message translates to:
  /// **'Next Match'**
  String get pdfNavNextMatch;

  /// No description provided for @pdfNavShareFile.
  ///
  /// In en, this message translates to:
  /// **'Share File'**
  String get pdfNavShareFile;

  /// No description provided for @pdfNavSaveToDownloads.
  ///
  /// In en, this message translates to:
  /// **'Save to Downloads'**
  String get pdfNavSaveToDownloads;

  /// No description provided for @pdfNavPageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String pdfNavPageOf(int current, int total);

  /// No description provided for @pdfNavPageLoading.
  ///
  /// In en, this message translates to:
  /// **'Page {current}...'**
  String pdfNavPageLoading(int current);

  /// No description provided for @pdfNavPrevPage.
  ///
  /// In en, this message translates to:
  /// **'Previous Page'**
  String get pdfNavPrevPage;

  /// No description provided for @pdfNavNextPage.
  ///
  /// In en, this message translates to:
  /// **'Next Page'**
  String get pdfNavNextPage;

  /// No description provided for @pdfNavZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom Out'**
  String get pdfNavZoomOut;

  /// No description provided for @pdfNavZoomReset.
  ///
  /// In en, this message translates to:
  /// **'Reset Zoom'**
  String get pdfNavZoomReset;

  /// No description provided for @pdfNavZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom In'**
  String get pdfNavZoomIn;

  /// No description provided for @pdfNavOrganizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Organize: {fileName}'**
  String pdfNavOrganizeTitle(String fileName);

  /// No description provided for @pdfNavOrganizeInsertTooltip.
  ///
  /// In en, this message translates to:
  /// **'Insert pages from another PDF'**
  String get pdfNavOrganizeInsertTooltip;

  /// No description provided for @pdfNavOrganizeApplyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Apply changes'**
  String get pdfNavOrganizeApplyTooltip;

  /// No description provided for @pdfNavOrganizePageCountHint.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 page} other{{count} pages}} - drag to reorder, tap to preview'**
  String pdfNavOrganizePageCountHint(int count);

  /// No description provided for @pdfNavOrganizeNoPages.
  ///
  /// In en, this message translates to:
  /// **'No pages'**
  String get pdfNavOrganizeNoPages;

  /// No description provided for @pdfViewerShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to share file: {error}'**
  String pdfViewerShareFailed(String error);

  /// No description provided for @pdfNavOrganizeLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load PDF: {error}'**
  String pdfNavOrganizeLoadFailed(String error);

  /// No description provided for @pdfNavOrganizeOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open PDF: {error}'**
  String pdfNavOrganizeOpenFailed(String error);

  /// No description provided for @pdfNavOrganizeReorganizeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to reorganize: {error}'**
  String pdfNavOrganizeReorganizeFailed(String error);

  /// No description provided for @pdfNavOrganizeCannotDeleteLastPage.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete the last page'**
  String get pdfNavOrganizeCannotDeleteLastPage;

  /// No description provided for @pdfNavOrganizeRemovePageTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Page'**
  String get pdfNavOrganizeRemovePageTitle;

  /// No description provided for @pdfNavOrganizeRemovePageMessage.
  ///
  /// In en, this message translates to:
  /// **'Remove page {pageNumber}?'**
  String pdfNavOrganizeRemovePageMessage(int pageNumber);

  /// No description provided for @pdfNavOrganizeInsertDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Insert Pages from \"{srcName}\"'**
  String pdfNavOrganizeInsertDialogTitle(String srcName);

  /// No description provided for @pdfNavOrganizeNoPagesFound.
  ///
  /// In en, this message translates to:
  /// **'No pages found'**
  String get pdfNavOrganizeNoPagesFound;

  /// No description provided for @pdfNavOrganizePageNumber.
  ///
  /// In en, this message translates to:
  /// **'Page {pageNumber}'**
  String pdfNavOrganizePageNumber(int pageNumber);

  /// No description provided for @pdfNavOrientationPortrait.
  ///
  /// In en, this message translates to:
  /// **'Portrait'**
  String get pdfNavOrientationPortrait;

  /// No description provided for @pdfNavOrientationLandscape.
  ///
  /// In en, this message translates to:
  /// **'Landscape'**
  String get pdfNavOrientationLandscape;

  /// No description provided for @pdfNavDeselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get pdfNavDeselectAll;

  /// No description provided for @pdfNavSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get pdfNavSelectAll;

  /// No description provided for @pdfNavOrganizeInsertCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Insert 1 page} other{Insert {count} pages}}'**
  String pdfNavOrganizeInsertCount(int count);

  /// No description provided for @pdfNavOrganizeComplete.
  ///
  /// In en, this message translates to:
  /// **'Organizing Complete'**
  String get pdfNavOrganizeComplete;

  /// No description provided for @pdfNavOrganizeNewSize.
  ///
  /// In en, this message translates to:
  /// **'New PDF size: {size}'**
  String pdfNavOrganizeNewSize(String size);

  /// No description provided for @pdfNavDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get pdfNavDownload;

  /// No description provided for @pdfNavOpenInViewer.
  ///
  /// In en, this message translates to:
  /// **'Open in Viewer'**
  String get pdfNavOpenInViewer;

  /// No description provided for @sigAdvancedSettings.
  ///
  /// In en, this message translates to:
  /// **'Advanced settings'**
  String get sigAdvancedSettings;

  /// No description provided for @sigTabDraw.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get sigTabDraw;

  /// No description provided for @sigTabSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get sigTabSaved;

  /// No description provided for @sigSavedToDownloads.
  ///
  /// In en, this message translates to:
  /// **'Signature saved to Downloads'**
  String get sigSavedToDownloads;

  /// No description provided for @sigCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Signature copied to clipboard'**
  String get sigCopiedToClipboard;

  /// No description provided for @sigSaved.
  ///
  /// In en, this message translates to:
  /// **'Signature saved'**
  String get sigSaved;

  /// No description provided for @sigDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete signature?'**
  String get sigDeleteTitle;

  /// No description provided for @sigDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'This signature will be removed.'**
  String get sigDeleteContent;

  /// No description provided for @sigUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get sigUndo;

  /// No description provided for @sigRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get sigRedo;

  /// No description provided for @sigPng.
  ///
  /// In en, this message translates to:
  /// **'PNG'**
  String get sigPng;

  /// No description provided for @sigSvg.
  ///
  /// In en, this message translates to:
  /// **'SVG'**
  String get sigSvg;

  /// No description provided for @sigAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get sigAdvanced;

  /// No description provided for @sigReduceLines.
  ///
  /// In en, this message translates to:
  /// **'Reduce lines (RDP)'**
  String get sigReduceLines;

  /// No description provided for @sigMoveTolerance.
  ///
  /// In en, this message translates to:
  /// **'Move tolerance'**
  String get sigMoveTolerance;

  /// No description provided for @sigMinWidthFactor.
  ///
  /// In en, this message translates to:
  /// **'Min width factor'**
  String get sigMinWidthFactor;

  /// No description provided for @sigMaxWidthFactor.
  ///
  /// In en, this message translates to:
  /// **'Max width factor'**
  String get sigMaxWidthFactor;

  /// No description provided for @sigVelocitySensitivity.
  ///
  /// In en, this message translates to:
  /// **'Velocity sensitivity'**
  String get sigVelocitySensitivity;

  /// No description provided for @sigVelocityInfluence.
  ///
  /// In en, this message translates to:
  /// **'Velocity influence'**
  String get sigVelocityInfluence;

  /// No description provided for @sigPressureInfluence.
  ///
  /// In en, this message translates to:
  /// **'Pressure influence'**
  String get sigPressureInfluence;

  /// No description provided for @sigWidthSmoothing.
  ///
  /// In en, this message translates to:
  /// **'Width smoothing'**
  String get sigWidthSmoothing;

  /// No description provided for @sigExportDpi.
  ///
  /// In en, this message translates to:
  /// **'Export DPI'**
  String get sigExportDpi;

  /// No description provided for @sigLoad.
  ///
  /// In en, this message translates to:
  /// **'Load'**
  String get sigLoad;

  /// No description provided for @widgetPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get widgetPasswordLabel;

  /// No description provided for @widgetPasswordShow.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get widgetPasswordShow;

  /// No description provided for @widgetPasswordHide.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get widgetPasswordHide;

  /// No description provided for @widgetFileDropFailedToSelect.
  ///
  /// In en, this message translates to:
  /// **'Failed to select file: {error}'**
  String widgetFileDropFailedToSelect(String error);

  /// No description provided for @widgetFileDropOnlyFilesSupported.
  ///
  /// In en, this message translates to:
  /// **'Only {extensions} files are supported'**
  String widgetFileDropOnlyFilesSupported(String extensions);

  /// No description provided for @widgetFileDropReleaseToLoad.
  ///
  /// In en, this message translates to:
  /// **'Release to load file'**
  String get widgetFileDropReleaseToLoad;

  /// No description provided for @widgetMarkdownExportMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Export Markdown'**
  String get widgetMarkdownExportMarkdown;

  /// No description provided for @widgetMarkdownExportPdf.
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get widgetMarkdownExportPdf;

  /// No description provided for @widgetMarkdownUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated: {date}'**
  String widgetMarkdownUpdated(String date);

  /// No description provided for @widgetMarkdownNoContent.
  ///
  /// In en, this message translates to:
  /// **'No additional content'**
  String get widgetMarkdownNoContent;

  /// No description provided for @widgetToolChooserOpenFile.
  ///
  /// In en, this message translates to:
  /// **'Open File'**
  String get widgetToolChooserOpenFile;

  /// No description provided for @widgetToolChooserChooseTool.
  ///
  /// In en, this message translates to:
  /// **'Choose a tool to open:'**
  String get widgetToolChooserChooseTool;

  /// No description provided for @widgetToolChooserAlwaysUseTool.
  ///
  /// In en, this message translates to:
  /// **'Always use this tool for this file type'**
  String get widgetToolChooserAlwaysUseTool;

  /// No description provided for @widgetShortcutHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Home Screen Shortcut'**
  String get widgetShortcutHomeTitle;

  /// No description provided for @widgetShortcutHomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add shortcut to your home launcher screen'**
  String get widgetShortcutHomeSubtitle;

  /// No description provided for @widgetShortcutDrawerTitle.
  ///
  /// In en, this message translates to:
  /// **'App Drawer Icon'**
  String get widgetShortcutDrawerTitle;

  /// No description provided for @widgetShortcutDrawerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show separate launcher icon in App Drawer'**
  String get widgetShortcutDrawerSubtitle;

  /// No description provided for @sectionTitleSensors.
  ///
  /// In en, this message translates to:
  /// **'Sensors'**
  String get sectionTitleSensors;

  /// No description provided for @sectionTitleUtilities.
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get sectionTitleUtilities;

  /// No description provided for @sectionTitleInfo.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get sectionTitleInfo;

  /// No description provided for @toolNameCalculator.
  ///
  /// In en, this message translates to:
  /// **'Calculator'**
  String get toolNameCalculator;

  /// No description provided for @toolDescCalculator.
  ///
  /// In en, this message translates to:
  /// **'Basic and scientific calculations'**
  String get toolDescCalculator;

  /// No description provided for @toolNameBubbleLevel.
  ///
  /// In en, this message translates to:
  /// **'Bubble Level'**
  String get toolNameBubbleLevel;

  /// No description provided for @toolDescBubbleLevel.
  ///
  /// In en, this message translates to:
  /// **'Precision spirit level using sensors'**
  String get toolDescBubbleLevel;

  /// No description provided for @toolNameEmfDetector.
  ///
  /// In en, this message translates to:
  /// **'EMF Detector'**
  String get toolNameEmfDetector;

  /// No description provided for @toolDescEmfDetector.
  ///
  /// In en, this message translates to:
  /// **'Detect electromagnetic fields'**
  String get toolDescEmfDetector;

  /// No description provided for @toolNameDeviceInfo.
  ///
  /// In en, this message translates to:
  /// **'Device Info'**
  String get toolNameDeviceInfo;

  /// No description provided for @toolDescDeviceInfo.
  ///
  /// In en, this message translates to:
  /// **'Battery, sensors, and system information'**
  String get toolDescDeviceInfo;

  /// No description provided for @toolNameNfcTagLab.
  ///
  /// In en, this message translates to:
  /// **'NFC Tag Lab'**
  String get toolNameNfcTagLab;

  /// No description provided for @toolDescNfcTagLab.
  ///
  /// In en, this message translates to:
  /// **'Scan NFC targets, decode NDEF, classify signatures, and write tags.'**
  String get toolDescNfcTagLab;

  /// No description provided for @toolNamePdfViewer.
  ///
  /// In en, this message translates to:
  /// **'PDF Viewer'**
  String get toolNamePdfViewer;

  /// No description provided for @toolDescPdfViewer.
  ///
  /// In en, this message translates to:
  /// **'View PDF files fullscreen with ease'**
  String get toolDescPdfViewer;

  /// No description provided for @toolNameNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get toolNameNotes;

  /// No description provided for @toolDescNotes.
  ///
  /// In en, this message translates to:
  /// **'Simple note taking tool with Markdown support and backend sync'**
  String get toolDescNotes;

  /// No description provided for @toolNameMarkdownViewer.
  ///
  /// In en, this message translates to:
  /// **'Markdown Viewer'**
  String get toolNameMarkdownViewer;

  /// No description provided for @toolDescMarkdownViewer.
  ///
  /// In en, this message translates to:
  /// **'View Markdown files fullscreen with ease'**
  String get toolDescMarkdownViewer;

  /// No description provided for @toolNameImageViewer.
  ///
  /// In en, this message translates to:
  /// **'Image Viewer'**
  String get toolNameImageViewer;

  /// No description provided for @toolDescImageViewer.
  ///
  /// In en, this message translates to:
  /// **'View, zoom, resize, and convert image formats'**
  String get toolDescImageViewer;

  /// No description provided for @toolNameFastDrop.
  ///
  /// In en, this message translates to:
  /// **'Fast Drop'**
  String get toolNameFastDrop;

  /// No description provided for @toolDescFastDrop.
  ///
  /// In en, this message translates to:
  /// **'Quickly drop files or paste clipboard data to the server for temporary storage and sharing'**
  String get toolDescFastDrop;

  /// No description provided for @toolNameImagesToPdf.
  ///
  /// In en, this message translates to:
  /// **'Images to PDF'**
  String get toolNameImagesToPdf;

  /// No description provided for @toolDescImagesToPdf.
  ///
  /// In en, this message translates to:
  /// **'Convert multiple images into a single PDF document'**
  String get toolDescImagesToPdf;

  /// No description provided for @toolNameChiptune.
  ///
  /// In en, this message translates to:
  /// **'Chiptune Player'**
  String get toolNameChiptune;

  /// No description provided for @toolDescChiptune.
  ///
  /// In en, this message translates to:
  /// **'Play Amiga MOD, XM and IT tracker modules'**
  String get toolDescChiptune;

  /// No description provided for @toolNameFocusNoise.
  ///
  /// In en, this message translates to:
  /// **'Focus Noise & Breathing'**
  String get toolNameFocusNoise;

  /// No description provided for @toolDescFocusNoise.
  ///
  /// In en, this message translates to:
  /// **'Ambient noise player with guided breathing patterns'**
  String get toolDescFocusNoise;

  /// No description provided for @toolNameSignatures.
  ///
  /// In en, this message translates to:
  /// **'Signature Creator'**
  String get toolNameSignatures;

  /// No description provided for @toolDescSignatures.
  ///
  /// In en, this message translates to:
  /// **'Draw signatures and export them as transparent PNG or SVG'**
  String get toolDescSignatures;

  /// No description provided for @toolNameQrCode.
  ///
  /// In en, this message translates to:
  /// **'QR Code'**
  String get toolNameQrCode;

  /// No description provided for @toolDescQrCode.
  ///
  /// In en, this message translates to:
  /// **'Scan QR codes with the camera or an image, and create your own'**
  String get toolDescQrCode;

  /// No description provided for @qrTabScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get qrTabScan;

  /// No description provided for @qrTabCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get qrTabCreate;

  /// No description provided for @qrModeCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get qrModeCamera;

  /// No description provided for @qrModeImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get qrModeImage;

  /// No description provided for @qrScannerEngineZxing.
  ///
  /// In en, this message translates to:
  /// **'ZXing'**
  String get qrScannerEngineZxing;

  /// No description provided for @qrScannerEngineMlKit.
  ///
  /// In en, this message translates to:
  /// **'ML Kit'**
  String get qrScannerEngineMlKit;

  /// No description provided for @qrImagesLabel.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get qrImagesLabel;

  /// No description provided for @qrScanDropTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan a QR code from an image'**
  String get qrScanDropTitle;

  /// No description provided for @qrScanDropSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Drop an image here, or browse to pick one'**
  String get qrScanDropSubtitle;

  /// No description provided for @qrBrowseImage.
  ///
  /// In en, this message translates to:
  /// **'Browse image'**
  String get qrBrowseImage;

  /// No description provided for @qrPasteImage.
  ///
  /// In en, this message translates to:
  /// **'Paste image'**
  String get qrPasteImage;

  /// No description provided for @qrPickFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Pick from gallery'**
  String get qrPickFromGallery;

  /// No description provided for @qrNoCodeFound.
  ///
  /// In en, this message translates to:
  /// **'No QR code found in the image'**
  String get qrNoCodeFound;

  /// No description provided for @qrNoImageInClipboard.
  ///
  /// In en, this message translates to:
  /// **'No image in the clipboard'**
  String get qrNoImageInClipboard;

  /// No description provided for @qrScanAgain.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get qrScanAgain;

  /// No description provided for @qrResultOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get qrResultOpen;

  /// No description provided for @qrActionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get qrActionCopy;

  /// No description provided for @qrActionShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get qrActionShare;

  /// No description provided for @qrCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get qrCopied;

  /// No description provided for @qrOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open this content'**
  String get qrOpenFailed;

  /// No description provided for @qrKindLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get qrKindLink;

  /// No description provided for @qrKindWifi.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi network'**
  String get qrKindWifi;

  /// No description provided for @qrKindEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get qrKindEmail;

  /// No description provided for @qrKindPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get qrKindPhone;

  /// No description provided for @qrKindSms.
  ///
  /// In en, this message translates to:
  /// **'SMS'**
  String get qrKindSms;

  /// No description provided for @qrKindLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get qrKindLocation;

  /// No description provided for @qrKindContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get qrKindContact;

  /// No description provided for @qrKindText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get qrKindText;

  /// No description provided for @qrTypeText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get qrTypeText;

  /// No description provided for @qrTypeUrl.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get qrTypeUrl;

  /// No description provided for @qrTypeWifi.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi'**
  String get qrTypeWifi;

  /// No description provided for @qrTypeEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get qrTypeEmail;

  /// No description provided for @qrTypePhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get qrTypePhone;

  /// No description provided for @qrTypeSms.
  ///
  /// In en, this message translates to:
  /// **'SMS'**
  String get qrTypeSms;

  /// No description provided for @qrTypeGeo.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get qrTypeGeo;

  /// No description provided for @qrTypeVcard.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get qrTypeVcard;

  /// No description provided for @qrFieldText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get qrFieldText;

  /// No description provided for @qrFieldUrl.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get qrFieldUrl;

  /// No description provided for @qrFieldSsid.
  ///
  /// In en, this message translates to:
  /// **'Network name (SSID)'**
  String get qrFieldSsid;

  /// No description provided for @qrFieldPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get qrFieldPassword;

  /// No description provided for @qrFieldEncryption.
  ///
  /// In en, this message translates to:
  /// **'Encryption'**
  String get qrFieldEncryption;

  /// No description provided for @qrFieldHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden network'**
  String get qrFieldHidden;

  /// No description provided for @qrEncWpa.
  ///
  /// In en, this message translates to:
  /// **'WPA/WPA2'**
  String get qrEncWpa;

  /// No description provided for @qrEncWep.
  ///
  /// In en, this message translates to:
  /// **'WEP'**
  String get qrEncWep;

  /// No description provided for @qrEncNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get qrEncNone;

  /// No description provided for @qrFieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get qrFieldEmail;

  /// No description provided for @qrFieldSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get qrFieldSubject;

  /// No description provided for @qrFieldBody.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get qrFieldBody;

  /// No description provided for @qrFieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get qrFieldPhone;

  /// No description provided for @qrFieldMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get qrFieldMessage;

  /// No description provided for @qrFieldLatitude.
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get qrFieldLatitude;

  /// No description provided for @qrFieldLongitude.
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get qrFieldLongitude;

  /// No description provided for @qrFieldName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get qrFieldName;

  /// No description provided for @qrFieldOrganization.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get qrFieldOrganization;

  /// No description provided for @qrCreatePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Fill in the fields to generate a QR code'**
  String get qrCreatePlaceholder;

  /// No description provided for @qrEncodeFailed.
  ///
  /// In en, this message translates to:
  /// **'Content is too long to encode as a QR code'**
  String get qrEncodeFailed;

  /// No description provided for @qrActionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get qrActionSave;

  /// No description provided for @qrActionCopyImage.
  ///
  /// In en, this message translates to:
  /// **'Copy image'**
  String get qrActionCopyImage;

  /// No description provided for @qrImageCopied.
  ///
  /// In en, this message translates to:
  /// **'QR image copied to clipboard'**
  String get qrImageCopied;

  /// No description provided for @qrCopyImageFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not copy the QR image'**
  String get qrCopyImageFailed;

  /// No description provided for @qrSavedToDownloads.
  ///
  /// In en, this message translates to:
  /// **'QR code saved to Downloads folder'**
  String get qrSavedToDownloads;

  /// No description provided for @qrSavedTo.
  ///
  /// In en, this message translates to:
  /// **'QR code saved to {path}'**
  String qrSavedTo(String path);

  /// No description provided for @qrSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save QR code: {error}'**
  String qrSaveFailed(String error);

  /// Name of the Document Scanner tool
  ///
  /// In en, this message translates to:
  /// **'Document Scanner'**
  String get toolNameDocumentScanner;

  /// Description of the Document Scanner tool
  ///
  /// In en, this message translates to:
  /// **'Scan documents via camera, adjust crop/skew, apply filters, and compile to PDF'**
  String get toolDescDocumentScanner;

  /// No description provided for @docScanNoPages.
  ///
  /// In en, this message translates to:
  /// **'No scanned pages yet'**
  String get docScanNoPages;

  /// No description provided for @docScanAddHint.
  ///
  /// In en, this message translates to:
  /// **'Add pages using the camera or gallery'**
  String get docScanAddHint;

  /// No description provided for @docScanPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Page {number}'**
  String docScanPageTitle(int number);

  /// No description provided for @docScanFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Filter: {filter}'**
  String docScanFilterLabel(String filter);

  /// No description provided for @docScanRotationLabel.
  ///
  /// In en, this message translates to:
  /// **'Rot: {rotation}°'**
  String docScanRotationLabel(int rotation);

  /// No description provided for @docScanSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Size: {width}x{height}'**
  String docScanSizeLabel(int width, int height);

  /// No description provided for @docScanEditPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Page {number}'**
  String docScanEditPageTitle(int number);

  /// No description provided for @docScanRotateL.
  ///
  /// In en, this message translates to:
  /// **'Rotate L'**
  String get docScanRotateL;

  /// No description provided for @docScanRotateR.
  ///
  /// In en, this message translates to:
  /// **'Rotate R'**
  String get docScanRotateR;

  /// No description provided for @docScanCropWarp.
  ///
  /// In en, this message translates to:
  /// **'Crop & Warp'**
  String get docScanCropWarp;

  /// No description provided for @docScanFiltersHeading.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get docScanFiltersHeading;

  /// No description provided for @docScanFilterOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get docScanFilterOriginal;

  /// No description provided for @docScanFilterGrayscale.
  ///
  /// In en, this message translates to:
  /// **'Grayscale'**
  String get docScanFilterGrayscale;

  /// No description provided for @docScanFilterBw.
  ///
  /// In en, this message translates to:
  /// **'B&W'**
  String get docScanFilterBw;

  /// No description provided for @docScanFilterClean.
  ///
  /// In en, this message translates to:
  /// **'Clean Doc'**
  String get docScanFilterClean;

  /// No description provided for @docScanClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear All Pages'**
  String get docScanClearTitle;

  /// No description provided for @docScanClearMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete all scanned pages? This cannot be undone.'**
  String get docScanClearMessage;

  /// No description provided for @docScanClearConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete All'**
  String get docScanClearConfirm;

  /// No description provided for @docScanActionScan.
  ///
  /// In en, this message translates to:
  /// **'Scan Page'**
  String get docScanActionScan;

  /// No description provided for @docScanActionGallery.
  ///
  /// In en, this message translates to:
  /// **'Import from Gallery'**
  String get docScanActionGallery;

  /// No description provided for @docScanActionSave.
  ///
  /// In en, this message translates to:
  /// **'Save PDF Document'**
  String get docScanActionSave;

  /// No description provided for @docScanGeneratingPdf.
  ///
  /// In en, this message translates to:
  /// **'Generating PDF Document...'**
  String get docScanGeneratingPdf;

  /// No description provided for @docScanSavedPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF saved to {path}'**
  String docScanSavedPdf(String path);

  /// No description provided for @docScanFailedPdf.
  ///
  /// In en, this message translates to:
  /// **'Failed to save PDF: {error}'**
  String docScanFailedPdf(String error);

  /// No description provided for @docScanFailedCreate.
  ///
  /// In en, this message translates to:
  /// **'PDF creation failed: {error}'**
  String docScanFailedCreate(String error);

  /// No description provided for @docScanFailedCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera capture failed: {error}'**
  String docScanFailedCamera(String error);

  /// No description provided for @docScanFailedGallery.
  ///
  /// In en, this message translates to:
  /// **'Failed to pick image: {error}'**
  String docScanFailedGallery(String error);

  /// No description provided for @docScanCropReset.
  ///
  /// In en, this message translates to:
  /// **'Reset to Full'**
  String get docScanCropReset;

  /// No description provided for @docScanCropUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get docScanCropUndo;

  /// No description provided for @docScanCropApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get docScanCropApply;

  /// No description provided for @docScanCropCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get docScanCropCancel;

  /// No description provided for @docScanActionScanMlKit.
  ///
  /// In en, this message translates to:
  /// **'Scan Page (ML Kit)'**
  String get docScanActionScanMlKit;

  /// No description provided for @docScanActionScanStandard.
  ///
  /// In en, this message translates to:
  /// **'Scan Page (Standard)'**
  String get docScanActionScanStandard;

  /// No description provided for @docScanMethodTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Scan Method'**
  String get docScanMethodTitle;

  /// No description provided for @docScanFailedMlKit.
  ///
  /// In en, this message translates to:
  /// **'ML Kit scan failed: {error}'**
  String docScanFailedMlKit(String error);

  /// No description provided for @docScanMlKitUnavailableFallback.
  ///
  /// In en, this message translates to:
  /// **'Document scanner unavailable, using the camera instead.'**
  String get docScanMlKitUnavailableFallback;

  /// No description provided for @toolNameGpsLocationStore.
  ///
  /// In en, this message translates to:
  /// **'GPS Location Store'**
  String get toolNameGpsLocationStore;

  /// No description provided for @toolDescGpsLocationStore.
  ///
  /// In en, this message translates to:
  /// **'Capture and store your current location with notes and map links'**
  String get toolDescGpsLocationStore;

  /// No description provided for @gpsStoreLocateButton.
  ///
  /// In en, this message translates to:
  /// **'Show current location'**
  String get gpsStoreLocateButton;

  /// No description provided for @gpsStoreCurrentTitle.
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get gpsStoreCurrentTitle;

  /// No description provided for @gpsStoreSaveThis.
  ///
  /// In en, this message translates to:
  /// **'Save this location'**
  String get gpsStoreSaveThis;

  /// No description provided for @gpsStoreLastSavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Last saved location'**
  String get gpsStoreLastSavedTitle;

  /// No description provided for @gpsStoreHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get gpsStoreHistoryTitle;

  /// No description provided for @gpsStoreOpenGoogleMaps.
  ///
  /// In en, this message translates to:
  /// **'Google Maps'**
  String get gpsStoreOpenGoogleMaps;

  /// No description provided for @gpsStoreOpenOsm.
  ///
  /// In en, this message translates to:
  /// **'OpenStreetMap'**
  String get gpsStoreOpenOsm;

  /// No description provided for @gpsStoreSourceGps.
  ///
  /// In en, this message translates to:
  /// **'GPS'**
  String get gpsStoreSourceGps;

  /// No description provided for @gpsStoreSourceApproxIp.
  ///
  /// In en, this message translates to:
  /// **'Approx (IP)'**
  String get gpsStoreSourceApproxIp;

  /// No description provided for @gpsStoreAccuracyMeters.
  ///
  /// In en, this message translates to:
  /// **'±{meters} m'**
  String gpsStoreAccuracyMeters(int meters);

  /// No description provided for @gpsStoreSaveLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Save location'**
  String get gpsStoreSaveLocationTitle;

  /// No description provided for @gpsStoreEditDescription.
  ///
  /// In en, this message translates to:
  /// **'Edit description'**
  String get gpsStoreEditDescription;

  /// No description provided for @gpsStoreDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get gpsStoreDescriptionLabel;

  /// No description provided for @gpsStoreDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Add a short note (optional)'**
  String get gpsStoreDescriptionHint;

  /// No description provided for @gpsStoreIpFallbackNote.
  ///
  /// In en, this message translates to:
  /// **'Precise GPS was unavailable — this is an approximate position based on your IP address.'**
  String get gpsStoreIpFallbackNote;

  /// No description provided for @gpsStoreLocationSaved.
  ///
  /// In en, this message translates to:
  /// **'Location saved'**
  String get gpsStoreLocationSaved;

  /// No description provided for @gpsStoreCaptureFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not determine a location. Check location permissions and connectivity.'**
  String get gpsStoreCaptureFailed;

  /// No description provided for @gpsStoreDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete location'**
  String get gpsStoreDeleteTitle;

  /// No description provided for @gpsStoreDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This location will be permanently removed.'**
  String get gpsStoreDeleteMessage;

  /// No description provided for @gpsStoreEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No locations yet'**
  String get gpsStoreEmptyTitle;

  /// No description provided for @gpsStoreEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Show current location\" to find where you are, then save it.'**
  String get gpsStoreEmptyMessage;

  /// No description provided for @gpsStoreDistanceFromHere.
  ///
  /// In en, this message translates to:
  /// **'Distance and direction from your current position'**
  String get gpsStoreDistanceFromHere;

  /// No description provided for @gpsStoreCompassN.
  ///
  /// In en, this message translates to:
  /// **'N'**
  String get gpsStoreCompassN;

  /// No description provided for @gpsStoreCompassNE.
  ///
  /// In en, this message translates to:
  /// **'NE'**
  String get gpsStoreCompassNE;

  /// No description provided for @gpsStoreCompassE.
  ///
  /// In en, this message translates to:
  /// **'E'**
  String get gpsStoreCompassE;

  /// No description provided for @gpsStoreCompassSE.
  ///
  /// In en, this message translates to:
  /// **'SE'**
  String get gpsStoreCompassSE;

  /// No description provided for @gpsStoreCompassS.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get gpsStoreCompassS;

  /// No description provided for @gpsStoreCompassSW.
  ///
  /// In en, this message translates to:
  /// **'SW'**
  String get gpsStoreCompassSW;

  /// No description provided for @gpsStoreCompassW.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get gpsStoreCompassW;

  /// No description provided for @gpsStoreCompassNW.
  ///
  /// In en, this message translates to:
  /// **'NW'**
  String get gpsStoreCompassNW;

  /// No description provided for @gpsInfoButtonTooltip.
  ///
  /// In en, this message translates to:
  /// **'GPS Hardware Details'**
  String get gpsInfoButtonTooltip;

  /// No description provided for @gpsInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'GPS & Satellite Info'**
  String get gpsInfoTitle;

  /// No description provided for @gpsInfoLatitude.
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get gpsInfoLatitude;

  /// No description provided for @gpsInfoLongitude.
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get gpsInfoLongitude;

  /// No description provided for @gpsInfoAltitude.
  ///
  /// In en, this message translates to:
  /// **'Altitude'**
  String get gpsInfoAltitude;

  /// No description provided for @gpsInfoSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get gpsInfoSpeed;

  /// No description provided for @gpsInfoHeading.
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get gpsInfoHeading;

  /// No description provided for @gpsInfoAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get gpsInfoAccuracy;

  /// No description provided for @gpsInfoTimestamp.
  ///
  /// In en, this message translates to:
  /// **'Last Fix Time'**
  String get gpsInfoTimestamp;

  /// No description provided for @gpsInfoProvider.
  ///
  /// In en, this message translates to:
  /// **'Source Provider'**
  String get gpsInfoProvider;

  /// No description provided for @gpsInfoMocked.
  ///
  /// In en, this message translates to:
  /// **'Mocked Location'**
  String get gpsInfoMocked;

  /// No description provided for @gpsInfoPositionDetails.
  ///
  /// In en, this message translates to:
  /// **'Current Position Data'**
  String get gpsInfoPositionDetails;

  /// No description provided for @gpsInfoHardwareDetails.
  ///
  /// In en, this message translates to:
  /// **'GNSS Constellations & Hardware'**
  String get gpsInfoHardwareDetails;

  /// No description provided for @gpsInfoSatelliteCount.
  ///
  /// In en, this message translates to:
  /// **'Visible Satellites'**
  String get gpsInfoSatelliteCount;

  /// No description provided for @gpsInfoSatelliteCountUsed.
  ///
  /// In en, this message translates to:
  /// **'Satellites Used in Fix'**
  String get gpsInfoSatelliteCountUsed;

  /// No description provided for @gpsInfoLocationProviders.
  ///
  /// In en, this message translates to:
  /// **'System Location Providers'**
  String get gpsInfoLocationProviders;

  /// No description provided for @gpsInfoConstellationGps.
  ///
  /// In en, this message translates to:
  /// **'GPS (USA)'**
  String get gpsInfoConstellationGps;

  /// No description provided for @gpsInfoConstellationGlonass.
  ///
  /// In en, this message translates to:
  /// **'GLONASS (Russia)'**
  String get gpsInfoConstellationGlonass;

  /// No description provided for @gpsInfoConstellationGalileo.
  ///
  /// In en, this message translates to:
  /// **'Galileo (EU)'**
  String get gpsInfoConstellationGalileo;

  /// No description provided for @gpsInfoConstellationBeidou.
  ///
  /// In en, this message translates to:
  /// **'BeiDou (China)'**
  String get gpsInfoConstellationBeidou;

  /// No description provided for @gpsInfoConstellationQzss.
  ///
  /// In en, this message translates to:
  /// **'QZSS (Japan)'**
  String get gpsInfoConstellationQzss;

  /// No description provided for @gpsInfoConstellationSbas.
  ///
  /// In en, this message translates to:
  /// **'SBAS'**
  String get gpsInfoConstellationSbas;

  /// No description provided for @gpsInfoConstellationIrnss.
  ///
  /// In en, this message translates to:
  /// **'NavIC / IRNSS (India)'**
  String get gpsInfoConstellationIrnss;

  /// No description provided for @gpsInfoConstellationUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown Constellation'**
  String get gpsInfoConstellationUnknown;

  /// No description provided for @gpsInfoStatusScanning.
  ///
  /// In en, this message translates to:
  /// **'Acquiring satellite signals...'**
  String get gpsInfoStatusScanning;

  /// No description provided for @gpsInfoStatusNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Satellite status not supported on this platform.'**
  String get gpsInfoStatusNotAvailable;

  /// No description provided for @gpsInfoSatelliteList.
  ///
  /// In en, this message translates to:
  /// **'Satellite Details'**
  String get gpsInfoSatelliteList;

  /// No description provided for @gpsInfoSatelliteSvid.
  ///
  /// In en, this message translates to:
  /// **'SVID: {svid}'**
  String gpsInfoSatelliteSvid(int svid);

  /// No description provided for @gpsInfoSatelliteCn0.
  ///
  /// In en, this message translates to:
  /// **'SNR: {cn0} dB-Hz'**
  String gpsInfoSatelliteCn0(double cn0);

  /// No description provided for @gpsInfoSatelliteUsed.
  ///
  /// In en, this message translates to:
  /// **'Used in Fix'**
  String get gpsInfoSatelliteUsed;

  /// No description provided for @gpsInfoSatelliteElevation.
  ///
  /// In en, this message translates to:
  /// **'El: {elevation}°'**
  String gpsInfoSatelliteElevation(double elevation);

  /// No description provided for @gpsInfoSatelliteAzimuth.
  ///
  /// In en, this message translates to:
  /// **'Az: {azimuth}°'**
  String gpsInfoSatelliteAzimuth(double azimuth);

  /// No description provided for @gpsInfoProviderEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get gpsInfoProviderEnabled;

  /// No description provided for @gpsInfoProviderDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get gpsInfoProviderDisabled;

  /// No description provided for @toolNameChatAi.
  ///
  /// In en, this message translates to:
  /// **'AI Chat'**
  String get toolNameChatAi;

  /// No description provided for @toolDescChatAi.
  ///
  /// In en, this message translates to:
  /// **'Chat with on-device AI model Gemini Nano using ML Kit'**
  String get toolDescChatAi;

  /// No description provided for @chatAiUnsupportedPlatform.
  ///
  /// In en, this message translates to:
  /// **'On-device AI Chat is only supported on Android. Desktop and iOS platforms are not supported by the ML Kit GenAI Prompt API.'**
  String get chatAiUnsupportedPlatform;

  /// No description provided for @chatAiNewChat.
  ///
  /// In en, this message translates to:
  /// **'New Chat'**
  String get chatAiNewChat;

  /// No description provided for @chatAiModelStatus.
  ///
  /// In en, this message translates to:
  /// **'Model Status: {status}'**
  String chatAiModelStatus(String status);

  /// No description provided for @chatAiModelLoading.
  ///
  /// In en, this message translates to:
  /// **'Downloading model... This may take a while.'**
  String get chatAiModelLoading;

  /// No description provided for @chatAiModelReady.
  ///
  /// In en, this message translates to:
  /// **'Model ready'**
  String get chatAiModelReady;

  /// No description provided for @chatAiModelNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Model not downloaded. Tap Download to start.'**
  String get chatAiModelNotDownloaded;

  /// No description provided for @chatAiDownloadButton.
  ///
  /// In en, this message translates to:
  /// **'Download Model'**
  String get chatAiDownloadButton;

  /// No description provided for @chatAiInputPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get chatAiInputPlaceholder;

  /// No description provided for @chatAiDeleteSession.
  ///
  /// In en, this message translates to:
  /// **'Delete Session'**
  String get chatAiDeleteSession;

  /// No description provided for @chatAiDeleteSessionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this chat session and all its messages?'**
  String get chatAiDeleteSessionConfirm;

  /// No description provided for @chatAiAttachImage.
  ///
  /// In en, this message translates to:
  /// **'Attach Image'**
  String get chatAiAttachImage;

  /// No description provided for @chatAiAttachDocument.
  ///
  /// In en, this message translates to:
  /// **'Attach Document'**
  String get chatAiAttachDocument;

  /// No description provided for @chatAiAttachTooltip.
  ///
  /// In en, this message translates to:
  /// **'Attach file or image'**
  String get chatAiAttachTooltip;

  /// No description provided for @chatAiPrepareButton.
  ///
  /// In en, this message translates to:
  /// **'Prepare AI Core'**
  String get chatAiPrepareButton;

  /// No description provided for @chatAiClearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get chatAiClearHistory;

  /// No description provided for @chatAiClearHistoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all messages in this chat?'**
  String get chatAiClearHistoryConfirm;

  /// No description provided for @chatAiThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking...'**
  String get chatAiThinking;

  /// No description provided for @chatAiSystemPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'System Prompt'**
  String get chatAiSystemPromptTitle;

  /// No description provided for @chatAiSystemPromptDescription.
  ///
  /// In en, this message translates to:
  /// **'Customize the instructions for the AI model. Leave empty to use the default.'**
  String get chatAiSystemPromptDescription;

  /// No description provided for @toolNameHexEditor.
  ///
  /// In en, this message translates to:
  /// **'Hex Editor'**
  String get toolNameHexEditor;

  /// No description provided for @toolDescHexEditor.
  ///
  /// In en, this message translates to:
  /// **'Inspect and edit files in hexadecimal and ASCII views'**
  String get toolDescHexEditor;

  /// No description provided for @hexEditorTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Any file'**
  String get hexEditorTypeLabel;

  /// No description provided for @hexEditorOpenTitle.
  ///
  /// In en, this message translates to:
  /// **'Open any file'**
  String get hexEditorOpenTitle;

  /// No description provided for @hexEditorDropSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Drop any file here'**
  String get hexEditorDropSubtitle;

  /// No description provided for @hexEditorStringsTitle.
  ///
  /// In en, this message translates to:
  /// **'Printable Strings'**
  String get hexEditorStringsTitle;

  /// No description provided for @hexEditorMinLength.
  ///
  /// In en, this message translates to:
  /// **'Minimum Length'**
  String get hexEditorMinLength;

  /// No description provided for @hexEditorScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get hexEditorScan;

  /// No description provided for @hexEditorScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning...'**
  String get hexEditorScanning;

  /// No description provided for @hexEditorScannedBytes.
  ///
  /// In en, this message translates to:
  /// **'Scanned {scanned} / {total} bytes'**
  String hexEditorScannedBytes(String scanned, String total);

  /// No description provided for @hexEditorFoundStrings.
  ///
  /// In en, this message translates to:
  /// **'Found {count} strings'**
  String hexEditorFoundStrings(int count);

  /// No description provided for @hexEditorCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get hexEditorCancelled;

  /// No description provided for @hexEditorNoStringsFound.
  ///
  /// In en, this message translates to:
  /// **'No strings found'**
  String get hexEditorNoStringsFound;

  /// No description provided for @hexEditorExportStarted.
  ///
  /// In en, this message translates to:
  /// **'Export started'**
  String get hexEditorExportStarted;

  /// No description provided for @hexEditorExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String hexEditorExportFailed(String error);

  /// No description provided for @hexEditorFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load file: {error}'**
  String hexEditorFailedToLoad(String error);

  /// No description provided for @hexEditorOffset.
  ///
  /// In en, this message translates to:
  /// **'Offset'**
  String get hexEditorOffset;

  /// No description provided for @hexEditorSize.
  ///
  /// In en, this message translates to:
  /// **'Size: {size} bytes'**
  String hexEditorSize(String size);

  /// No description provided for @hexEditorSearchType.
  ///
  /// In en, this message translates to:
  /// **'Search type'**
  String get hexEditorSearchType;

  /// No description provided for @hexEditorSearchHex.
  ///
  /// In en, this message translates to:
  /// **'Hexadecimal'**
  String get hexEditorSearchHex;

  /// No description provided for @hexEditorSearchText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get hexEditorSearchText;

  /// No description provided for @hexEditorSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search pattern'**
  String get hexEditorSearchPlaceholder;

  /// No description provided for @hexEditorShowAscii.
  ///
  /// In en, this message translates to:
  /// **'Show ASCII View'**
  String get hexEditorShowAscii;

  /// No description provided for @hexEditorReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get hexEditorReset;

  /// No description provided for @hexEditorStringsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Strings'**
  String get hexEditorStringsTooltip;

  /// No description provided for @hexEditorSearchNext.
  ///
  /// In en, this message translates to:
  /// **'Next Match'**
  String get hexEditorSearchNext;

  /// No description provided for @hexEditorSearchPrev.
  ///
  /// In en, this message translates to:
  /// **'Prev Match'**
  String get hexEditorSearchPrev;

  /// No description provided for @hexEditorInvalidHex.
  ///
  /// In en, this message translates to:
  /// **'Invalid hex pattern'**
  String get hexEditorInvalidHex;

  /// No description provided for @hexEditorHexLengthEven.
  ///
  /// In en, this message translates to:
  /// **'Hex search must be even length'**
  String get hexEditorHexLengthEven;

  /// No description provided for @hexEditorPatternNotFound.
  ///
  /// In en, this message translates to:
  /// **'Pattern not found'**
  String get hexEditorPatternNotFound;

  /// No description provided for @hexEditorEditByteTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Byte at {offset}'**
  String hexEditorEditByteTitle(String offset);

  /// No description provided for @hexEditorEditByteHex.
  ///
  /// In en, this message translates to:
  /// **'Hex'**
  String get hexEditorEditByteHex;

  /// No description provided for @hexEditorEditByteAscii.
  ///
  /// In en, this message translates to:
  /// **'ASCII'**
  String get hexEditorEditByteAscii;

  /// No description provided for @hexEditorSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get hexEditorSave;

  /// No description provided for @hexEditorDiscardChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get hexEditorDiscardChangesTitle;

  /// No description provided for @hexEditorDiscardChangesMessage.
  ///
  /// In en, this message translates to:
  /// **'Do you want to discard your modifications?'**
  String get hexEditorDiscardChangesMessage;

  /// No description provided for @hexEditorKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get hexEditorKeepEditing;

  /// No description provided for @hexEditorDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get hexEditorDiscard;

  /// No description provided for @toolNameFileConverter.
  ///
  /// In en, this message translates to:
  /// **'File Converter'**
  String get toolNameFileConverter;

  /// No description provided for @toolDescFileConverter.
  ///
  /// In en, this message translates to:
  /// **'Convert documents between DOCX, PDF, HTML, Markdown and text'**
  String get toolDescFileConverter;

  /// No description provided for @fileConverterTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get fileConverterTypeLabel;

  /// No description provided for @fileConverterOpenTitle.
  ///
  /// In en, this message translates to:
  /// **'Open a document'**
  String get fileConverterOpenTitle;

  /// No description provided for @fileConverterDropSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Drop a DOCX, PDF, HTML, Markdown or text file here'**
  String get fileConverterDropSubtitle;

  /// No description provided for @fileConverterConvertTo.
  ///
  /// In en, this message translates to:
  /// **'Convert to'**
  String get fileConverterConvertTo;

  /// No description provided for @fileConverterConvert.
  ///
  /// In en, this message translates to:
  /// **'Convert'**
  String get fileConverterConvert;

  /// No description provided for @fileConverterConverting.
  ///
  /// In en, this message translates to:
  /// **'Converting…'**
  String get fileConverterConverting;

  /// No description provided for @fileConverterUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This file type can\'t be converted'**
  String get fileConverterUnsupported;

  /// No description provided for @fileConverterError.
  ///
  /// In en, this message translates to:
  /// **'Conversion failed: {error}'**
  String fileConverterError(String error);

  /// No description provided for @fileConverterFormatDocx.
  ///
  /// In en, this message translates to:
  /// **'Word (DOCX)'**
  String get fileConverterFormatDocx;

  /// No description provided for @fileConverterFormatPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get fileConverterFormatPdf;

  /// No description provided for @fileConverterFormatHtml.
  ///
  /// In en, this message translates to:
  /// **'HTML'**
  String get fileConverterFormatHtml;

  /// No description provided for @fileConverterFormatMd.
  ///
  /// In en, this message translates to:
  /// **'Markdown'**
  String get fileConverterFormatMd;

  /// No description provided for @fileConverterFormatTxt.
  ///
  /// In en, this message translates to:
  /// **'Plain text'**
  String get fileConverterFormatTxt;

  /// No description provided for @toolNameSketchBoard.
  ///
  /// In en, this message translates to:
  /// **'Sketch Board'**
  String get toolNameSketchBoard;

  /// No description provided for @toolDescSketchBoard.
  ///
  /// In en, this message translates to:
  /// **'Infinite-canvas whiteboard with freehand, shapes, text and saved drawings'**
  String get toolDescSketchBoard;

  /// No description provided for @sketchTabDraw.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get sketchTabDraw;

  /// No description provided for @sketchTabSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get sketchTabSaved;

  /// No description provided for @sketchToolSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get sketchToolSelect;

  /// No description provided for @sketchToolPan.
  ///
  /// In en, this message translates to:
  /// **'Pan'**
  String get sketchToolPan;

  /// No description provided for @sketchToolPen.
  ///
  /// In en, this message translates to:
  /// **'Pen'**
  String get sketchToolPen;

  /// No description provided for @sketchToolLine.
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get sketchToolLine;

  /// No description provided for @sketchToolArrow.
  ///
  /// In en, this message translates to:
  /// **'Arrow'**
  String get sketchToolArrow;

  /// No description provided for @sketchToolRect.
  ///
  /// In en, this message translates to:
  /// **'Rectangle'**
  String get sketchToolRect;

  /// No description provided for @sketchToolEllipse.
  ///
  /// In en, this message translates to:
  /// **'Ellipse'**
  String get sketchToolEllipse;

  /// No description provided for @sketchToolDiamond.
  ///
  /// In en, this message translates to:
  /// **'Diamond'**
  String get sketchToolDiamond;

  /// No description provided for @sketchToolTriangle.
  ///
  /// In en, this message translates to:
  /// **'Triangle'**
  String get sketchToolTriangle;

  /// No description provided for @sketchToolHexagon.
  ///
  /// In en, this message translates to:
  /// **'Hexagon'**
  String get sketchToolHexagon;

  /// No description provided for @sketchToolDoubleArrow.
  ///
  /// In en, this message translates to:
  /// **'Double arrow'**
  String get sketchToolDoubleArrow;

  /// No description provided for @sketchToolSpeechBubble.
  ///
  /// In en, this message translates to:
  /// **'Speech bubble'**
  String get sketchToolSpeechBubble;

  /// No description provided for @sketchToolCheckmark.
  ///
  /// In en, this message translates to:
  /// **'Checkmark'**
  String get sketchToolCheckmark;

  /// No description provided for @sketchToolText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get sketchToolText;

  /// No description provided for @sketchPropStroke.
  ///
  /// In en, this message translates to:
  /// **'Stroke'**
  String get sketchPropStroke;

  /// No description provided for @sketchPropFill.
  ///
  /// In en, this message translates to:
  /// **'Fill'**
  String get sketchPropFill;

  /// No description provided for @sketchPropWidth.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get sketchPropWidth;

  /// No description provided for @sketchPropText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get sketchPropText;

  /// No description provided for @sketchEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Pick a tool and start drawing'**
  String get sketchEmptyHint;

  /// No description provided for @sketchGalleryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No drawings saved yet.'**
  String get sketchGalleryEmpty;

  /// No description provided for @sketchElementCount.
  ///
  /// In en, this message translates to:
  /// **'{count} elements'**
  String sketchElementCount(int count);

  /// No description provided for @sketchTextTitle.
  ///
  /// In en, this message translates to:
  /// **'Add text'**
  String get sketchTextTitle;

  /// No description provided for @sketchTextHint.
  ///
  /// In en, this message translates to:
  /// **'Type text…'**
  String get sketchTextHint;

  /// No description provided for @sketchSaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Save drawing'**
  String get sketchSaveTitle;

  /// No description provided for @sketchSaveHint.
  ///
  /// In en, this message translates to:
  /// **'Drawing name'**
  String get sketchSaveHint;

  /// No description provided for @sketchDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Drawing {date}'**
  String sketchDefaultName(String date);

  /// No description provided for @sketchSaved.
  ///
  /// In en, this message translates to:
  /// **'Drawing saved'**
  String get sketchSaved;

  /// No description provided for @sketchNothingToExport.
  ///
  /// In en, this message translates to:
  /// **'Nothing to draw yet'**
  String get sketchNothingToExport;

  /// No description provided for @sketchCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get sketchCopied;

  /// No description provided for @sketchDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete drawing'**
  String get sketchDeleteTitle;

  /// No description provided for @sketchDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'This will permanently remove the saved drawing.'**
  String get sketchDeleteContent;

  /// No description provided for @sketchClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear canvas'**
  String get sketchClearTitle;

  /// No description provided for @sketchClearContent.
  ///
  /// In en, this message translates to:
  /// **'Remove everything from the canvas?'**
  String get sketchClearContent;

  /// No description provided for @sketchBackgroundTitle.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get sketchBackgroundTitle;

  /// No description provided for @sketchBgCheckerboard.
  ///
  /// In en, this message translates to:
  /// **'Checkerboard'**
  String get sketchBgCheckerboard;

  /// No description provided for @sketchBgWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get sketchBgWhite;

  /// No description provided for @sketchBgBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get sketchBgBlack;

  /// No description provided for @sketchMenuBackground.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get sketchMenuBackground;

  /// No description provided for @sketchMenuResetView.
  ///
  /// In en, this message translates to:
  /// **'Reset view'**
  String get sketchMenuResetView;

  /// No description provided for @sketchUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get sketchUndo;

  /// No description provided for @sketchRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get sketchRedo;

  /// No description provided for @sketchToolShapes.
  ///
  /// In en, this message translates to:
  /// **'Shapes'**
  String get sketchToolShapes;

  /// No description provided for @sketchColorTitle.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get sketchColorTitle;

  /// No description provided for @sketchColorOpacity.
  ///
  /// In en, this message translates to:
  /// **'Opacity'**
  String get sketchColorOpacity;

  /// No description provided for @sketchDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get sketchDiscardTitle;

  /// No description provided for @sketchDiscardMessage.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Discard them?'**
  String get sketchDiscardMessage;

  /// No description provided for @sketchDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get sketchDiscard;

  /// No description provided for @sketchKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get sketchKeepEditing;

  /// No description provided for @sketchBringToFront.
  ///
  /// In en, this message translates to:
  /// **'Bring to front'**
  String get sketchBringToFront;

  /// No description provided for @sketchSendToBack.
  ///
  /// In en, this message translates to:
  /// **'Send to back'**
  String get sketchSendToBack;

  /// No description provided for @sketchGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get sketchGroup;

  /// No description provided for @sketchUngroup.
  ///
  /// In en, this message translates to:
  /// **'Ungroup'**
  String get sketchUngroup;

  /// No description provided for @sketchInsertImage.
  ///
  /// In en, this message translates to:
  /// **'Insert image'**
  String get sketchInsertImage;

  /// No description provided for @sketchPasteImage.
  ///
  /// In en, this message translates to:
  /// **'Paste image'**
  String get sketchPasteImage;

  /// No description provided for @sketchNoClipboardImage.
  ///
  /// In en, this message translates to:
  /// **'No image in clipboard'**
  String get sketchNoClipboardImage;

  /// No description provided for @sketchPropBrush.
  ///
  /// In en, this message translates to:
  /// **'Brush'**
  String get sketchPropBrush;

  /// No description provided for @sketchBrushNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get sketchBrushNormal;

  /// No description provided for @sketchBrushShaky.
  ///
  /// In en, this message translates to:
  /// **'Shaky'**
  String get sketchBrushShaky;

  /// No description provided for @sketchBrushNatural.
  ///
  /// In en, this message translates to:
  /// **'Natural'**
  String get sketchBrushNatural;

  /// No description provided for @sketchSelectBox.
  ///
  /// In en, this message translates to:
  /// **'Box select'**
  String get sketchSelectBox;

  /// No description provided for @sketchSelectLasso.
  ///
  /// In en, this message translates to:
  /// **'Lasso select'**
  String get sketchSelectLasso;

  /// No description provided for @sketchResetImageSize.
  ///
  /// In en, this message translates to:
  /// **'Reset image size'**
  String get sketchResetImageSize;

  /// No description provided for @sketchMenuInfo.
  ///
  /// In en, this message translates to:
  /// **'Board info'**
  String get sketchMenuInfo;

  /// No description provided for @sketchInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Sketch Board Information'**
  String get sketchInfoTitle;

  /// No description provided for @sketchInfoViewportSize.
  ///
  /// In en, this message translates to:
  /// **'Viewport Size'**
  String get sketchInfoViewportSize;

  /// No description provided for @sketchInfoContentBounds.
  ///
  /// In en, this message translates to:
  /// **'Content Dimensions'**
  String get sketchInfoContentBounds;

  /// No description provided for @sketchInfoTotalElements.
  ///
  /// In en, this message translates to:
  /// **'Total Elements'**
  String get sketchInfoTotalElements;

  /// No description provided for @sketchInfoZoomLevel.
  ///
  /// In en, this message translates to:
  /// **'Zoom Level'**
  String get sketchInfoZoomLevel;

  /// No description provided for @sketchInfoElementsBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Elements Breakdown'**
  String get sketchInfoElementsBreakdown;

  /// No description provided for @sketchInfoPenElements.
  ///
  /// In en, this message translates to:
  /// **'Pen Elements'**
  String get sketchInfoPenElements;

  /// No description provided for @sketchInfoShapeElements.
  ///
  /// In en, this message translates to:
  /// **'Shape Elements'**
  String get sketchInfoShapeElements;

  /// No description provided for @sketchInfoTextElements.
  ///
  /// In en, this message translates to:
  /// **'Text Elements'**
  String get sketchInfoTextElements;

  /// No description provided for @sketchInfoImageElements.
  ///
  /// In en, this message translates to:
  /// **'Image Elements'**
  String get sketchInfoImageElements;

  /// No description provided for @sketchInfoGroupElements.
  ///
  /// In en, this message translates to:
  /// **'Group Elements'**
  String get sketchInfoGroupElements;

  /// No description provided for @sketchInfoViewOffset.
  ///
  /// In en, this message translates to:
  /// **'Camera Position'**
  String get sketchInfoViewOffset;

  /// No description provided for @sketchInfoUnsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Unsaved Changes'**
  String get sketchInfoUnsavedChanges;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
