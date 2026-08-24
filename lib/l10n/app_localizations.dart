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

  /// No description provided for @settingsLowLatencyAudio.
  ///
  /// In en, this message translates to:
  /// **'Low Latency Audio'**
  String get settingsLowLatencyAudio;

  /// No description provided for @settingsLowLatencyAudioSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Allows faster audio response. Disable if screen recording has silent audio'**
  String get settingsLowLatencyAudioSubtitle;

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

  /// No description provided for @commonHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get commonHome;

  /// No description provided for @commonBrowseFiles.
  ///
  /// In en, this message translates to:
  /// **'Browse Files'**
  String get commonBrowseFiles;

  /// No description provided for @backgroundTaskOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get backgroundTaskOff;

  /// No description provided for @backgroundTaskEveryMinutes.
  ///
  /// In en, this message translates to:
  /// **'Every {minutes} minutes'**
  String backgroundTaskEveryMinutes(int minutes);

  /// No description provided for @backgroundTaskEveryHours.
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, =1{Every hour} other{Every {hours} hours}}'**
  String backgroundTaskEveryHours(int hours);

  /// No description provided for @backgroundTaskEveryDay.
  ///
  /// In en, this message translates to:
  /// **'Once a day'**
  String get backgroundTaskEveryDay;

  /// No description provided for @backgroundTaskRunNow.
  ///
  /// In en, this message translates to:
  /// **'Run now'**
  String get backgroundTaskRunNow;

  /// No description provided for @backgroundTaskNeverRun.
  ///
  /// In en, this message translates to:
  /// **'Has not run yet'**
  String get backgroundTaskNeverRun;

  /// Result of the last background run. {detail} is a short technical summary reported by the task itself and stays untranslated.
  ///
  /// In en, this message translates to:
  /// **'Last run {when}: {detail}'**
  String backgroundTaskLastRun(String when, String detail);

  /// No description provided for @backgroundTaskDozeHint.
  ///
  /// In en, this message translates to:
  /// **'Android decides when a background run actually happens, so the interval is a limit, not a promise. In deep sleep a run can be hours late.'**
  String get backgroundTaskDozeHint;

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

  /// No description provided for @chipUnsupportedAudioOpenedInternally.
  ///
  /// In en, this message translates to:
  /// **'Opened with the internal audio player'**
  String get chipUnsupportedAudioOpenedInternally;

  /// No description provided for @chipUnsupportedAudioFormat.
  ///
  /// In en, this message translates to:
  /// **'This audio format cannot be played on this device'**
  String get chipUnsupportedAudioFormat;

  /// No description provided for @chipAudioPlaybackFailed.
  ///
  /// In en, this message translates to:
  /// **'Audio playback failed: {error}'**
  String chipAudioPlaybackFailed(Object error);

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

  /// No description provided for @chipLoadFiles.
  ///
  /// In en, this message translates to:
  /// **'Load files'**
  String get chipLoadFiles;

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

  /// No description provided for @treadmillNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Treadmill workout active'**
  String get treadmillNotificationTitle;

  /// No description provided for @treadmillNotificationText.
  ///
  /// In en, this message translates to:
  /// **'ToolLab keeps recording your session'**
  String get treadmillNotificationText;

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

  /// No description provided for @chipRandomTooltip.
  ///
  /// In en, this message translates to:
  /// **'Random tune from The Mod Archive'**
  String get chipRandomTooltip;

  /// No description provided for @chipNextRandomTooltip.
  ///
  /// In en, this message translates to:
  /// **'Next random tune'**
  String get chipNextRandomTooltip;

  /// No description provided for @chipNextTrackTooltip.
  ///
  /// In en, this message translates to:
  /// **'Next track'**
  String get chipNextTrackTooltip;

  /// No description provided for @chipRandomMenuTooltip.
  ///
  /// In en, this message translates to:
  /// **'Random tune'**
  String get chipRandomMenuTooltip;

  /// No description provided for @chipRandomSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get chipRandomSourceLabel;

  /// No description provided for @chipRandomSourceModArchive.
  ///
  /// In en, this message translates to:
  /// **'The Mod Archive'**
  String get chipRandomSourceModArchive;

  /// No description provided for @chipRandomSourceServer.
  ///
  /// In en, this message translates to:
  /// **'My collection (server)'**
  String get chipRandomSourceServer;

  /// No description provided for @chipServerRandomFailed.
  ///
  /// In en, this message translates to:
  /// **'Collection fetch failed: {error}'**
  String chipServerRandomFailed(Object error);

  /// No description provided for @chipPlaylistTitle.
  ///
  /// In en, this message translates to:
  /// **'Playlist ({count})'**
  String chipPlaylistTitle(Object count);

  /// No description provided for @chipFolderTooltip.
  ///
  /// In en, this message translates to:
  /// **'Play folder'**
  String get chipFolderTooltip;

  /// No description provided for @chipFolderEmpty.
  ///
  /// In en, this message translates to:
  /// **'No playable module files in this folder'**
  String get chipFolderEmpty;

  /// No description provided for @chipPlaylistNoSupported.
  ///
  /// In en, this message translates to:
  /// **'No supported module files selected'**
  String get chipPlaylistNoSupported;

  /// No description provided for @chipSelectOutputDevice.
  ///
  /// In en, this message translates to:
  /// **'Select Output Device'**
  String get chipSelectOutputDevice;

  /// No description provided for @chipTweaks.
  ///
  /// In en, this message translates to:
  /// **'Tweaks'**
  String get chipTweaks;

  /// No description provided for @chipInterpolation.
  ///
  /// In en, this message translates to:
  /// **'Interpolation'**
  String get chipInterpolation;

  /// No description provided for @chipInterpolationSinc.
  ///
  /// In en, this message translates to:
  /// **'Sinc (clearest)'**
  String get chipInterpolationSinc;

  /// No description provided for @chipInterpolationCubic.
  ///
  /// In en, this message translates to:
  /// **'Cubic (smooth)'**
  String get chipInterpolationCubic;

  /// No description provided for @chipInterpolationLinear.
  ///
  /// In en, this message translates to:
  /// **'Linear (bright)'**
  String get chipInterpolationLinear;

  /// No description provided for @chipInterpolationNone.
  ///
  /// In en, this message translates to:
  /// **'None (raw)'**
  String get chipInterpolationNone;

  /// No description provided for @chipPreAmp.
  ///
  /// In en, this message translates to:
  /// **'Pre-amp'**
  String get chipPreAmp;

  /// No description provided for @chipAmigaFilter.
  ///
  /// In en, this message translates to:
  /// **'Amiga filter'**
  String get chipAmigaFilter;

  /// No description provided for @chipAmigaFilterAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get chipAmigaFilterAuto;

  /// No description provided for @chipAmigaFilterOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get chipAmigaFilterOn;

  /// No description provided for @chipAmigaFilterOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get chipAmigaFilterOff;

  /// No description provided for @chipVolumeRamping.
  ///
  /// In en, this message translates to:
  /// **'Volume ramping'**
  String get chipVolumeRamping;

  /// No description provided for @chipRampOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get chipRampOff;

  /// No description provided for @chipRampFast.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get chipRampFast;

  /// No description provided for @chipRampSmooth.
  ///
  /// In en, this message translates to:
  /// **'Smooth'**
  String get chipRampSmooth;

  /// No description provided for @chipStereoSeparation.
  ///
  /// In en, this message translates to:
  /// **'Stereo separation'**
  String get chipStereoSeparation;

  /// No description provided for @chipDefaultDevice.
  ///
  /// In en, this message translates to:
  /// **'Default Device'**
  String get chipDefaultDevice;

  /// No description provided for @chipOutputDeviceChanged.
  ///
  /// In en, this message translates to:
  /// **'Output device changed to {name}'**
  String chipOutputDeviceChanged(Object name);

  /// No description provided for @chipRandomTitle.
  ///
  /// In en, this message translates to:
  /// **'Random Tune'**
  String get chipRandomTitle;

  /// No description provided for @chipRandomFetching.
  ///
  /// In en, this message translates to:
  /// **'Fetching a random tune from The Mod Archive…'**
  String get chipRandomFetching;

  /// No description provided for @chipRandomFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not fetch a random tune: {error}'**
  String chipRandomFetchFailed(Object error);

  /// No description provided for @chipRandomRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get chipRandomRetry;

  /// No description provided for @chipRandomShuffleAgain.
  ///
  /// In en, this message translates to:
  /// **'Shuffle again'**
  String get chipRandomShuffleAgain;

  /// No description provided for @chipRandomCredits.
  ///
  /// In en, this message translates to:
  /// **'Source: The Mod Archive — a free repository of tracker music. All rights belong to the original artists.'**
  String get chipRandomCredits;

  /// No description provided for @chipRandomSourceLink.
  ///
  /// In en, this message translates to:
  /// **'View module #{moduleId} on modarchive.org'**
  String chipRandomSourceLink(Object moduleId);

  /// No description provided for @chipMetricFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get chipMetricFormat;

  /// No description provided for @chipMetricGenre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get chipMetricGenre;

  /// No description provided for @chipMetricSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get chipMetricSize;

  /// No description provided for @chipMetricDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get chipMetricDuration;

  /// No description provided for @chipAudioFile.
  ///
  /// In en, this message translates to:
  /// **'Audio file'**
  String get chipAudioFile;

  /// No description provided for @chipStereoWidth.
  ///
  /// In en, this message translates to:
  /// **'Stereo Width'**
  String get chipStereoWidth;

  /// No description provided for @chipExportToWav.
  ///
  /// In en, this message translates to:
  /// **'Export to WAV'**
  String get chipExportToWav;

  /// No description provided for @chipExportingToWav.
  ///
  /// In en, this message translates to:
  /// **'Exporting to WAV…'**
  String get chipExportingToWav;

  /// No description provided for @chipExportSuccess.
  ///
  /// In en, this message translates to:
  /// **'WAV file exported successfully'**
  String get chipExportSuccess;

  /// No description provided for @chipExportFailed.
  ///
  /// In en, this message translates to:
  /// **'WAV export failed: {error}'**
  String chipExportFailed(String error);

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

  /// No description provided for @coreDatabaseSize.
  ///
  /// In en, this message translates to:
  /// **'Current database size: {size}'**
  String coreDatabaseSize(String size);

  /// No description provided for @coreDatabaseSizeLoading.
  ///
  /// In en, this message translates to:
  /// **'Current database size: Loading...'**
  String get coreDatabaseSizeLoading;

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

  /// No description provided for @coreSyncStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Server Statistics'**
  String get coreSyncStatsTitle;

  /// No description provided for @coreSyncStatsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What the backend is storing, per tool'**
  String get coreSyncStatsSubtitle;

  /// No description provided for @coreSyncStatsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get coreSyncStatsRefresh;

  /// No description provided for @coreSyncStatsItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get coreSyncStatsItems;

  /// No description provided for @coreSyncStatsDeleted.
  ///
  /// In en, this message translates to:
  /// **'Tombstones'**
  String get coreSyncStatsDeleted;

  /// No description provided for @coreSyncStatsData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get coreSyncStatsData;

  /// No description provided for @coreSyncStatsTotalSize.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get coreSyncStatsTotalSize;

  /// No description provided for @coreSyncStatsEmpty.
  ///
  /// In en, this message translates to:
  /// **'The server is not storing anything yet.'**
  String get coreSyncStatsEmpty;

  /// No description provided for @coreSyncStatsUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This server does not report statistics. Update the backend to a version that provides /api/sync/stats.'**
  String get coreSyncStatsUnsupported;

  /// No description provided for @coreSyncStatsBinary.
  ///
  /// In en, this message translates to:
  /// **'Binary ({count})'**
  String coreSyncStatsBinary(int count);

  /// No description provided for @coreSyncStatsTotals.
  ///
  /// In en, this message translates to:
  /// **'{count} tools on the server'**
  String coreSyncStatsTotals(int count);

  /// No description provided for @coreSyncToolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tools to Synchronize'**
  String get coreSyncToolsTitle;

  /// No description provided for @coreSyncToolsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose which tools take part. New tools start switched on.'**
  String get coreSyncToolsSubtitle;

  /// No description provided for @coreSyncToolsDisabledHint.
  ///
  /// In en, this message translates to:
  /// **'A switched-off tool stops syncing but keeps its data on the server.'**
  String get coreSyncToolsDisabledHint;

  /// No description provided for @coreSyncToolDisabled.
  ///
  /// In en, this message translates to:
  /// **'Sync is switched off for this tool in the sync settings.'**
  String get coreSyncToolDisabled;

  /// No description provided for @coreSyncBackgroundTitle.
  ///
  /// In en, this message translates to:
  /// **'Background Sync'**
  String get coreSyncBackgroundTitle;

  /// No description provided for @coreSyncBackgroundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How often a full sync of all enabled tools runs in the background while the app is closed.'**
  String get coreSyncBackgroundSubtitle;

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

  /// No description provided for @fastDropProgressDetails.
  ///
  /// In en, this message translates to:
  /// **'{transferred} / {total} ({speed} MB/s, {seconds}s)'**
  String fastDropProgressDetails(
    String transferred,
    String total,
    String speed,
    String seconds,
  );

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

  /// No description provided for @fastDropOpenFile.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get fastDropOpenFile;

  /// No description provided for @fastDropDownloadFile.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get fastDropDownloadFile;

  /// No description provided for @fastDropModeCloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get fastDropModeCloud;

  /// No description provided for @fastDropModeNearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get fastDropModeNearby;

  /// No description provided for @fastDropP2pStartReceiving.
  ///
  /// In en, this message translates to:
  /// **'Start Receiving'**
  String get fastDropP2pStartReceiving;

  /// No description provided for @fastDropP2pStopReceiving.
  ///
  /// In en, this message translates to:
  /// **'Stop Receiving'**
  String get fastDropP2pStopReceiving;

  /// No description provided for @fastDropP2pWaitingForSender.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a nearby device to send a file...'**
  String get fastDropP2pWaitingForSender;

  /// No description provided for @fastDropP2pAbortSend.
  ///
  /// In en, this message translates to:
  /// **'Cancel send'**
  String get fastDropP2pAbortSend;

  /// No description provided for @fastDropP2pWaitingForReceiver.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a nearby device to start receiving...'**
  String get fastDropP2pWaitingForReceiver;

  /// No description provided for @fastDropP2pPeersFoundPickOne.
  ///
  /// In en, this message translates to:
  /// **'Device found — pick it below to send'**
  String get fastDropP2pPeersFoundPickOne;

  /// No description provided for @fastDropP2pEstimateWifi.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi: {duration}'**
  String fastDropP2pEstimateWifi(String duration);

  /// No description provided for @fastDropP2pEstimateBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth: {duration}'**
  String fastDropP2pEstimateBluetooth(String duration);

  /// No description provided for @fastDropP2pSendSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'SEND A FILE'**
  String get fastDropP2pSendSectionTitle;

  /// No description provided for @fastDropP2pReceivedSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'RECEIVED FILES'**
  String get fastDropP2pReceivedSectionTitle;

  /// No description provided for @fastDropP2pPickFileToSend.
  ///
  /// In en, this message translates to:
  /// **'Pick a file to send'**
  String get fastDropP2pPickFileToSend;

  /// No description provided for @fastDropP2pScanningForPeers.
  ///
  /// In en, this message translates to:
  /// **'Searching for nearby devices...'**
  String get fastDropP2pScanningForPeers;

  /// No description provided for @fastDropP2pNoPeersFound.
  ///
  /// In en, this message translates to:
  /// **'No nearby devices found yet. Make sure the other device tapped \"Start Receiving\".'**
  String get fastDropP2pNoPeersFound;

  /// No description provided for @fastDropP2pSignalStrength.
  ///
  /// In en, this message translates to:
  /// **'Signal: {rssi} dBm'**
  String fastDropP2pSignalStrength(int rssi);

  /// No description provided for @fastDropP2pLocalNetwork.
  ///
  /// In en, this message translates to:
  /// **'Local network'**
  String get fastDropP2pLocalNetwork;

  /// No description provided for @fastDropP2pSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get fastDropP2pSend;

  /// No description provided for @fastDropP2pTransferringLan.
  ///
  /// In en, this message translates to:
  /// **'Sending over Wi-Fi'**
  String get fastDropP2pTransferringLan;

  /// No description provided for @fastDropP2pTransferringBle.
  ///
  /// In en, this message translates to:
  /// **'Sending over Bluetooth'**
  String get fastDropP2pTransferringBle;

  /// No description provided for @fastDropP2pBleFallbackWarning.
  ///
  /// In en, this message translates to:
  /// **'No shared network found — transferring over Bluetooth, which is much slower. Connect both devices to the same Wi-Fi network for faster transfers.'**
  String get fastDropP2pBleFallbackWarning;

  /// No description provided for @fastDropP2pIncomingTitle.
  ///
  /// In en, this message translates to:
  /// **'Incoming File'**
  String get fastDropP2pIncomingTitle;

  /// No description provided for @fastDropP2pIncomingMessage.
  ///
  /// In en, this message translates to:
  /// **'{sender} wants to send you \"{filename}\" ({size}). Accept the transfer?'**
  String fastDropP2pIncomingMessage(
    String sender,
    String filename,
    String size,
  );

  /// No description provided for @fastDropP2pAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get fastDropP2pAccept;

  /// No description provided for @fastDropP2pDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get fastDropP2pDecline;

  /// No description provided for @fastDropP2pErrorBleConnect.
  ///
  /// In en, this message translates to:
  /// **'Could not establish a Bluetooth connection to the device. Move the devices closer together, make sure the other device still shows \"Waiting for a sender\", then try again.'**
  String get fastDropP2pErrorBleConnect;

  /// No description provided for @fastDropP2pErrorDeclined.
  ///
  /// In en, this message translates to:
  /// **'The other device declined the transfer.'**
  String get fastDropP2pErrorDeclined;

  /// No description provided for @fastDropP2pErrorStalled.
  ///
  /// In en, this message translates to:
  /// **'The Bluetooth transfer stopped making progress and was aborted. Keep both devices close and awake, then start the transfer again.'**
  String get fastDropP2pErrorStalled;

  /// No description provided for @fastDropP2pDismissFile.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get fastDropP2pDismissFile;

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

  /// No description provided for @focusPausedSound.
  ///
  /// In en, this message translates to:
  /// **'Paused {name}'**
  String focusPausedSound(String name);

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
  /// **'Supports PNG, JPEG, WebP, BMP, GIF, TIFF, ICO'**
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

  /// No description provided for @imgViewUnsupportedTitle.
  ///
  /// In en, this message translates to:
  /// **'Format cannot be displayed'**
  String get imgViewUnsupportedTitle;

  /// No description provided for @imgViewUnsupportedMessage.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" uses an image format the viewer cannot decode. Open it with a system app instead.'**
  String imgViewUnsupportedMessage(String name);

  /// No description provided for @imgViewOpenExternally.
  ///
  /// In en, this message translates to:
  /// **'Open with system app'**
  String get imgViewOpenExternally;

  /// No description provided for @imgViewChooseAnother.
  ///
  /// In en, this message translates to:
  /// **'Choose another image'**
  String get imgViewChooseAnother;

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

  /// No description provided for @miscCalculatorPasteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Paste from clipboard'**
  String get miscCalculatorPasteTooltip;

  /// No description provided for @miscCalculatorPasteInvalid.
  ///
  /// In en, this message translates to:
  /// **'Clipboard has no usable number'**
  String get miscCalculatorPasteInvalid;

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

  /// No description provided for @miscBatteryChargingSlow.
  ///
  /// In en, this message translates to:
  /// **'Slow Charging'**
  String get miscBatteryChargingSlow;

  /// No description provided for @miscBatteryChargingNormal.
  ///
  /// In en, this message translates to:
  /// **'Charging'**
  String get miscBatteryChargingNormal;

  /// No description provided for @miscBatteryChargingFast.
  ///
  /// In en, this message translates to:
  /// **'Fast Charging'**
  String get miscBatteryChargingFast;

  /// No description provided for @miscBatteryVoltage.
  ///
  /// In en, this message translates to:
  /// **'Voltage'**
  String get miscBatteryVoltage;

  /// No description provided for @miscBatteryCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get miscBatteryCurrent;

  /// No description provided for @miscBatteryPower.
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get miscBatteryPower;

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

  /// No description provided for @miscDeviceInfoWindowsDisplayResolution.
  ///
  /// In en, this message translates to:
  /// **'Current Display Resolution'**
  String get miscDeviceInfoWindowsDisplayResolution;

  /// No description provided for @miscDeviceInfoAppViewSize.
  ///
  /// In en, this message translates to:
  /// **'App View Size'**
  String get miscDeviceInfoAppViewSize;

  /// No description provided for @miscDeviceInfoAppViewPixels.
  ///
  /// In en, this message translates to:
  /// **'App View Pixels'**
  String get miscDeviceInfoAppViewPixels;

  /// No description provided for @miscDeviceInfoDisplayScale.
  ///
  /// In en, this message translates to:
  /// **'Display Scale'**
  String get miscDeviceInfoDisplayScale;

  /// No description provided for @miscDeviceInfoOrientation.
  ///
  /// In en, this message translates to:
  /// **'Orientation'**
  String get miscDeviceInfoOrientation;

  /// No description provided for @miscDeviceInfoRefreshRate.
  ///
  /// In en, this message translates to:
  /// **'Refresh Rate'**
  String get miscDeviceInfoRefreshRate;

  /// No description provided for @miscDeviceInfoCpuModel.
  ///
  /// In en, this message translates to:
  /// **'CPU Model'**
  String get miscDeviceInfoCpuModel;

  /// No description provided for @miscDeviceInfoCpuArchitecture.
  ///
  /// In en, this message translates to:
  /// **'CPU Architecture'**
  String get miscDeviceInfoCpuArchitecture;

  /// No description provided for @miscDeviceInfoGpuModel.
  ///
  /// In en, this message translates to:
  /// **'GPU Model'**
  String get miscDeviceInfoGpuModel;

  /// No description provided for @miscDeviceInfoGpuVram.
  ///
  /// In en, this message translates to:
  /// **'GPU VRAM'**
  String get miscDeviceInfoGpuVram;

  /// No description provided for @miscDeviceInfoSystemUptime.
  ///
  /// In en, this message translates to:
  /// **'System Uptime'**
  String get miscDeviceInfoSystemUptime;

  /// No description provided for @miscDeviceInfoWindowsUptime.
  ///
  /// In en, this message translates to:
  /// **'Uptime Since Last Full Restart'**
  String get miscDeviceInfoWindowsUptime;

  /// No description provided for @miscDeviceInfoUptimeDays.
  ///
  /// In en, this message translates to:
  /// **'{days}d {hours}h'**
  String miscDeviceInfoUptimeDays(int days, int hours);

  /// No description provided for @miscDeviceInfoUptimeHours.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String miscDeviceInfoUptimeHours(int hours, int minutes);

  /// No description provided for @miscDeviceInfoStorageVolume.
  ///
  /// In en, this message translates to:
  /// **'Storage: {name}'**
  String miscDeviceInfoStorageVolume(Object name);

  /// No description provided for @miscDeviceInfoFree.
  ///
  /// In en, this message translates to:
  /// **'free'**
  String get miscDeviceInfoFree;

  /// No description provided for @miscDeviceInfoWifiSsid.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi SSID'**
  String get miscDeviceInfoWifiSsid;

  /// No description provided for @miscDeviceInfoWifiSignal.
  ///
  /// In en, this message translates to:
  /// **'Signal'**
  String get miscDeviceInfoWifiSignal;

  /// No description provided for @miscDeviceInfoWifiLinkSpeed.
  ///
  /// In en, this message translates to:
  /// **'Link Speed'**
  String get miscDeviceInfoWifiLinkSpeed;

  /// No description provided for @miscDeviceInfoWifiFrequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get miscDeviceInfoWifiFrequency;

  /// No description provided for @miscDeviceInfoGeneralSettings.
  ///
  /// In en, this message translates to:
  /// **'General Settings'**
  String get miscDeviceInfoGeneralSettings;

  /// No description provided for @miscDeviceInfoStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage & Memory'**
  String get miscDeviceInfoStorage;

  /// No description provided for @miscDeviceInfoNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network Connection'**
  String get miscDeviceInfoNetwork;

  /// No description provided for @miscDeviceInfoSensors.
  ///
  /// In en, this message translates to:
  /// **'Available Sensors'**
  String get miscDeviceInfoSensors;

  /// No description provided for @miscDeviceInfoAppInfo.
  ///
  /// In en, this message translates to:
  /// **'Application Info'**
  String get miscDeviceInfoAppInfo;

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

  /// No description provided for @miscMarkdownReloaded.
  ///
  /// In en, this message translates to:
  /// **'Reloaded from disk'**
  String get miscMarkdownReloaded;

  /// No description provided for @miscMarkdownReloadNoChange.
  ///
  /// In en, this message translates to:
  /// **'File unchanged'**
  String get miscMarkdownReloadNoChange;

  /// No description provided for @miscMarkdownReloadMissing.
  ///
  /// In en, this message translates to:
  /// **'File no longer exists on disk'**
  String get miscMarkdownReloadMissing;

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

  /// No description provided for @notesSaveKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Save and keep editing'**
  String get notesSaveKeepEditing;

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

  /// No description provided for @notesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Notes Found'**
  String get notesEmptyTitle;

  /// No description provided for @notesEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Create a new note or drag and drop a Markdown (.md) file to import.'**
  String get notesEmptyDescription;

  /// No description provided for @notesArchiveEntryCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 note} other{{count} notes}}'**
  String notesArchiveEntryCount(int count);

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

  /// No description provided for @notesEditorToolbarTitle.
  ///
  /// In en, this message translates to:
  /// **'Formatting Tools'**
  String get notesEditorToolbarTitle;

  /// No description provided for @notesEditorTagsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get notesEditorTagsTitle;

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

  /// No description provided for @notesToggleSourceMode.
  ///
  /// In en, this message translates to:
  /// **'Show Markdown Source'**
  String get notesToggleSourceMode;

  /// No description provided for @notesToggleLiveMode.
  ///
  /// In en, this message translates to:
  /// **'Show Styled Preview'**
  String get notesToggleLiveMode;

  /// No description provided for @notesModeLiveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Live Editor (with markdown syntax)'**
  String get notesModeLiveTooltip;

  /// No description provided for @notesModeSourceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Markdown Source (raw text)'**
  String get notesModeSourceTooltip;

  /// No description provided for @notesModePreviewTooltip.
  ///
  /// In en, this message translates to:
  /// **'Preview (without markdown syntax)'**
  String get notesModePreviewTooltip;

  /// No description provided for @notesToolbarImage.
  ///
  /// In en, this message translates to:
  /// **'Insert Image'**
  String get notesToolbarImage;

  /// No description provided for @notesImageSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Insert Image'**
  String get notesImageSourceTitle;

  /// No description provided for @notesImageSourceGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get notesImageSourceGallery;

  /// No description provided for @notesImageSourceCamera.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get notesImageSourceCamera;

  /// No description provided for @notesImageSourceClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste from Clipboard'**
  String get notesImageSourceClipboard;

  /// No description provided for @notesImageSourceClipboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'No image in clipboard'**
  String get notesImageSourceClipboardEmpty;

  /// No description provided for @notesImageProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing image...'**
  String get notesImageProcessing;

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

  /// No description provided for @pdfEditRedactTitle.
  ///
  /// In en, this message translates to:
  /// **'Redact: {fileName}'**
  String pdfEditRedactTitle(String fileName);

  /// No description provided for @pdfEditRedactFailed.
  ///
  /// In en, this message translates to:
  /// **'Redaction failed: {error}'**
  String pdfEditRedactFailed(String error);

  /// No description provided for @pdfEditRedactPageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String pdfEditRedactPageOf(int current, int total);

  /// No description provided for @pdfEditRedactDrawHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to draw a redaction rectangle'**
  String get pdfEditRedactDrawHint;

  /// No description provided for @pdfEditRedactModeDraw.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get pdfEditRedactModeDraw;

  /// No description provided for @pdfEditRedactModeNavigate.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get pdfEditRedactModeNavigate;

  /// No description provided for @pdfEditRedactModeSelect.
  ///
  /// In en, this message translates to:
  /// **'Select Text'**
  String get pdfEditRedactModeSelect;

  /// No description provided for @pdfEditRedactProcessing.
  ///
  /// In en, this message translates to:
  /// **'Applying redactions…'**
  String get pdfEditRedactProcessing;

  /// No description provided for @pdfEditRedactDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Redaction Complete'**
  String get pdfEditRedactDoneTitle;

  /// No description provided for @pdfEditRedactDoneSize.
  ///
  /// In en, this message translates to:
  /// **'Redacted PDF size: {size}'**
  String pdfEditRedactDoneSize(String size);

  /// No description provided for @pdfEditRedactRedactSelected.
  ///
  /// In en, this message translates to:
  /// **'Redact Selected'**
  String get pdfEditRedactRedactSelected;

  /// No description provided for @pdfEditRedactSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Select text in the document, then tap \"Redact Selected\"'**
  String get pdfEditRedactSelectHint;

  /// No description provided for @pdfEditRedactFindTooltip.
  ///
  /// In en, this message translates to:
  /// **'Find text'**
  String get pdfEditRedactFindTooltip;

  /// No description provided for @pdfEditRedactFindTitle.
  ///
  /// In en, this message translates to:
  /// **'Find Text to Redact'**
  String get pdfEditRedactFindTitle;

  /// No description provided for @pdfEditRedactFindFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Search text'**
  String get pdfEditRedactFindFieldLabel;

  /// No description provided for @pdfEditRedactFindMarkAll.
  ///
  /// In en, this message translates to:
  /// **'Mark All'**
  String get pdfEditRedactFindMarkAll;

  /// No description provided for @pdfEditRedactFoundCount.
  ///
  /// In en, this message translates to:
  /// **'{count} occurrence(s) marked'**
  String pdfEditRedactFoundCount(int count);

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

  /// No description provided for @pdfNavModeExtractText.
  ///
  /// In en, this message translates to:
  /// **'Extract Text'**
  String get pdfNavModeExtractText;

  /// No description provided for @pdfExtractTextTitle.
  ///
  /// In en, this message translates to:
  /// **'Extract Text: {fileName}'**
  String pdfExtractTextTitle(String fileName);

  /// No description provided for @pdfExtractTextProgress.
  ///
  /// In en, this message translates to:
  /// **'Extracting text… {current}/{total}'**
  String pdfExtractTextProgress(int current, int total);

  /// No description provided for @pdfExtractTextEmpty.
  ///
  /// In en, this message translates to:
  /// **'No extractable text found in this PDF. It may be scanned or image-only.'**
  String get pdfExtractTextEmpty;

  /// No description provided for @pdfExtractTextFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to extract text: {error}'**
  String pdfExtractTextFailed(String error);

  /// No description provided for @pdfExtractTextCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get pdfExtractTextCopy;

  /// No description provided for @pdfExtractTextCopied.
  ///
  /// In en, this message translates to:
  /// **'Text copied to clipboard'**
  String get pdfExtractTextCopied;

  /// No description provided for @pdfExtractTextSave.
  ///
  /// In en, this message translates to:
  /// **'Save as .txt'**
  String get pdfExtractTextSave;

  /// No description provided for @pdfExtractTextAskHint.
  ///
  /// In en, this message translates to:
  /// **'Ask a question about this text…'**
  String get pdfExtractTextAskHint;

  /// No description provided for @pdfExtractTextAskSend.
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get pdfExtractTextAskSend;

  /// No description provided for @pdfExtractTextThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking…'**
  String get pdfExtractTextThinking;

  /// No description provided for @pdfExtractTextTruncatedNote.
  ///
  /// In en, this message translates to:
  /// **'Note: only the first part of the text is sent to the on-device AI.'**
  String get pdfExtractTextTruncatedNote;

  /// No description provided for @textToolsSummarize.
  ///
  /// In en, this message translates to:
  /// **'Summarize'**
  String get textToolsSummarize;

  /// No description provided for @textToolsKeywords.
  ///
  /// In en, this message translates to:
  /// **'Keywords'**
  String get textToolsKeywords;

  /// No description provided for @textToolsSourceAi.
  ///
  /// In en, this message translates to:
  /// **'AI answer'**
  String get textToolsSourceAi;

  /// No description provided for @textToolsSourceOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline result — best-matching passages'**
  String get textToolsSourceOffline;

  /// No description provided for @textToolsSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Summary (offline)'**
  String get textToolsSummaryTitle;

  /// No description provided for @textToolsKeywordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Keywords (offline)'**
  String get textToolsKeywordsTitle;

  /// No description provided for @genaiOfflineAnalysisActive.
  ///
  /// In en, this message translates to:
  /// **'On-device AI unavailable — offline text analysis is active.'**
  String get genaiOfflineAnalysisActive;

  /// No description provided for @pdfNavModeMetadata.
  ///
  /// In en, this message translates to:
  /// **'Metadata'**
  String get pdfNavModeMetadata;

  /// No description provided for @pdfNavModeRedact.
  ///
  /// In en, this message translates to:
  /// **'Redact PDF'**
  String get pdfNavModeRedact;

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

  /// No description provided for @widgetMarkdownReload.
  ///
  /// In en, this message translates to:
  /// **'Reload from disk'**
  String get widgetMarkdownReload;

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

  /// No description provided for @widgetMarkdownImageEnlarge.
  ///
  /// In en, this message translates to:
  /// **'Tap to enlarge'**
  String get widgetMarkdownImageEnlarge;

  /// No description provided for @widgetMarkdownFrontmatter.
  ///
  /// In en, this message translates to:
  /// **'Frontmatter'**
  String get widgetMarkdownFrontmatter;

  /// No description provided for @widgetMarkdownFrontmatterInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid frontmatter YAML: {error}'**
  String widgetMarkdownFrontmatterInvalid(String error);

  /// No description provided for @widgetMarkdownCodeCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get widgetMarkdownCodeCopy;

  /// No description provided for @widgetMarkdownCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get widgetMarkdownCodeCopied;

  /// No description provided for @widgetMarkdownCodeLanguageAuto.
  ///
  /// In en, this message translates to:
  /// **'{language} · auto'**
  String widgetMarkdownCodeLanguageAuto(String language);

  /// No description provided for @widgetMarkdownCodeCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse code'**
  String get widgetMarkdownCodeCollapse;

  /// No description provided for @widgetMarkdownCodeExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand code'**
  String get widgetMarkdownCodeExpand;

  /// No description provided for @widgetMarkdownCodeLines.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 line} other{{count} lines}}'**
  String widgetMarkdownCodeLines(int count);

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

  /// No description provided for @toolNameGroceryList.
  ///
  /// In en, this message translates to:
  /// **'Grocery List'**
  String get toolNameGroceryList;

  /// No description provided for @toolDescGroceryList.
  ///
  /// In en, this message translates to:
  /// **'Create grocery lists with quantities, reusable items, and check-off tracking'**
  String get toolDescGroceryList;

  /// No description provided for @groceryNoItems.
  ///
  /// In en, this message translates to:
  /// **'No items in your grocery list'**
  String get groceryNoItems;

  /// No description provided for @groceryAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add Item'**
  String get groceryAddItem;

  /// No description provided for @groceryEditItem.
  ///
  /// In en, this message translates to:
  /// **'Edit Item'**
  String get groceryEditItem;

  /// No description provided for @groceryItemName.
  ///
  /// In en, this message translates to:
  /// **'Item name'**
  String get groceryItemName;

  /// No description provided for @groceryAmount.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get groceryAmount;

  /// No description provided for @groceryUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get groceryUnit;

  /// No description provided for @groceryAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get groceryAdd;

  /// No description provided for @groceryUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get groceryUpdate;

  /// No description provided for @groceryClearBought.
  ///
  /// In en, this message translates to:
  /// **'Clear bought'**
  String get groceryClearBought;

  /// No description provided for @groceryReAddBought.
  ///
  /// In en, this message translates to:
  /// **'Re-add bought'**
  String get groceryReAddBought;

  /// No description provided for @groceryExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get groceryExport;

  /// No description provided for @groceryImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get groceryImport;

  /// No description provided for @groceryConfirmClearBought.
  ///
  /// In en, this message translates to:
  /// **'Remove {count} bought item(s)?'**
  String groceryConfirmClearBought(int count);

  /// No description provided for @groceryConfirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String groceryConfirmDelete(String name);

  /// No description provided for @groceryImportComplete.
  ///
  /// In en, this message translates to:
  /// **'Import complete! Imported: {imported}, Skipped: {skipped} (duplicates).'**
  String groceryImportComplete(int imported, int skipped);

  /// No description provided for @groceryImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String groceryImportFailed(String error);

  /// No description provided for @groceryItemsCount.
  ///
  /// In en, this message translates to:
  /// **'{unchecked} to buy, {checked} bought'**
  String groceryItemsCount(int unchecked, int checked);

  /// No description provided for @groceryAllBoughtMovedBack.
  ///
  /// In en, this message translates to:
  /// **'All bought items moved back to list.'**
  String get groceryAllBoughtMovedBack;

  /// No description provided for @grocerySync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get grocerySync;

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
  /// **'Play tracker modules and audio files'**
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

  /// No description provided for @qrCameraZoom.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get qrCameraZoom;

  /// No description provided for @qrCameraTorch.
  ///
  /// In en, this message translates to:
  /// **'Flashlight'**
  String get qrCameraTorch;

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

  /// No description provided for @qrKindFido.
  ///
  /// In en, this message translates to:
  /// **'Passkey Request'**
  String get qrKindFido;

  /// No description provided for @qrKindOtp.
  ///
  /// In en, this message translates to:
  /// **'2FA / Authenticator'**
  String get qrKindOtp;

  /// No description provided for @qrKindMath.
  ///
  /// In en, this message translates to:
  /// **'Mathematical Expression'**
  String get qrKindMath;

  /// No description provided for @qrKindCoordinate.
  ///
  /// In en, this message translates to:
  /// **'Coordinates'**
  String get qrKindCoordinate;

  /// No description provided for @qrKindNumber.
  ///
  /// In en, this message translates to:
  /// **'Numeric Value'**
  String get qrKindNumber;

  /// No description provided for @qrResultFulfillPasskey.
  ///
  /// In en, this message translates to:
  /// **'Fulfill Passkey'**
  String get qrResultFulfillPasskey;

  /// No description provided for @qrResultOpenAuthenticator.
  ///
  /// In en, this message translates to:
  /// **'Add to Authenticator'**
  String get qrResultOpenAuthenticator;

  /// No description provided for @qrResultCalculate.
  ///
  /// In en, this message translates to:
  /// **'Calculate'**
  String get qrResultCalculate;

  /// No description provided for @qrResultShowOnMap.
  ///
  /// In en, this message translates to:
  /// **'Show on Map'**
  String get qrResultShowOnMap;

  /// No description provided for @qrResultConvertUnit.
  ///
  /// In en, this message translates to:
  /// **'Convert Unit'**
  String get qrResultConvertUnit;

  /// No description provided for @qrResultUseInCalc.
  ///
  /// In en, this message translates to:
  /// **'Use in Calculator'**
  String get qrResultUseInCalc;

  /// No description provided for @qrResultSimulatePasskey.
  ///
  /// In en, this message translates to:
  /// **'Simulate Passkey'**
  String get qrResultSimulatePasskey;

  /// No description provided for @qrPasskeySimTitle.
  ///
  /// In en, this message translates to:
  /// **'Passkey Simulator'**
  String get qrPasskeySimTitle;

  /// No description provided for @qrPasskeySimSuccess.
  ///
  /// In en, this message translates to:
  /// **'Mock Passkey successfully signed the request!'**
  String get qrPasskeySimSuccess;

  /// No description provided for @qrPasskeySimPrompt.
  ///
  /// In en, this message translates to:
  /// **'Confirm biometric fingerprint or PIN to authorize authentication.'**
  String get qrPasskeySimPrompt;

  /// No description provided for @qrPasskeySimUser.
  ///
  /// In en, this message translates to:
  /// **'User: alice@example.com'**
  String get qrPasskeySimUser;

  /// No description provided for @qrPasskeySimDomain.
  ///
  /// In en, this message translates to:
  /// **'Domain: secure.login'**
  String get qrPasskeySimDomain;

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

  /// No description provided for @sketchExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export image'**
  String get sketchExportTitle;

  /// No description provided for @sketchExportFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get sketchExportFormat;

  /// No description provided for @sketchExportQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get sketchExportQuality;

  /// No description provided for @sketchExportLossless.
  ///
  /// In en, this message translates to:
  /// **'PNG is lossless — no quality setting.'**
  String get sketchExportLossless;

  /// No description provided for @sketchExportResolution.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get sketchExportResolution;

  /// No description provided for @sketchExportEstimatedSize.
  ///
  /// In en, this message translates to:
  /// **'Estimated size'**
  String get sketchExportEstimatedSize;

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

  /// No description provided for @sketchResetRotation.
  ///
  /// In en, this message translates to:
  /// **'Reset rotation'**
  String get sketchResetRotation;

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

  /// No description provided for @toolNameUnitConverter.
  ///
  /// In en, this message translates to:
  /// **'Unit Converter'**
  String get toolNameUnitConverter;

  /// No description provided for @toolDescUnitConverter.
  ///
  /// In en, this message translates to:
  /// **'Convert between units across many categories'**
  String get toolDescUnitConverter;

  /// No description provided for @ucFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get ucFrom;

  /// No description provided for @ucTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get ucTo;

  /// No description provided for @ucSwap.
  ///
  /// In en, this message translates to:
  /// **'Swap units'**
  String get ucSwap;

  /// No description provided for @ucCopyResult.
  ///
  /// In en, this message translates to:
  /// **'Copy result'**
  String get ucCopyResult;

  /// No description provided for @ucCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get ucCopied;

  /// No description provided for @ucValueHint.
  ///
  /// In en, this message translates to:
  /// **'Enter value'**
  String get ucValueHint;

  /// No description provided for @ucAllUnits.
  ///
  /// In en, this message translates to:
  /// **'All units'**
  String get ucAllUnits;

  /// No description provided for @ucCatLength.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get ucCatLength;

  /// No description provided for @ucCatMass.
  ///
  /// In en, this message translates to:
  /// **'Mass'**
  String get ucCatMass;

  /// No description provided for @ucCatTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get ucCatTemperature;

  /// No description provided for @ucCatArea.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get ucCatArea;

  /// No description provided for @ucCatVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get ucCatVolume;

  /// No description provided for @ucCatSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get ucCatSpeed;

  /// No description provided for @ucCatTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get ucCatTime;

  /// No description provided for @ucCatData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get ucCatData;

  /// No description provided for @ucCatPressure.
  ///
  /// In en, this message translates to:
  /// **'Pressure'**
  String get ucCatPressure;

  /// No description provided for @ucCatEnergy.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get ucCatEnergy;

  /// No description provided for @ucCatPower.
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get ucCatPower;

  /// No description provided for @ucCatAngle.
  ///
  /// In en, this message translates to:
  /// **'Angle'**
  String get ucCatAngle;

  /// No description provided for @ucCatFrequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get ucCatFrequency;

  /// No description provided for @ucCatDataRate.
  ///
  /// In en, this message translates to:
  /// **'Data Rate'**
  String get ucCatDataRate;

  /// No description provided for @ucCatFuel.
  ///
  /// In en, this message translates to:
  /// **'Fuel Economy'**
  String get ucCatFuel;

  /// No description provided for @ucuMeter.
  ///
  /// In en, this message translates to:
  /// **'Meter'**
  String get ucuMeter;

  /// No description provided for @ucuKilometer.
  ///
  /// In en, this message translates to:
  /// **'Kilometer'**
  String get ucuKilometer;

  /// No description provided for @ucuCentimeter.
  ///
  /// In en, this message translates to:
  /// **'Centimeter'**
  String get ucuCentimeter;

  /// No description provided for @ucuMillimeter.
  ///
  /// In en, this message translates to:
  /// **'Millimeter'**
  String get ucuMillimeter;

  /// No description provided for @ucuMile.
  ///
  /// In en, this message translates to:
  /// **'Mile'**
  String get ucuMile;

  /// No description provided for @ucuYard.
  ///
  /// In en, this message translates to:
  /// **'Yard'**
  String get ucuYard;

  /// No description provided for @ucuFoot.
  ///
  /// In en, this message translates to:
  /// **'Foot'**
  String get ucuFoot;

  /// No description provided for @ucuInch.
  ///
  /// In en, this message translates to:
  /// **'Inch'**
  String get ucuInch;

  /// No description provided for @ucuKilogram.
  ///
  /// In en, this message translates to:
  /// **'Kilogram'**
  String get ucuKilogram;

  /// No description provided for @ucuGram.
  ///
  /// In en, this message translates to:
  /// **'Gram'**
  String get ucuGram;

  /// No description provided for @ucuMilligram.
  ///
  /// In en, this message translates to:
  /// **'Milligram'**
  String get ucuMilligram;

  /// No description provided for @ucuMetricTon.
  ///
  /// In en, this message translates to:
  /// **'Metric ton'**
  String get ucuMetricTon;

  /// No description provided for @ucuPound.
  ///
  /// In en, this message translates to:
  /// **'Pound'**
  String get ucuPound;

  /// No description provided for @ucuOunce.
  ///
  /// In en, this message translates to:
  /// **'Ounce'**
  String get ucuOunce;

  /// No description provided for @ucuStone.
  ///
  /// In en, this message translates to:
  /// **'Stone'**
  String get ucuStone;

  /// No description provided for @ucuUsTon.
  ///
  /// In en, this message translates to:
  /// **'US ton'**
  String get ucuUsTon;

  /// No description provided for @ucuCelsius.
  ///
  /// In en, this message translates to:
  /// **'Celsius'**
  String get ucuCelsius;

  /// No description provided for @ucuFahrenheit.
  ///
  /// In en, this message translates to:
  /// **'Fahrenheit'**
  String get ucuFahrenheit;

  /// No description provided for @ucuKelvin.
  ///
  /// In en, this message translates to:
  /// **'Kelvin'**
  String get ucuKelvin;

  /// No description provided for @ucuRankine.
  ///
  /// In en, this message translates to:
  /// **'Rankine'**
  String get ucuRankine;

  /// No description provided for @ucuSquareMeter.
  ///
  /// In en, this message translates to:
  /// **'Square meter'**
  String get ucuSquareMeter;

  /// No description provided for @ucuSquareKilometer.
  ///
  /// In en, this message translates to:
  /// **'Square kilometer'**
  String get ucuSquareKilometer;

  /// No description provided for @ucuSquareCentimeter.
  ///
  /// In en, this message translates to:
  /// **'Square centimeter'**
  String get ucuSquareCentimeter;

  /// No description provided for @ucuHectare.
  ///
  /// In en, this message translates to:
  /// **'Hectare'**
  String get ucuHectare;

  /// No description provided for @ucuSquareMile.
  ///
  /// In en, this message translates to:
  /// **'Square mile'**
  String get ucuSquareMile;

  /// No description provided for @ucuAcre.
  ///
  /// In en, this message translates to:
  /// **'Acre'**
  String get ucuAcre;

  /// No description provided for @ucuSquareFoot.
  ///
  /// In en, this message translates to:
  /// **'Square foot'**
  String get ucuSquareFoot;

  /// No description provided for @ucuLiter.
  ///
  /// In en, this message translates to:
  /// **'Liter'**
  String get ucuLiter;

  /// No description provided for @ucuMilliliter.
  ///
  /// In en, this message translates to:
  /// **'Milliliter'**
  String get ucuMilliliter;

  /// No description provided for @ucuCubicMeter.
  ///
  /// In en, this message translates to:
  /// **'Cubic meter'**
  String get ucuCubicMeter;

  /// No description provided for @ucuGallonUs.
  ///
  /// In en, this message translates to:
  /// **'Gallon (US)'**
  String get ucuGallonUs;

  /// No description provided for @ucuQuartUs.
  ///
  /// In en, this message translates to:
  /// **'Quart (US)'**
  String get ucuQuartUs;

  /// No description provided for @ucuPintUs.
  ///
  /// In en, this message translates to:
  /// **'Pint (US)'**
  String get ucuPintUs;

  /// No description provided for @ucuCupUs.
  ///
  /// In en, this message translates to:
  /// **'Cup (US)'**
  String get ucuCupUs;

  /// No description provided for @ucuFluidOunceUs.
  ///
  /// In en, this message translates to:
  /// **'Fluid ounce (US)'**
  String get ucuFluidOunceUs;

  /// No description provided for @ucuMeterPerSecond.
  ///
  /// In en, this message translates to:
  /// **'Meter per second'**
  String get ucuMeterPerSecond;

  /// No description provided for @ucuKilometerPerHour.
  ///
  /// In en, this message translates to:
  /// **'Kilometer per hour'**
  String get ucuKilometerPerHour;

  /// No description provided for @ucuMilePerHour.
  ///
  /// In en, this message translates to:
  /// **'Mile per hour'**
  String get ucuMilePerHour;

  /// No description provided for @ucuFootPerSecond.
  ///
  /// In en, this message translates to:
  /// **'Foot per second'**
  String get ucuFootPerSecond;

  /// No description provided for @ucuKnot.
  ///
  /// In en, this message translates to:
  /// **'Knot'**
  String get ucuKnot;

  /// No description provided for @ucuMach.
  ///
  /// In en, this message translates to:
  /// **'Mach'**
  String get ucuMach;

  /// No description provided for @ucuSecond.
  ///
  /// In en, this message translates to:
  /// **'Second'**
  String get ucuSecond;

  /// No description provided for @ucuMillisecond.
  ///
  /// In en, this message translates to:
  /// **'Millisecond'**
  String get ucuMillisecond;

  /// No description provided for @ucuMinute.
  ///
  /// In en, this message translates to:
  /// **'Minute'**
  String get ucuMinute;

  /// No description provided for @ucuHour.
  ///
  /// In en, this message translates to:
  /// **'Hour'**
  String get ucuHour;

  /// No description provided for @ucuDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get ucuDay;

  /// No description provided for @ucuWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get ucuWeek;

  /// No description provided for @ucuMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get ucuMonth;

  /// No description provided for @ucuYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get ucuYear;

  /// No description provided for @ucuByte.
  ///
  /// In en, this message translates to:
  /// **'Byte'**
  String get ucuByte;

  /// No description provided for @ucuKilobyte.
  ///
  /// In en, this message translates to:
  /// **'Kilobyte'**
  String get ucuKilobyte;

  /// No description provided for @ucuMegabyte.
  ///
  /// In en, this message translates to:
  /// **'Megabyte'**
  String get ucuMegabyte;

  /// No description provided for @ucuGigabyte.
  ///
  /// In en, this message translates to:
  /// **'Gigabyte'**
  String get ucuGigabyte;

  /// No description provided for @ucuTerabyte.
  ///
  /// In en, this message translates to:
  /// **'Terabyte'**
  String get ucuTerabyte;

  /// No description provided for @ucuKibibyte.
  ///
  /// In en, this message translates to:
  /// **'Kibibyte'**
  String get ucuKibibyte;

  /// No description provided for @ucuMebibyte.
  ///
  /// In en, this message translates to:
  /// **'Mebibyte'**
  String get ucuMebibyte;

  /// No description provided for @ucuGibibyte.
  ///
  /// In en, this message translates to:
  /// **'Gibibyte'**
  String get ucuGibibyte;

  /// No description provided for @ucuBit.
  ///
  /// In en, this message translates to:
  /// **'Bit'**
  String get ucuBit;

  /// No description provided for @ucuMegabit.
  ///
  /// In en, this message translates to:
  /// **'Megabit'**
  String get ucuMegabit;

  /// No description provided for @ucuPascal.
  ///
  /// In en, this message translates to:
  /// **'Pascal'**
  String get ucuPascal;

  /// No description provided for @ucuKilopascal.
  ///
  /// In en, this message translates to:
  /// **'Kilopascal'**
  String get ucuKilopascal;

  /// No description provided for @ucuBar.
  ///
  /// In en, this message translates to:
  /// **'Bar'**
  String get ucuBar;

  /// No description provided for @ucuMillibar.
  ///
  /// In en, this message translates to:
  /// **'Millibar'**
  String get ucuMillibar;

  /// No description provided for @ucuAtmosphere.
  ///
  /// In en, this message translates to:
  /// **'Atmosphere'**
  String get ucuAtmosphere;

  /// No description provided for @ucuTorr.
  ///
  /// In en, this message translates to:
  /// **'Torr'**
  String get ucuTorr;

  /// No description provided for @ucuPsi.
  ///
  /// In en, this message translates to:
  /// **'Pounds per square inch'**
  String get ucuPsi;

  /// No description provided for @ucuMmhg.
  ///
  /// In en, this message translates to:
  /// **'Millimeter of mercury'**
  String get ucuMmhg;

  /// No description provided for @ucuJoule.
  ///
  /// In en, this message translates to:
  /// **'Joule'**
  String get ucuJoule;

  /// No description provided for @ucuKilojoule.
  ///
  /// In en, this message translates to:
  /// **'Kilojoule'**
  String get ucuKilojoule;

  /// No description provided for @ucuCalorie.
  ///
  /// In en, this message translates to:
  /// **'Calorie'**
  String get ucuCalorie;

  /// No description provided for @ucuKilocalorie.
  ///
  /// In en, this message translates to:
  /// **'Kilocalorie'**
  String get ucuKilocalorie;

  /// No description provided for @ucuWattHour.
  ///
  /// In en, this message translates to:
  /// **'Watt hour'**
  String get ucuWattHour;

  /// No description provided for @ucuKilowattHour.
  ///
  /// In en, this message translates to:
  /// **'Kilowatt hour'**
  String get ucuKilowattHour;

  /// No description provided for @ucuElectronvolt.
  ///
  /// In en, this message translates to:
  /// **'Electronvolt'**
  String get ucuElectronvolt;

  /// No description provided for @ucuBtu.
  ///
  /// In en, this message translates to:
  /// **'British thermal unit'**
  String get ucuBtu;

  /// No description provided for @ucuWatt.
  ///
  /// In en, this message translates to:
  /// **'Watt'**
  String get ucuWatt;

  /// No description provided for @ucuKilowatt.
  ///
  /// In en, this message translates to:
  /// **'Kilowatt'**
  String get ucuKilowatt;

  /// No description provided for @ucuMegawatt.
  ///
  /// In en, this message translates to:
  /// **'Megawatt'**
  String get ucuMegawatt;

  /// No description provided for @ucuMilliwatt.
  ///
  /// In en, this message translates to:
  /// **'Milliwatt'**
  String get ucuMilliwatt;

  /// No description provided for @ucuHorsepower.
  ///
  /// In en, this message translates to:
  /// **'Horsepower'**
  String get ucuHorsepower;

  /// No description provided for @ucuMetricHorsepower.
  ///
  /// In en, this message translates to:
  /// **'Metric horsepower'**
  String get ucuMetricHorsepower;

  /// No description provided for @ucuDegree.
  ///
  /// In en, this message translates to:
  /// **'Degree'**
  String get ucuDegree;

  /// No description provided for @ucuRadian.
  ///
  /// In en, this message translates to:
  /// **'Radian'**
  String get ucuRadian;

  /// No description provided for @ucuGradian.
  ///
  /// In en, this message translates to:
  /// **'Gradian'**
  String get ucuGradian;

  /// No description provided for @ucuArcminute.
  ///
  /// In en, this message translates to:
  /// **'Arcminute'**
  String get ucuArcminute;

  /// No description provided for @ucuArcsecond.
  ///
  /// In en, this message translates to:
  /// **'Arcsecond'**
  String get ucuArcsecond;

  /// No description provided for @ucuTurn.
  ///
  /// In en, this message translates to:
  /// **'Turn'**
  String get ucuTurn;

  /// No description provided for @ucuHertz.
  ///
  /// In en, this message translates to:
  /// **'Hertz'**
  String get ucuHertz;

  /// No description provided for @ucuKilohertz.
  ///
  /// In en, this message translates to:
  /// **'Kilohertz'**
  String get ucuKilohertz;

  /// No description provided for @ucuMegahertz.
  ///
  /// In en, this message translates to:
  /// **'Megahertz'**
  String get ucuMegahertz;

  /// No description provided for @ucuGigahertz.
  ///
  /// In en, this message translates to:
  /// **'Gigahertz'**
  String get ucuGigahertz;

  /// No description provided for @ucuRpm.
  ///
  /// In en, this message translates to:
  /// **'Revolutions per minute'**
  String get ucuRpm;

  /// No description provided for @ucuBitPerSecond.
  ///
  /// In en, this message translates to:
  /// **'Bit per second'**
  String get ucuBitPerSecond;

  /// No description provided for @ucuKilobitPerSecond.
  ///
  /// In en, this message translates to:
  /// **'Kilobit per second'**
  String get ucuKilobitPerSecond;

  /// No description provided for @ucuMegabitPerSecond.
  ///
  /// In en, this message translates to:
  /// **'Megabit per second'**
  String get ucuMegabitPerSecond;

  /// No description provided for @ucuGigabitPerSecond.
  ///
  /// In en, this message translates to:
  /// **'Gigabit per second'**
  String get ucuGigabitPerSecond;

  /// No description provided for @ucuBytePerSecond.
  ///
  /// In en, this message translates to:
  /// **'Byte per second'**
  String get ucuBytePerSecond;

  /// No description provided for @ucuKilobytePerSecond.
  ///
  /// In en, this message translates to:
  /// **'Kilobyte per second'**
  String get ucuKilobytePerSecond;

  /// No description provided for @ucuMegabytePerSecond.
  ///
  /// In en, this message translates to:
  /// **'Megabyte per second'**
  String get ucuMegabytePerSecond;

  /// No description provided for @ucuGigabytePerSecond.
  ///
  /// In en, this message translates to:
  /// **'Gigabyte per second'**
  String get ucuGigabytePerSecond;

  /// No description provided for @ucuKmPerLiter.
  ///
  /// In en, this message translates to:
  /// **'Kilometers per liter'**
  String get ucuKmPerLiter;

  /// No description provided for @ucuLiterPer100km.
  ///
  /// In en, this message translates to:
  /// **'Liters per 100 km'**
  String get ucuLiterPer100km;

  /// No description provided for @ucuMpgUs.
  ///
  /// In en, this message translates to:
  /// **'Miles per gallon (US)'**
  String get ucuMpgUs;

  /// No description provided for @ucuMpgUk.
  ///
  /// In en, this message translates to:
  /// **'Miles per gallon (UK)'**
  String get ucuMpgUk;

  /// No description provided for @focusBreathingBox.
  ///
  /// In en, this message translates to:
  /// **'Box 4-4-4-4'**
  String get focusBreathingBox;

  /// No description provided for @focusBreathingRelax.
  ///
  /// In en, this message translates to:
  /// **'Relax 4-7-8'**
  String get focusBreathingRelax;

  /// No description provided for @focusBreathingCalm.
  ///
  /// In en, this message translates to:
  /// **'Calm 5-5'**
  String get focusBreathingCalm;

  /// No description provided for @focusBreathingInhale.
  ///
  /// In en, this message translates to:
  /// **'Inhale'**
  String get focusBreathingInhale;

  /// No description provided for @focusBreathingHold.
  ///
  /// In en, this message translates to:
  /// **'Hold'**
  String get focusBreathingHold;

  /// No description provided for @focusBreathingExhale.
  ///
  /// In en, this message translates to:
  /// **'Exhale'**
  String get focusBreathingExhale;

  /// No description provided for @focusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get focusReady;

  /// No description provided for @hexEditorModified.
  ///
  /// In en, this message translates to:
  /// **'MODIFIED'**
  String get hexEditorModified;

  /// No description provided for @sketchCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Copy to clipboard failed'**
  String get sketchCopyFailed;

  /// No description provided for @sketchExportLabelImage.
  ///
  /// In en, this message translates to:
  /// **'{format} image'**
  String sketchExportLabelImage(String format);

  /// No description provided for @sketchImageLabel.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get sketchImageLabel;

  /// No description provided for @sigPngImage.
  ///
  /// In en, this message translates to:
  /// **'PNG image'**
  String get sigPngImage;

  /// No description provided for @sigSvgImage.
  ///
  /// In en, this message translates to:
  /// **'SVG image'**
  String get sigSvgImage;

  /// No description provided for @sigCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Copy to clipboard failed'**
  String get sigCopyFailed;

  /// No description provided for @chatAiDocumentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get chatAiDocumentsLabel;

  /// No description provided for @toolNameCodeHighlight.
  ///
  /// In en, this message translates to:
  /// **'Code Highlight & Edit'**
  String get toolNameCodeHighlight;

  /// No description provided for @toolDescCodeHighlight.
  ///
  /// In en, this message translates to:
  /// **'Highlight syntax and edit code files'**
  String get toolDescCodeHighlight;

  /// No description provided for @codeHighlightPasteCode.
  ///
  /// In en, this message translates to:
  /// **'Paste Code'**
  String get codeHighlightPasteCode;

  /// No description provided for @codeHighlightLoadFile.
  ///
  /// In en, this message translates to:
  /// **'Load File'**
  String get codeHighlightLoadFile;

  /// No description provided for @codeHighlightLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get codeHighlightLanguage;

  /// No description provided for @codeHighlightTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get codeHighlightTheme;

  /// No description provided for @codeHighlightEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Code Editor'**
  String get codeHighlightEditorTitle;

  /// No description provided for @codeHighlightEmptyText.
  ///
  /// In en, this message translates to:
  /// **'Paste code or drop a file here to get started'**
  String get codeHighlightEmptyText;

  /// No description provided for @codeHighlightFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load code: {error}'**
  String codeHighlightFailedToLoad(String error);

  /// No description provided for @codeHighlightCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied to clipboard'**
  String get codeHighlightCopied;

  /// No description provided for @codeHighlightFailedToCopy.
  ///
  /// In en, this message translates to:
  /// **'Failed to copy code: {error}'**
  String codeHighlightFailedToCopy(String error);

  /// No description provided for @codeHighlightTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Text or source code files'**
  String get codeHighlightTypeLabel;

  /// No description provided for @codeHighlightOpenTitle.
  ///
  /// In en, this message translates to:
  /// **'Open code file'**
  String get codeHighlightOpenTitle;

  /// No description provided for @codeHighlightDropSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Drop file here or click to choose'**
  String get codeHighlightDropSubtitle;

  /// No description provided for @codeHighlightOpenInViewer.
  ///
  /// In en, this message translates to:
  /// **'Open in Code Highlighter'**
  String get codeHighlightOpenInViewer;

  /// No description provided for @codeHighlightThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light Theme'**
  String get codeHighlightThemeLight;

  /// No description provided for @codeHighlightThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark Theme'**
  String get codeHighlightThemeDark;

  /// No description provided for @codeHighlightExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Option'**
  String get codeHighlightExportTitle;

  /// No description provided for @codeHighlightExportText.
  ///
  /// In en, this message translates to:
  /// **'Export as Raw Text File'**
  String get codeHighlightExportText;

  /// No description provided for @codeHighlightExportImage.
  ///
  /// In en, this message translates to:
  /// **'Export as Colored Image'**
  String get codeHighlightExportImage;

  /// No description provided for @codeHighlightSaveImage.
  ///
  /// In en, this message translates to:
  /// **'Save Image'**
  String get codeHighlightSaveImage;

  /// No description provided for @codeHighlightCopyImage.
  ///
  /// In en, this message translates to:
  /// **'Copy Image'**
  String get codeHighlightCopyImage;

  /// No description provided for @codeHighlightCopiedImage.
  ///
  /// In en, this message translates to:
  /// **'Image copied to clipboard'**
  String get codeHighlightCopiedImage;

  /// No description provided for @codeHighlightFailedToCopyImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to copy image: {error}'**
  String codeHighlightFailedToCopyImage(String error);

  /// No description provided for @codeHighlightFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get codeHighlightFormat;

  /// No description provided for @codeHighlightFailedToSaveImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to save image: {error}'**
  String codeHighlightFailedToSaveImage(String error);

  /// No description provided for @codeHighlightExportWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Large Image Warning'**
  String get codeHighlightExportWarningTitle;

  /// No description provided for @codeHighlightExportWarningMessage.
  ///
  /// In en, this message translates to:
  /// **'This file contains {lines} lines. Exporting very long code files as an image may fail to render due to memory limits, or the text might be too small to be readable. We recommend exporting as a raw text file instead.'**
  String codeHighlightExportWarningMessage(int lines);

  /// No description provided for @toolNameBluetoothScanner.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth Scanner'**
  String get toolNameBluetoothScanner;

  /// No description provided for @toolDescBluetoothScanner.
  ///
  /// In en, this message translates to:
  /// **'Scan for nearby Bluetooth Low Energy devices and identify them.'**
  String get toolDescBluetoothScanner;

  /// No description provided for @bleStartScan.
  ///
  /// In en, this message translates to:
  /// **'Start Scan'**
  String get bleStartScan;

  /// No description provided for @bleStopScan.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get bleStopScan;

  /// No description provided for @bleStartScanning.
  ///
  /// In en, this message translates to:
  /// **'Start scanning to discover nearby BLE devices'**
  String get bleStartScanning;

  /// No description provided for @bleNoDevicesFound.
  ///
  /// In en, this message translates to:
  /// **'No devices found'**
  String get bleNoDevicesFound;

  /// No description provided for @bleClearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get bleClearHistory;

  /// No description provided for @bleFilterHighConfidence.
  ///
  /// In en, this message translates to:
  /// **'High Confidence'**
  String get bleFilterHighConfidence;

  /// No description provided for @bleFilterBeacons.
  ///
  /// In en, this message translates to:
  /// **'Beacons'**
  String get bleFilterBeacons;

  /// No description provided for @bleFilterUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get bleFilterUnknown;

  /// No description provided for @bleFilterRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get bleFilterRecent;

  /// No description provided for @bleFilterStrongSignal.
  ///
  /// In en, this message translates to:
  /// **'Strong Signal'**
  String get bleFilterStrongSignal;

  /// No description provided for @bleBluetoothOff.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth Off'**
  String get bleBluetoothOff;

  /// No description provided for @bleDeviceCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 device} other{{count} devices}}'**
  String bleDeviceCount(int count);

  /// No description provided for @bleCategoryAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get bleCategoryAudio;

  /// No description provided for @bleCategoryWearables.
  ///
  /// In en, this message translates to:
  /// **'Wearables'**
  String get bleCategoryWearables;

  /// No description provided for @bleCategoryHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get bleCategoryHealth;

  /// No description provided for @bleCategoryFitness.
  ///
  /// In en, this message translates to:
  /// **'Fitness'**
  String get bleCategoryFitness;

  /// No description provided for @bleCategoryIoT.
  ///
  /// In en, this message translates to:
  /// **'IoT'**
  String get bleCategoryIoT;

  /// No description provided for @bleCategoryPhones.
  ///
  /// In en, this message translates to:
  /// **'Phones'**
  String get bleCategoryPhones;

  /// No description provided for @bleCategoryComputers.
  ///
  /// In en, this message translates to:
  /// **'Computers'**
  String get bleCategoryComputers;

  /// No description provided for @bleCategoryInput.
  ///
  /// In en, this message translates to:
  /// **'Input'**
  String get bleCategoryInput;

  /// No description provided for @bleCategoryGaming.
  ///
  /// In en, this message translates to:
  /// **'Gaming'**
  String get bleCategoryGaming;

  /// No description provided for @bleCategoryVehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get bleCategoryVehicle;

  /// No description provided for @bleCategoryUnidentified.
  ///
  /// In en, this message translates to:
  /// **'Unidentified'**
  String get bleCategoryUnidentified;

  /// No description provided for @bleConfidenceMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get bleConfidenceMedium;

  /// No description provided for @bleConfidenceLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get bleConfidenceLow;

  /// No description provided for @bleDetailConfidence.
  ///
  /// In en, this message translates to:
  /// **'Confidence'**
  String get bleDetailConfidence;

  /// No description provided for @bleDetailCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get bleDetailCategory;

  /// No description provided for @bleDetailType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get bleDetailType;

  /// No description provided for @bleDetailRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get bleDetailRole;

  /// No description provided for @bleDetailRSSI.
  ///
  /// In en, this message translates to:
  /// **'RSSI'**
  String get bleDetailRSSI;

  /// No description provided for @bleDetailDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get bleDetailDistance;

  /// No description provided for @bleDetailManufacturer.
  ///
  /// In en, this message translates to:
  /// **'Manufacturer'**
  String get bleDetailManufacturer;

  /// No description provided for @bleDetailIdentifiedAs.
  ///
  /// In en, this message translates to:
  /// **'Identified As'**
  String get bleDetailIdentifiedAs;

  /// No description provided for @bleDetailFirstSeen.
  ///
  /// In en, this message translates to:
  /// **'First seen'**
  String get bleDetailFirstSeen;

  /// No description provided for @bleDetailLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen'**
  String get bleDetailLastSeen;

  /// No description provided for @bleDetailSightings.
  ///
  /// In en, this message translates to:
  /// **'Sightings'**
  String get bleDetailSightings;

  /// No description provided for @bleDetailStrongestRSSI.
  ///
  /// In en, this message translates to:
  /// **'Strongest RSSI'**
  String get bleDetailStrongestRSSI;

  /// No description provided for @bleDetailSensorData.
  ///
  /// In en, this message translates to:
  /// **'Sensor Data'**
  String get bleDetailSensorData;

  /// No description provided for @bleDetailTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get bleDetailTemperature;

  /// No description provided for @bleDetailHumidity.
  ///
  /// In en, this message translates to:
  /// **'Humidity'**
  String get bleDetailHumidity;

  /// No description provided for @bleDetailBattery.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get bleDetailBattery;

  /// No description provided for @bleDetailBeacons.
  ///
  /// In en, this message translates to:
  /// **'Beacons'**
  String get bleDetailBeacons;

  /// No description provided for @bleDetailServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get bleDetailServices;

  /// No description provided for @bleDetailWhyIdentified.
  ///
  /// In en, this message translates to:
  /// **'Why identified'**
  String get bleDetailWhyIdentified;

  /// No description provided for @bleDetailRawData.
  ///
  /// In en, this message translates to:
  /// **'Raw Data'**
  String get bleDetailRawData;

  /// No description provided for @bleTimeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get bleTimeJustNow;

  /// No description provided for @bleTimeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String bleTimeMinutesAgo(int minutes);

  /// No description provided for @bleTimeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String bleTimeHoursAgo(int hours);

  /// No description provided for @bleTimeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String bleTimeDaysAgo(int days);

  /// No description provided for @toolNameStringTransformer.
  ///
  /// In en, this message translates to:
  /// **'String Transformer'**
  String get toolNameStringTransformer;

  /// No description provided for @toolDescStringTransformer.
  ///
  /// In en, this message translates to:
  /// **'Convert text between various formats: camelCase, snake_case, kebab-case, PascalCase, URL slugs, Base64, Hex, and decode ad URLs.'**
  String get toolDescStringTransformer;

  /// No description provided for @stringTransformerInputLabel.
  ///
  /// In en, this message translates to:
  /// **'Input Text'**
  String get stringTransformerInputLabel;

  /// No description provided for @stringTransformerOutputLabel.
  ///
  /// In en, this message translates to:
  /// **'Output Text'**
  String get stringTransformerOutputLabel;

  /// No description provided for @stringTransformerSelectTransform.
  ///
  /// In en, this message translates to:
  /// **'Select Transformation'**
  String get stringTransformerSelectTransform;

  /// No description provided for @stringTransformerCharsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} chars'**
  String stringTransformerCharsCount(int count);

  /// No description provided for @stringTransformerSwap.
  ///
  /// In en, this message translates to:
  /// **'Swap Input/Output'**
  String get stringTransformerSwap;

  /// No description provided for @stringTransformerTypeCamel.
  ///
  /// In en, this message translates to:
  /// **'camelCase'**
  String get stringTransformerTypeCamel;

  /// No description provided for @stringTransformerTypeSnake.
  ///
  /// In en, this message translates to:
  /// **'snake_case'**
  String get stringTransformerTypeSnake;

  /// No description provided for @stringTransformerTypeKebab.
  ///
  /// In en, this message translates to:
  /// **'kebab-case'**
  String get stringTransformerTypeKebab;

  /// No description provided for @stringTransformerTypePascal.
  ///
  /// In en, this message translates to:
  /// **'PascalCase'**
  String get stringTransformerTypePascal;

  /// No description provided for @stringTransformerTypeUrlSlug.
  ///
  /// In en, this message translates to:
  /// **'URL Slug'**
  String get stringTransformerTypeUrlSlug;

  /// No description provided for @stringTransformerTypeBase64Encode.
  ///
  /// In en, this message translates to:
  /// **'Base64 Encode'**
  String get stringTransformerTypeBase64Encode;

  /// No description provided for @stringTransformerTypeBase64Decode.
  ///
  /// In en, this message translates to:
  /// **'Base64 Decode'**
  String get stringTransformerTypeBase64Decode;

  /// No description provided for @stringTransformerTypeHexEncode.
  ///
  /// In en, this message translates to:
  /// **'Hex Encode'**
  String get stringTransformerTypeHexEncode;

  /// No description provided for @stringTransformerTypeHexDecode.
  ///
  /// In en, this message translates to:
  /// **'Hex Decode'**
  String get stringTransformerTypeHexDecode;

  /// No description provided for @stringTransformerTypeAdUrlDecode.
  ///
  /// In en, this message translates to:
  /// **'Ad URL Decode'**
  String get stringTransformerTypeAdUrlDecode;

  /// No description provided for @stringTransformerPlaceholderInput.
  ///
  /// In en, this message translates to:
  /// **'Type or paste text here...'**
  String get stringTransformerPlaceholderInput;

  /// No description provided for @stringTransformerPlaceholderOutput.
  ///
  /// In en, this message translates to:
  /// **'Result will appear here...'**
  String get stringTransformerPlaceholderOutput;

  /// No description provided for @stringTransformerCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get stringTransformerCopied;

  /// No description provided for @stringTransformerFailedToCopy.
  ///
  /// In en, this message translates to:
  /// **'Failed to copy: {error}'**
  String stringTransformerFailedToCopy(String error);

  /// No description provided for @stringTransformerInvalidInput.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String stringTransformerInvalidInput(String message);

  /// No description provided for @stringTransformerNoEmbeddedUrl.
  ///
  /// In en, this message translates to:
  /// **'No embedded URL detected.'**
  String get stringTransformerNoEmbeddedUrl;

  /// No description provided for @toolNameTreadmillControl.
  ///
  /// In en, this message translates to:
  /// **'Treadmill Control'**
  String get toolNameTreadmillControl;

  /// No description provided for @toolDescTreadmillControl.
  ///
  /// In en, this message translates to:
  /// **'Control your treadmill and monitor heart rate via Bluetooth'**
  String get toolDescTreadmillControl;

  /// No description provided for @speedLabel.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get speedLabel;

  /// No description provided for @inclineLabel.
  ///
  /// In en, this message translates to:
  /// **'Incline'**
  String get inclineLabel;

  /// No description provided for @hrLabel.
  ///
  /// In en, this message translates to:
  /// **'Heart Rate'**
  String get hrLabel;

  /// No description provided for @elapsedTime.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get elapsedTime;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @calories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get calories;

  /// No description provided for @steps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get steps;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Workout History'**
  String get historyTitle;

  /// No description provided for @workoutStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get workoutStart;

  /// No description provided for @workoutPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get workoutPause;

  /// No description provided for @workoutResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get workoutResume;

  /// No description provided for @workoutStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get workoutStop;

  /// No description provided for @importHistory.
  ///
  /// In en, this message translates to:
  /// **'Import Workouts'**
  String get importHistory;

  /// No description provided for @exportHistory.
  ///
  /// In en, this message translates to:
  /// **'Export Workouts'**
  String get exportHistory;

  /// No description provided for @treadmillHistorySync.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get treadmillHistorySync;

  /// No description provided for @treadmillHistorySyncDisabled.
  ///
  /// In en, this message translates to:
  /// **'Sync is not enabled. Turn it on in Settings.'**
  String get treadmillHistorySyncDisabled;

  /// No description provided for @treadmillHistorySyncSuccess.
  ///
  /// In en, this message translates to:
  /// **'Synced: {pushed} pushed, {pulled} pulled'**
  String treadmillHistorySyncSuccess(int pushed, int pulled);

  /// No description provided for @treadmillHistorySyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {error}'**
  String treadmillHistorySyncFailed(String error);

  /// No description provided for @treadmillConnectDevices.
  ///
  /// In en, this message translates to:
  /// **'Connect devices'**
  String get treadmillConnectDevices;

  /// No description provided for @treadmillBadgeTreadmill.
  ///
  /// In en, this message translates to:
  /// **'Treadmill'**
  String get treadmillBadgeTreadmill;

  /// No description provided for @treadmillStatusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get treadmillStatusConnected;

  /// No description provided for @treadmillStatusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get treadmillStatusConnecting;

  /// No description provided for @treadmillStatusDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get treadmillStatusDisconnected;

  /// No description provided for @treadmillSessionRunningTitle.
  ///
  /// In en, this message translates to:
  /// **'Workout still running'**
  String get treadmillSessionRunningTitle;

  /// No description provided for @treadmillSessionRunningMessage.
  ///
  /// In en, this message translates to:
  /// **'Leaving this screen keeps recording in the background - the session is saved automatically and can be recovered even if the app is closed. Stop it now to file it in the history.'**
  String get treadmillSessionRunningMessage;

  /// No description provided for @treadmillKeepRecording.
  ///
  /// In en, this message translates to:
  /// **'Leave, keep recording'**
  String get treadmillKeepRecording;

  /// No description provided for @treadmillStopAndSave.
  ///
  /// In en, this message translates to:
  /// **'Stop and save'**
  String get treadmillStopAndSave;

  /// No description provided for @treadmillRecoveredTitle.
  ///
  /// In en, this message translates to:
  /// **'Unfinished workout found'**
  String get treadmillRecoveredTitle;

  /// No description provided for @treadmillRecoveredMessage.
  ///
  /// In en, this message translates to:
  /// **'A workout of {duration} with {distance} km was still recording when the app closed.'**
  String treadmillRecoveredMessage(String duration, String distance);

  /// No description provided for @treadmillRecoveredResume.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get treadmillRecoveredResume;

  /// No description provided for @treadmillRecoveredSave.
  ///
  /// In en, this message translates to:
  /// **'Save to history'**
  String get treadmillRecoveredSave;

  /// No description provided for @treadmillRecoveredDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get treadmillRecoveredDiscard;

  /// No description provided for @treadmillRecoveredSaved.
  ///
  /// In en, this message translates to:
  /// **'Workout saved to history'**
  String get treadmillRecoveredSaved;

  /// No description provided for @treadmillPublishNow.
  ///
  /// In en, this message translates to:
  /// **'Publish now'**
  String get treadmillPublishNow;

  /// No description provided for @treadmillPublishNowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Workouts go to Health Connect when one ends, on a manual sync and when the health dashboard opens, at most once every five minutes.'**
  String get treadmillPublishNowSubtitle;

  /// No description provided for @treadmillPublishDone.
  ///
  /// In en, this message translates to:
  /// **'Published {count} workout(s) to Health Connect'**
  String treadmillPublishDone(int count);

  /// No description provided for @treadmillPublishNothing.
  ///
  /// In en, this message translates to:
  /// **'Health Connect is already up to date'**
  String get treadmillPublishNothing;

  /// No description provided for @treadmillPublishFailed.
  ///
  /// In en, this message translates to:
  /// **'{count} workout(s) could not be published to Health Connect'**
  String treadmillPublishFailed(int count);

  /// No description provided for @treadmillPublishNoPermission.
  ///
  /// In en, this message translates to:
  /// **'Health Connect did not grant write access'**
  String get treadmillPublishNoPermission;

  /// No description provided for @treadmillPublishThrottled.
  ///
  /// In en, this message translates to:
  /// **'Just published — nothing new to send'**
  String get treadmillPublishThrottled;

  /// No description provided for @treadmillPublishDisabled.
  ///
  /// In en, this message translates to:
  /// **'Publishing to Health Connect is switched off'**
  String get treadmillPublishDisabled;

  /// No description provided for @treadmillPublishUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Health Connect is only available on Android'**
  String get treadmillPublishUnsupported;

  /// No description provided for @treadmillRemoveFromHealthConnect.
  ///
  /// In en, this message translates to:
  /// **'Remove workouts from Health Connect'**
  String get treadmillRemoveFromHealthConnect;

  /// No description provided for @treadmillRemoveFromHealthConnectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Deletes everything this app wrote there and publishes it again on the next run.'**
  String get treadmillRemoveFromHealthConnectSubtitle;

  /// No description provided for @treadmillRemoveFromHealthConnectConfirm.
  ///
  /// In en, this message translates to:
  /// **'Every treadmill record ToolLab wrote is deleted from Health Connect. Records from other apps are not touched. Distance records are the exception: Health Connect offers no way to delete them here, so they are overwritten on the next publish. Your local workout history stays and is published again on the next run.'**
  String get treadmillRemoveFromHealthConnectConfirm;

  /// No description provided for @treadmillRemoveFromHealthConnectAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get treadmillRemoveFromHealthConnectAction;

  /// No description provided for @treadmillRemoveFromHealthConnectDone.
  ///
  /// In en, this message translates to:
  /// **'Removed — {count} workout(s) will be published again'**
  String treadmillRemoveFromHealthConnectDone(int count);

  /// No description provided for @treadmillRemoveFromHealthConnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Removing the Health Connect data failed'**
  String get treadmillRemoveFromHealthConnectFailed;

  /// No description provided for @treadmillHistoryDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get treadmillHistoryDashboard;

  /// No description provided for @treadmillHistoryWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get treadmillHistoryWorkouts;

  /// No description provided for @treadmillHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No workouts saved yet'**
  String get treadmillHistoryEmpty;

  /// No description provided for @treadmillHistoryOverview.
  ///
  /// In en, this message translates to:
  /// **'Your running story'**
  String get treadmillHistoryOverview;

  /// No description provided for @treadmillHistoryOverviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Every recorded workout, in one place.'**
  String get treadmillHistoryOverviewSubtitle;

  /// No description provided for @treadmillHistoryLastSevenDays.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get treadmillHistoryLastSevenDays;

  /// No description provided for @treadmillHistoryDistanceLastSevenDays.
  ///
  /// In en, this message translates to:
  /// **'Distance in the last 7 days'**
  String get treadmillHistoryDistanceLastSevenDays;

  /// No description provided for @treadmillHistoryDistanceChartSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Daily distance with a seven-day trend'**
  String get treadmillHistoryDistanceChartSubtitle;

  /// No description provided for @treadmillHistoryTotalDistance.
  ///
  /// In en, this message translates to:
  /// **'Total distance'**
  String get treadmillHistoryTotalDistance;

  /// No description provided for @treadmillHistoryTotalDuration.
  ///
  /// In en, this message translates to:
  /// **'Total duration'**
  String get treadmillHistoryTotalDuration;

  /// No description provided for @treadmillHistoryTotalCalories.
  ///
  /// In en, this message translates to:
  /// **'Total calories'**
  String get treadmillHistoryTotalCalories;

  /// No description provided for @treadmillHistoryAverageSpeed.
  ///
  /// In en, this message translates to:
  /// **'Average speed'**
  String get treadmillHistoryAverageSpeed;

  /// No description provided for @treadmillHistoryWorkoutCount.
  ///
  /// In en, this message translates to:
  /// **'Total workouts'**
  String get treadmillHistoryWorkoutCount;

  /// No description provided for @treadmillHistoryScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Dashboard screenshot'**
  String get treadmillHistoryScreenshot;

  /// No description provided for @treadmillHistorySaveScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Save screenshot'**
  String get treadmillHistorySaveScreenshot;

  /// No description provided for @treadmillHistoryShareScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Share screenshot'**
  String get treadmillHistoryShareScreenshot;

  /// No description provided for @treadmillHistoryScreenshotFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create dashboard screenshot'**
  String get treadmillHistoryScreenshotFailed;

  /// No description provided for @treadmillHistoryGenerateReport.
  ///
  /// In en, this message translates to:
  /// **'Generate PDF report'**
  String get treadmillHistoryGenerateReport;

  /// No description provided for @treadmillHistoryReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Treadmill Workout Report'**
  String get treadmillHistoryReportTitle;

  /// No description provided for @treadmillHistoryReportGenerated.
  ///
  /// In en, this message translates to:
  /// **'Generated'**
  String get treadmillHistoryReportGenerated;

  /// No description provided for @treadmillHistoryReportDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get treadmillHistoryReportDate;

  /// No description provided for @treadmillHistoryReportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not generate workout report'**
  String get treadmillHistoryReportFailed;

  /// No description provided for @treadmillHistoryTotalWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Total workouts'**
  String get treadmillHistoryTotalWorkouts;

  /// No description provided for @treadmillHistoryLongestDuration.
  ///
  /// In en, this message translates to:
  /// **'Longest duration'**
  String get treadmillHistoryLongestDuration;

  /// No description provided for @treadmillHistoryMostCalories.
  ///
  /// In en, this message translates to:
  /// **'Most calories'**
  String get treadmillHistoryMostCalories;

  /// No description provided for @treadmillHistoryMostSteps.
  ///
  /// In en, this message translates to:
  /// **'Most steps'**
  String get treadmillHistoryMostSteps;

  /// No description provided for @treadmillHistoryHeartRateLastSevenDays.
  ///
  /// In en, this message translates to:
  /// **'Average heart rate in the last 7 days'**
  String get treadmillHistoryHeartRateLastSevenDays;

  /// No description provided for @treadmillHistoryAllTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get treadmillHistoryAllTime;

  /// No description provided for @treadmillHistoryPersonalBests.
  ///
  /// In en, this message translates to:
  /// **'Personal bests'**
  String get treadmillHistoryPersonalBests;

  /// No description provided for @treadmillHistoryLongestRun.
  ///
  /// In en, this message translates to:
  /// **'Longest run'**
  String get treadmillHistoryLongestRun;

  /// No description provided for @treadmillHistoryTopSpeed.
  ///
  /// In en, this message translates to:
  /// **'Top speed'**
  String get treadmillHistoryTopSpeed;

  /// No description provided for @treadmillHistoryAverage.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get treadmillHistoryAverage;

  /// No description provided for @treadmillHistoryAverageHr.
  ///
  /// In en, this message translates to:
  /// **'Avg HR'**
  String get treadmillHistoryAverageHr;

  /// No description provided for @treadmillHistoryHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Heart rate'**
  String get treadmillHistoryHeartRate;

  /// No description provided for @treadmillHistoryHeartRateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All-time workout intensity, with a last 7-day trend below'**
  String get treadmillHistoryHeartRateSubtitle;

  /// No description provided for @treadmillHistoryRestingAverage.
  ///
  /// In en, this message translates to:
  /// **'Workout average'**
  String get treadmillHistoryRestingAverage;

  /// No description provided for @treadmillHistoryPeakHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Highest peak'**
  String get treadmillHistoryPeakHeartRate;

  /// No description provided for @treadmillHistoryImportNoNewWorkouts.
  ///
  /// In en, this message translates to:
  /// **'All workouts from this backup are already saved'**
  String get treadmillHistoryImportNoNewWorkouts;

  /// No description provided for @treadmillHistoryImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Successfully imported {count} workouts'**
  String treadmillHistoryImportSuccess(int count);

  /// No description provided for @treadmillDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Workout Details'**
  String get treadmillDetailsTitle;

  /// No description provided for @treadmillScreenshotCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy to clipboard'**
  String get treadmillScreenshotCopy;

  /// No description provided for @treadmillScreenshotCopied.
  ///
  /// In en, this message translates to:
  /// **'Screenshot copied to clipboard'**
  String get treadmillScreenshotCopied;

  /// No description provided for @treadmillScreenshotCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not copy screenshot to clipboard'**
  String get treadmillScreenshotCopyFailed;

  /// No description provided for @treadmillDetailsScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Workout screenshot'**
  String get treadmillDetailsScreenshot;

  /// No description provided for @treadmillDetailsScreenshotFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create workout screenshot'**
  String get treadmillDetailsScreenshotFailed;

  /// No description provided for @treadmillDetailsDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get treadmillDetailsDuration;

  /// No description provided for @treadmillDetailsPaceUnit.
  ///
  /// In en, this message translates to:
  /// **'min/km'**
  String get treadmillDetailsPaceUnit;

  /// No description provided for @treadmillDetailsAvgSpeed.
  ///
  /// In en, this message translates to:
  /// **'Avg speed'**
  String get treadmillDetailsAvgSpeed;

  /// No description provided for @treadmillDetailsMaxSpeed.
  ///
  /// In en, this message translates to:
  /// **'Max speed'**
  String get treadmillDetailsMaxSpeed;

  /// No description provided for @treadmillDetailsAvgHr.
  ///
  /// In en, this message translates to:
  /// **'Avg heart rate'**
  String get treadmillDetailsAvgHr;

  /// No description provided for @treadmillDetailsMaxHr.
  ///
  /// In en, this message translates to:
  /// **'Max heart rate'**
  String get treadmillDetailsMaxHr;

  /// No description provided for @treadmillDetailsMinHr.
  ///
  /// In en, this message translates to:
  /// **'Min heart rate'**
  String get treadmillDetailsMinHr;

  /// No description provided for @treadmillDetailsCalories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get treadmillDetailsCalories;

  /// No description provided for @treadmillDetailsSteps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get treadmillDetailsSteps;

  /// No description provided for @treadmillDetailsAvgIncline.
  ///
  /// In en, this message translates to:
  /// **'Avg incline'**
  String get treadmillDetailsAvgIncline;

  /// No description provided for @treadmillDetailsMaxIncline.
  ///
  /// In en, this message translates to:
  /// **'Max incline'**
  String get treadmillDetailsMaxIncline;

  /// No description provided for @treadmillDetailsSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get treadmillDetailsSpeed;

  /// No description provided for @treadmillDetailsChart.
  ///
  /// In en, this message translates to:
  /// **'Speed & heart rate'**
  String get treadmillDetailsChart;

  /// No description provided for @treadmillDetailsIncline.
  ///
  /// In en, this message translates to:
  /// **'Incline'**
  String get treadmillDetailsIncline;

  /// No description provided for @treadmillDetailsZones.
  ///
  /// In en, this message translates to:
  /// **'Heart rate zones'**
  String get treadmillDetailsZones;

  /// No description provided for @treadmillDetailsZone1.
  ///
  /// In en, this message translates to:
  /// **'Recovery'**
  String get treadmillDetailsZone1;

  /// No description provided for @treadmillDetailsZone2.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get treadmillDetailsZone2;

  /// No description provided for @treadmillDetailsZone3.
  ///
  /// In en, this message translates to:
  /// **'Aerobic'**
  String get treadmillDetailsZone3;

  /// No description provided for @treadmillDetailsZone4.
  ///
  /// In en, this message translates to:
  /// **'Threshold'**
  String get treadmillDetailsZone4;

  /// No description provided for @treadmillDetailsZone5.
  ///
  /// In en, this message translates to:
  /// **'Maximum'**
  String get treadmillDetailsZone5;

  /// No description provided for @treadmillDetailsSplits.
  ///
  /// In en, this message translates to:
  /// **'Kilometer splits'**
  String get treadmillDetailsSplits;

  /// No description provided for @treadmillDetailsSplitKm.
  ///
  /// In en, this message translates to:
  /// **'Km'**
  String get treadmillDetailsSplitKm;

  /// No description provided for @treadmillDetailsSplitTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get treadmillDetailsSplitTime;

  /// No description provided for @treadmillDetailsSplitPace.
  ///
  /// In en, this message translates to:
  /// **'Pace'**
  String get treadmillDetailsSplitPace;

  /// No description provided for @treadmillDetailsSplitHr.
  ///
  /// In en, this message translates to:
  /// **'HR'**
  String get treadmillDetailsSplitHr;

  /// No description provided for @treadmillDetailsNoSamples.
  ///
  /// In en, this message translates to:
  /// **'No detailed samples were recorded for this workout'**
  String get treadmillDetailsNoSamples;

  /// No description provided for @toolNameAudioLab.
  ///
  /// In en, this message translates to:
  /// **'Audio Lab'**
  String get toolNameAudioLab;

  /// No description provided for @toolDescAudioLab.
  ///
  /// In en, this message translates to:
  /// **'Locate, mask, analyze, and generate audio signals'**
  String get toolDescAudioLab;

  /// No description provided for @sfTitleFinder.
  ///
  /// In en, this message translates to:
  /// **'Finder'**
  String get sfTitleFinder;

  /// No description provided for @sfTitleCounter.
  ///
  /// In en, this message translates to:
  /// **'Counter'**
  String get sfTitleCounter;

  /// No description provided for @sfTitleGenerator.
  ///
  /// In en, this message translates to:
  /// **'Generator'**
  String get sfTitleGenerator;

  /// No description provided for @sfModeTracker.
  ///
  /// In en, this message translates to:
  /// **'Locate'**
  String get sfModeTracker;

  /// No description provided for @sfModeCounter.
  ///
  /// In en, this message translates to:
  /// **'Counter'**
  String get sfModeCounter;

  /// No description provided for @sfModeGenerator.
  ///
  /// In en, this message translates to:
  /// **'Generator'**
  String get sfModeGenerator;

  /// No description provided for @sfStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get sfStop;

  /// No description provided for @sfPlayTone.
  ///
  /// In en, this message translates to:
  /// **'Play tone'**
  String get sfPlayTone;

  /// No description provided for @sfPlayCounter.
  ///
  /// In en, this message translates to:
  /// **'Play counter tone'**
  String get sfPlayCounter;

  /// No description provided for @sfMicDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission needed'**
  String get sfMicDeniedTitle;

  /// No description provided for @sfMicDeniedBody.
  ///
  /// In en, this message translates to:
  /// **'Grant microphone access to locate and analyze room sounds.'**
  String get sfMicDeniedBody;

  /// No description provided for @sfMicUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Microphone capture unavailable'**
  String get sfMicUnavailableTitle;

  /// No description provided for @sfMicUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Live microphone analysis isn\'t supported on this platform. The frequency generator still works.'**
  String get sfMicUnavailableBody;

  /// No description provided for @sfGrantPermission.
  ///
  /// In en, this message translates to:
  /// **'Grant access'**
  String get sfGrantPermission;

  /// No description provided for @sfOpenGenerator.
  ///
  /// In en, this message translates to:
  /// **'Open generator'**
  String get sfOpenGenerator;

  /// No description provided for @sfTrackerTitle.
  ///
  /// In en, this message translates to:
  /// **'Locate the source'**
  String get sfTrackerTitle;

  /// No description provided for @sfLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get sfLevel;

  /// No description provided for @sfDominant.
  ///
  /// In en, this message translates to:
  /// **'Dominant'**
  String get sfDominant;

  /// No description provided for @sfPeakHold.
  ///
  /// In en, this message translates to:
  /// **'Peak'**
  String get sfPeakHold;

  /// No description provided for @sfGuidanceHotter.
  ///
  /// In en, this message translates to:
  /// **'Getting warmer — closer to the source'**
  String get sfGuidanceHotter;

  /// No description provided for @sfGuidanceColder.
  ///
  /// In en, this message translates to:
  /// **'Getting colder — moving away'**
  String get sfGuidanceColder;

  /// No description provided for @sfGuidanceSteady.
  ///
  /// In en, this message translates to:
  /// **'Steady — move to change the reading'**
  String get sfGuidanceSteady;

  /// No description provided for @sfGuidanceSilent.
  ///
  /// In en, this message translates to:
  /// **'Too quiet — no clear sound detected'**
  String get sfGuidanceSilent;

  /// No description provided for @sfSetReference.
  ///
  /// In en, this message translates to:
  /// **'Mark spot'**
  String get sfSetReference;

  /// No description provided for @sfClearReference.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get sfClearReference;

  /// No description provided for @sfResetPeak.
  ///
  /// In en, this message translates to:
  /// **'Reset peak'**
  String get sfResetPeak;

  /// No description provided for @sfVsReference.
  ///
  /// In en, this message translates to:
  /// **'vs. marked spot'**
  String get sfVsReference;

  /// No description provided for @sfSpectrum.
  ///
  /// In en, this message translates to:
  /// **'Spectrum'**
  String get sfSpectrum;

  /// No description provided for @sfCounterTitle.
  ///
  /// In en, this message translates to:
  /// **'Counter / mask tone'**
  String get sfCounterTitle;

  /// No description provided for @sfCounterDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'A phone speaker can\'t truly cancel room noise. This plays a matching tone (optionally phase-inverted) plus optional masking noise to make the sound less noticeable.'**
  String get sfCounterDisclaimer;

  /// No description provided for @sfDetected.
  ///
  /// In en, this message translates to:
  /// **'Detected'**
  String get sfDetected;

  /// No description provided for @sfUseDetected.
  ///
  /// In en, this message translates to:
  /// **'Use detected'**
  String get sfUseDetected;

  /// No description provided for @sfCounterMicOff.
  ///
  /// In en, this message translates to:
  /// **'Microphone analysis is off — set the target frequency manually below.'**
  String get sfCounterMicOff;

  /// No description provided for @sfTargetFrequency.
  ///
  /// In en, this message translates to:
  /// **'Target frequency'**
  String get sfTargetFrequency;

  /// No description provided for @sfWaveform.
  ///
  /// In en, this message translates to:
  /// **'Waveform'**
  String get sfWaveform;

  /// No description provided for @sfPhase.
  ///
  /// In en, this message translates to:
  /// **'Phase'**
  String get sfPhase;

  /// No description provided for @sfInvertPhase.
  ///
  /// In en, this message translates to:
  /// **'Invert phase (180°)'**
  String get sfInvertPhase;

  /// No description provided for @sfMaskNoise.
  ///
  /// In en, this message translates to:
  /// **'Masking noise'**
  String get sfMaskNoise;

  /// No description provided for @sfVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get sfVolume;

  /// No description provided for @sfGeneratorTitle.
  ///
  /// In en, this message translates to:
  /// **'Frequency generator'**
  String get sfGeneratorTitle;

  /// No description provided for @sfGeneratorHint.
  ///
  /// In en, this message translates to:
  /// **'Pick a frequency and waveform to generate a pure test tone.'**
  String get sfGeneratorHint;

  /// No description provided for @sfTitleDoppler.
  ///
  /// In en, this message translates to:
  /// **'Doppler'**
  String get sfTitleDoppler;

  /// No description provided for @sfModeDoppler.
  ///
  /// In en, this message translates to:
  /// **'Doppler'**
  String get sfModeDoppler;

  /// No description provided for @sfDopplerTitle.
  ///
  /// In en, this message translates to:
  /// **'Doppler Effect Analysis'**
  String get sfDopplerTitle;

  /// No description provided for @sfDopplerExplanation.
  ///
  /// In en, this message translates to:
  /// **'Record a passing tone (like a car horn or siren) to estimate its speed, frequency, and distance, or load a previously saved WAV audio clip.'**
  String get sfDopplerExplanation;

  /// No description provided for @sfDopplerLoadClip.
  ///
  /// In en, this message translates to:
  /// **'Load WAV Clip'**
  String get sfDopplerLoadClip;

  /// No description provided for @sfDopplerVelocity.
  ///
  /// In en, this message translates to:
  /// **'Velocity'**
  String get sfDopplerVelocity;

  /// No description provided for @sfDopplerDistance.
  ///
  /// In en, this message translates to:
  /// **'Closest Distance'**
  String get sfDopplerDistance;

  /// No description provided for @sfDopplerSourceFreq.
  ///
  /// In en, this message translates to:
  /// **'Source Frequency'**
  String get sfDopplerSourceFreq;

  /// No description provided for @sfDopplerInflection.
  ///
  /// In en, this message translates to:
  /// **'Inflection Time'**
  String get sfDopplerInflection;

  /// No description provided for @sfDopplerTemp.
  ///
  /// In en, this message translates to:
  /// **'Air Temperature'**
  String get sfDopplerTemp;

  /// No description provided for @sfDopplerSpeedOfSound.
  ///
  /// In en, this message translates to:
  /// **'Speed of Sound'**
  String get sfDopplerSpeedOfSound;

  /// No description provided for @sfDopplerParameters.
  ///
  /// In en, this message translates to:
  /// **'Model Parameters'**
  String get sfDopplerParameters;

  /// No description provided for @sfDopplerStatusNoData.
  ///
  /// In en, this message translates to:
  /// **'No audio clip recorded yet. Start recording above or load a demo.'**
  String get sfDopplerStatusNoData;

  /// No description provided for @sfDopplerStatusAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing audio clip...'**
  String get sfDopplerStatusAnalyzing;

  /// No description provided for @sfDopplerStatusSuccess.
  ///
  /// In en, this message translates to:
  /// **'Analysis complete. Adjust markers to align the theoretical model (solid line) with the recorded peak frequencies (purple dots).'**
  String get sfDopplerStatusSuccess;

  /// No description provided for @sfDopplerGraphTitle.
  ///
  /// In en, this message translates to:
  /// **'Frequency vs. Time'**
  String get sfDopplerGraphTitle;

  /// No description provided for @sfDopplerInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Understanding the Doppler Graph'**
  String get sfDopplerInfoTitle;

  /// No description provided for @sfDopplerInfoContent.
  ///
  /// In en, this message translates to:
  /// **'• X-Axis (Horizontal): Time in seconds.\n• Y-Axis (Vertical): Frequency in Hertz (Hz).\n• Dots: Detected peak frequencies from the recorded clip.\n• Solid Line: Theoretical Doppler model curve.\n• Vertical Line (t₀): Time of closest approach.\n\nGoal: Adjust the parameters to align the solid line with the dots.'**
  String get sfDopplerInfoContent;

  /// No description provided for @sfWaveSine.
  ///
  /// In en, this message translates to:
  /// **'Sine'**
  String get sfWaveSine;

  /// No description provided for @sfWaveSquare.
  ///
  /// In en, this message translates to:
  /// **'Square'**
  String get sfWaveSquare;

  /// No description provided for @sfWaveTriangle.
  ///
  /// In en, this message translates to:
  /// **'Triangle'**
  String get sfWaveTriangle;

  /// No description provided for @sfWaveSawtooth.
  ///
  /// In en, this message translates to:
  /// **'Sawtooth'**
  String get sfWaveSawtooth;

  /// No description provided for @sfToneNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Tone active'**
  String get sfToneNotificationTitle;

  /// No description provided for @sfToneNotificationText.
  ///
  /// In en, this message translates to:
  /// **'ToolLab is generating a tone'**
  String get sfToneNotificationText;

  /// No description provided for @sfMicDefault.
  ///
  /// In en, this message translates to:
  /// **'Default microphone'**
  String get sfMicDefault;

  /// No description provided for @sfRefreshMics.
  ///
  /// In en, this message translates to:
  /// **'Rescan microphones'**
  String get sfRefreshMics;

  /// No description provided for @sfMicGain.
  ///
  /// In en, this message translates to:
  /// **'Mic gain'**
  String get sfMicGain;

  /// No description provided for @sfInputSettings.
  ///
  /// In en, this message translates to:
  /// **'Input settings'**
  String get sfInputSettings;

  /// No description provided for @sfSaveClipButton.
  ///
  /// In en, this message translates to:
  /// **'Save clip'**
  String get sfSaveClipButton;

  /// No description provided for @sfSpectrumSettings.
  ///
  /// In en, this message translates to:
  /// **'Spectrum settings'**
  String get sfSpectrumSettings;

  /// No description provided for @sfRecordClip.
  ///
  /// In en, this message translates to:
  /// **'Record clip'**
  String get sfRecordClip;

  /// No description provided for @sfStopAndSave.
  ///
  /// In en, this message translates to:
  /// **'Stop & save'**
  String get sfStopAndSave;

  /// No description provided for @sfClipSavedAndroid.
  ///
  /// In en, this message translates to:
  /// **'Audio clip saved to Downloads'**
  String get sfClipSavedAndroid;

  /// No description provided for @sfClipSaved.
  ///
  /// In en, this message translates to:
  /// **'Clip saved to {path}'**
  String sfClipSaved(String path);

  /// No description provided for @sfClipSaveError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the audio clip'**
  String get sfClipSaveError;

  /// No description provided for @sfEnlargeSpectrum.
  ///
  /// In en, this message translates to:
  /// **'Enlarge spectrum'**
  String get sfEnlargeSpectrum;

  /// No description provided for @sfMaxHold.
  ///
  /// In en, this message translates to:
  /// **'Max hold'**
  String get sfMaxHold;

  /// No description provided for @sfResetZoom.
  ///
  /// In en, this message translates to:
  /// **'Reset zoom'**
  String get sfResetZoom;

  /// No description provided for @sfRange.
  ///
  /// In en, this message translates to:
  /// **'Range'**
  String get sfRange;

  /// No description provided for @sfScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Screenshot'**
  String get sfScreenshot;

  /// No description provided for @sfCopyImage.
  ///
  /// In en, this message translates to:
  /// **'Copy to clipboard'**
  String get sfCopyImage;

  /// No description provided for @sfSaveImage.
  ///
  /// In en, this message translates to:
  /// **'Save image'**
  String get sfSaveImage;

  /// No description provided for @sfImageCopied.
  ///
  /// In en, this message translates to:
  /// **'Spectrum copied to clipboard'**
  String get sfImageCopied;

  /// No description provided for @sfImageCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t copy the spectrum image'**
  String get sfImageCopyFailed;

  /// No description provided for @sfSpectrogram.
  ///
  /// In en, this message translates to:
  /// **'Spectrogram'**
  String get sfSpectrogram;

  /// No description provided for @sfStopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get sfStopRecording;

  /// No description provided for @sfRecordingLabel.
  ///
  /// In en, this message translates to:
  /// **'REC'**
  String get sfRecordingLabel;

  /// No description provided for @sfSavingClip.
  ///
  /// In en, this message translates to:
  /// **'Saving clip…'**
  String get sfSavingClip;

  /// No description provided for @sfResFast.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get sfResFast;

  /// No description provided for @sfResBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get sfResBalanced;

  /// No description provided for @sfResFine.
  ///
  /// In en, this message translates to:
  /// **'Fine'**
  String get sfResFine;

  /// No description provided for @sfBinWidth.
  ///
  /// In en, this message translates to:
  /// **'≈ {hz} Hz per bin'**
  String sfBinWidth(String hz);

  /// No description provided for @sfTitleMorse.
  ///
  /// In en, this message translates to:
  /// **'Morse Code'**
  String get sfTitleMorse;

  /// No description provided for @sfMorseGenTab.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get sfMorseGenTab;

  /// No description provided for @sfMorseAnalTab.
  ///
  /// In en, this message translates to:
  /// **'Analyze'**
  String get sfMorseAnalTab;

  /// No description provided for @sfMorseWpm.
  ///
  /// In en, this message translates to:
  /// **'Morse Speed'**
  String get sfMorseWpm;

  /// No description provided for @sfMorsePlayMode.
  ///
  /// In en, this message translates to:
  /// **'Signal Mode'**
  String get sfMorsePlayMode;

  /// No description provided for @sfMorsePlayBoth.
  ///
  /// In en, this message translates to:
  /// **'Sound & Flash'**
  String get sfMorsePlayBoth;

  /// No description provided for @sfMorsePlaySound.
  ///
  /// In en, this message translates to:
  /// **'Sound only'**
  String get sfMorsePlaySound;

  /// No description provided for @sfMorsePlayFlash.
  ///
  /// In en, this message translates to:
  /// **'Flash only'**
  String get sfMorsePlayFlash;

  /// No description provided for @sfMorsePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Message to encode...'**
  String get sfMorsePlaceholder;

  /// No description provided for @sfMorseDecodedOutput.
  ///
  /// In en, this message translates to:
  /// **'Decoded Text'**
  String get sfMorseDecodedOutput;

  /// No description provided for @sfMorseLiveListening.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get sfMorseLiveListening;

  /// No description provided for @sfMorseExportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Morse audio exported successfully'**
  String get sfMorseExportSuccess;

  /// No description provided for @toolNameCompass.
  ///
  /// In en, this message translates to:
  /// **'Compass'**
  String get toolNameCompass;

  /// No description provided for @toolDescCompass.
  ///
  /// In en, this message translates to:
  /// **'Tilt-compensated heading dial with magnetic status'**
  String get toolDescCompass;

  /// No description provided for @compassHeading.
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get compassHeading;

  /// No description provided for @compassMagneticField.
  ///
  /// In en, this message translates to:
  /// **'Magnetic Field'**
  String get compassMagneticField;

  /// No description provided for @compassInterferenceNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get compassInterferenceNormal;

  /// No description provided for @compassInterferenceWarning.
  ///
  /// In en, this message translates to:
  /// **'Interference Detected'**
  String get compassInterferenceWarning;

  /// No description provided for @compassCalibrateTip.
  ///
  /// In en, this message translates to:
  /// **'Keep away from metal or magnets if heading feels inaccurate.'**
  String get compassCalibrateTip;

  /// No description provided for @compassInfoTooltip.
  ///
  /// In en, this message translates to:
  /// **'How to use'**
  String get compassInfoTooltip;

  /// No description provided for @compassInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Using the Compass'**
  String get compassInfoTitle;

  /// No description provided for @compassInfoIntro.
  ///
  /// In en, this message translates to:
  /// **'The compass shows your heading — the direction the top edge of your device is pointing — from the built-in magnetometer and accelerometer.'**
  String get compassInfoIntro;

  /// No description provided for @compassStepLevelTitle.
  ///
  /// In en, this message translates to:
  /// **'1. Hold the device flat'**
  String get compassStepLevelTitle;

  /// No description provided for @compassStepLevelBody.
  ///
  /// In en, this message translates to:
  /// **'Keep the screen facing up and roughly level with the ground. The level indicator turns green when you are flat enough for an accurate reading. Reading it while tilted or held upright is unreliable.'**
  String get compassStepLevelBody;

  /// No description provided for @compassStepCalibrateTitle.
  ///
  /// In en, this message translates to:
  /// **'2. Calibrate with a figure-8'**
  String get compassStepCalibrateTitle;

  /// No description provided for @compassStepCalibrateBody.
  ///
  /// In en, this message translates to:
  /// **'If the heading drifts, spins, or never settles, wave the device slowly through a figure-8 motion a few times. This recalibrates the magnetometer — the most common cause of a jumpy compass.'**
  String get compassStepCalibrateBody;

  /// No description provided for @compassStepMetalTitle.
  ///
  /// In en, this message translates to:
  /// **'3. Stay clear of metal'**
  String get compassStepMetalTitle;

  /// No description provided for @compassStepMetalBody.
  ///
  /// In en, this message translates to:
  /// **'Magnets, speakers, laptops, phone cases, cars and steel furniture bend the magnetic field. The Magnetic Field panel warns you when interference is detected.'**
  String get compassStepMetalBody;

  /// No description provided for @compassStepReadTitle.
  ///
  /// In en, this message translates to:
  /// **'4. Read the heading'**
  String get compassStepReadTitle;

  /// No description provided for @compassStepReadBody.
  ///
  /// In en, this message translates to:
  /// **'The red needle stays pointing up; the dial rotates so N sits at magnetic north. The large number and letters (e.g. 214° SW) are your current heading.'**
  String get compassStepReadBody;

  /// No description provided for @compassSimNote.
  ///
  /// In en, this message translates to:
  /// **'On devices without magnetic sensors the compass runs in simulation — swipe horizontally on the dial to turn it.'**
  String get compassSimNote;

  /// No description provided for @compassLevelGood.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get compassLevelGood;

  /// No description provided for @compassLevelHoldFlat.
  ///
  /// In en, this message translates to:
  /// **'Hold flat'**
  String get compassLevelHoldFlat;

  /// No description provided for @compassTiltLabel.
  ///
  /// In en, this message translates to:
  /// **'Tilt {deg}°'**
  String compassTiltLabel(String deg);

  /// No description provided for @compassHoldFlatHint.
  ///
  /// In en, this message translates to:
  /// **'Hold the device flat and level for an accurate heading.'**
  String get compassHoldFlatHint;

  /// No description provided for @compassCalibrateHint.
  ///
  /// In en, this message translates to:
  /// **'Heading unstable? Wave the device in a figure-8 to recalibrate.'**
  String get compassCalibrateHint;

  /// No description provided for @toolNameFileManager.
  ///
  /// In en, this message translates to:
  /// **'File Manager'**
  String get toolNameFileManager;

  /// No description provided for @toolDescFileManager.
  ///
  /// In en, this message translates to:
  /// **'Browse local files and FTP or SMB network shares'**
  String get toolDescFileManager;

  /// No description provided for @fileManagerAppFiles.
  ///
  /// In en, this message translates to:
  /// **'Default folder'**
  String get fileManagerAppFiles;

  /// No description provided for @fileManagerConnections.
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get fileManagerConnections;

  /// No description provided for @fileManagerAddConnection.
  ///
  /// In en, this message translates to:
  /// **'Add connection'**
  String get fileManagerAddConnection;

  /// No description provided for @fileManagerRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get fileManagerRefresh;

  /// No description provided for @fileManagerNewFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get fileManagerNewFolder;

  /// No description provided for @fileManagerFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite folder'**
  String get fileManagerFavorite;

  /// No description provided for @fileManagerEmptyFolder.
  ///
  /// In en, this message translates to:
  /// **'This folder is empty'**
  String get fileManagerEmptyFolder;

  /// No description provided for @fileManagerBrokenLink.
  ///
  /// In en, this message translates to:
  /// **'Broken link - the target no longer exists'**
  String get fileManagerBrokenLink;

  /// No description provided for @fileManagerFtp.
  ///
  /// In en, this message translates to:
  /// **'FTP'**
  String get fileManagerFtp;

  /// No description provided for @fileManagerSmb.
  ///
  /// In en, this message translates to:
  /// **'SMB'**
  String get fileManagerSmb;

  /// No description provided for @fileManagerConnectionName.
  ///
  /// In en, this message translates to:
  /// **'Connection name'**
  String get fileManagerConnectionName;

  /// No description provided for @fileManagerHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get fileManagerHost;

  /// No description provided for @fileManagerPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get fileManagerPort;

  /// No description provided for @fileManagerShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get fileManagerShare;

  /// No description provided for @fileManagerUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get fileManagerUsername;

  /// No description provided for @fileManagerPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get fileManagerPassword;

  /// No description provided for @fileManagerInitialPath.
  ///
  /// In en, this message translates to:
  /// **'Initial path'**
  String get fileManagerInitialPath;

  /// No description provided for @fileManagerAllFilesAccess.
  ///
  /// In en, this message translates to:
  /// **'Allow access to all files'**
  String get fileManagerAllFilesAccess;

  /// No description provided for @fileManagerCut.
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get fileManagerCut;

  /// No description provided for @fileManagerPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get fileManagerPaste;

  /// No description provided for @fileManagerDiscoverShares.
  ///
  /// In en, this message translates to:
  /// **'Discover shares'**
  String get fileManagerDiscoverShares;

  /// No description provided for @fileManagerDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete selected files?'**
  String get fileManagerDeleteTitle;

  /// No description provided for @fileManagerDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} selected item(s), including all contents of selected folders? This cannot be undone.'**
  String fileManagerDeleteMessage(int count);

  /// No description provided for @fileManagerSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String fileManagerSelected(int count);

  /// No description provided for @fileManagerSelect.
  ///
  /// In en, this message translates to:
  /// **'Select files'**
  String get fileManagerSelect;

  /// No description provided for @fileManagerSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get fileManagerSelectAll;

  /// No description provided for @fileManagerCopying.
  ///
  /// In en, this message translates to:
  /// **'Copying files'**
  String get fileManagerCopying;

  /// No description provided for @fileManagerMoving.
  ///
  /// In en, this message translates to:
  /// **'Moving files'**
  String get fileManagerMoving;

  /// No description provided for @fileManagerDeleting.
  ///
  /// In en, this message translates to:
  /// **'Deleting files'**
  String get fileManagerDeleting;

  /// No description provided for @fileManagerOperationProgress.
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total} files processed'**
  String fileManagerOperationProgress(int completed, int total);

  /// No description provided for @fileManagerOperationBackground.
  ///
  /// In en, this message translates to:
  /// **'Continues while ToolLab is in the background'**
  String get fileManagerOperationBackground;

  /// No description provided for @fileManagerMoveBuffer.
  ///
  /// In en, this message translates to:
  /// **'{count} item(s) ready to move'**
  String fileManagerMoveBuffer(int count);

  /// No description provided for @fileManagerCopyBuffer.
  ///
  /// In en, this message translates to:
  /// **'{count} item(s) ready to copy'**
  String fileManagerCopyBuffer(int count);

  /// No description provided for @fileManagerDropActionTitle.
  ///
  /// In en, this message translates to:
  /// **'Add dropped files'**
  String get fileManagerDropActionTitle;

  /// No description provided for @fileManagerDropActionMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose whether to copy or move the dropped files.'**
  String get fileManagerDropActionMessage;

  /// No description provided for @fileManagerMove.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get fileManagerMove;

  /// No description provided for @fileManagerSettings.
  ///
  /// In en, this message translates to:
  /// **'File Manager settings'**
  String get fileManagerSettings;

  /// No description provided for @fileManagerSortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort files by'**
  String get fileManagerSortBy;

  /// No description provided for @fileManagerSortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fileManagerSortName;

  /// No description provided for @fileManagerSortDate.
  ///
  /// In en, this message translates to:
  /// **'Modified date'**
  String get fileManagerSortDate;

  /// No description provided for @fileManagerSortSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get fileManagerSortSize;

  /// No description provided for @fileManagerSortAscending.
  ///
  /// In en, this message translates to:
  /// **'Ascending order'**
  String get fileManagerSortAscending;

  /// No description provided for @fileManagerRemoveConnectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove connection?'**
  String get fileManagerRemoveConnectionTitle;

  /// No description provided for @fileManagerRemoveConnectionMessage.
  ///
  /// In en, this message translates to:
  /// **'Remove saved connection \"{name}\" and its stored password?'**
  String fileManagerRemoveConnectionMessage(String name);

  /// No description provided for @fileManagerClearClipboard.
  ///
  /// In en, this message translates to:
  /// **'Clear clipboard'**
  String get fileManagerClearClipboard;

  /// No description provided for @fileManagerOpenChooser.
  ///
  /// In en, this message translates to:
  /// **'Ask every time'**
  String get fileManagerOpenChooser;

  /// No description provided for @fileManagerOpenImages.
  ///
  /// In en, this message translates to:
  /// **'Open images with'**
  String get fileManagerOpenImages;

  /// No description provided for @fileManagerOpenPdf.
  ///
  /// In en, this message translates to:
  /// **'Open PDFs with'**
  String get fileManagerOpenPdf;

  /// No description provided for @fileManagerOpenAudio.
  ///
  /// In en, this message translates to:
  /// **'Open audio with'**
  String get fileManagerOpenAudio;

  /// No description provided for @fileManagerOpenVideo.
  ///
  /// In en, this message translates to:
  /// **'Open video with'**
  String get fileManagerOpenVideo;

  /// No description provided for @fileManagerOpenInternalPlayer.
  ///
  /// In en, this message translates to:
  /// **'Internal player'**
  String get fileManagerOpenInternalPlayer;

  /// No description provided for @fileManagerOpenMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Open Markdown with'**
  String get fileManagerOpenMarkdown;

  /// No description provided for @fileManagerOpenText.
  ///
  /// In en, this message translates to:
  /// **'Open text files with'**
  String get fileManagerOpenText;

  /// No description provided for @fileManagerOpenSqlite.
  ///
  /// In en, this message translates to:
  /// **'Open SQLite databases with'**
  String get fileManagerOpenSqlite;

  /// No description provided for @fileManagerOpenWithSystem.
  ///
  /// In en, this message translates to:
  /// **'Open with system default'**
  String get fileManagerOpenWithSystem;

  /// No description provided for @fileManagerDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get fileManagerDownloads;

  /// No description provided for @fileManagerGrantFileAccess.
  ///
  /// In en, this message translates to:
  /// **'Allow access to device files'**
  String get fileManagerGrantFileAccess;

  /// No description provided for @fileManagerDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get fileManagerDetails;

  /// No description provided for @fileManagerDetailSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get fileManagerDetailSize;

  /// No description provided for @fileManagerDetailModified.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get fileManagerDetailModified;

  /// No description provided for @fileManagerDetailType.
  ///
  /// In en, this message translates to:
  /// **'File type'**
  String get fileManagerDetailType;

  /// No description provided for @fileManagerDetailPath.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get fileManagerDetailPath;

  /// No description provided for @fileManagerFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get fileManagerFolder;

  /// No description provided for @fileManagerStartupFolder.
  ///
  /// In en, this message translates to:
  /// **'Startup folder'**
  String get fileManagerStartupFolder;

  /// No description provided for @fileManagerCurrentFolder.
  ///
  /// In en, this message translates to:
  /// **'Current folder'**
  String get fileManagerCurrentFolder;

  /// No description provided for @fileManagerSorting.
  ///
  /// In en, this message translates to:
  /// **'Sorting'**
  String get fileManagerSorting;

  /// No description provided for @fileManagerOpenWith.
  ///
  /// In en, this message translates to:
  /// **'Open with'**
  String get fileManagerOpenWith;

  /// No description provided for @fileManagerFoldersFirst.
  ///
  /// In en, this message translates to:
  /// **'Folders before files'**
  String get fileManagerFoldersFirst;

  /// No description provided for @fileManagerFileExistsTitle.
  ///
  /// In en, this message translates to:
  /// **'File already exists'**
  String get fileManagerFileExistsTitle;

  /// No description provided for @fileManagerFileExistsMessage.
  ///
  /// In en, this message translates to:
  /// **'{names} already exists in this folder.'**
  String fileManagerFileExistsMessage(String names);

  /// No description provided for @fileManagerKeepBoth.
  ///
  /// In en, this message translates to:
  /// **'Keep both'**
  String get fileManagerKeepBoth;

  /// No description provided for @fileManagerOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get fileManagerOverwrite;

  /// No description provided for @fileManagerRecentLocations.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get fileManagerRecentLocations;

  /// No description provided for @fileManagerCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get fileManagerCategories;

  /// No description provided for @fileManagerCategoryImages.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get fileManagerCategoryImages;

  /// No description provided for @fileManagerCategoryApps.
  ///
  /// In en, this message translates to:
  /// **'Apps'**
  String get fileManagerCategoryApps;

  /// No description provided for @fileManagerCategorySystem.
  ///
  /// In en, this message translates to:
  /// **'System files'**
  String get fileManagerCategorySystem;

  /// No description provided for @fileManagerNoImages.
  ///
  /// In en, this message translates to:
  /// **'No images found'**
  String get fileManagerNoImages;

  /// No description provided for @fileManagerNoApps.
  ///
  /// In en, this message translates to:
  /// **'No apps found'**
  String get fileManagerNoApps;

  /// No description provided for @fileManagerNoSystemPaths.
  ///
  /// In en, this message translates to:
  /// **'No system folders available'**
  String get fileManagerNoSystemPaths;

  /// No description provided for @fileManagerAppCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 app} other{{count} apps}}'**
  String fileManagerAppCount(int count);

  /// No description provided for @fileManagerStorageUsed.
  ///
  /// In en, this message translates to:
  /// **'{used} of {total} used'**
  String fileManagerStorageUsed(String used, String total);

  /// No description provided for @fileManagerStorageFree.
  ///
  /// In en, this message translates to:
  /// **'{free} free'**
  String fileManagerStorageFree(String free);

  /// No description provided for @fileManagerOpenAppInfo.
  ///
  /// In en, this message translates to:
  /// **'App info'**
  String get fileManagerOpenAppInfo;

  /// No description provided for @fileManagerFolderItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get fileManagerFolderItems;

  /// No description provided for @fileManagerFolderFileCount.
  ///
  /// In en, this message translates to:
  /// **'{count} files'**
  String fileManagerFolderFileCount(int count);

  /// No description provided for @fileManagerFolderItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String fileManagerFolderItemCount(int count);

  /// No description provided for @fileManagerInstallApk.
  ///
  /// In en, this message translates to:
  /// **'Install APK'**
  String get fileManagerInstallApk;

  /// No description provided for @fileManagerStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get fileManagerStorage;

  /// No description provided for @fileManagerCompressZip.
  ///
  /// In en, this message translates to:
  /// **'Compress to ZIP'**
  String get fileManagerCompressZip;

  /// No description provided for @fileManagerCompressing.
  ///
  /// In en, this message translates to:
  /// **'Creating ZIP archive'**
  String get fileManagerCompressing;

  /// No description provided for @fileManagerExtract.
  ///
  /// In en, this message translates to:
  /// **'Extract'**
  String get fileManagerExtract;

  /// No description provided for @fileManagerExtracting.
  ///
  /// In en, this message translates to:
  /// **'Extracting archive'**
  String get fileManagerExtracting;

  /// No description provided for @fileManagerArchiveConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive files already exist'**
  String get fileManagerArchiveConflictTitle;

  /// No description provided for @fileManagerArchiveConflictMessage.
  ///
  /// In en, this message translates to:
  /// **'{count} extracted files already exist.'**
  String fileManagerArchiveConflictMessage(int count);

  /// No description provided for @fileManagerItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String fileManagerItemCount(int count);

  /// No description provided for @fileManagerCollapseGroup.
  ///
  /// In en, this message translates to:
  /// **'Collapse folder'**
  String get fileManagerCollapseGroup;

  /// No description provided for @fileManagerExpandGroup.
  ///
  /// In en, this message translates to:
  /// **'Expand folder'**
  String get fileManagerExpandGroup;

  /// No description provided for @fileManagerOpenFolder.
  ///
  /// In en, this message translates to:
  /// **'Open folder in explorer'**
  String get fileManagerOpenFolder;

  /// No description provided for @fileManagerMoreEntries.
  ///
  /// In en, this message translates to:
  /// **'and {count} more'**
  String fileManagerMoreEntries(int count);

  /// No description provided for @fileManagerSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get fileManagerSkip;

  /// No description provided for @fileManagerApplyToAll.
  ///
  /// In en, this message translates to:
  /// **'Apply to all conflicts'**
  String get fileManagerApplyToAll;

  /// No description provided for @fileManagerDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get fileManagerDocuments;

  /// No description provided for @toolNameHealthDashboard.
  ///
  /// In en, this message translates to:
  /// **'Health Dashboard'**
  String get toolNameHealthDashboard;

  /// No description provided for @toolDescHealthDashboard.
  ///
  /// In en, this message translates to:
  /// **'Bring your health data and workouts together'**
  String get toolDescHealthDashboard;

  /// No description provided for @healthDashboardRefresh.
  ///
  /// In en, this message translates to:
  /// **'Sync health data and the backend'**
  String get healthDashboardRefresh;

  /// No description provided for @healthDashboardHeadline.
  ///
  /// In en, this message translates to:
  /// **'Your health, in focus'**
  String get healthDashboardHeadline;

  /// No description provided for @healthDashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A single private view of your activity and recovery.'**
  String get healthDashboardSubtitle;

  /// No description provided for @healthDashboardDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get healthDashboardDistance;

  /// No description provided for @healthDashboardDistanceAllTime.
  ///
  /// In en, this message translates to:
  /// **'Distance · all time'**
  String get healthDashboardDistanceAllTime;

  /// No description provided for @healthDashboardCaloriesAllTime.
  ///
  /// In en, this message translates to:
  /// **'Calories · all time'**
  String get healthDashboardCaloriesAllTime;

  /// No description provided for @healthDashboardActiveTimeAllTime.
  ///
  /// In en, this message translates to:
  /// **'Active time · all time'**
  String get healthDashboardActiveTimeAllTime;

  /// No description provided for @healthDashboardStepsAllTime.
  ///
  /// In en, this message translates to:
  /// **'Steps · all time'**
  String get healthDashboardStepsAllTime;

  /// No description provided for @healthDashboardWorkoutsAllTime.
  ///
  /// In en, this message translates to:
  /// **'Workouts · all time'**
  String get healthDashboardWorkoutsAllTime;

  /// No description provided for @healthDashboardDistanceLastSevenDays.
  ///
  /// In en, this message translates to:
  /// **'Distance · last 7 days'**
  String get healthDashboardDistanceLastSevenDays;

  /// No description provided for @healthDashboardCaloriesLastSevenDays.
  ///
  /// In en, this message translates to:
  /// **'Calories · last 7 days'**
  String get healthDashboardCaloriesLastSevenDays;

  /// No description provided for @healthDashboardActiveTimeLastSevenDays.
  ///
  /// In en, this message translates to:
  /// **'Active time · last 7 days'**
  String get healthDashboardActiveTimeLastSevenDays;

  /// No description provided for @healthDashboardStepsLastSevenDays.
  ///
  /// In en, this message translates to:
  /// **'Steps · last 7 days'**
  String get healthDashboardStepsLastSevenDays;

  /// No description provided for @healthDashboardLatestRestingHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Latest resting heart rate'**
  String get healthDashboardLatestRestingHeartRate;

  /// No description provided for @healthDashboardLatestHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Latest heart rate'**
  String get healthDashboardLatestHeartRate;

  /// No description provided for @healthDashboardCalories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get healthDashboardCalories;

  /// No description provided for @healthDashboardCaloriesIntakeAllTime.
  ///
  /// In en, this message translates to:
  /// **'Calories intake · all time'**
  String get healthDashboardCaloriesIntakeAllTime;

  /// No description provided for @healthDashboardCaloriesIntakeLastSevenDays.
  ///
  /// In en, this message translates to:
  /// **'Calories intake · last 7 days'**
  String get healthDashboardCaloriesIntakeLastSevenDays;

  /// No description provided for @healthDashboardCaloriesIntakeToday.
  ///
  /// In en, this message translates to:
  /// **'Calories intake · today'**
  String get healthDashboardCaloriesIntakeToday;

  /// No description provided for @healthDashboardCaloriesToday.
  ///
  /// In en, this message translates to:
  /// **'Calories · today'**
  String get healthDashboardCaloriesToday;

  /// No description provided for @healthDashboardNutrition.
  ///
  /// In en, this message translates to:
  /// **'Nutrition'**
  String get healthDashboardNutrition;

  /// No description provided for @healthDashboardMeal.
  ///
  /// In en, this message translates to:
  /// **'Meal'**
  String get healthDashboardMeal;

  /// No description provided for @healthDashboardMealsOnDay.
  ///
  /// In en, this message translates to:
  /// **'Meals on {date}'**
  String healthDashboardMealsOnDay(String date);

  /// No description provided for @healthDashboardNoMeals.
  ///
  /// In en, this message translates to:
  /// **'No meals recorded.'**
  String get healthDashboardNoMeals;

  /// No description provided for @healthDashboardMealTimeline.
  ///
  /// In en, this message translates to:
  /// **'Meal timeline'**
  String get healthDashboardMealTimeline;

  /// No description provided for @healthDashboardProtein.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get healthDashboardProtein;

  /// No description provided for @healthDashboardCarbohydrates.
  ///
  /// In en, this message translates to:
  /// **'Carbohydrates'**
  String get healthDashboardCarbohydrates;

  /// No description provided for @healthDashboardFat.
  ///
  /// In en, this message translates to:
  /// **'Fat'**
  String get healthDashboardFat;

  /// No description provided for @healthDashboardActiveTime.
  ///
  /// In en, this message translates to:
  /// **'Active time'**
  String get healthDashboardActiveTime;

  /// No description provided for @healthDashboardWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get healthDashboardWorkouts;

  /// No description provided for @healthDashboardStepsToday.
  ///
  /// In en, this message translates to:
  /// **'Steps today'**
  String get healthDashboardStepsToday;

  /// No description provided for @healthDashboardWeight.
  ///
  /// In en, this message translates to:
  /// **'Latest weight'**
  String get healthDashboardWeight;

  /// No description provided for @healthDashboardRestingHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Resting heart rate'**
  String get healthDashboardRestingHeartRate;

  /// No description provided for @healthDashboardLastSleep.
  ///
  /// In en, this message translates to:
  /// **'Latest sleep'**
  String get healthDashboardLastSleep;

  /// No description provided for @healthDashboardWorkoutTrend.
  ///
  /// In en, this message translates to:
  /// **'Distance · last 7 days'**
  String get healthDashboardWorkoutTrend;

  /// No description provided for @healthDashboardHeartRateTrend.
  ///
  /// In en, this message translates to:
  /// **'Average heart rate · last 7 days'**
  String get healthDashboardHeartRateTrend;

  /// No description provided for @healthDashboardRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get healthDashboardRecentActivity;

  /// No description provided for @healthDashboardNoData.
  ///
  /// In en, this message translates to:
  /// **'No health data yet. Sync a treadmill workout or connect Health Connect on Android.'**
  String get healthDashboardNoData;

  /// No description provided for @healthDashboardTreadmillRun.
  ///
  /// In en, this message translates to:
  /// **'Treadmill run'**
  String get healthDashboardTreadmillRun;

  /// No description provided for @healthDashboardConnectHealthConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect and import Health Connect'**
  String get healthDashboardConnectHealthConnect;

  /// No description provided for @healthDashboardImportHealthConnect.
  ///
  /// In en, this message translates to:
  /// **'Import Health Connect now'**
  String get healthDashboardImportHealthConnect;

  /// No description provided for @healthDashboardManageHealthConnect.
  ///
  /// In en, this message translates to:
  /// **'Manage Health Connect'**
  String get healthDashboardManageHealthConnect;

  /// No description provided for @healthDashboardManageHealthConnectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open Android permissions or Health Connect system settings.'**
  String get healthDashboardManageHealthConnectSubtitle;

  /// No description provided for @healthDashboardHealthConnectImported.
  ///
  /// In en, this message translates to:
  /// **'Health Connect data imported'**
  String get healthDashboardHealthConnectImported;

  /// No description provided for @healthDashboardHealthConnectRepaired.
  ///
  /// In en, this message translates to:
  /// **'Health Connect cache repaired'**
  String get healthDashboardHealthConnectRepaired;

  /// No description provided for @healthDashboardSyncInProgress.
  ///
  /// In en, this message translates to:
  /// **'Sync already in progress'**
  String get healthDashboardSyncInProgress;

  /// No description provided for @healthDashboardSyncInProgressBody.
  ///
  /// In en, this message translates to:
  /// **'A Health Connect import or cloud sync is still running. Wait for it to finish before starting another one.'**
  String get healthDashboardSyncInProgressBody;

  /// No description provided for @healthDashboardSyncNoChanges.
  ///
  /// In en, this message translates to:
  /// **'No health data changes to sync'**
  String get healthDashboardSyncNoChanges;

  /// No description provided for @healthDashboardRepairHealthConnect.
  ///
  /// In en, this message translates to:
  /// **'Start Health Connect import over'**
  String get healthDashboardRepairHealthConnect;

  /// No description provided for @healthDashboardRepairHealthConnectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clear locally imported Health Connect data and import history again.'**
  String get healthDashboardRepairHealthConnectSubtitle;

  /// No description provided for @healthDashboardResetHealthConnectDescription.
  ///
  /// In en, this message translates to:
  /// **'This removes all locally imported Health Connect cache and canonical records on this device. It does not affect Health Connect or cloud data. The next import starts from the beginning and can take a long time. Regular imports resume from the last successful sync.'**
  String get healthDashboardResetHealthConnectDescription;

  /// No description provided for @healthDashboardStartOver.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get healthDashboardStartOver;

  /// No description provided for @healthDashboardConnectHealthConnectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Requests access and imports all available historical data from Health Connect.'**
  String get healthDashboardConnectHealthConnectSubtitle;

  /// No description provided for @healthDashboardHealthConnectAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Export Health Connect analysis'**
  String get healthDashboardHealthConnectAnalysis;

  /// No description provided for @healthDashboardHealthConnectAnalysisSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read every supported type and save raw records, metadata, sessions, routes, and per-type errors to a separate SQLite database.'**
  String get healthDashboardHealthConnectAnalysisSubtitle;

  /// No description provided for @healthDashboardHealthConnectAnalysisFailed.
  ///
  /// In en, this message translates to:
  /// **'Health Connect analysis export failed'**
  String get healthDashboardHealthConnectAnalysisFailed;

  /// No description provided for @healthDashboardHealthConnectDiscovery.
  ///
  /// In en, this message translates to:
  /// **'Export Health Connect discovery'**
  String get healthDashboardHealthConnectDiscovery;

  /// No description provided for @healthDashboardHealthConnectDiscoverySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Quickly inspect every supported type with one sample page each. This does not export full history.'**
  String get healthDashboardHealthConnectDiscoverySubtitle;

  /// No description provided for @healthDashboardHealthConnectDiscoveryFailed.
  ///
  /// In en, this message translates to:
  /// **'Health Connect discovery export failed'**
  String get healthDashboardHealthConnectDiscoveryFailed;

  /// No description provided for @healthDashboardHealthConnectComparison.
  ///
  /// In en, this message translates to:
  /// **'Export source comparison'**
  String get healthDashboardHealthConnectComparison;

  /// No description provided for @healthDashboardHealthConnectComparisonSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export 90 days of compact Zepp, Google Fit, and Renpho values. Excludes raw records, routes, and other sources.'**
  String get healthDashboardHealthConnectComparisonSubtitle;

  /// No description provided for @healthDashboardHealthConnectComparisonDone.
  ///
  /// In en, this message translates to:
  /// **'Source comparison saved to Downloads'**
  String get healthDashboardHealthConnectComparisonDone;

  /// No description provided for @healthDashboardHealthConnectComparisonFailed.
  ///
  /// In en, this message translates to:
  /// **'Source comparison export failed'**
  String get healthDashboardHealthConnectComparisonFailed;

  /// No description provided for @healthDashboardHealthConnectComparisonProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Exporting source comparison'**
  String get healthDashboardHealthConnectComparisonProgressTitle;

  /// No description provided for @healthDashboardHealthConnectComparisonProgressStatus.
  ///
  /// In en, this message translates to:
  /// **'Preparing source comparison...'**
  String get healthDashboardHealthConnectComparisonProgressStatus;

  /// No description provided for @healthDashboardHealthConnectComparisonProgressCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Health Connect records processed'**
  String healthDashboardHealthConnectComparisonProgressCount(int count);

  /// No description provided for @healthDashboardHealthConnectComparisonProgressHint.
  ///
  /// In en, this message translates to:
  /// **'The export keeps running in the background with a notification. You can switch away or turn the screen off.'**
  String get healthDashboardHealthConnectComparisonProgressHint;

  /// No description provided for @healthDashboardAutoHealthConnectSync.
  ///
  /// In en, this message translates to:
  /// **'Sync Health Connect on open'**
  String get healthDashboardAutoHealthConnectSync;

  /// No description provided for @healthDashboardAutoHealthConnectSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Import Health Connect data whenever the dashboard opens.'**
  String get healthDashboardAutoHealthConnectSyncSubtitle;

  /// No description provided for @healthDashboardSettings.
  ///
  /// In en, this message translates to:
  /// **'Health dashboard settings'**
  String get healthDashboardSettings;

  /// No description provided for @healthDashboardDataToShow.
  ///
  /// In en, this message translates to:
  /// **'Data to show'**
  String get healthDashboardDataToShow;

  /// No description provided for @healthDashboardSectionAccess.
  ///
  /// In en, this message translates to:
  /// **'Access'**
  String get healthDashboardSectionAccess;

  /// No description provided for @healthDashboardSectionSelect.
  ///
  /// In en, this message translates to:
  /// **'What to collect'**
  String get healthDashboardSectionSelect;

  /// No description provided for @healthDashboardSectionSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Nothing is pulled unless you enable it here.'**
  String get healthDashboardSectionSelectHint;

  /// No description provided for @healthDashboardSectionCollect.
  ///
  /// In en, this message translates to:
  /// **'Collect'**
  String get healthDashboardSectionCollect;

  /// No description provided for @healthDashboardSectionCollectHint.
  ///
  /// In en, this message translates to:
  /// **'Fills the new typed store. Not shown on the dashboard yet.'**
  String get healthDashboardSectionCollectHint;

  /// No description provided for @healthDashboardSectionCurrent.
  ///
  /// In en, this message translates to:
  /// **'Dashboard data'**
  String get healthDashboardSectionCurrent;

  /// No description provided for @healthDashboardSectionCurrentHint.
  ///
  /// In en, this message translates to:
  /// **'The older import that still feeds the dashboard you see.'**
  String get healthDashboardSectionCurrentHint;

  /// No description provided for @healthDashboardDataTypes.
  ///
  /// In en, this message translates to:
  /// **'Data types'**
  String get healthDashboardDataTypes;

  /// No description provided for @healthDashboardDataTypesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose what to pull from Health Connect'**
  String get healthDashboardDataTypesSubtitle;

  /// No description provided for @healthDashboardDataSources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get healthDashboardDataSources;

  /// No description provided for @healthDashboardDataSourcesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose which app each type is pulled from'**
  String get healthDashboardDataSourcesSubtitle;

  /// No description provided for @healthDashboardScanSources.
  ///
  /// In en, this message translates to:
  /// **'Scan available data'**
  String get healthDashboardScanSources;

  /// No description provided for @healthDashboardScanSourcesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Finds which types hold data and which apps wrote it'**
  String get healthDashboardScanSourcesSubtitle;

  /// No description provided for @healthDashboardImportSelected.
  ///
  /// In en, this message translates to:
  /// **'Import selected data'**
  String get healthDashboardImportSelected;

  /// No description provided for @healthDashboardImportSelectedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Full history for every enabled type'**
  String get healthDashboardImportSelectedSubtitle;

  /// No description provided for @healthDashboardImportRestart.
  ///
  /// In en, this message translates to:
  /// **'Re-import from scratch'**
  String get healthDashboardImportRestart;

  /// No description provided for @healthDashboardImportRestartSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clears stored data and reads all history again'**
  String get healthDashboardImportRestartSubtitle;

  /// No description provided for @healthDashboardSyncChanges.
  ///
  /// In en, this message translates to:
  /// **'Sync changes now'**
  String get healthDashboardSyncChanges;

  /// No description provided for @healthDashboardSyncChangesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fetches only what changed since the last sync'**
  String get healthDashboardSyncChangesSubtitle;

  /// No description provided for @healthDashboardNoTypesFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing scanned yet. Run a scan to see what is available.'**
  String get healthDashboardNoTypesFound;

  /// No description provided for @healthDashboardNoSourcesFound.
  ///
  /// In en, this message translates to:
  /// **'No apps found for this type yet.'**
  String get healthDashboardNoSourcesFound;

  /// No description provided for @healthDashboardTypeRecordCount.
  ///
  /// In en, this message translates to:
  /// **'{count} imported'**
  String healthDashboardTypeRecordCount(int count);

  /// No description provided for @healthDashboardDataSourcesHint.
  ///
  /// In en, this message translates to:
  /// **'Apps this data type is read from. Switching one off keeps what it already contributed - it only stops being read and stops counting towards totals.'**
  String get healthDashboardDataSourcesHint;

  /// No description provided for @healthDashboardApps.
  ///
  /// In en, this message translates to:
  /// **'Apps'**
  String get healthDashboardApps;

  /// No description provided for @healthDashboardAppsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Switch writing apps on or off and set which one wins'**
  String get healthDashboardAppsSubtitle;

  /// No description provided for @healthDashboardNoAppsFound.
  ///
  /// In en, this message translates to:
  /// **'No writing apps known yet. Scan for sources first.'**
  String get healthDashboardNoAppsFound;

  /// No description provided for @healthDashboardAppPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority order'**
  String get healthDashboardAppPriority;

  /// No description provided for @healthDashboardAppPriorityHint.
  ///
  /// In en, this message translates to:
  /// **'The topmost app with data for a day is the one that day\'s totals are computed from. Apps below it stay as a fallback for days it did not cover.'**
  String get healthDashboardAppPriorityHint;

  /// No description provided for @healthDashboardAppRowCount.
  ///
  /// In en, this message translates to:
  /// **'{count} rows stored'**
  String healthDashboardAppRowCount(int count);

  /// No description provided for @healthDashboardAppTypeCount.
  ///
  /// In en, this message translates to:
  /// **'{count} data types'**
  String healthDashboardAppTypeCount(int count);

  /// No description provided for @healthDashboardAppMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Higher priority'**
  String get healthDashboardAppMoveUp;

  /// No description provided for @healthDashboardAppMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Lower priority'**
  String get healthDashboardAppMoveDown;

  /// No description provided for @healthDashboardAppDeleteData.
  ///
  /// In en, this message translates to:
  /// **'Delete stored data'**
  String get healthDashboardAppDeleteData;

  /// No description provided for @healthDashboardAppDeleteDataConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete every row this app contributed and shrink the database. Switching the app off instead keeps its data and costs nothing to undo.'**
  String get healthDashboardAppDeleteDataConfirm;

  /// No description provided for @healthDashboardAppDeleteHere.
  ///
  /// In en, this message translates to:
  /// **'Free up space on this device'**
  String get healthDashboardAppDeleteHere;

  /// No description provided for @healthDashboardAppDeleteHereHint.
  ///
  /// In en, this message translates to:
  /// **'Removes the rows here only. Other devices keep their copy, and this one gets it back on the next sync unless the app is switched off.'**
  String get healthDashboardAppDeleteHereHint;

  /// No description provided for @healthDashboardAppDeleteEverywhere.
  ///
  /// In en, this message translates to:
  /// **'Remove from every device'**
  String get healthDashboardAppDeleteEverywhere;

  /// No description provided for @healthDashboardAppDeleteEverywhereHint.
  ///
  /// In en, this message translates to:
  /// **'Says the data is wrong and deletes the server copy too, so every device drops it. This cannot be undone.'**
  String get healthDashboardAppDeleteEverywhereHint;

  /// No description provided for @healthDashboardAutoSync.
  ///
  /// In en, this message translates to:
  /// **'Sync changes on open'**
  String get healthDashboardAutoSync;

  /// No description provided for @healthDashboardAutoSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fetch what Health Connect reports as changed each time the tool opens. Off means data only arrives when you import manually.'**
  String get healthDashboardAutoSyncSubtitle;

  /// No description provided for @healthDashboardImportConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Import full history?'**
  String get healthDashboardImportConfirmTitle;

  /// No description provided for @healthDashboardImportConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'{count} data types are selected. Reading their full history can take hours on a large store. It continues in the background and can be interrupted.'**
  String healthDashboardImportConfirmBody(int count);

  /// No description provided for @healthDashboardImportConfirmNoTypes.
  ///
  /// In en, this message translates to:
  /// **'No data types are selected, so an import would store nothing. Scan for sources first, then pick what to collect.'**
  String get healthDashboardImportConfirmNoTypes;

  /// No description provided for @healthDashboardScanFirstHint.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been discovered yet. Scan Health Connect to find which data types hold data and which apps wrote them.'**
  String get healthDashboardScanFirstHint;

  /// No description provided for @healthDashboardSourceRecordCount.
  ///
  /// In en, this message translates to:
  /// **'{count} seen'**
  String healthDashboardSourceRecordCount(int count);

  /// No description provided for @healthDashboardStoreSummary.
  ///
  /// In en, this message translates to:
  /// **'{points} measurements, {sessions} sessions'**
  String healthDashboardStoreSummary(int points, int sessions);

  /// No description provided for @healthDashboardStoreEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Nothing stored yet. Scan, then import.'**
  String get healthDashboardStoreEmptyHint;

  /// No description provided for @healthDashboardStoreRollupRows.
  ///
  /// In en, this message translates to:
  /// **'{rows} daily summary rows'**
  String healthDashboardStoreRollupRows(int rows);

  /// No description provided for @healthDashboardBaselineEstablished.
  ///
  /// In en, this message translates to:
  /// **'Change tracking started. Run an import to load history.'**
  String get healthDashboardBaselineEstablished;

  /// No description provided for @healthDashboardSyncChangesResult.
  ///
  /// In en, this message translates to:
  /// **'{updated} updated, {removed} removed'**
  String healthDashboardSyncChangesResult(int updated, int removed);

  /// No description provided for @healthDashboardFullImportNeeded.
  ///
  /// In en, this message translates to:
  /// **'Change tracking expired and recovery failed. A full import is needed.'**
  String get healthDashboardFullImportNeeded;

  /// No description provided for @healthDashboardSyncRecovered.
  ///
  /// In en, this message translates to:
  /// **'Change tracking expired. Re-read recent history: {imported} records.'**
  String healthDashboardSyncRecovered(int imported);

  /// No description provided for @healthDashboardShowTreadmill.
  ///
  /// In en, this message translates to:
  /// **'Treadmill workouts'**
  String get healthDashboardShowTreadmill;

  /// No description provided for @healthDashboardShowTreadmillSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Include local treadmill runs in dashboard totals and activity.'**
  String get healthDashboardShowTreadmillSubtitle;

  /// No description provided for @healthDashboardSync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get healthDashboardSync;

  /// No description provided for @healthDashboardSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get healthDashboardSyncNow;

  /// No description provided for @healthDashboardSyncEnabled.
  ///
  /// In en, this message translates to:
  /// **'Sync health records with your configured backend.'**
  String get healthDashboardSyncEnabled;

  /// No description provided for @healthDashboardSyncDisabled.
  ///
  /// In en, this message translates to:
  /// **'Enable backend sync in Settings first.'**
  String get healthDashboardSyncDisabled;

  /// No description provided for @healthDashboardSyncSuccess.
  ///
  /// In en, this message translates to:
  /// **'Synced: {pushed} pushed, {pulled} pulled'**
  String healthDashboardSyncSuccess(int pushed, int pulled);

  /// No description provided for @healthDashboardSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Health data sync failed'**
  String get healthDashboardSyncFailed;

  /// No description provided for @healthDashboardHealthConnectWorkout.
  ///
  /// In en, this message translates to:
  /// **'Health Connect workout'**
  String get healthDashboardHealthConnectWorkout;

  /// No description provided for @healthDashboardLastSevenDays.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get healthDashboardLastSevenDays;

  /// No description provided for @healthDashboardHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get healthDashboardHistory;

  /// No description provided for @healthDashboardDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get healthDashboardDetails;

  /// No description provided for @healthDashboardDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get healthDashboardDate;

  /// No description provided for @healthDashboardTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get healthDashboardTime;

  /// No description provided for @healthDashboardSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get healthDashboardSource;

  /// No description provided for @healthDashboardData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get healthDashboardData;

  /// No description provided for @healthDashboardHuaweiHealth.
  ///
  /// In en, this message translates to:
  /// **'Huawei Health'**
  String get healthDashboardHuaweiHealth;

  /// No description provided for @healthDashboardAmazfit.
  ///
  /// In en, this message translates to:
  /// **'Amazfit / Zepp'**
  String get healthDashboardAmazfit;

  /// No description provided for @healthDashboardGoogleFit.
  ///
  /// In en, this message translates to:
  /// **'Google Fit'**
  String get healthDashboardGoogleFit;

  /// No description provided for @healthDashboardSamsungHealth.
  ///
  /// In en, this message translates to:
  /// **'Samsung Health'**
  String get healthDashboardSamsungHealth;

  /// No description provided for @healthDashboardFitbit.
  ///
  /// In en, this message translates to:
  /// **'Fitbit'**
  String get healthDashboardFitbit;

  /// No description provided for @healthDashboardGarmin.
  ///
  /// In en, this message translates to:
  /// **'Garmin'**
  String get healthDashboardGarmin;

  /// No description provided for @healthDashboardWithings.
  ///
  /// In en, this message translates to:
  /// **'Withings'**
  String get healthDashboardWithings;

  /// No description provided for @healthDashboardRenpho.
  ///
  /// In en, this message translates to:
  /// **'Renpho'**
  String get healthDashboardRenpho;

  /// No description provided for @healthDashboardMiFitness.
  ///
  /// In en, this message translates to:
  /// **'Mi Fitness'**
  String get healthDashboardMiFitness;

  /// No description provided for @healthDashboardSourceHealthConnect.
  ///
  /// In en, this message translates to:
  /// **'Health Connect'**
  String get healthDashboardSourceHealthConnect;

  /// No description provided for @healthDashboardSourceUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown app'**
  String get healthDashboardSourceUnknown;

  /// No description provided for @healthDashboardSourcePreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferred data sources'**
  String get healthDashboardSourcePreferences;

  /// No description provided for @healthDashboardSourcePreferencesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use a preferred app for each metric when records overlap.'**
  String get healthDashboardSourcePreferencesSubtitle;

  /// No description provided for @healthDashboardAnySource.
  ///
  /// In en, this message translates to:
  /// **'Any source'**
  String get healthDashboardAnySource;

  /// No description provided for @healthDashboardNap.
  ///
  /// In en, this message translates to:
  /// **'Nap'**
  String get healthDashboardNap;

  /// No description provided for @healthDashboardNaps.
  ///
  /// In en, this message translates to:
  /// **'Naps'**
  String get healthDashboardNaps;

  /// No description provided for @healthDashboardAllData.
  ///
  /// In en, this message translates to:
  /// **'All Health Data'**
  String get healthDashboardAllData;

  /// No description provided for @healthDashboardSleepDetails.
  ///
  /// In en, this message translates to:
  /// **'Sleep details'**
  String get healthDashboardSleepDetails;

  /// No description provided for @healthDashboardSleepDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get healthDashboardSleepDuration;

  /// No description provided for @healthDashboardSleepStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get healthDashboardSleepStart;

  /// No description provided for @healthDashboardSleepEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get healthDashboardSleepEnd;

  /// No description provided for @healthDashboardSleepStageTimes.
  ///
  /// In en, this message translates to:
  /// **'×{count}'**
  String healthDashboardSleepStageTimes(int count);

  /// No description provided for @healthDashboardSleepStageDuration.
  ///
  /// In en, this message translates to:
  /// **'{duration} ({count} times)'**
  String healthDashboardSleepStageDuration(Object duration, Object count);

  /// No description provided for @healthDashboardSleepStages.
  ///
  /// In en, this message translates to:
  /// **'Sleep stages'**
  String get healthDashboardSleepStages;

  /// No description provided for @healthDashboardTrends.
  ///
  /// In en, this message translates to:
  /// **'Trends'**
  String get healthDashboardTrends;

  /// No description provided for @healthDashboardWeightTrend.
  ///
  /// In en, this message translates to:
  /// **'Weight · last 7 days'**
  String get healthDashboardWeightTrend;

  /// No description provided for @healthDashboardPreviousDay.
  ///
  /// In en, this message translates to:
  /// **'Previous day'**
  String get healthDashboardPreviousDay;

  /// No description provided for @healthDashboardNextDay.
  ///
  /// In en, this message translates to:
  /// **'Next day'**
  String get healthDashboardNextDay;

  /// No description provided for @healthDashboardSleepAwake.
  ///
  /// In en, this message translates to:
  /// **'Awake'**
  String get healthDashboardSleepAwake;

  /// No description provided for @healthDashboardSleepRem.
  ///
  /// In en, this message translates to:
  /// **'REM'**
  String get healthDashboardSleepRem;

  /// No description provided for @healthDashboardSleepLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get healthDashboardSleepLight;

  /// No description provided for @healthDashboardSleepDeep.
  ///
  /// In en, this message translates to:
  /// **'Deep'**
  String get healthDashboardSleepDeep;

  /// No description provided for @healthDashboardHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Heart rate'**
  String get healthDashboardHeartRate;

  /// No description provided for @healthDashboardNoSleepHeartRate.
  ///
  /// In en, this message translates to:
  /// **'No heart-rate samples during this sleep session'**
  String get healthDashboardNoSleepHeartRate;

  /// No description provided for @healthDashboardSectionBackground.
  ///
  /// In en, this message translates to:
  /// **'Automatic sync'**
  String get healthDashboardSectionBackground;

  /// No description provided for @healthDashboardBackgroundSync.
  ///
  /// In en, this message translates to:
  /// **'Sync in the background'**
  String get healthDashboardBackgroundSync;

  /// No description provided for @healthDashboardBackgroundSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Import Health Connect changes and send them to the backend while the app is closed.'**
  String get healthDashboardBackgroundSyncSubtitle;

  /// No description provided for @healthDashboardBackup.
  ///
  /// In en, this message translates to:
  /// **'Data backup'**
  String get healthDashboardBackup;

  /// No description provided for @healthDashboardExportBackup.
  ///
  /// In en, this message translates to:
  /// **'Export health database'**
  String get healthDashboardExportBackup;

  /// No description provided for @healthDashboardExportBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save Health Dashboard records as a SQLite database.'**
  String get healthDashboardExportBackupSubtitle;

  /// No description provided for @healthDashboardExportBackupWarning.
  ///
  /// In en, this message translates to:
  /// **'Exporting a large health database can take a while. It keeps running if you leave the app, and the file is saved when it finishes.'**
  String get healthDashboardExportBackupWarning;

  /// No description provided for @healthDashboardExportBackupProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Exporting health database'**
  String get healthDashboardExportBackupProgressTitle;

  /// No description provided for @healthDashboardExportBackupProgressStatus.
  ///
  /// In en, this message translates to:
  /// **'Measuring the database...'**
  String get healthDashboardExportBackupProgressStatus;

  /// No description provided for @healthDashboardExportBackupStatusWriting.
  ///
  /// In en, this message translates to:
  /// **'Writing the backup file...'**
  String get healthDashboardExportBackupStatusWriting;

  /// No description provided for @healthDashboardExportBackupStatusSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving to the Downloads folder...'**
  String get healthDashboardExportBackupStatusSaving;

  /// No description provided for @healthDashboardExportBackupProgressCount.
  ///
  /// In en, this message translates to:
  /// **'Written {processed} of {total} rows'**
  String healthDashboardExportBackupProgressCount(int processed, int total);

  /// No description provided for @healthDashboardExportBackupProgressHint.
  ///
  /// In en, this message translates to:
  /// **'You can leave the app; the backup keeps being written in the background.'**
  String get healthDashboardExportBackupProgressHint;

  /// No description provided for @healthDashboardExportBackupFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not export health database'**
  String get healthDashboardExportBackupFailed;

  /// No description provided for @healthDashboardExportBackupSavedDownloads.
  ///
  /// In en, this message translates to:
  /// **'Health database saved to the Downloads folder'**
  String get healthDashboardExportBackupSavedDownloads;

  /// No description provided for @healthDashboardExportBackupSavedTo.
  ///
  /// In en, this message translates to:
  /// **'Health database saved to {path}'**
  String healthDashboardExportBackupSavedTo(String path);

  /// No description provided for @healthDashboardImportBackup.
  ///
  /// In en, this message translates to:
  /// **'Import health database'**
  String get healthDashboardImportBackup;

  /// No description provided for @healthDashboardImportBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Replace all stored records with a Health Dashboard SQLite backup.'**
  String get healthDashboardImportBackupSubtitle;

  /// No description provided for @healthDashboardImportBackupWarning.
  ///
  /// In en, this message translates to:
  /// **'This deletes all stored health data and replaces it with the backup\'s contents. Anything collected since the backup was taken is lost. Health Connect is not touched, so a new import can fetch that data again.'**
  String get healthDashboardImportBackupWarning;

  /// No description provided for @healthDashboardImportBackupReplace.
  ///
  /// In en, this message translates to:
  /// **'Delete and restore'**
  String get healthDashboardImportBackupReplace;

  /// No description provided for @healthDashboardImportBackupTooNew.
  ///
  /// In en, this message translates to:
  /// **'This backup comes from a newer app version and cannot be restored'**
  String get healthDashboardImportBackupTooNew;

  /// No description provided for @healthDashboardImportBackupSuccess.
  ///
  /// In en, this message translates to:
  /// **'Restored {count} health records'**
  String healthDashboardImportBackupSuccess(int count);

  /// No description provided for @healthDashboardImportBackupFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not import health database'**
  String get healthDashboardImportBackupFailed;

  /// No description provided for @healthDashboardSelectedDay.
  ///
  /// In en, this message translates to:
  /// **'Selected day'**
  String get healthDashboardSelectedDay;

  /// No description provided for @healthDashboardImportBackupProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Restoring health database'**
  String get healthDashboardImportBackupProgressTitle;

  /// No description provided for @healthDashboardImportBackupProgressStatus.
  ///
  /// In en, this message translates to:
  /// **'Replacing table {processed} of {total}...'**
  String healthDashboardImportBackupProgressStatus(int processed, int total);

  /// No description provided for @healthDashboardImportBackupProgressCount.
  ///
  /// In en, this message translates to:
  /// **'Restored {processed} of {total} tables'**
  String healthDashboardImportBackupProgressCount(int processed, int total);

  /// No description provided for @healthDashboardImportBackupProgressHint.
  ///
  /// In en, this message translates to:
  /// **'You can leave the app; the restore keeps running in the background.'**
  String get healthDashboardImportBackupProgressHint;

  /// No description provided for @healthDashboardImportHealthConnectProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Importing health data'**
  String get healthDashboardImportHealthConnectProgressTitle;

  /// No description provided for @healthDashboardImportHealthConnectProgressStatus.
  ///
  /// In en, this message translates to:
  /// **'Fetching records from Health Connect...'**
  String get healthDashboardImportHealthConnectProgressStatus;

  /// No description provided for @healthDashboardImportHealthConnectProgressCount.
  ///
  /// In en, this message translates to:
  /// **'Fetched {count} records so far'**
  String healthDashboardImportHealthConnectProgressCount(int count);

  /// No description provided for @healthDashboardImportHealthConnectProgressHint.
  ///
  /// In en, this message translates to:
  /// **'The import keeps running in the background with a notification. You can switch away or turn the screen off.'**
  String get healthDashboardImportHealthConnectProgressHint;

  /// No description provided for @healthDashboardHealthConnectAnalysisProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Exporting Health Connect analysis'**
  String get healthDashboardHealthConnectAnalysisProgressTitle;

  /// No description provided for @healthDashboardHealthConnectAnalysisProgressStatus.
  ///
  /// In en, this message translates to:
  /// **'Reading Health Connect records...'**
  String get healthDashboardHealthConnectAnalysisProgressStatus;

  /// No description provided for @healthDashboardHealthConnectAnalysisProgressCount.
  ///
  /// In en, this message translates to:
  /// **'Analyzed {count} records'**
  String healthDashboardHealthConnectAnalysisProgressCount(int count);

  /// No description provided for @healthDashboardHealthConnectAnalysisProgressHint.
  ///
  /// In en, this message translates to:
  /// **'This does not change dashboard data. The export keeps running in the background with a notification.'**
  String get healthDashboardHealthConnectAnalysisProgressHint;

  /// No description provided for @healthDashboardSevenDayTotal.
  ///
  /// In en, this message translates to:
  /// **'7-Day Total'**
  String get healthDashboardSevenDayTotal;

  /// No description provided for @healthDashboardSevenDayAvg.
  ///
  /// In en, this message translates to:
  /// **'7-Day Avg'**
  String get healthDashboardSevenDayAvg;

  /// No description provided for @healthDashboardSevenDayMin.
  ///
  /// In en, this message translates to:
  /// **'7-Day Min'**
  String get healthDashboardSevenDayMin;

  /// No description provided for @healthDashboardSevenDayMax.
  ///
  /// In en, this message translates to:
  /// **'7-Day Max'**
  String get healthDashboardSevenDayMax;

  /// No description provided for @healthDashboardNightAvg.
  ///
  /// In en, this message translates to:
  /// **'Night Avg'**
  String get healthDashboardNightAvg;

  /// No description provided for @healthDashboardNightMin.
  ///
  /// In en, this message translates to:
  /// **'Night Min'**
  String get healthDashboardNightMin;

  /// No description provided for @healthDashboardNightMax.
  ///
  /// In en, this message translates to:
  /// **'Night Max'**
  String get healthDashboardNightMax;

  /// No description provided for @healthDashboardDayTotal.
  ///
  /// In en, this message translates to:
  /// **'Day Total'**
  String get healthDashboardDayTotal;

  /// No description provided for @healthDashboardDayAvg.
  ///
  /// In en, this message translates to:
  /// **'Day Avg'**
  String get healthDashboardDayAvg;

  /// No description provided for @healthDashboardDayMin.
  ///
  /// In en, this message translates to:
  /// **'Day Min'**
  String get healthDashboardDayMin;

  /// No description provided for @healthDashboardDayMax.
  ///
  /// In en, this message translates to:
  /// **'Day Max'**
  String get healthDashboardDayMax;

  /// No description provided for @healthDashboardWorkoutDayTotals.
  ///
  /// In en, this message translates to:
  /// **'Day total'**
  String get healthDashboardWorkoutDayTotals;

  /// No description provided for @healthDashboardWorkoutSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get healthDashboardWorkoutSessions;

  /// No description provided for @healthDashboardPace.
  ///
  /// In en, this message translates to:
  /// **'Pace'**
  String get healthDashboardPace;

  /// No description provided for @healthDashboardAverage.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get healthDashboardAverage;

  /// No description provided for @healthDashboardMinimum.
  ///
  /// In en, this message translates to:
  /// **'Minimum'**
  String get healthDashboardMinimum;

  /// No description provided for @healthDashboardMaximum.
  ///
  /// In en, this message translates to:
  /// **'Maximum'**
  String get healthDashboardMaximum;

  /// No description provided for @healthDashboardAvgHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Avg heart rate'**
  String get healthDashboardAvgHeartRate;

  /// No description provided for @healthDashboardMaxHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Max heart rate'**
  String get healthDashboardMaxHeartRate;

  /// No description provided for @healthDashboardAvgSpeed.
  ///
  /// In en, this message translates to:
  /// **'Avg speed'**
  String get healthDashboardAvgSpeed;

  /// No description provided for @healthDashboardMaxSpeed.
  ///
  /// In en, this message translates to:
  /// **'Max speed'**
  String get healthDashboardMaxSpeed;

  /// No description provided for @healthDashboardCadence.
  ///
  /// In en, this message translates to:
  /// **'Cadence'**
  String get healthDashboardCadence;

  /// No description provided for @healthDashboardPower.
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get healthDashboardPower;

  /// No description provided for @healthDashboardDuringWorkout.
  ///
  /// In en, this message translates to:
  /// **'During the workout'**
  String get healthDashboardDuringWorkout;

  /// No description provided for @healthDashboardLaps.
  ///
  /// In en, this message translates to:
  /// **'Laps'**
  String get healthDashboardLaps;

  /// No description provided for @healthDashboardLap.
  ///
  /// In en, this message translates to:
  /// **'Lap {number}'**
  String healthDashboardLap(int number);

  /// No description provided for @healthDashboardSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get healthDashboardSpeed;

  /// No description provided for @healthDashboardCount.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get healthDashboardCount;

  /// No description provided for @healthDashboardBloodPressure.
  ///
  /// In en, this message translates to:
  /// **'Blood Pressure'**
  String get healthDashboardBloodPressure;

  /// No description provided for @healthDashboardPercentage.
  ///
  /// In en, this message translates to:
  /// **'Percentage'**
  String get healthDashboardPercentage;

  /// No description provided for @healthDashboardFloors.
  ///
  /// In en, this message translates to:
  /// **'Floors'**
  String get healthDashboardFloors;

  /// No description provided for @healthDashboardDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get healthDashboardDuration;

  /// No description provided for @treadmillSyncToHealthConnect.
  ///
  /// In en, this message translates to:
  /// **'Sync workouts to Health Connect'**
  String get treadmillSyncToHealthConnect;

  /// No description provided for @treadmillSyncToHealthConnectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Write treadmill run sessions to Health Connect when finished.'**
  String get treadmillSyncToHealthConnectSubtitle;

  /// No description provided for @healthDashboardCloudBackendSync.
  ///
  /// In en, this message translates to:
  /// **'Cloud Backend Sync'**
  String get healthDashboardCloudBackendSync;

  /// No description provided for @healthDashboardHealthConnectSettings.
  ///
  /// In en, this message translates to:
  /// **'Health Connect'**
  String get healthDashboardHealthConnectSettings;

  /// No description provided for @healthDashboardHealthConnectSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permissions, import, automatic sync on open, and starting the import over.'**
  String get healthDashboardHealthConnectSettingsSubtitle;

  /// No description provided for @healthDashboardHealthConnectOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open Health Connect settings'**
  String get healthDashboardHealthConnectOpenFailed;

  /// No description provided for @healthDashboardHealthConnectImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Health Connect import failed'**
  String get healthDashboardHealthConnectImportFailed;

  /// No description provided for @healthDashboardHealthConnectRepairFailed.
  ///
  /// In en, this message translates to:
  /// **'Health Connect repair failed'**
  String get healthDashboardHealthConnectRepairFailed;

  /// No description provided for @healthDashboardHrv.
  ///
  /// In en, this message translates to:
  /// **'HRV (RMSSD)'**
  String get healthDashboardHrv;

  /// No description provided for @healthDashboardOxygenSaturation.
  ///
  /// In en, this message translates to:
  /// **'Oxygen Saturation'**
  String get healthDashboardOxygenSaturation;

  /// No description provided for @healthDashboardRespiratoryRate.
  ///
  /// In en, this message translates to:
  /// **'Respiratory Rate'**
  String get healthDashboardRespiratoryRate;

  /// No description provided for @healthDashboardBodyFat.
  ///
  /// In en, this message translates to:
  /// **'Body Fat'**
  String get healthDashboardBodyFat;

  /// No description provided for @healthDashboardBloodGlucose.
  ///
  /// In en, this message translates to:
  /// **'Blood Glucose'**
  String get healthDashboardBloodGlucose;

  /// No description provided for @healthDashboardBmr.
  ///
  /// In en, this message translates to:
  /// **'BMR'**
  String get healthDashboardBmr;

  /// No description provided for @healthDashboardVo2Max.
  ///
  /// In en, this message translates to:
  /// **'VO2 Max'**
  String get healthDashboardVo2Max;

  /// No description provided for @healthDashboardLatestOxygenSaturation.
  ///
  /// In en, this message translates to:
  /// **'Latest Oxygen Saturation'**
  String get healthDashboardLatestOxygenSaturation;

  /// No description provided for @healthDashboardLatestRespiratoryRate.
  ///
  /// In en, this message translates to:
  /// **'Latest Respiratory Rate'**
  String get healthDashboardLatestRespiratoryRate;

  /// No description provided for @healthDashboardLatestBodyFat.
  ///
  /// In en, this message translates to:
  /// **'Latest Body Fat'**
  String get healthDashboardLatestBodyFat;

  /// No description provided for @healthDashboardHrvTrend.
  ///
  /// In en, this message translates to:
  /// **'HRV (RMSSD) · last 7 days'**
  String get healthDashboardHrvTrend;

  /// No description provided for @healthDashboardOxygenSaturationTrend.
  ///
  /// In en, this message translates to:
  /// **'Oxygen Saturation (SpO2) · last 7 days'**
  String get healthDashboardOxygenSaturationTrend;

  /// No description provided for @healthDashboardRespiratoryRateTrend.
  ///
  /// In en, this message translates to:
  /// **'Respiratory Rate · last 7 days'**
  String get healthDashboardRespiratoryRateTrend;

  /// No description provided for @healthDashboardWeightBodyFatTrend.
  ///
  /// In en, this message translates to:
  /// **'Weight & Body Fat · last 7 days'**
  String get healthDashboardWeightBodyFatTrend;

  /// No description provided for @healthDashboardChartNoData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get healthDashboardChartNoData;

  /// No description provided for @healthDashboardLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get healthDashboardLoadMore;

  /// No description provided for @healthDashboardScrollToTop.
  ///
  /// In en, this message translates to:
  /// **'Scroll to top'**
  String get healthDashboardScrollToTop;

  /// No description provided for @healthDashboardShowMoreRecords.
  ///
  /// In en, this message translates to:
  /// **'Show 100 more ({count} remaining)'**
  String healthDashboardShowMoreRecords(int count);

  /// No description provided for @healthDashboardLoadMoreRecords.
  ///
  /// In en, this message translates to:
  /// **'Load more records…'**
  String get healthDashboardLoadMoreRecords;

  /// No description provided for @healthDashboardHeight.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get healthDashboardHeight;

  /// No description provided for @healthDashboardHydration.
  ///
  /// In en, this message translates to:
  /// **'Hydration'**
  String get healthDashboardHydration;

  /// No description provided for @healthDashboardBmi.
  ///
  /// In en, this message translates to:
  /// **'BMI'**
  String get healthDashboardBmi;

  /// No description provided for @healthDashboardNoMetricDataInWeek.
  ///
  /// In en, this message translates to:
  /// **'No {metric} in these 7 days'**
  String healthDashboardNoMetricDataInWeek(String metric);

  /// No description provided for @healthDashboardNoMetricDataInWeekHint.
  ///
  /// In en, this message translates to:
  /// **'Pick another day, or check that the type and its source are switched on.'**
  String get healthDashboardNoMetricDataInWeekHint;

  /// No description provided for @healthDashboardBackToToday.
  ///
  /// In en, this message translates to:
  /// **'Back to today'**
  String get healthDashboardBackToToday;

  /// No description provided for @healthDashboardNoMetricHistory.
  ///
  /// In en, this message translates to:
  /// **'Nothing stored for {metric}'**
  String healthDashboardNoMetricHistory(String metric);

  /// No description provided for @healthDashboardNoMetricHistoryHint.
  ///
  /// In en, this message translates to:
  /// **'Import this type from Health Connect to fill the history.'**
  String get healthDashboardNoMetricHistoryHint;

  /// No description provided for @healthDashboardNoWorkoutsOnDay.
  ///
  /// In en, this message translates to:
  /// **'No workouts on this day'**
  String get healthDashboardNoWorkoutsOnDay;

  /// No description provided for @healthDashboardNoSleepOnDay.
  ///
  /// In en, this message translates to:
  /// **'No sleep recorded for this day'**
  String get healthDashboardNoSleepOnDay;

  /// No description provided for @healthDashboardSleepQuality.
  ///
  /// In en, this message translates to:
  /// **'Sleep quality'**
  String get healthDashboardSleepQuality;

  /// No description provided for @healthDashboardSleepQualityDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Compared against general adult sleep-study ranges. Not a medical assessment.'**
  String get healthDashboardSleepQualityDisclaimer;

  /// No description provided for @healthDashboardSleepRatingGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get healthDashboardSleepRatingGood;

  /// No description provided for @healthDashboardSleepRatingFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get healthDashboardSleepRatingFair;

  /// No description provided for @healthDashboardSleepRatingPoor.
  ///
  /// In en, this message translates to:
  /// **'Poor'**
  String get healthDashboardSleepRatingPoor;

  /// No description provided for @healthDashboardSleepScore.
  ///
  /// In en, this message translates to:
  /// **'{score} of 100'**
  String healthDashboardSleepScore(int score);

  /// No description provided for @healthDashboardSleepAsleep.
  ///
  /// In en, this message translates to:
  /// **'Asleep'**
  String get healthDashboardSleepAsleep;

  /// No description provided for @healthDashboardSleepTimeInBed.
  ///
  /// In en, this message translates to:
  /// **'In bed'**
  String get healthDashboardSleepTimeInBed;

  /// No description provided for @healthDashboardSleepEfficiency.
  ///
  /// In en, this message translates to:
  /// **'Efficiency'**
  String get healthDashboardSleepEfficiency;

  /// No description provided for @healthDashboardSleepAwakenings.
  ///
  /// In en, this message translates to:
  /// **'Awake'**
  String get healthDashboardSleepAwakenings;

  /// No description provided for @healthDashboardSleepFindingAllInRange.
  ///
  /// In en, this message translates to:
  /// **'Duration, efficiency and stage shares are all in their usual ranges.'**
  String get healthDashboardSleepFindingAllInRange;

  /// No description provided for @healthDashboardSleepFindingDurationShort.
  ///
  /// In en, this message translates to:
  /// **'Less than 7 h asleep. Adults usually need 7-9 h.'**
  String get healthDashboardSleepFindingDurationShort;

  /// No description provided for @healthDashboardSleepFindingDurationLong.
  ///
  /// In en, this message translates to:
  /// **'More than 10 h asleep, well above the usual 7-9 h.'**
  String get healthDashboardSleepFindingDurationLong;

  /// No description provided for @healthDashboardSleepFindingEfficiencyLow.
  ///
  /// In en, this message translates to:
  /// **'Sleep efficiency below 85 %: a lot of the time in bed was spent awake.'**
  String get healthDashboardSleepFindingEfficiencyLow;

  /// No description provided for @healthDashboardSleepFindingDeepLow.
  ///
  /// In en, this message translates to:
  /// **'Deep sleep below 13 % of the night (usual range 13-23 %).'**
  String get healthDashboardSleepFindingDeepLow;

  /// No description provided for @healthDashboardSleepFindingDeepHigh.
  ///
  /// In en, this message translates to:
  /// **'Deep sleep above 23 % of the night (usual range 13-23 %).'**
  String get healthDashboardSleepFindingDeepHigh;

  /// No description provided for @healthDashboardSleepFindingRemLow.
  ///
  /// In en, this message translates to:
  /// **'REM below 20 % of the night (usual range 20-25 %).'**
  String get healthDashboardSleepFindingRemLow;

  /// No description provided for @healthDashboardSleepFindingRemHigh.
  ///
  /// In en, this message translates to:
  /// **'REM above 25 % of the night (usual range 20-25 %).'**
  String get healthDashboardSleepFindingRemHigh;

  /// No description provided for @healthDashboardSleepFindingAwakeHigh.
  ///
  /// In en, this message translates to:
  /// **'More than 30 minutes awake after falling asleep.'**
  String get healthDashboardSleepFindingAwakeHigh;

  /// No description provided for @healthDashboardSectionMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get healthDashboardSectionMaintenance;

  /// No description provided for @healthDashboardSectionMaintenanceHint.
  ///
  /// In en, this message translates to:
  /// **'Reclaims space. These actions delete stored rows.'**
  String get healthDashboardSectionMaintenanceHint;

  /// No description provided for @healthDashboardPruneUnused.
  ///
  /// In en, this message translates to:
  /// **'Clean up and shrink database'**
  String get healthDashboardPruneUnused;

  /// No description provided for @healthDashboardPruneUnusedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Deletes rows nothing reads any more, then rewrites the file'**
  String get healthDashboardPruneUnusedSubtitle;

  /// No description provided for @healthDashboardPruneUnusedConfirm.
  ///
  /// In en, this message translates to:
  /// **'Deletes every row written by switched-off apps ({apps}), plus orphaned rows and unused labels, then rewrites the database file. Switching those apps back on will not bring the data back - only a fresh import will. This cannot be undone.'**
  String healthDashboardPruneUnusedConfirm(String apps);

  /// No description provided for @healthDashboardPruneUnusedConfirmNoApps.
  ///
  /// In en, this message translates to:
  /// **'No app is switched off, so only orphaned rows and unused labels are removed before the database file is rewritten. This cannot be undone.'**
  String get healthDashboardPruneUnusedConfirmNoApps;

  /// No description provided for @healthDashboardPruneUnusedConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Clean up'**
  String get healthDashboardPruneUnusedConfirmAction;

  /// No description provided for @healthDashboardPruneUnusedDone.
  ///
  /// In en, this message translates to:
  /// **'{rows} rows removed, database rewritten'**
  String healthDashboardPruneUnusedDone(int rows);

  /// No description provided for @healthDashboardPruneUnusedFailed.
  ///
  /// In en, this message translates to:
  /// **'Cleaning up the health database failed'**
  String get healthDashboardPruneUnusedFailed;

  /// No description provided for @healthDashboardManageFellBack.
  ///
  /// In en, this message translates to:
  /// **'Health Connect has no settings screen on this device, so app info opened instead.'**
  String get healthDashboardManageFellBack;

  /// No description provided for @healthDashboardPermissionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Health Connect access needed'**
  String get healthDashboardPermissionNeeded;

  /// No description provided for @healthDashboardPermissionNeededBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing was granted, so there is nothing to read. Grant read access in Health Connect, then start the import again.'**
  String get healthDashboardPermissionNeededBody;

  /// No description provided for @healthDashboardOpenHealthConnect.
  ///
  /// In en, this message translates to:
  /// **'Open Health Connect'**
  String get healthDashboardOpenHealthConnect;

  /// No description provided for @healthDashboardMetaApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get healthDashboardMetaApp;

  /// No description provided for @healthDashboardMetaPackage.
  ///
  /// In en, this message translates to:
  /// **'Package'**
  String get healthDashboardMetaPackage;

  /// No description provided for @healthDashboardMetaOurType.
  ///
  /// In en, this message translates to:
  /// **'Our type'**
  String get healthDashboardMetaOurType;

  /// No description provided for @healthDashboardMetaMetricKey.
  ///
  /// In en, this message translates to:
  /// **'Metric key'**
  String get healthDashboardMetaMetricKey;

  /// No description provided for @healthDashboardMetaRecordType.
  ///
  /// In en, this message translates to:
  /// **'Health Connect type'**
  String get healthDashboardMetaRecordType;

  /// No description provided for @healthDashboardMetaActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get healthDashboardMetaActivity;

  /// No description provided for @healthDashboardMetaUnit.
  ///
  /// In en, this message translates to:
  /// **'Stored unit'**
  String get healthDashboardMetaUnit;

  /// No description provided for @healthDashboardMetaAggregation.
  ///
  /// In en, this message translates to:
  /// **'Daily aggregation'**
  String get healthDashboardMetaAggregation;

  /// No description provided for @healthDashboardMetaShape.
  ///
  /// In en, this message translates to:
  /// **'Storage shape'**
  String get healthDashboardMetaShape;

  /// No description provided for @healthDashboardMetaSource.
  ///
  /// In en, this message translates to:
  /// **'Ingested via'**
  String get healthDashboardMetaSource;

  /// No description provided for @healthDashboardMetaRowId.
  ///
  /// In en, this message translates to:
  /// **'Row id'**
  String get healthDashboardMetaRowId;

  /// No description provided for @healthDashboardMetaOrigin.
  ///
  /// In en, this message translates to:
  /// **'Health Connect record id'**
  String get healthDashboardMetaOrigin;

  /// No description provided for @healthDashboardMetaClientId.
  ///
  /// In en, this message translates to:
  /// **'Client record id'**
  String get healthDashboardMetaClientId;

  /// No description provided for @healthDashboardMetaDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get healthDashboardMetaDevice;

  /// No description provided for @healthDashboardMetaDuplicateOf.
  ///
  /// In en, this message translates to:
  /// **'Duplicate of'**
  String get healthDashboardMetaDuplicateOf;

  /// No description provided for @healthDashboardMetaStart.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get healthDashboardMetaStart;

  /// No description provided for @healthDashboardMetaEnd.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get healthDashboardMetaEnd;

  /// No description provided for @healthDashboardMetaDuration.
  ///
  /// In en, this message translates to:
  /// **'Spans'**
  String get healthDashboardMetaDuration;

  /// No description provided for @healthDashboardMetaAggregateIncluded.
  ///
  /// In en, this message translates to:
  /// **'Counts in totals'**
  String get healthDashboardMetaAggregateIncluded;

  /// No description provided for @healthDashboardMetaSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced to backend'**
  String get healthDashboardMetaSynced;

  /// No description provided for @healthDashboardMetaDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get healthDashboardMetaDeleted;

  /// No description provided for @healthDashboardMetaRawValues.
  ///
  /// In en, this message translates to:
  /// **'Stored values'**
  String get healthDashboardMetaRawValues;

  /// No description provided for @healthDashboardSectionDebug.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get healthDashboardSectionDebug;

  /// No description provided for @healthDebugSourceGenerated.
  ///
  /// In en, this message translates to:
  /// **'Generated test data'**
  String get healthDebugSourceGenerated;

  /// No description provided for @healthDebugSeedTitle.
  ///
  /// In en, this message translates to:
  /// **'Generated test data'**
  String get healthDebugSeedTitle;

  /// No description provided for @healthDebugSeedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fill Health Connect with a synthetic history'**
  String get healthDebugSeedSubtitle;

  /// No description provided for @healthDebugSeedWarning.
  ///
  /// In en, this message translates to:
  /// **'Debug builds only. Records are written into Health Connect as this app, marked as generated, and can be removed again below.'**
  String get healthDebugSeedWarning;

  /// No description provided for @healthDebugSeedRange.
  ///
  /// In en, this message translates to:
  /// **'Time range'**
  String get healthDebugSeedRange;

  /// No description provided for @healthDebugSeedDays.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String healthDebugSeedDays(int count);

  /// No description provided for @healthDebugSeedPresets.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get healthDebugSeedPresets;

  /// No description provided for @healthDebugSeedPresetsHint.
  ///
  /// In en, this message translates to:
  /// **'A preset only picks a set of groups — adjust them below.'**
  String get healthDebugSeedPresetsHint;

  /// No description provided for @healthDebugSeedGroups.
  ///
  /// In en, this message translates to:
  /// **'Data groups'**
  String get healthDebugSeedGroups;

  /// No description provided for @healthDebugSeedActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get healthDebugSeedActions;

  /// No description provided for @healthDebugSeedGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate data'**
  String get healthDebugSeedGenerate;

  /// No description provided for @healthDebugSeedGenerateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Writes day by day and replaces days already generated'**
  String get healthDebugSeedGenerateSubtitle;

  /// No description provided for @healthDebugSeedGenerateConfirm.
  ///
  /// In en, this message translates to:
  /// **'Write {days} day(s) of generated data across {groups} group(s) into Health Connect?'**
  String healthDebugSeedGenerateConfirm(int days, int groups);

  /// No description provided for @healthDebugSeedGenerateAction.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get healthDebugSeedGenerateAction;

  /// No description provided for @healthDebugSeedProgress.
  ///
  /// In en, this message translates to:
  /// **'{count} record(s)...'**
  String healthDebugSeedProgress(int count);

  /// No description provided for @healthDebugSeedDone.
  ///
  /// In en, this message translates to:
  /// **'Wrote {count} record(s)'**
  String healthDebugSeedDone(int count);

  /// No description provided for @healthDebugSeedPartial.
  ///
  /// In en, this message translates to:
  /// **'Wrote {written} record(s), {failed} failed'**
  String healthDebugSeedPartial(int written, int failed);

  /// No description provided for @healthDebugSeedClear.
  ///
  /// In en, this message translates to:
  /// **'Remove generated data'**
  String get healthDebugSeedClear;

  /// No description provided for @healthDebugSeedClearSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Deletes only records this generator wrote'**
  String get healthDebugSeedClearSubtitle;

  /// No description provided for @healthDebugSeedClearConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete every generated record from Health Connect and drop its rows from the store? Real data stays.'**
  String get healthDebugSeedClearConfirm;

  /// No description provided for @healthDebugSeedClearAction.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get healthDebugSeedClearAction;

  /// No description provided for @healthDebugSeedClearDone.
  ///
  /// In en, this message translates to:
  /// **'Removed {count} record(s)'**
  String healthDebugSeedClearDone(int count);

  /// No description provided for @healthDebugSeedNoGroups.
  ///
  /// In en, this message translates to:
  /// **'Select at least one data group'**
  String get healthDebugSeedNoGroups;

  /// No description provided for @healthDebugSeedNoPermission.
  ///
  /// In en, this message translates to:
  /// **'Health Connect access was declined'**
  String get healthDebugSeedNoPermission;

  /// No description provided for @healthDebugSeedFailed.
  ///
  /// In en, this message translates to:
  /// **'Health Connect refused the run — check the log'**
  String get healthDebugSeedFailed;

  /// No description provided for @healthDebugSeedUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Health Connect is only available on Android'**
  String get healthDebugSeedUnsupported;

  /// No description provided for @healthDebugSeedImportHint.
  ///
  /// In en, this message translates to:
  /// **'Generated data lands in Health Connect, not in the dashboard. Run Scan sources, then Restart import, to pull it in.'**
  String get healthDebugSeedImportHint;

  /// No description provided for @healthDebugPresetEveryday.
  ///
  /// In en, this message translates to:
  /// **'Everyday'**
  String get healthDebugPresetEveryday;

  /// No description provided for @healthDebugPresetAthlete.
  ///
  /// In en, this message translates to:
  /// **'Athlete'**
  String get healthDebugPresetAthlete;

  /// No description provided for @healthDebugPresetClinical.
  ///
  /// In en, this message translates to:
  /// **'Clinical'**
  String get healthDebugPresetClinical;

  /// No description provided for @healthDebugPresetEverything.
  ///
  /// In en, this message translates to:
  /// **'Everything'**
  String get healthDebugPresetEverything;

  /// No description provided for @healthDebugGroupActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity — steps, distance, energy, floors'**
  String get healthDebugGroupActivity;

  /// No description provided for @healthDebugGroupHeart.
  ///
  /// In en, this message translates to:
  /// **'Heart — rate series, resting rate, HRV'**
  String get healthDebugGroupHeart;

  /// No description provided for @healthDebugGroupSleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep — one night per day with stages'**
  String get healthDebugGroupSleep;

  /// No description provided for @healthDebugGroupWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Workouts — three sessions a week'**
  String get healthDebugGroupWorkouts;

  /// No description provided for @healthDebugGroupBody.
  ///
  /// In en, this message translates to:
  /// **'Body — weight, body fat, lean mass, height'**
  String get healthDebugGroupBody;

  /// No description provided for @healthDebugGroupVitals.
  ///
  /// In en, this message translates to:
  /// **'Vitals — oxygen, breathing, pressure, glucose'**
  String get healthDebugGroupVitals;

  /// No description provided for @healthDebugGroupHydration.
  ///
  /// In en, this message translates to:
  /// **'Hydration — drinks spread over the day'**
  String get healthDebugGroupHydration;

  /// No description provided for @toolNameSqliteViewer.
  ///
  /// In en, this message translates to:
  /// **'SQLite Viewer'**
  String get toolNameSqliteViewer;

  /// No description provided for @toolDescSqliteViewer.
  ///
  /// In en, this message translates to:
  /// **'Inspect SQLite databases: schema, tables and free SQL'**
  String get toolDescSqliteViewer;

  /// No description provided for @sqliteViewerOpenTitle.
  ///
  /// In en, this message translates to:
  /// **'Open a SQLite database'**
  String get sqliteViewerOpenTitle;

  /// No description provided for @sqliteViewerDropSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Drop a .db file here or browse for one'**
  String get sqliteViewerDropSubtitle;

  /// No description provided for @sqliteViewerTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'SQLite database'**
  String get sqliteViewerTypeLabel;

  /// No description provided for @sqliteViewerInternalTitle.
  ///
  /// In en, this message translates to:
  /// **'ToolLab databases'**
  String get sqliteViewerInternalTitle;

  /// No description provided for @sqliteViewerInternalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Opened as a read-only copy so the running app is not disturbed'**
  String get sqliteViewerInternalSubtitle;

  /// No description provided for @sqliteViewerNoInternal.
  ///
  /// In en, this message translates to:
  /// **'No ToolLab databases found'**
  String get sqliteViewerNoInternal;

  /// No description provided for @sqliteViewerAppDatabase.
  ///
  /// In en, this message translates to:
  /// **'app database'**
  String get sqliteViewerAppDatabase;

  /// No description provided for @sqliteViewerErrorMissing.
  ///
  /// In en, this message translates to:
  /// **'The file no longer exists.'**
  String get sqliteViewerErrorMissing;

  /// No description provided for @sqliteViewerErrorNotSqlite.
  ///
  /// In en, this message translates to:
  /// **'This file is not a SQLite database.'**
  String get sqliteViewerErrorNotSqlite;

  /// No description provided for @sqliteViewerErrorLocked.
  ///
  /// In en, this message translates to:
  /// **'The database is locked or cannot be read.'**
  String get sqliteViewerErrorLocked;

  /// No description provided for @sqliteViewerErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'The database could not be opened: {detail}'**
  String sqliteViewerErrorUnknown(String detail);

  /// No description provided for @sqliteViewerTabOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get sqliteViewerTabOverview;

  /// No description provided for @sqliteViewerTabData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get sqliteViewerTabData;

  /// No description provided for @sqliteViewerTabSql.
  ///
  /// In en, this message translates to:
  /// **'SQL'**
  String get sqliteViewerTabSql;

  /// No description provided for @sqliteViewerSectionFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get sqliteViewerSectionFile;

  /// No description provided for @sqliteViewerSectionPragmas.
  ///
  /// In en, this message translates to:
  /// **'Database parameters'**
  String get sqliteViewerSectionPragmas;

  /// No description provided for @sqliteViewerFileName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sqliteViewerFileName;

  /// No description provided for @sqliteViewerFileSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get sqliteViewerFileSize;

  /// No description provided for @sqliteViewerFilePath.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get sqliteViewerFilePath;

  /// No description provided for @sqliteViewerSqliteVersion.
  ///
  /// In en, this message translates to:
  /// **'SQLite version'**
  String get sqliteViewerSqliteVersion;

  /// No description provided for @sqliteViewerPageSize.
  ///
  /// In en, this message translates to:
  /// **'Page size'**
  String get sqliteViewerPageSize;

  /// No description provided for @sqliteViewerPageCount.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get sqliteViewerPageCount;

  /// No description provided for @sqliteViewerFreelistPages.
  ///
  /// In en, this message translates to:
  /// **'Free pages'**
  String get sqliteViewerFreelistPages;

  /// No description provided for @sqliteViewerEncoding.
  ///
  /// In en, this message translates to:
  /// **'Encoding'**
  String get sqliteViewerEncoding;

  /// No description provided for @sqliteViewerJournalMode.
  ///
  /// In en, this message translates to:
  /// **'Journal mode'**
  String get sqliteViewerJournalMode;

  /// No description provided for @sqliteViewerAutoVacuum.
  ///
  /// In en, this message translates to:
  /// **'Auto vacuum'**
  String get sqliteViewerAutoVacuum;

  /// No description provided for @sqliteViewerUserVersion.
  ///
  /// In en, this message translates to:
  /// **'User version'**
  String get sqliteViewerUserVersion;

  /// No description provided for @sqliteViewerApplicationId.
  ///
  /// In en, this message translates to:
  /// **'Application ID'**
  String get sqliteViewerApplicationId;

  /// No description provided for @sqliteViewerObjects.
  ///
  /// In en, this message translates to:
  /// **'Objects'**
  String get sqliteViewerObjects;

  /// No description provided for @sqliteViewerTables.
  ///
  /// In en, this message translates to:
  /// **'Tables'**
  String get sqliteViewerTables;

  /// No description provided for @sqliteViewerViews.
  ///
  /// In en, this message translates to:
  /// **'Views'**
  String get sqliteViewerViews;

  /// No description provided for @sqliteViewerIndexes.
  ///
  /// In en, this message translates to:
  /// **'Indexes'**
  String get sqliteViewerIndexes;

  /// No description provided for @sqliteViewerTriggers.
  ///
  /// In en, this message translates to:
  /// **'Triggers'**
  String get sqliteViewerTriggers;

  /// No description provided for @sqliteViewerNoObjects.
  ///
  /// In en, this message translates to:
  /// **'This database has no tables or views.'**
  String get sqliteViewerNoObjects;

  /// No description provided for @sqliteViewerSelectObject.
  ///
  /// In en, this message translates to:
  /// **'Select a table or view.'**
  String get sqliteViewerSelectObject;

  /// No description provided for @sqliteViewerIntegrityTitle.
  ///
  /// In en, this message translates to:
  /// **'Integrity'**
  String get sqliteViewerIntegrityTitle;

  /// No description provided for @sqliteViewerRunIntegrityCheck.
  ///
  /// In en, this message translates to:
  /// **'Run integrity check'**
  String get sqliteViewerRunIntegrityCheck;

  /// No description provided for @sqliteViewerIntegrityOk.
  ///
  /// In en, this message translates to:
  /// **'Intact'**
  String get sqliteViewerIntegrityOk;

  /// No description provided for @sqliteViewerIntegrityFailed.
  ///
  /// In en, this message translates to:
  /// **'Problems found'**
  String get sqliteViewerIntegrityFailed;

  /// No description provided for @sqliteViewerIntegrityEmpty.
  ///
  /// In en, this message translates to:
  /// **'Not checked yet'**
  String get sqliteViewerIntegrityEmpty;

  /// No description provided for @sqliteViewerSchema.
  ///
  /// In en, this message translates to:
  /// **'Schema'**
  String get sqliteViewerSchema;

  /// No description provided for @sqliteViewerDdl.
  ///
  /// In en, this message translates to:
  /// **'Definition (DDL)'**
  String get sqliteViewerDdl;

  /// No description provided for @sqliteViewerForeignKeys.
  ///
  /// In en, this message translates to:
  /// **'Foreign keys'**
  String get sqliteViewerForeignKeys;

  /// No description provided for @sqliteViewerPrimaryKey.
  ///
  /// In en, this message translates to:
  /// **'PK'**
  String get sqliteViewerPrimaryKey;

  /// No description provided for @sqliteViewerNotNull.
  ///
  /// In en, this message translates to:
  /// **'NOT NULL'**
  String get sqliteViewerNotNull;

  /// No description provided for @sqliteViewerUnique.
  ///
  /// In en, this message translates to:
  /// **'UNIQUE'**
  String get sqliteViewerUnique;

  /// No description provided for @sqliteViewerDefaultValue.
  ///
  /// In en, this message translates to:
  /// **'default {value}'**
  String sqliteViewerDefaultValue(String value);

  /// No description provided for @sqliteViewerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Filter rows…'**
  String get sqliteViewerSearchHint;

  /// No description provided for @sqliteViewerRowRange.
  ///
  /// In en, this message translates to:
  /// **'{start} – {end} of {total}'**
  String sqliteViewerRowRange(String start, String end, String total);

  /// No description provided for @sqliteViewerPreviousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get sqliteViewerPreviousPage;

  /// No description provided for @sqliteViewerNextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get sqliteViewerNextPage;

  /// No description provided for @sqliteViewerNoRows.
  ///
  /// In en, this message translates to:
  /// **'No rows'**
  String get sqliteViewerNoRows;

  /// No description provided for @sqliteViewerAddRow.
  ///
  /// In en, this message translates to:
  /// **'Insert row'**
  String get sqliteViewerAddRow;

  /// No description provided for @sqliteViewerDeleteRow.
  ///
  /// In en, this message translates to:
  /// **'Delete row'**
  String get sqliteViewerDeleteRow;

  /// No description provided for @sqliteViewerDeleteRowConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this row? This cannot be undone.'**
  String get sqliteViewerDeleteRowConfirm;

  /// No description provided for @sqliteViewerWriteFailed.
  ///
  /// In en, this message translates to:
  /// **'The change could not be written.'**
  String get sqliteViewerWriteFailed;

  /// No description provided for @sqliteViewerNull.
  ///
  /// In en, this message translates to:
  /// **'NULL'**
  String get sqliteViewerNull;

  /// No description provided for @sqliteViewerSetNull.
  ///
  /// In en, this message translates to:
  /// **'Set NULL'**
  String get sqliteViewerSetNull;

  /// No description provided for @sqliteViewerEmptyValue.
  ///
  /// In en, this message translates to:
  /// **'Empty value'**
  String get sqliteViewerEmptyValue;

  /// No description provided for @sqliteViewerShowImage.
  ///
  /// In en, this message translates to:
  /// **'Open image'**
  String get sqliteViewerShowImage;

  /// No description provided for @sqliteViewerEditModeOn.
  ///
  /// In en, this message translates to:
  /// **'Edit mode on'**
  String get sqliteViewerEditModeOn;

  /// No description provided for @sqliteViewerEditModeOff.
  ///
  /// In en, this message translates to:
  /// **'Read-only'**
  String get sqliteViewerEditModeOff;

  /// No description provided for @sqliteViewerEditModeBanner.
  ///
  /// In en, this message translates to:
  /// **'Edit mode: changes are written immediately and cannot be undone.'**
  String get sqliteViewerEditModeBanner;

  /// No description provided for @sqliteViewerReadOnlyNotice.
  ///
  /// In en, this message translates to:
  /// **'Read-only. Enable edit mode to change data.'**
  String get sqliteViewerReadOnlyNotice;

  /// No description provided for @sqliteViewerSnapshotNotice.
  ///
  /// In en, this message translates to:
  /// **'Working on a copy — changes do not reach the original file.'**
  String get sqliteViewerSnapshotNotice;

  /// No description provided for @sqliteViewerInternalNotice.
  ///
  /// In en, this message translates to:
  /// **'A ToolLab database, opened read-only as a copy.'**
  String get sqliteViewerInternalNotice;

  /// No description provided for @sqliteViewerEnableEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable edit mode?'**
  String get sqliteViewerEnableEditTitle;

  /// No description provided for @sqliteViewerEnableEditMessage.
  ///
  /// In en, this message translates to:
  /// **'Writes go straight into the database file and cannot be undone.'**
  String get sqliteViewerEnableEditMessage;

  /// No description provided for @sqliteViewerEnableEditMessageCopy.
  ///
  /// In en, this message translates to:
  /// **'Writes go into the working copy, not the original file. Save a copy afterwards to keep the changes.'**
  String get sqliteViewerEnableEditMessageCopy;

  /// No description provided for @sqliteViewerEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get sqliteViewerEnable;

  /// No description provided for @sqliteViewerEditNotPossible.
  ///
  /// In en, this message translates to:
  /// **'This database cannot be opened for writing.'**
  String get sqliteViewerEditNotPossible;

  /// No description provided for @sqliteViewerEditNotAllowedInternal.
  ///
  /// In en, this message translates to:
  /// **'ToolLab\'s own databases stay read-only here.'**
  String get sqliteViewerEditNotAllowedInternal;

  /// No description provided for @sqliteViewerSaveCopy.
  ///
  /// In en, this message translates to:
  /// **'Save modified copy'**
  String get sqliteViewerSaveCopy;

  /// No description provided for @sqliteViewerSaveCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'The working copy is no longer available.'**
  String get sqliteViewerSaveCopyFailed;

  /// No description provided for @sqliteViewerSqlHint.
  ///
  /// In en, this message translates to:
  /// **'SELECT * FROM ...'**
  String get sqliteViewerSqlHint;

  /// No description provided for @sqliteViewerSqlIdle.
  ///
  /// In en, this message translates to:
  /// **'Run a statement to see its result.'**
  String get sqliteViewerSqlIdle;

  /// No description provided for @sqliteViewerRun.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get sqliteViewerRun;

  /// No description provided for @sqliteViewerQueryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter a statement first.'**
  String get sqliteViewerQueryEmpty;

  /// No description provided for @sqliteViewerReadOnlyRefusal.
  ///
  /// In en, this message translates to:
  /// **'Read-only: only SELECT, EXPLAIN and reading PRAGMA statements run.'**
  String get sqliteViewerReadOnlyRefusal;

  /// No description provided for @sqliteViewerConfirmWriteTitle.
  ///
  /// In en, this message translates to:
  /// **'Run this statement?'**
  String get sqliteViewerConfirmWriteTitle;

  /// No description provided for @sqliteViewerConfirmWriteMessage.
  ///
  /// In en, this message translates to:
  /// **'It modifies the database and cannot be undone.'**
  String get sqliteViewerConfirmWriteMessage;

  /// No description provided for @sqliteViewerRowsReturned.
  ///
  /// In en, this message translates to:
  /// **'{count} rows in {ms} ms'**
  String sqliteViewerRowsReturned(String count, String ms);

  /// No description provided for @sqliteViewerRowsAffected.
  ///
  /// In en, this message translates to:
  /// **'{count} rows affected in {ms} ms'**
  String sqliteViewerRowsAffected(String count, String ms);

  /// No description provided for @sqliteViewerStatementDone.
  ///
  /// In en, this message translates to:
  /// **'Statement executed in {ms} ms'**
  String sqliteViewerStatementDone(String ms);

  /// No description provided for @sqliteViewerTruncated.
  ///
  /// In en, this message translates to:
  /// **'Only the first {count} rows are shown.'**
  String sqliteViewerTruncated(String count);

  /// No description provided for @sqliteViewerSqlError.
  ///
  /// In en, this message translates to:
  /// **'SQL error'**
  String get sqliteViewerSqlError;

  /// No description provided for @toolNameRenphoScale.
  ///
  /// In en, this message translates to:
  /// **'Renpho Scale'**
  String get toolNameRenphoScale;

  /// No description provided for @toolDescRenphoScale.
  ///
  /// In en, this message translates to:
  /// **'Local MorphoScan Nova body-composition scans, stored on this device'**
  String get toolDescRenphoScale;

  /// No description provided for @renphoStartScan.
  ///
  /// In en, this message translates to:
  /// **'Scan for the scale'**
  String get renphoStartScan;

  /// No description provided for @renphoStopScan.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get renphoStopScan;

  /// No description provided for @renphoStatusIdle.
  ///
  /// In en, this message translates to:
  /// **'Step on the scale to wake it, then start the scan.'**
  String get renphoStatusIdle;

  /// No description provided for @renphoStatusDiscovering.
  ///
  /// In en, this message translates to:
  /// **'Looking for the scale...'**
  String get renphoStatusDiscovering;

  /// No description provided for @renphoStatusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get renphoStatusConnecting;

  /// No description provided for @renphoStatusPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing the measurement...'**
  String get renphoStatusPreparing;

  /// No description provided for @renphoStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Stand barefoot on the scale, then hold both handles until the result appears.'**
  String get renphoStatusReady;

  /// No description provided for @renphoStatusSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving the measurement...'**
  String get renphoStatusSaving;

  /// No description provided for @renphoStatusRetrying.
  ///
  /// In en, this message translates to:
  /// **'The scale did not answer. Retrying setup...'**
  String get renphoStatusRetrying;

  /// No description provided for @renphoErrorBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth is unavailable or permission was refused.'**
  String get renphoErrorBluetooth;

  /// No description provided for @renphoErrorNotFound.
  ///
  /// In en, this message translates to:
  /// **'No scale found. Step on it to wake it, then scan again.'**
  String get renphoErrorNotFound;

  /// No description provided for @renphoErrorScan.
  ///
  /// In en, this message translates to:
  /// **'The Bluetooth scan failed.'**
  String get renphoErrorScan;

  /// No description provided for @renphoErrorConnect.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to the scale. Step on it to wake it, then try again.'**
  String get renphoErrorConnect;

  /// No description provided for @renphoErrorSetup.
  ///
  /// In en, this message translates to:
  /// **'The scale stopped responding during setup. Step on it to wake it, then scan again.'**
  String get renphoErrorSetup;

  /// No description provided for @renphoErrorSave.
  ///
  /// In en, this message translates to:
  /// **'Could not save the measurement.'**
  String get renphoErrorSave;

  /// No description provided for @renphoPhaseComplete.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get renphoPhaseComplete;

  /// No description provided for @renphoStatusComplete.
  ///
  /// In en, this message translates to:
  /// **'Measurement complete and saved.'**
  String get renphoStatusComplete;

  /// No description provided for @renphoStepWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get renphoStepWeight;

  /// No description provided for @renphoStepImpedance.
  ///
  /// In en, this message translates to:
  /// **'Handles'**
  String get renphoStepImpedance;

  /// No description provided for @renphoStepResult.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get renphoStepResult;

  /// No description provided for @renphoStepHintWeight.
  ///
  /// In en, this message translates to:
  /// **'Stand barefoot on the scale and keep still.'**
  String get renphoStepHintWeight;

  /// No description provided for @renphoStepHintImpedance.
  ///
  /// In en, this message translates to:
  /// **'Grab both handles, arms straight, and hold still.'**
  String get renphoStepHintImpedance;

  /// No description provided for @renphoStepHintComputing.
  ///
  /// In en, this message translates to:
  /// **'Calculating the body composition...'**
  String get renphoStepHintComputing;

  /// No description provided for @renphoImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import old data'**
  String get renphoImportTitle;

  /// No description provided for @renphoImportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read a Renpho JSON export into the local history'**
  String get renphoImportSubtitle;

  /// No description provided for @renphoImportNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing to import from that file.'**
  String get renphoImportNothing;

  /// No description provided for @renphoImportDone.
  ///
  /// In en, this message translates to:
  /// **'Imported {added}, skipped {duplicates} already present and {skipped} unusable.'**
  String renphoImportDone(int added, int duplicates, int skipped);

  /// No description provided for @renphoSourceImported.
  ///
  /// In en, this message translates to:
  /// **'Imported from an export'**
  String get renphoSourceImported;

  /// No description provided for @renphoPhaseIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get renphoPhaseIdle;

  /// No description provided for @renphoPhaseDiscovering.
  ///
  /// In en, this message translates to:
  /// **'Searching'**
  String get renphoPhaseDiscovering;

  /// No description provided for @renphoPhaseConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get renphoPhaseConnecting;

  /// No description provided for @renphoPhasePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get renphoPhasePreparing;

  /// No description provided for @renphoPhaseReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get renphoPhaseReady;

  /// No description provided for @renphoPhaseSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get renphoPhaseSaving;

  /// No description provided for @renphoImportedStored.
  ///
  /// In en, this message translates to:
  /// **'Also imported {count} earlier measurement(s) from the scale memory'**
  String renphoImportedStored(int count);

  /// No description provided for @renphoSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get renphoSyncNow;

  /// No description provided for @renphoSectionLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest measurement'**
  String get renphoSectionLatest;

  /// No description provided for @renphoSectionHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get renphoSectionHistory;

  /// No description provided for @renphoDevicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get renphoDevicesTitle;

  /// No description provided for @renphoAutoConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect automatically'**
  String get renphoAutoConnect;

  /// No description provided for @renphoAutoConnectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to the known scale as soon as it is found'**
  String get renphoAutoConnectSubtitle;

  /// No description provided for @renphoNoDevices.
  ///
  /// In en, this message translates to:
  /// **'No scale found yet. Step on it to wake it.'**
  String get renphoNoDevices;

  /// No description provided for @renphoConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get renphoConnect;

  /// No description provided for @renphoConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get renphoConnected;

  /// No description provided for @renphoForgetDevice.
  ///
  /// In en, this message translates to:
  /// **'Forget this scale'**
  String get renphoForgetDevice;

  /// No description provided for @renphoNoRememberedDevice.
  ///
  /// In en, this message translates to:
  /// **'No scale paired yet'**
  String get renphoNoRememberedDevice;

  /// No description provided for @renphoProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Measurement profile'**
  String get renphoProfileTitle;

  /// No description provided for @renphoProfileFirstRunHint.
  ///
  /// In en, this message translates to:
  /// **'Sex, height and birth date drive every calculated value. Enter them before the first scan.'**
  String get renphoProfileFirstRunHint;

  /// No description provided for @renphoProfileName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get renphoProfileName;

  /// No description provided for @renphoProfileNameHelper.
  ///
  /// In en, this message translates to:
  /// **'Sent to the scale to select the user slot'**
  String get renphoProfileNameHelper;

  /// No description provided for @renphoProfileSex.
  ///
  /// In en, this message translates to:
  /// **'Sex'**
  String get renphoProfileSex;

  /// No description provided for @renphoProfileHeight.
  ///
  /// In en, this message translates to:
  /// **'Height (cm)'**
  String get renphoProfileHeight;

  /// No description provided for @renphoProfileHeightInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a height between 80 and 250 cm'**
  String get renphoProfileHeightInvalid;

  /// No description provided for @renphoProfileBirthDate.
  ///
  /// In en, this message translates to:
  /// **'Birth date'**
  String get renphoProfileBirthDate;

  /// No description provided for @renphoSexMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get renphoSexMale;

  /// No description provided for @renphoSexFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get renphoSexFemale;

  /// No description provided for @renphoSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Scale settings'**
  String get renphoSettingsTitle;

  /// No description provided for @renphoSyncToHealthConnect.
  ///
  /// In en, this message translates to:
  /// **'Write to Health Connect'**
  String get renphoSyncToHealthConnect;

  /// No description provided for @renphoSyncToHealthConnectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Weight, body fat, lean mass, bone mass, body water and BMR'**
  String get renphoSyncToHealthConnectSubtitle;

  /// No description provided for @renphoBackendSyncHint.
  ///
  /// In en, this message translates to:
  /// **'Backend sync follows the global sync switch in the app settings.'**
  String get renphoBackendSyncHint;

  /// No description provided for @renphoPublishNow.
  ///
  /// In en, this message translates to:
  /// **'Publish now'**
  String get renphoPublishNow;

  /// No description provided for @renphoPublishNowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Write every unpublished measurement to Health Connect'**
  String get renphoPublishNowSubtitle;

  /// No description provided for @renphoRemoveFromHealthConnect.
  ///
  /// In en, this message translates to:
  /// **'Remove from Health Connect'**
  String get renphoRemoveFromHealthConnect;

  /// No description provided for @renphoRemoveFromHealthConnectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Delete every scale record this app wrote'**
  String get renphoRemoveFromHealthConnectSubtitle;

  /// No description provided for @renphoRemoveFromHealthConnectConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete every body-composition record this app wrote to Health Connect? The local history is kept and can be published again.'**
  String get renphoRemoveFromHealthConnectConfirm;

  /// No description provided for @renphoRemoveFromHealthConnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not remove the Health Connect records'**
  String get renphoRemoveFromHealthConnectFailed;

  /// No description provided for @renphoRemoveFromHealthConnectDone.
  ///
  /// In en, this message translates to:
  /// **'Removed the records; {count} measurement(s) can be published again'**
  String renphoRemoveFromHealthConnectDone(int count);

  /// No description provided for @renphoPublishNothing.
  ///
  /// In en, this message translates to:
  /// **'Health Connect is already up to date'**
  String get renphoPublishNothing;

  /// No description provided for @renphoPublishUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Health Connect is only available on Android'**
  String get renphoPublishUnsupported;

  /// No description provided for @renphoPublishDisabled.
  ///
  /// In en, this message translates to:
  /// **'Writing to Health Connect is switched off'**
  String get renphoPublishDisabled;

  /// No description provided for @renphoPublishNoPermission.
  ///
  /// In en, this message translates to:
  /// **'Health Connect write permission was not granted'**
  String get renphoPublishNoPermission;

  /// No description provided for @renphoPublishThrottled.
  ///
  /// In en, this message translates to:
  /// **'Already published a moment ago'**
  String get renphoPublishThrottled;

  /// No description provided for @renphoPublishFailed.
  ///
  /// In en, this message translates to:
  /// **'{count} measurement(s) could not be published'**
  String renphoPublishFailed(int count);

  /// No description provided for @renphoPublishDone.
  ///
  /// In en, this message translates to:
  /// **'Published {count} measurement(s) to Health Connect'**
  String renphoPublishDone(int count);

  /// No description provided for @renphoMetricWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get renphoMetricWeight;

  /// No description provided for @renphoMetricBodyFat.
  ///
  /// In en, this message translates to:
  /// **'Body fat'**
  String get renphoMetricBodyFat;

  /// No description provided for @renphoMetricMuscle.
  ///
  /// In en, this message translates to:
  /// **'Muscle'**
  String get renphoMetricMuscle;

  /// No description provided for @renphoMetricBmi.
  ///
  /// In en, this message translates to:
  /// **'BMI'**
  String get renphoMetricBmi;

  /// No description provided for @renphoMetricBmiOnScale.
  ///
  /// In en, this message translates to:
  /// **'BMI reported by the scale'**
  String get renphoMetricBmiOnScale;

  /// No description provided for @renphoMetricFatMass.
  ///
  /// In en, this message translates to:
  /// **'Fat mass'**
  String get renphoMetricFatMass;

  /// No description provided for @renphoMetricFatFreeMass.
  ///
  /// In en, this message translates to:
  /// **'Fat-free mass'**
  String get renphoMetricFatFreeMass;

  /// No description provided for @renphoMetricBodyWater.
  ///
  /// In en, this message translates to:
  /// **'Body water'**
  String get renphoMetricBodyWater;

  /// No description provided for @renphoMetricVisceralFat.
  ///
  /// In en, this message translates to:
  /// **'Visceral score'**
  String get renphoMetricVisceralFat;

  /// No description provided for @renphoMetricSkeletalMuscleMass.
  ///
  /// In en, this message translates to:
  /// **'Skeletal muscle mass'**
  String get renphoMetricSkeletalMuscleMass;

  /// No description provided for @renphoMetricProtein.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get renphoMetricProtein;

  /// No description provided for @renphoMetricLeanSoftTissue.
  ///
  /// In en, this message translates to:
  /// **'Lean soft tissue'**
  String get renphoMetricLeanSoftTissue;

  /// No description provided for @renphoMetricSubcutaneousFat.
  ///
  /// In en, this message translates to:
  /// **'Subcutaneous fat'**
  String get renphoMetricSubcutaneousFat;

  /// No description provided for @renphoMetricBoneMass.
  ///
  /// In en, this message translates to:
  /// **'Bone mass'**
  String get renphoMetricBoneMass;

  /// No description provided for @renphoMetricBmr.
  ///
  /// In en, this message translates to:
  /// **'Basal metabolic rate'**
  String get renphoMetricBmr;

  /// No description provided for @renphoMetricBodyScore.
  ///
  /// In en, this message translates to:
  /// **'Body score'**
  String get renphoMetricBodyScore;

  /// No description provided for @renphoMetricBodyType.
  ///
  /// In en, this message translates to:
  /// **'Body type'**
  String get renphoMetricBodyType;

  /// No description provided for @renphoMetricObesityDegree.
  ///
  /// In en, this message translates to:
  /// **'Obesity degree'**
  String get renphoMetricObesityDegree;

  /// No description provided for @renphoMetricWeightControl.
  ///
  /// In en, this message translates to:
  /// **'Weight control'**
  String get renphoMetricWeightControl;

  /// No description provided for @renphoMetricTargetWeight.
  ///
  /// In en, this message translates to:
  /// **'Target weight'**
  String get renphoMetricTargetWeight;

  /// No description provided for @renphoMetricSmi.
  ///
  /// In en, this message translates to:
  /// **'Skeletal muscle index'**
  String get renphoMetricSmi;

  /// No description provided for @renphoTrendWeightBodyFat.
  ///
  /// In en, this message translates to:
  /// **'Weight and body fat, last 7 days'**
  String get renphoTrendWeightBodyFat;

  /// No description provided for @renphoTrendMuscleWater.
  ///
  /// In en, this message translates to:
  /// **'Muscle and body water, last 7 days'**
  String get renphoTrendMuscleWater;

  /// No description provided for @renphoHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No measurements yet. Everything you scan stays on this device.'**
  String get renphoHistoryEmpty;

  /// No description provided for @renphoDeleteMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Delete measurement'**
  String get renphoDeleteMeasurement;

  /// No description provided for @renphoDeleteMeasurementConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this measurement? It is removed from the backend and from Health Connect on the next sync.'**
  String get renphoDeleteMeasurementConfirm;

  /// No description provided for @renphoSectionReported.
  ///
  /// In en, this message translates to:
  /// **'Reported by the scale'**
  String get renphoSectionReported;

  /// No description provided for @renphoSectionReportedHint.
  ///
  /// In en, this message translates to:
  /// **'These five values plus the ten segment impedances are the whole measurement. The visceral figure is a device score, not a fat mass.'**
  String get renphoSectionReportedHint;

  /// No description provided for @renphoSectionExact.
  ///
  /// In en, this message translates to:
  /// **'Exact calculations'**
  String get renphoSectionExact;

  /// No description provided for @renphoSectionModel.
  ///
  /// In en, this message translates to:
  /// **'Renpho model'**
  String get renphoSectionModel;

  /// No description provided for @renphoModelUncalibrated.
  ///
  /// In en, this message translates to:
  /// **'These coefficients were fitted against one profile (male, 173 cm). For a different body they are indicative, not measured.'**
  String get renphoModelUncalibrated;

  /// No description provided for @renphoSectionSegments.
  ///
  /// In en, this message translates to:
  /// **'Segment composition'**
  String get renphoSectionSegments;

  /// No description provided for @renphoSectionImpedance.
  ///
  /// In en, this message translates to:
  /// **'Impedance'**
  String get renphoSectionImpedance;

  /// No description provided for @renphoSectionEnergy.
  ///
  /// In en, this message translates to:
  /// **'Resting energy estimates'**
  String get renphoSectionEnergy;

  /// No description provided for @renphoEnergyHint.
  ///
  /// In en, this message translates to:
  /// **'Resting-energy estimates, not measured metabolism.'**
  String get renphoEnergyHint;

  /// No description provided for @renphoSectionPublished.
  ///
  /// In en, this message translates to:
  /// **'Independent published equations'**
  String get renphoSectionPublished;

  /// No description provided for @renphoPublishedHint.
  ///
  /// In en, this message translates to:
  /// **'Peer-reviewed equations, as a cross-check. They are specified for 50 kHz resistance, which this scale does not measure; the 50 kHz column interpolates to {ohms} ohm and is the weakest assumption here.'**
  String renphoPublishedHint(String ohms);

  /// No description provided for @renphoSectionRecord.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get renphoSectionRecord;

  /// No description provided for @renphoWholeBody20.
  ///
  /// In en, this message translates to:
  /// **'Whole body at 20 kHz'**
  String get renphoWholeBody20;

  /// No description provided for @renphoWholeBody100.
  ///
  /// In en, this message translates to:
  /// **'Whole body at 100 kHz'**
  String get renphoWholeBody100;

  /// No description provided for @renphoImpedanceRatio.
  ///
  /// In en, this message translates to:
  /// **'100/20 kHz ratio'**
  String get renphoImpedanceRatio;

  /// No description provided for @renphoArmDifference.
  ///
  /// In en, this message translates to:
  /// **'Left/right arm difference'**
  String get renphoArmDifference;

  /// No description provided for @renphoLegDifference.
  ///
  /// In en, this message translates to:
  /// **'Left/right leg difference'**
  String get renphoLegDifference;

  /// No description provided for @renphoImpedanceHint.
  ///
  /// In en, this message translates to:
  /// **'The whole-body value is an arm + torso + leg path approximation. The 100/20 kHz ratio is an extracellular-water and cell-integrity proxy.'**
  String get renphoImpedanceHint;

  /// No description provided for @renphoEquation.
  ///
  /// In en, this message translates to:
  /// **'Equation'**
  String get renphoEquation;

  /// No description provided for @renphoAgeAtScan.
  ///
  /// In en, this message translates to:
  /// **'Age at measurement'**
  String get renphoAgeAtScan;

  /// No description provided for @renphoSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get renphoSource;

  /// No description provided for @renphoSourceStored.
  ///
  /// In en, this message translates to:
  /// **'From the scale memory'**
  String get renphoSourceStored;

  /// No description provided for @renphoSourceLive.
  ///
  /// In en, this message translates to:
  /// **'Live scan'**
  String get renphoSourceLive;

  /// No description provided for @renphoRawPacket.
  ///
  /// In en, this message translates to:
  /// **'Raw packet'**
  String get renphoRawPacket;

  /// No description provided for @renphoCopyPacket.
  ///
  /// In en, this message translates to:
  /// **'Copy packet'**
  String get renphoCopyPacket;

  /// No description provided for @renphoPacketCopied.
  ///
  /// In en, this message translates to:
  /// **'Packet copied'**
  String get renphoPacketCopied;

  /// No description provided for @renphoSegment.
  ///
  /// In en, this message translates to:
  /// **'Segment'**
  String get renphoSegment;

  /// No description provided for @renphoSegmentMuscle.
  ///
  /// In en, this message translates to:
  /// **'Muscle'**
  String get renphoSegmentMuscle;

  /// No description provided for @renphoSegmentOfStandard.
  ///
  /// In en, this message translates to:
  /// **'Of standard'**
  String get renphoSegmentOfStandard;

  /// No description provided for @renphoSegmentFat.
  ///
  /// In en, this message translates to:
  /// **'Fat'**
  String get renphoSegmentFat;

  /// No description provided for @renphoSegmentLeftArm.
  ///
  /// In en, this message translates to:
  /// **'Left arm'**
  String get renphoSegmentLeftArm;

  /// No description provided for @renphoSegmentRightArm.
  ///
  /// In en, this message translates to:
  /// **'Right arm'**
  String get renphoSegmentRightArm;

  /// No description provided for @renphoSegmentLeftLeg.
  ///
  /// In en, this message translates to:
  /// **'Left leg'**
  String get renphoSegmentLeftLeg;

  /// No description provided for @renphoSegmentRightLeg.
  ///
  /// In en, this message translates to:
  /// **'Right leg'**
  String get renphoSegmentRightLeg;

  /// No description provided for @renphoSegmentTrunk.
  ///
  /// In en, this message translates to:
  /// **'Trunk'**
  String get renphoSegmentTrunk;

  /// No description provided for @renphoSegmentMuscleOfStandard.
  ///
  /// In en, this message translates to:
  /// **'Muscle of standard'**
  String get renphoSegmentMuscleOfStandard;

  /// No description provided for @renphoSegmentFatOfStandard.
  ///
  /// In en, this message translates to:
  /// **'Fat of standard'**
  String get renphoSegmentFatOfStandard;

  /// No description provided for @renphoSegmentMapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a body part or its label for the full breakdown of that segment.'**
  String get renphoSegmentMapHint;

  /// No description provided for @renphoSegmentTable.
  ///
  /// In en, this message translates to:
  /// **'All segments as a table'**
  String get renphoSegmentTable;

  /// No description provided for @renphoReportTooltip.
  ///
  /// In en, this message translates to:
  /// **'Create PDF report'**
  String get renphoReportTooltip;

  /// No description provided for @renphoReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Body composition report'**
  String get renphoReportTitle;

  /// No description provided for @renphoReportGenerated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get renphoReportGenerated;

  /// No description provided for @renphoReportMeasured.
  ///
  /// In en, this message translates to:
  /// **'Measured'**
  String get renphoReportMeasured;

  /// No description provided for @renphoReportYears.
  ///
  /// In en, this message translates to:
  /// **'years'**
  String get renphoReportYears;

  /// No description provided for @renphoReportAssessment.
  ///
  /// In en, this message translates to:
  /// **'Assessment'**
  String get renphoReportAssessment;

  /// No description provided for @renphoReportMetric.
  ///
  /// In en, this message translates to:
  /// **'Metric'**
  String get renphoReportMetric;

  /// No description provided for @renphoReportValue.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get renphoReportValue;

  /// No description provided for @renphoReportReference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get renphoReportReference;

  /// No description provided for @renphoReportRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get renphoReportRating;

  /// No description provided for @renphoReportTrends.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get renphoReportTrends;

  /// No description provided for @renphoReportDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Bioimpedance estimates from a consumer scale, not a clinical measurement. The reference ranges follow population data (WHO for BMI, ACE for body fat, EWGSOP2 for the muscle index) and do not replace a medical diagnosis.'**
  String get renphoReportDisclaimer;

  /// No description provided for @renphoReportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the report'**
  String get renphoReportFailed;

  /// No description provided for @renphoReportNoMeasurement.
  ///
  /// In en, this message translates to:
  /// **'No measurement to report yet'**
  String get renphoReportNoMeasurement;

  /// No description provided for @renphoAssessmentSegmentMuscle.
  ///
  /// In en, this message translates to:
  /// **'Weakest segment vs standard'**
  String get renphoAssessmentSegmentMuscle;

  /// No description provided for @renphoAssessmentSymmetry.
  ///
  /// In en, this message translates to:
  /// **'Left/right difference'**
  String get renphoAssessmentSymmetry;

  /// No description provided for @renphoRatingLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get renphoRatingLow;

  /// No description provided for @renphoRatingOptimal.
  ///
  /// In en, this message translates to:
  /// **'Optimal'**
  String get renphoRatingOptimal;

  /// No description provided for @renphoRatingElevated.
  ///
  /// In en, this message translates to:
  /// **'Elevated'**
  String get renphoRatingElevated;

  /// No description provided for @renphoRatingHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get renphoRatingHigh;

  /// No description provided for @treadmillHistoryDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Workout?'**
  String get treadmillHistoryDeleteTitle;

  /// No description provided for @treadmillHistoryDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this workout session permanently?'**
  String get treadmillHistoryDeleteMessage;

  /// No description provided for @treadmillHistoryExportEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sessions to export'**
  String get treadmillHistoryExportEmpty;

  /// No description provided for @treadmillHistoryExportSaved.
  ///
  /// In en, this message translates to:
  /// **'Workouts backup saved to Downloads'**
  String get treadmillHistoryExportSaved;

  /// No description provided for @treadmillHistoryExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String treadmillHistoryExportFailed(String error);

  /// No description provided for @treadmillHistoryImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String treadmillHistoryImportFailed(String error);

  /// No description provided for @treadmillHistoryJsonLabel.
  ///
  /// In en, this message translates to:
  /// **'JSON Backup'**
  String get treadmillHistoryJsonLabel;

  /// No description provided for @treadmillSimulateDevice.
  ///
  /// In en, this message translates to:
  /// **'Simulate Device'**
  String get treadmillSimulateDevice;

  /// No description provided for @treadmillConnectedDevices.
  ///
  /// In en, this message translates to:
  /// **'Connected Devices'**
  String get treadmillConnectedDevices;

  /// No description provided for @treadmillFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Treadmill'**
  String get treadmillFallbackName;

  /// No description provided for @treadmillHrmFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Heart Rate Monitor'**
  String get treadmillHrmFallbackName;

  /// No description provided for @treadmillConnectedStatus.
  ///
  /// In en, this message translates to:
  /// **'Connected | {id}'**
  String treadmillConnectedStatus(String id);

  /// No description provided for @treadmillDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get treadmillDisconnect;

  /// No description provided for @treadmillConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get treadmillConnect;

  /// No description provided for @treadmillScanTreadmills.
  ///
  /// In en, this message translates to:
  /// **'Treadmills'**
  String get treadmillScanTreadmills;

  /// No description provided for @treadmillScanNoTreadmills.
  ///
  /// In en, this message translates to:
  /// **'No treadmills found'**
  String get treadmillScanNoTreadmills;

  /// No description provided for @treadmillScanHrms.
  ///
  /// In en, this message translates to:
  /// **'Heart Rate Monitors'**
  String get treadmillScanHrms;

  /// No description provided for @treadmillScanNoHrms.
  ///
  /// In en, this message translates to:
  /// **'No heart rate monitors found'**
  String get treadmillScanNoHrms;

  /// No description provided for @treadmillHrHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Heart Rate History'**
  String get treadmillHrHistoryTitle;

  /// No description provided for @treadmillHrHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No heart rate data recorded yet.'**
  String get treadmillHrHistoryEmpty;

  /// No description provided for @treadmillHrCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get treadmillHrCurrent;

  /// No description provided for @treadmillHrMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get treadmillHrMax;

  /// No description provided for @treadmillHrMin.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get treadmillHrMin;

  /// No description provided for @treadmillHrAccumulating.
  ///
  /// In en, this message translates to:
  /// **'Accumulating data for chart...'**
  String get treadmillHrAccumulating;

  /// No description provided for @treadmillLabel.
  ///
  /// In en, this message translates to:
  /// **'Treadmill'**
  String get treadmillLabel;

  /// No description provided for @codeHighlightCreateBlankFile.
  ///
  /// In en, this message translates to:
  /// **'Create Blank File'**
  String get codeHighlightCreateBlankFile;

  /// No description provided for @imageViewerFormatPng.
  ///
  /// In en, this message translates to:
  /// **'PNG (.png)'**
  String get imageViewerFormatPng;

  /// No description provided for @imageViewerFormatJpeg.
  ///
  /// In en, this message translates to:
  /// **'JPEG (.jpg)'**
  String get imageViewerFormatJpeg;

  /// No description provided for @imageViewerFormatBmp.
  ///
  /// In en, this message translates to:
  /// **'BMP (.bmp)'**
  String get imageViewerFormatBmp;

  /// No description provided for @imageViewerFormatWebp.
  ///
  /// In en, this message translates to:
  /// **'WebP (.webp)'**
  String get imageViewerFormatWebp;

  /// No description provided for @noteFailedToProcessImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to process image: {error}'**
  String noteFailedToProcessImage(String error);

  /// No description provided for @fastDropNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Fast Drop transfer'**
  String get fastDropNotificationTitle;

  /// No description provided for @fastDropUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading'**
  String get fastDropUploading;

  /// No description provided for @fastDropDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get fastDropDownloading;

  /// No description provided for @sfMorseLiveTranslate.
  ///
  /// In en, this message translates to:
  /// **'Live Translate'**
  String get sfMorseLiveTranslate;

  /// No description provided for @sfMorseDecodingAudioFile.
  ///
  /// In en, this message translates to:
  /// **'Decoding audio file...'**
  String get sfMorseDecodingAudioFile;

  /// No description provided for @toolNameTextEditor.
  ///
  /// In en, this message translates to:
  /// **'Text Editor'**
  String get toolNameTextEditor;

  /// No description provided for @toolDescTextEditor.
  ///
  /// In en, this message translates to:
  /// **'Edit text files, local or from network shares'**
  String get toolDescTextEditor;

  /// No description provided for @textEditorOpenTitle.
  ///
  /// In en, this message translates to:
  /// **'Open text file'**
  String get textEditorOpenTitle;

  /// No description provided for @textEditorDropSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Drop file here or click to choose'**
  String get textEditorDropSubtitle;

  /// No description provided for @textEditorTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Text and source code files'**
  String get textEditorTypeLabel;

  /// No description provided for @textEditorNewBlank.
  ///
  /// In en, this message translates to:
  /// **'New file'**
  String get textEditorNewBlank;

  /// No description provided for @textEditorPasteClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste text'**
  String get textEditorPasteClipboard;

  /// No description provided for @textEditorClipboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'Clipboard is empty or contains no text'**
  String get textEditorClipboardEmpty;

  /// No description provided for @textEditorRecentFiles.
  ///
  /// In en, this message translates to:
  /// **'Recent files'**
  String get textEditorRecentFiles;

  /// No description provided for @textEditorNoRecentFiles.
  ///
  /// In en, this message translates to:
  /// **'No recent files yet'**
  String get textEditorNoRecentFiles;

  /// No description provided for @textEditorReopenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not reopen file'**
  String get textEditorReopenFailed;

  /// No description provided for @textEditorUnsavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get textEditorUnsavedTitle;

  /// No description provided for @textEditorUnsavedMessage.
  ///
  /// In en, this message translates to:
  /// **'The document has unsaved changes. Save before closing?'**
  String get textEditorUnsavedMessage;

  /// No description provided for @textEditorDiscardChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get textEditorDiscardChanges;

  /// No description provided for @textEditorSaveAndClose.
  ///
  /// In en, this message translates to:
  /// **'Save & close'**
  String get textEditorSaveAndClose;

  /// No description provided for @textEditorFileNameTitle.
  ///
  /// In en, this message translates to:
  /// **'File name'**
  String get textEditorFileNameTitle;

  /// No description provided for @textEditorSaveAs.
  ///
  /// In en, this message translates to:
  /// **'Save as…'**
  String get textEditorSaveAs;

  /// No description provided for @textEditorSavedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String textEditorSavedTo(Object path);

  /// No description provided for @textEditorFind.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get textEditorFind;

  /// No description provided for @textEditorFindHint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get textEditorFindHint;

  /// No description provided for @textEditorReplaceHint.
  ///
  /// In en, this message translates to:
  /// **'Replace with'**
  String get textEditorReplaceHint;

  /// No description provided for @textEditorFindNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get textEditorFindNoResults;

  /// No description provided for @textEditorFindSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get textEditorFindSearching;

  /// No description provided for @textEditorFindPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous match'**
  String get textEditorFindPrevious;

  /// No description provided for @textEditorFindNext.
  ///
  /// In en, this message translates to:
  /// **'Next match'**
  String get textEditorFindNext;

  /// No description provided for @textEditorReplaceOne.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get textEditorReplaceOne;

  /// No description provided for @textEditorReplaceAll.
  ///
  /// In en, this message translates to:
  /// **'Replace all'**
  String get textEditorReplaceAll;

  /// No description provided for @textEditorFindMode.
  ///
  /// In en, this message translates to:
  /// **'Find mode'**
  String get textEditorFindMode;

  /// No description provided for @textEditorReplaceMode.
  ///
  /// In en, this message translates to:
  /// **'Replace mode'**
  String get textEditorReplaceMode;

  /// No description provided for @textEditorUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get textEditorUndo;

  /// No description provided for @textEditorRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get textEditorRedo;

  /// No description provided for @textEditorFontSmaller.
  ///
  /// In en, this message translates to:
  /// **'Smaller font'**
  String get textEditorFontSmaller;

  /// No description provided for @textEditorFontLarger.
  ///
  /// In en, this message translates to:
  /// **'Larger font'**
  String get textEditorFontLarger;

  /// No description provided for @textEditorWordWrap.
  ///
  /// In en, this message translates to:
  /// **'Wrap'**
  String get textEditorWordWrap;

  /// No description provided for @textEditorSyntaxHighlight.
  ///
  /// In en, this message translates to:
  /// **'Highlighting'**
  String get textEditorSyntaxHighlight;

  /// No description provided for @textEditorUnsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get textEditorUnsavedChanges;

  /// No description provided for @textEditorRemote.
  ///
  /// In en, this message translates to:
  /// **'Remote'**
  String get textEditorRemote;

  /// No description provided for @textEditorTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get textEditorTools;

  /// No description provided for @textEditorSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get textEditorSettings;

  /// No description provided for @textEditorDefaultsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Defaults applied when opening a file'**
  String get textEditorDefaultsSubtitle;

  /// No description provided for @textEditorFontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get textEditorFontSize;

  /// No description provided for @commonCut.
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get commonCut;

  /// No description provided for @commonPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get commonPaste;

  /// No description provided for @textEditorSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get textEditorSelectAll;

  /// No description provided for @fileManagerChooseDestination.
  ///
  /// In en, this message translates to:
  /// **'Choose destination folder'**
  String get fileManagerChooseDestination;

  /// No description provided for @fileManagerSelectFolder.
  ///
  /// In en, this message translates to:
  /// **'Select folder'**
  String get fileManagerSelectFolder;

  /// No description provided for @fileManagerMoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Move selected files?'**
  String get fileManagerMoveTitle;

  /// No description provided for @fileManagerMoveMessage.
  ///
  /// In en, this message translates to:
  /// **'Move {count} selected item(s) to \"{folder}\"?'**
  String fileManagerMoveMessage(int count, String folder);

  /// No description provided for @fileManagerDateToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get fileManagerDateToday;

  /// No description provided for @fileManagerDateYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get fileManagerDateYesterday;

  /// No description provided for @fileManagerZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Larger previews'**
  String get fileManagerZoomIn;

  /// No description provided for @fileManagerZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Smaller previews'**
  String get fileManagerZoomOut;

  /// No description provided for @fileManagerUnknownDate.
  ///
  /// In en, this message translates to:
  /// **'Unknown date'**
  String get fileManagerUnknownDate;

  /// No description provided for @fileManagerDeselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get fileManagerDeselectAll;

  /// No description provided for @fileManagerImagePreviews.
  ///
  /// In en, this message translates to:
  /// **'Image previews'**
  String get fileManagerImagePreviews;

  /// No description provided for @fileManagerCropPreviews.
  ///
  /// In en, this message translates to:
  /// **'Fill the tile'**
  String get fileManagerCropPreviews;

  /// No description provided for @fileManagerCropPreviewsHint.
  ///
  /// In en, this message translates to:
  /// **'Crop previews to a square. Off shows the whole image, which also uses less memory.'**
  String get fileManagerCropPreviewsHint;
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
