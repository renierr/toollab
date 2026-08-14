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
  String get settingsLowLatencyAudio => 'Low Latency Audio';

  @override
  String get settingsLowLatencyAudioSubtitle =>
      'Allows faster audio response. Disable if screen recording has silent audio';

  @override
  String get settingsSortBy => 'Sort by';

  @override
  String get settingsSortRecent => 'Recent';

  @override
  String get settingsSortDefaultOrder => 'Default order';

  @override
  String get settingsSortName => 'Name';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonClose => 'Close';

  @override
  String get commonOk => 'OK';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonShare => 'Share';

  @override
  String get commonExport => 'Export';

  @override
  String get commonImport => 'Import';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonError => 'Error';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonRename => 'Rename';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonReset => 'Reset';

  @override
  String get commonDone => 'Done';

  @override
  String get commonApply => 'Apply';

  @override
  String get commonOpen => 'Open';

  @override
  String get commonSettings => 'Settings';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonBack => 'Back';

  @override
  String get commonHome => 'Home';

  @override
  String get commonBrowseFiles => 'Browse Files';

  @override
  String chipFailedToParseModule(Object error) {
    return 'Failed to parse module: $error';
  }

  @override
  String chipFailedToOpenSharedFile(Object error) {
    return 'Failed to open shared file: $error';
  }

  @override
  String get chipUnsupportedAudioOpenedInternally =>
      'Opened with the internal audio player';

  @override
  String get chipUnsupportedAudioFormat =>
      'This audio format cannot be played on this device';

  @override
  String chipAudioPlaybackFailed(Object error) {
    return 'Audio playback failed: $error';
  }

  @override
  String get chipHideVisualizer => 'Hide visualizer';

  @override
  String get chipShowVisualizer => 'Show visualizer';

  @override
  String get chipLoadFiles => 'Load files';

  @override
  String get chipModuleArchived => 'Module archived';

  @override
  String get chipAlreadyInArchive => 'Already in archive';

  @override
  String get chipArchivedModuleNotFound => 'Archived module not found';

  @override
  String get chipModuleDataNotAvailable => 'Module data not available';

  @override
  String get chipDeleteModuleTitle => 'Delete Module';

  @override
  String get chipDeleteModuleMessage => 'Remove this module from the archive?';

  @override
  String chipSyncedResult(Object pulled, Object pushed) {
    return 'Synced: $pulled pulled, $pushed pushed';
  }

  @override
  String chipSyncFailed(Object error) {
    return 'Sync failed: $error';
  }

  @override
  String chipArchiveTitle(Object count) {
    return 'Archive ($count)';
  }

  @override
  String get chipSyncTooltip => 'Sync';

  @override
  String get chipNoArchivedModules => 'No archived modules';

  @override
  String get chipDownloadTooltip => 'Download';

  @override
  String get chipUntitled => 'Untitled';

  @override
  String get chipMetricChannels => 'Channels';

  @override
  String get chipMetricPatterns => 'Patterns';

  @override
  String get chipMetricOrders => 'Orders';

  @override
  String get chipMetricInstruments => 'Instruments';

  @override
  String get chipMetricBpm => 'BPM';

  @override
  String get chipMetricSpeed => 'Speed';

  @override
  String get chipEmptyDropTitle => 'Drop a tracker module';

  @override
  String get chipEmptyDropSubtitle => 'MOD · XM · IT files';

  @override
  String get chipEmptyTypeLabel => 'Tracker module';

  @override
  String get chipNotificationTitle => 'Chiptune playback active';

  @override
  String get chipNotificationText =>
      'ToolLab keeps audio running in background';

  @override
  String get treadmillNotificationTitle => 'Treadmill workout active';

  @override
  String get treadmillNotificationText =>
      'ToolLab keeps recording your session';

  @override
  String get chipPauseTooltip => 'Pause';

  @override
  String get chipPlayTooltip => 'Play';

  @override
  String get chipStopTooltip => 'Stop';

  @override
  String get chipLoopingTooltip => 'Looping';

  @override
  String get chipLoopOffTooltip => 'Loop off';

  @override
  String get chipRandomTooltip => 'Random tune from The Mod Archive';

  @override
  String get chipNextRandomTooltip => 'Next random tune';

  @override
  String get chipNextTrackTooltip => 'Next track';

  @override
  String get chipRandomMenuTooltip => 'Random tune';

  @override
  String get chipRandomSourceLabel => 'Source';

  @override
  String get chipRandomSourceModArchive => 'The Mod Archive';

  @override
  String get chipRandomSourceServer => 'My collection (server)';

  @override
  String chipServerRandomFailed(Object error) {
    return 'Collection fetch failed: $error';
  }

  @override
  String chipPlaylistTitle(Object count) {
    return 'Playlist ($count)';
  }

  @override
  String get chipFolderTooltip => 'Play folder';

  @override
  String get chipFolderEmpty => 'No playable module files in this folder';

  @override
  String get chipPlaylistNoSupported => 'No supported module files selected';

  @override
  String get chipSelectOutputDevice => 'Select Output Device';

  @override
  String get chipTweaks => 'Tweaks';

  @override
  String get chipInterpolation => 'Interpolation';

  @override
  String get chipInterpolationSinc => 'Sinc (clearest)';

  @override
  String get chipInterpolationCubic => 'Cubic (smooth)';

  @override
  String get chipInterpolationLinear => 'Linear (bright)';

  @override
  String get chipInterpolationNone => 'None (raw)';

  @override
  String get chipPreAmp => 'Pre-amp';

  @override
  String get chipAmigaFilter => 'Amiga filter';

  @override
  String get chipAmigaFilterAuto => 'Auto';

  @override
  String get chipAmigaFilterOn => 'On';

  @override
  String get chipAmigaFilterOff => 'Off';

  @override
  String get chipVolumeRamping => 'Volume ramping';

  @override
  String get chipRampOff => 'Off';

  @override
  String get chipRampFast => 'Fast';

  @override
  String get chipRampSmooth => 'Smooth';

  @override
  String get chipStereoSeparation => 'Stereo separation';

  @override
  String get chipDefaultDevice => 'Default Device';

  @override
  String chipOutputDeviceChanged(Object name) {
    return 'Output device changed to $name';
  }

  @override
  String get chipRandomTitle => 'Random Tune';

  @override
  String get chipRandomFetching =>
      'Fetching a random tune from The Mod Archive…';

  @override
  String chipRandomFetchFailed(Object error) {
    return 'Could not fetch a random tune: $error';
  }

  @override
  String get chipRandomRetry => 'Retry';

  @override
  String get chipRandomShuffleAgain => 'Shuffle again';

  @override
  String get chipRandomCredits =>
      'Source: The Mod Archive — a free repository of tracker music. All rights belong to the original artists.';

  @override
  String chipRandomSourceLink(Object moduleId) {
    return 'View module #$moduleId on modarchive.org';
  }

  @override
  String get chipMetricFormat => 'Format';

  @override
  String get chipMetricGenre => 'Genre';

  @override
  String get chipMetricSize => 'Size';

  @override
  String get chipMetricDuration => 'Duration';

  @override
  String get chipAudioFile => 'Audio file';

  @override
  String get chipStereoWidth => 'Stereo Width';

  @override
  String get chipExportToWav => 'Export to WAV';

  @override
  String get chipExportingToWav => 'Exporting to WAV…';

  @override
  String get chipExportSuccess => 'WAV file exported successfully';

  @override
  String chipExportFailed(String error) {
    return 'WAV export failed: $error';
  }

  @override
  String coreNoToolsFoundToOpen(String name) {
    return 'No tools found to open \"$name\"';
  }

  @override
  String get coreAboutTitle => 'About';

  @override
  String coreAboutVersion(String version) {
    return 'v$version';
  }

  @override
  String get coreAboutDescription =>
      'ToolLab is a collection of utility tools for your device. It includes sensors, calculator, device information, NFC tag reading/writing, PDF viewing, note taking, and more — all in one app.';

  @override
  String get coreAboutDisclaimer => 'Disclaimer';

  @override
  String get coreAboutDisclaimerText =>
      'This app is provided \"as is\" without warranty of any kind. The developer shall not be held liable for any damages, data loss, or issues arising from the use of this software.';

  @override
  String get coreAboutThirdPartyLicenses => 'Third-Party Licenses';

  @override
  String get coreMaintenanceTitle => 'Maintenance Settings';

  @override
  String get coreDatabaseExportedAndroid =>
      'Database exported to Downloads folder successfully.';

  @override
  String coreDatabaseExportedGeneral(String path) {
    return 'Database exported to $path successfully.';
  }

  @override
  String coreDatabaseExportFailed(String error) {
    return 'Database export failed: $error';
  }

  @override
  String get coreSettingsExportedAndroid =>
      'Settings exported to Downloads folder successfully.';

  @override
  String coreSettingsExportedGeneral(String path) {
    return 'Settings exported to $path successfully.';
  }

  @override
  String coreSettingsExportFailed(String error) {
    return 'Settings export failed: $error';
  }

  @override
  String get coreDangerZoneTitle => 'Danger Zone';

  @override
  String get coreDatabaseImportButton => 'Import Database (.db)';

  @override
  String get coreDatabaseImportDescription =>
      'Restore a previously exported database. This permanently overwrites all current tool data and settings. This cannot be undone.';

  @override
  String get coreDatabaseImportConfirmTitle => 'Import Database?';

  @override
  String get coreDatabaseImportConfirmMessage =>
      'This will permanently overwrite all current data and settings with the contents of the selected backup, and the app will reload. This action cannot be undone.';

  @override
  String coreDatabaseImportInvalid(String error) {
    return 'Invalid or incompatible database file: $error';
  }

  @override
  String get coreDatabaseImportSuccess =>
      'Database imported successfully. Your data and settings have been restored.';

  @override
  String coreDatabaseImportFailed(String error) {
    return 'Database import failed: $error';
  }

  @override
  String coreDatabaseSize(String size) {
    return 'Current database size: $size';
  }

  @override
  String get coreDatabaseSizeLoading => 'Current database size: Loading...';

  @override
  String get coreTempFilesTitle => 'Temp Files';

  @override
  String coreTempFilesUsage(int count, String size) {
    return '$count file(s) using $size';
  }

  @override
  String get coreTempFilesCleanUp => 'Clean Up Temp Files';

  @override
  String get coreTempFilesCleanedUp => 'Temp files cleaned up';

  @override
  String get coreShortcutsTitle => 'Tool Shortcuts';

  @override
  String get coreShortcutsDirectAccessTitle => 'Direct Access Launcher';

  @override
  String get coreShortcutsDirectAccessSubtitle =>
      'Add separate home screen icons or app drawer launchers for your favorite tools. Tapping a shortcut will open the app directly inside that tool.';

  @override
  String get coreShortcutsAndroidRequired =>
      'Android OS is required to pin native shortcuts or toggle app drawer icons. Toggles will persist locally but no native icons will be modified.';

  @override
  String get coreShortcutsSelectTools => 'Select Tools to Configure';

  @override
  String coreShortcutsPinRequested(String name) {
    return 'Shortcut requested for $name! Accept system dialog.';
  }

  @override
  String coreShortcutsDrawerDisabled(String name) {
    return 'Disabled App Drawer icon for $name';
  }

  @override
  String coreShortcutsDrawerEnabled(String name) {
    return 'Enabled App Drawer icon for $name (Updates in a few seconds).';
  }

  @override
  String get coreSyncTitle => 'Cloud Synchronization';

  @override
  String get coreSyncAcrossDevicesTitle => 'Sync data across devices';

  @override
  String get coreSyncAcrossDevicesSubtitle =>
      'Enabling cloud sync lets you back up your tools data and sync seamlessly to a centralized server.';

  @override
  String get coreSyncEnableTitle => 'Enable Synchronization';

  @override
  String get coreSyncActive => 'Syncing active';

  @override
  String get coreSyncDisabled => 'Syncing disabled';

  @override
  String get coreSyncStatsTitle => 'Server Statistics';

  @override
  String get coreSyncStatsSubtitle => 'What the backend is storing, per tool';

  @override
  String get coreSyncStatsRefresh => 'Refresh';

  @override
  String get coreSyncStatsItems => 'Items';

  @override
  String get coreSyncStatsDeleted => 'Tombstones';

  @override
  String get coreSyncStatsData => 'Data';

  @override
  String get coreSyncStatsTotalSize => 'Total';

  @override
  String get coreSyncStatsEmpty => 'The server is not storing anything yet.';

  @override
  String get coreSyncStatsUnsupported =>
      'This server does not report statistics. Update the backend to a version that provides /api/sync/stats.';

  @override
  String coreSyncStatsBinary(int count) {
    return 'Binary ($count)';
  }

  @override
  String coreSyncStatsTotals(int count) {
    return '$count tools on the server';
  }

  @override
  String get coreSyncToolsTitle => 'Tools to Synchronize';

  @override
  String get coreSyncToolsSubtitle =>
      'Choose which tools take part. New tools start switched on.';

  @override
  String get coreSyncToolsDisabledHint =>
      'A switched-off tool stops syncing but keeps its data on the server.';

  @override
  String get coreSyncToolDisabled =>
      'Sync is switched off for this tool in the sync settings.';

  @override
  String get coreSyncServerCredentials => 'Server Credentials';

  @override
  String get coreSyncServerBaseUrl => 'Server Base URL';

  @override
  String get coreSyncServerUrlRequired =>
      'Server URL is required when sync is enabled';

  @override
  String get coreSyncUserId => 'User ID (Optional)';

  @override
  String get coreSyncUserIdHint => 'Enter your username or user ID (optional)';

  @override
  String get coreSyncStatusTitle => 'Sync Status';

  @override
  String get coreSyncNeverSynced => 'Never synced';

  @override
  String coreSyncLastSynced(String dateTime) {
    return 'Last synced: $dateTime';
  }

  @override
  String get coreSyncSyncing => 'Syncing...';

  @override
  String get coreSyncNow => 'Sync Now';

  @override
  String coreSyncCompleted(String pulled, String pushed, String deleted) {
    return 'Sync completed. Pulled: $pulled, Pushed: $pushed, Deleted: $deleted.';
  }

  @override
  String get coreSyncFailedNoUrl => 'Sync failed. Server URL is empty.';

  @override
  String coreSyncFailed(String error) {
    return 'Sync failed: $error';
  }

  @override
  String get coreSyncSaveConfiguration => 'Save Configuration';

  @override
  String get coreSyncSettingsSaved => 'Settings saved successfully';

  @override
  String coreSyncSettingsSaveFailed(String error) {
    return 'Failed to save settings: $error';
  }

  @override
  String get coreOverviewSearchHint => 'Search tools...';

  @override
  String get coreOverviewNoToolsFound => 'No tools found';

  @override
  String get coreSettingsDialogTitle => 'Overview Settings';

  @override
  String get coreSettingsDialogSyncSubtitle =>
      'Backup and sync tool data to the cloud';

  @override
  String get coreSettingsDialogMaintenanceSubtitle =>
      'Download database backups and settings JSON';

  @override
  String get coreSettingsDialogShortcutsSubtitle =>
      'Pin shortcuts or manage app drawer icons';

  @override
  String get coreSettingsDialogOpenWithSubtitle =>
      'Manage default tool associations for shared files';

  @override
  String get coreSettingsDialogAppearanceSubtitle =>
      'Theme, compact view, notifications, sorting';

  @override
  String get coreSettingsDialogAboutSubtitle =>
      'Version, licenses, and app info';

  @override
  String get coreOpenWithDefaultsTitle => 'Open with Defaults';

  @override
  String get coreOpenWithResetTitle => 'Reset All Defaults?';

  @override
  String get coreOpenWithResetContent =>
      'This will clear all \"always open with\" associations. The chooser dialog will appear next time you open a shared file.';

  @override
  String get coreOpenWithNoDefaults => 'No default associations set.';

  @override
  String get coreOpenWithAssociationsLabel =>
      'Default tool associations for shared files:';

  @override
  String get coreOpenWithResetButton => 'Reset All Defaults';

  @override
  String get coreOpenWithResetting => 'Resetting...';

  @override
  String get coreOpenWithCleared => 'Default associations cleared';

  @override
  String get emfStartScanning => 'START SCANNING';

  @override
  String get emfStopScanning => 'STOP SCANNING';

  @override
  String get emfAudioTick => 'AUDIO TICK';

  @override
  String get emfScreenOn => 'SCREEN ON';

  @override
  String get emfCableTriggerThreshold => 'CABLE TRIGGER THRESHOLD';

  @override
  String get emfScannerTitle => 'EMF SCANNER';

  @override
  String get emfPro => 'PRO';

  @override
  String get emfWallCurrentSubtitle => 'WALL CURRENT & CURRENT LOCATOR';

  @override
  String get emfSimulator => 'SIMULATOR';

  @override
  String get emfHardwareSensor => 'HARDWARE SENSOR';

  @override
  String get emfOpenVirtualSensorToolbox =>
      'OPEN VIRTUAL SENSOR TOOLBOX (DEVELOPER)';

  @override
  String get emfDeveloperSimulationLab => '🛠️ DEVELOPER SIMULATION LAB';

  @override
  String get emfExitSim => 'EXIT SIM';

  @override
  String get emfSelectFieldScenarioPreset => 'SELECT FIELD SCENARIO PRESET';

  @override
  String get emfPresetEarthNormal => 'Earth Normal';

  @override
  String get emfPresetMainsWire => 'Mains Wire (AC)';

  @override
  String get emfPresetMagnetProximity => 'Magnet Proximity';

  @override
  String get emfPresetWalkDrift => 'Walk Drift (Drift)';

  @override
  String get emfManualVectorAdjustments => 'MANUAL X, Y, Z VECTOR ADJUSTMENTS';

  @override
  String get emfManualActive => 'MANUAL ACTIVE';

  @override
  String get emfXOffset => 'X Offset';

  @override
  String get emfYOffset => 'Y Offset';

  @override
  String get emfZOffset => 'Z Offset';

  @override
  String get emfThreeAxisVectorReadout => '3-AXIS VECTOR READOUT';

  @override
  String get emfLiveSensors => 'LIVE SENSORS';

  @override
  String get emfPaused => 'PAUSED';

  @override
  String get fastDropPastingText => 'Pasting text from clipboard...';

  @override
  String get fastDropPastingImage => 'Pasting image from clipboard...';

  @override
  String get fastDropClipboardEmpty =>
      'No text or image content found in clipboard';

  @override
  String get fastDropUploadedSuccessfully => 'Uploaded successfully!';

  @override
  String fastDropUploadingFiles(int count) {
    return 'Uploading $count files...';
  }

  @override
  String fastDropUploadingFileProgress(int current, int total, String name) {
    return 'Uploading $current of $total: $name...';
  }

  @override
  String get fastDropSharedFilesUploaded =>
      'Shared files uploaded successfully!';

  @override
  String get fastDropDeleteTitle => 'Delete Drop';

  @override
  String fastDropDeleteMessage(String filename) {
    return 'Are you sure you want to delete \"$filename\"?';
  }

  @override
  String get fastDropDeletedSuccessfully => 'Deleted successfully';

  @override
  String fastDropDeleteFailed(String error) {
    return 'Failed to delete drop: $error';
  }

  @override
  String fastDropDownloadingFile(String filename) {
    return 'Downloading $filename...';
  }

  @override
  String fastDropDownloadingFileToOpen(String filename) {
    return 'Downloading $filename to open...';
  }

  @override
  String get fastDropDescriptionUpdated => 'Description updated';

  @override
  String get fastDropRetentionUpdated => 'Retention updated';

  @override
  String get fastDropTitle => 'Fast Drop';

  @override
  String get fastDropStatusOnline => 'Online';

  @override
  String get fastDropStatusOffline => 'Offline';

  @override
  String get fastDropStatusSyncDisabled => 'Sync Disabled';

  @override
  String get fastDropStatusNotConfigured => 'Not Configured';

  @override
  String get fastDropRefreshList => 'Refresh List';

  @override
  String get fastDropProgressUploading => 'Uploading';

  @override
  String fastDropProgressDetails(
    String transferred,
    String total,
    String speed,
    String seconds,
  ) {
    return '$transferred / $total ($speed MB/s, ${seconds}s)';
  }

  @override
  String get fastDropProgressDownloading => 'Downloading';

  @override
  String get fastDropSectionTitle => 'DROPPED FILES';

  @override
  String get fastDropEditRetentionTitle => 'Edit Retention Period';

  @override
  String get fastDropEditDescriptionTitle => 'Edit Description';

  @override
  String get fastDropDescriptionHint => 'Add a description...';

  @override
  String fastDropExpires(String date) {
    return 'Expires: $date';
  }

  @override
  String get fastDropIndefiniteRetention => 'Indefinite retention';

  @override
  String get fastDropClipboardBadge => 'CLIPBOARD';

  @override
  String fastDropUploaded(String date) {
    return 'Uploaded: $date';
  }

  @override
  String get fastDropAddDescriptionPlaceholder => 'Add description...';

  @override
  String get fastDropPreviewTooltip => 'Preview';

  @override
  String get fastDropOpenShare => 'Open / Share';

  @override
  String get fastDropDownload => 'Download';

  @override
  String get fastDropConnectionStatus => 'Connection Status';

  @override
  String get fastDropRetryConnection => 'Retry Connection';

  @override
  String get fastDropNoDropsTitle => 'No Drops Yet';

  @override
  String get fastDropNoDropsSubtitle =>
      'Drag and drop files or paste content from clipboard to save temporarily.';

  @override
  String get fastDropDownloadingForPreview => 'Downloading file for preview...';

  @override
  String fastDropPreviewFailed(String error) {
    return 'Failed to load preview:\n$error';
  }

  @override
  String fastDropReadFileFailed(String error) {
    return 'Error reading file: $error';
  }

  @override
  String get fastDropPreviewNotAvailable =>
      'Preview not available for this file type.';

  @override
  String get fastDropOpenWithApp => 'Open with Tool / App';

  @override
  String get fastDropNotConfiguredTitle => 'Sync Server Not Configured';

  @override
  String get fastDropNotConfiguredBody =>
      'Fast Drop requires a connection to the backend server. Please configure your Sync Server URL in settings to start dropping files.';

  @override
  String get fastDropConfigureServer => 'Configure Server';

  @override
  String get fastDropSyncDisabledTitle => 'Cloud Sync is Disabled';

  @override
  String get fastDropSyncDisabledBody =>
      'Fast Drop requires cloud sync to be enabled in settings.';

  @override
  String get fastDropEnableButton => 'Enable';

  @override
  String get fastDropConfigureServerBody =>
      'Configure server URL in Cloud settings first.';

  @override
  String get fastDropServerUnreachable => 'Sync Server Unreachable';

  @override
  String get fastDropAllFiles => 'All Files';

  @override
  String get fastDropSelectFilesAndroid => 'Select files to upload';

  @override
  String get fastDropDropFilesHere => 'Drop files here';

  @override
  String get fastDropOrClickToBrowse => 'or click to browse';

  @override
  String get fastDropPasteClipboard => 'Paste Clipboard';

  @override
  String get fastDropOpenFile => 'Open';

  @override
  String get fastDropDownloadFile => 'Save';

  @override
  String get fastDropModeCloud => 'Cloud';

  @override
  String get fastDropModeNearby => 'Nearby';

  @override
  String get fastDropP2pStartReceiving => 'Start Receiving';

  @override
  String get fastDropP2pStopReceiving => 'Stop Receiving';

  @override
  String get fastDropP2pWaitingForSender =>
      'Waiting for a nearby device to send a file...';

  @override
  String get fastDropP2pAbortSend => 'Cancel send';

  @override
  String get fastDropP2pWaitingForReceiver =>
      'Waiting for a nearby device to start receiving...';

  @override
  String get fastDropP2pPeersFoundPickOne =>
      'Device found — pick it below to send';

  @override
  String fastDropP2pEstimateWifi(String duration) {
    return 'Wi-Fi: $duration';
  }

  @override
  String fastDropP2pEstimateBluetooth(String duration) {
    return 'Bluetooth: $duration';
  }

  @override
  String get fastDropP2pSendSectionTitle => 'SEND A FILE';

  @override
  String get fastDropP2pReceivedSectionTitle => 'RECEIVED FILES';

  @override
  String get fastDropP2pPickFileToSend => 'Pick a file to send';

  @override
  String get fastDropP2pScanningForPeers => 'Searching for nearby devices...';

  @override
  String get fastDropP2pNoPeersFound =>
      'No nearby devices found yet. Make sure the other device tapped \"Start Receiving\".';

  @override
  String fastDropP2pSignalStrength(int rssi) {
    return 'Signal: $rssi dBm';
  }

  @override
  String get fastDropP2pLocalNetwork => 'Local network';

  @override
  String get fastDropP2pSend => 'Send';

  @override
  String get fastDropP2pTransferringLan => 'Sending over Wi-Fi';

  @override
  String get fastDropP2pTransferringBle => 'Sending over Bluetooth';

  @override
  String get fastDropP2pBleFallbackWarning =>
      'No shared network found — transferring over Bluetooth, which is much slower. Connect both devices to the same Wi-Fi network for faster transfers.';

  @override
  String get fastDropP2pIncomingTitle => 'Incoming File';

  @override
  String fastDropP2pIncomingMessage(
    String sender,
    String filename,
    String size,
  ) {
    return '$sender wants to send you \"$filename\" ($size). Accept the transfer?';
  }

  @override
  String get fastDropP2pAccept => 'Accept';

  @override
  String get fastDropP2pDecline => 'Decline';

  @override
  String get fastDropP2pDismissFile => 'Dismiss';

  @override
  String get focusAutoStopTimer => 'Auto-stop Timer';

  @override
  String get focusStartPlaybackToEnableTimer =>
      'Start playback to enable timer';

  @override
  String focusCustomMinutes(int minutes) {
    return 'Custom: $minutes min';
  }

  @override
  String get focusSetTimer => 'Set';

  @override
  String get focusCancelTimer => 'Cancel Timer';

  @override
  String get focusBreathingGuide => 'Breathing Guide';

  @override
  String get focusStartBreathing => 'Start Breathing';

  @override
  String get focusStopBreathing => 'Stop Breathing';

  @override
  String get focusSoundLibrary => 'Sound Library';

  @override
  String get focusPlayback => 'Playback';

  @override
  String get focusStart => 'Start';

  @override
  String get focusStop => 'Stop';

  @override
  String get focusNotificationTitle => 'Focus noise active';

  @override
  String get focusNotificationText => 'ToolLab keeps ambient audio running';

  @override
  String get focusNoTimerSet => 'No timer set';

  @override
  String get focusStopping => 'Stopping...';

  @override
  String focusWillStopIn(String time) {
    return 'Will stop in $time';
  }

  @override
  String focusPlayingSound(String name) {
    return 'Playing $name';
  }

  @override
  String focusSelectedSound(String name) {
    return 'Selected $name';
  }

  @override
  String get img2pdfNoImageInClipboard => 'No image found in clipboard';

  @override
  String img2pdfFailedReadClipboard(String error) {
    return 'Failed to read clipboard: $error';
  }

  @override
  String get img2pdfSettingsTooltip => 'PDF Settings';

  @override
  String get img2pdfImagesLabel => 'Images';

  @override
  String get img2pdfDropTitle => 'Drop images here';

  @override
  String get img2pdfDropSubtitle => 'Supports PNG, JPEG, WebP, BMP, GIF';

  @override
  String get img2pdfBrowseFiles => 'Browse Files';

  @override
  String get img2pdfPasteFromClipboard => 'Paste from Clipboard';

  @override
  String get img2pdfPickFromGallery => 'Pick from Gallery';

  @override
  String get img2pdfNoImagesYet => 'No images added yet';

  @override
  String get img2pdfNoImagesHint =>
      'Drop images here or use \"Add More\" to begin';

  @override
  String img2pdfPageNumber(int page) {
    return 'Page $page';
  }

  @override
  String get img2pdfPdfSettings => 'PDF Settings';

  @override
  String get img2pdfPageSize => 'Page Size';

  @override
  String get img2pdfFitToImage => 'Fit to Image';

  @override
  String get img2pdfOrientation => 'Orientation';

  @override
  String get img2pdfLandscape => 'Landscape';

  @override
  String get img2pdfJpegQuality => 'JPEG Quality';

  @override
  String get img2pdfImageCountSingle => '1 image';

  @override
  String img2pdfImageCountPlural(int count) {
    return '$count images';
  }

  @override
  String get img2pdfAddMore => 'Add More';

  @override
  String get img2pdfCreatePdf => 'Create PDF';

  @override
  String get img2pdfPreparing => 'Preparing…';

  @override
  String img2pdfProcessingImage(int done, int total) {
    return 'Processing image $done of $total…';
  }

  @override
  String get img2pdfSavingPdf => 'Saving PDF…';

  @override
  String img2pdfSavedTo(String path) {
    return 'PDF saved to $path';
  }

  @override
  String img2pdfSaveFailed(String error) {
    return 'Failed to save PDF: $error';
  }

  @override
  String img2pdfCreateFailed(String error) {
    return 'Failed to create PDF: $error';
  }

  @override
  String get imgViewDiscardChangesTitle => 'Discard changes?';

  @override
  String get imgViewDiscardChangesMessage =>
      'You have unsaved edits to this image. Leaving will discard them.';

  @override
  String get imgViewDiscard => 'Discard';

  @override
  String get imgViewKeepEditing => 'Keep editing';

  @override
  String get imgViewImageCopied => 'Image copied to clipboard';

  @override
  String get imgViewHideSettings => 'Hide settings';

  @override
  String get imgViewShowSettings => 'Show settings';

  @override
  String get imgViewEditImageTooltip => 'Edit image';

  @override
  String get imgViewCloseImage => 'Close image';

  @override
  String get imgViewEditImageDrawerTitle => 'Edit Image';

  @override
  String get imgViewUndo => 'Undo';

  @override
  String get imgViewRedo => 'Redo';

  @override
  String get imgViewCopyToClipboard => 'Copy to clipboard';

  @override
  String get imgViewDropZoneTitle => 'Drop an image here';

  @override
  String get imgViewDropZoneSubtitle =>
      'Supports PNG, JPEG, WebP, BMP, GIF, TIFF, ICO';

  @override
  String get imgViewTypeLabel => 'Images';

  @override
  String get imgViewBrowseFiles => 'Browse Files';

  @override
  String get imgViewPasteFromClipboard => 'Paste from Clipboard';

  @override
  String get imgViewUnsupportedTitle => 'Format cannot be displayed';

  @override
  String imgViewUnsupportedMessage(String name) {
    return '\"$name\" uses an image format the viewer cannot decode. Open it with a system app instead.';
  }

  @override
  String get imgViewOpenExternally => 'Open with system app';

  @override
  String get imgViewChooseAnother => 'Choose another image';

  @override
  String get imgViewOriginalFileDetails => 'Original File Details';

  @override
  String get imgViewMoreInformation => 'More Information';

  @override
  String get imgViewTransform => 'Transform';

  @override
  String get imgViewCroppingActive =>
      'Cropping Active. Adjust controls on the image display.';

  @override
  String get imgViewRedactingActive =>
      'Redacting Active. Adjust controls on the image display.';

  @override
  String get imgViewRotateLeft => 'Rotate 90° Left';

  @override
  String get imgViewRotateRight => 'Rotate 90° Right';

  @override
  String get imgViewFlipHorizontal => 'Flip Horizontally';

  @override
  String get imgViewFlipVertical => 'Flip Vertically';

  @override
  String get imgViewCrop => 'Crop';

  @override
  String get imgViewRedact => 'Redact';

  @override
  String get imgViewResizeImage => 'Resize Image';

  @override
  String get imgViewWidthLabel => 'Width (px)';

  @override
  String get imgViewAspectRatioLocked => 'Aspect ratio locked';

  @override
  String get imgViewAspectRatioUnlocked => 'Aspect ratio unlocked';

  @override
  String get imgViewHeightLabel => 'Height (px)';

  @override
  String get imgViewPreviewResize => 'Preview Resize';

  @override
  String get imgViewOutputFormat => 'Output Format';

  @override
  String get imgViewPreserveExif => 'Preserve EXIF Metadata';

  @override
  String get imgViewPreserveExifSubtitle =>
      'Keep GPS, camera tags, and date (JPEG only)';

  @override
  String imgViewCompressionQuality(int quality) {
    return 'Compression Quality: $quality%';
  }

  @override
  String get imgViewSaveImage => 'Save Image';

  @override
  String get imgViewShareImage => 'Share Image';

  @override
  String get imgViewDimensions => 'Dimensions';

  @override
  String get imgViewFileSize => 'File Size';

  @override
  String get imgViewRedactStyleHeader => 'Redaction Style & Shape';

  @override
  String get imgViewShapeLabel => 'Shape: ';

  @override
  String get imgViewShapeRectangle => 'Rectangle';

  @override
  String get imgViewShapeFreehand => 'Freehand';

  @override
  String get imgViewRedraw => 'Redraw';

  @override
  String get imgViewStyleSolid => 'Solid';

  @override
  String get imgViewStylePixelate => 'Pixelate';

  @override
  String get imgViewStyleBlur => 'Blur';

  @override
  String get imgViewColorLabel => 'Color: ';

  @override
  String imgViewBlockSize(int size) {
    return 'Block Size: $size px';
  }

  @override
  String imgViewBlurRadius(int radius) {
    return 'Blur Radius: $radius px';
  }

  @override
  String get imgViewRedactHint => 'Draw a path over the area to redact';

  @override
  String get imgViewApplyRedaction => 'Apply Redaction';

  @override
  String get imgViewCropPresetsHeader => 'Crop Presets';

  @override
  String get imgViewCropPresetFree => 'Free';

  @override
  String get imgViewCropPreset1x1 => '1:1 Square';

  @override
  String get imgViewCropPreset16x9 => '16:9 Widescreen';

  @override
  String get imgViewCropPreset4x3 => '4:3 Standard';

  @override
  String get imgViewCropPreset3x2 => '3:2 Photo';

  @override
  String get imgViewApplyCrop => 'Apply Crop';

  @override
  String get imgViewZoomOut => 'Zoom out';

  @override
  String get imgViewZoomIn => 'Zoom in';

  @override
  String get imgViewPreviousImage => 'Previous image';

  @override
  String get imgViewNextImage => 'Next image';

  @override
  String get imgViewGpsTitle => 'GPS Location Information';

  @override
  String get imgViewGpsLatitude => 'Latitude';

  @override
  String get imgViewGpsLongitude => 'Longitude';

  @override
  String get imgViewGpsCoordinatesDms => 'Coordinates (DMS)';

  @override
  String get imgViewOpenInMaps => 'Open in Maps';

  @override
  String get imgViewBrowseGallery => 'Browse Gallery';

  @override
  String get imgViewTakePhoto => 'Take Photo';

  @override
  String get imgViewExifThumbnailTitle => 'EXIF Embedded Thumbnail';

  @override
  String get imgViewMetadataDialogTitle => 'Metadata & EXIF Info';

  @override
  String get imgViewNoExifData => 'No EXIF metadata found in this image.';

  @override
  String get imgViewSegmentSubject => 'Segment Subject';

  @override
  String get imgViewSegmentSubjectTooltip =>
      'Isolate the subject from the background using ML';

  @override
  String get imgViewSegmentSubjectUnsupported =>
      'Subject segmentation is only supported on Android';

  @override
  String imgViewSegmentSubjectFailed(String error) {
    return 'Failed to segment subject: $error';
  }

  @override
  String get imgViewSegmentSubjectDownloading =>
      'Google Play Services is downloading the required machine learning model. Please wait a minute and try again.';

  @override
  String get imgViewExtractText => 'Extract Text';

  @override
  String get imgViewExtractTextTooltip =>
      'Extract text from the image using ML';

  @override
  String get imgViewExtractTextTitle => 'Extracted Text';

  @override
  String get imgViewExtractTextNoText => 'No text detected in the image.';

  @override
  String imgViewExtractTextFailed(String error) {
    return 'Failed to extract text: $error';
  }

  @override
  String get imgViewTextCopied => 'Text copied to clipboard';

  @override
  String get levelSensorsUnavailable => 'Sensors not available on this device.';

  @override
  String get levelCalibratedToZero => 'Surface calibrated to zero.';

  @override
  String get levelCalibrationReset => 'Calibration reset.';

  @override
  String get levelMode2Axis => '2-Axis';

  @override
  String get levelModeBeam => 'Beam';

  @override
  String get levelRuler => 'Ruler';

  @override
  String get levelCalibrateRuler => 'Calibrate Ruler';

  @override
  String get levelRotationLocked => 'Locked';

  @override
  String get levelLockRotation => 'Lock Rot.';

  @override
  String get levelWakeLock => 'Wake Lock';

  @override
  String get levelTolerance => 'TOLERANCE';

  @override
  String get levelSetZero => 'Set Zero';

  @override
  String get levelRulerCalibration => 'Ruler Calibration';

  @override
  String get levelRulerCalibrationHint =>
      'Hold a physical ruler against the screen edge. Adjust the scale until the markings match exactly.';

  @override
  String get levelPitch => 'Pitch';

  @override
  String get levelRoll => 'Roll';

  @override
  String get miscCalculatorCopied => 'Copied';

  @override
  String get miscCalculatorSciLabel => 'SCI';

  @override
  String get miscCalculatorHistLabel => 'HIST';

  @override
  String get miscCalculatorCopyResultTooltip => 'Copy result';

  @override
  String get miscCalculatorPasteTooltip => 'Paste from clipboard';

  @override
  String get miscCalculatorPasteInvalid => 'Clipboard has no usable number';

  @override
  String get miscCalculatorBackspaceTooltip => 'Backspace';

  @override
  String get miscCalculatorHistoryTitle => 'History';

  @override
  String get miscCalculatorNoHistory => 'No calculations yet';

  @override
  String get miscBatteryPowerStatus => 'Power Status';

  @override
  String get miscBatteryFullyCharged => 'Fully Charged';

  @override
  String get miscBatteryCharging => 'Charging';

  @override
  String get miscBatteryDischarging => 'Discharging';

  @override
  String get miscBatterySaverActive => 'Saver Active';

  @override
  String get miscBatteryChargingSlow => 'Slow Charging';

  @override
  String get miscBatteryChargingNormal => 'Charging';

  @override
  String get miscBatteryChargingFast => 'Fast Charging';

  @override
  String get miscBatteryVoltage => 'Voltage';

  @override
  String get miscBatteryCurrent => 'Current';

  @override
  String get miscBatteryPower => 'Power';

  @override
  String get miscDeviceInfoSystemOs => 'System & OS';

  @override
  String get miscDeviceInfoHardwareSpecs => 'Hardware Specs';

  @override
  String get miscDeviceInfoDisplayDetails => 'Display Details';

  @override
  String get miscDeviceInfoWindowsDisplayResolution =>
      'Current Display Resolution';

  @override
  String get miscDeviceInfoAppViewSize => 'App View Size';

  @override
  String get miscDeviceInfoAppViewPixels => 'App View Pixels';

  @override
  String get miscDeviceInfoDisplayScale => 'Display Scale';

  @override
  String get miscDeviceInfoOrientation => 'Orientation';

  @override
  String get miscDeviceInfoRefreshRate => 'Refresh Rate';

  @override
  String get miscDeviceInfoCpuModel => 'CPU Model';

  @override
  String get miscDeviceInfoCpuArchitecture => 'CPU Architecture';

  @override
  String get miscDeviceInfoGpuModel => 'GPU Model';

  @override
  String get miscDeviceInfoGpuVram => 'GPU VRAM';

  @override
  String get miscDeviceInfoSystemUptime => 'System Uptime';

  @override
  String get miscDeviceInfoWindowsUptime => 'Uptime Since Last Full Restart';

  @override
  String miscDeviceInfoUptimeDays(int days, int hours) {
    return '${days}d ${hours}h';
  }

  @override
  String miscDeviceInfoUptimeHours(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String miscDeviceInfoStorageVolume(Object name) {
    return 'Storage: $name';
  }

  @override
  String get miscDeviceInfoFree => 'free';

  @override
  String get miscDeviceInfoWifiSsid => 'Wi-Fi SSID';

  @override
  String get miscDeviceInfoWifiSignal => 'Signal';

  @override
  String get miscDeviceInfoWifiLinkSpeed => 'Link Speed';

  @override
  String get miscDeviceInfoWifiFrequency => 'Frequency';

  @override
  String get miscDeviceInfoGeneralSettings => 'General Settings';

  @override
  String get miscDeviceInfoStorage => 'Storage & Memory';

  @override
  String get miscDeviceInfoNetwork => 'Network Connection';

  @override
  String get miscDeviceInfoSensors => 'Available Sensors';

  @override
  String get miscDeviceInfoAppInfo => 'Application Info';

  @override
  String miscMarkdownFailedToLoad(String error) {
    return 'Failed to load file: $error';
  }

  @override
  String miscMarkdownFailedToRead(String error) {
    return 'Failed to read file: $error';
  }

  @override
  String get miscMarkdownOpenTitle => 'Open a Markdown File';

  @override
  String get miscMarkdownDropSubtitle => 'Drag & drop a .md or .txt file here';

  @override
  String get miscMarkdownTypeLabel => 'Markdown';

  @override
  String get nfcEditorFormTitle => 'NDEF Record Creator';

  @override
  String get nfcTemplatePreset => 'Template Preset';

  @override
  String get nfcTemplateCustomRecord => 'Custom Record';

  @override
  String get nfcTemplateUrlHomepage => 'URL: Homepage Link';

  @override
  String get nfcTemplateTextNote => 'Text: Plain Note';

  @override
  String get nfcTemplateMimeJson => 'MIME: JSON Config';

  @override
  String get nfcTemplateMimeVcard => 'MIME: vCard Contact';

  @override
  String get nfcRecordType => 'Record Type (NDEF Format)';

  @override
  String get nfcRecordTypeUri => 'Well-known URI (URL)';

  @override
  String get nfcRecordTypeText => 'Well-known Text';

  @override
  String get nfcRecordTypeMime => 'MIME Media Payload';

  @override
  String get nfcUriTargetLink => 'URI Target Link';

  @override
  String get nfcUriHelperText =>
      'Auto-detects common prefixes (https://, http://, mailto:, file://) to save tag space.';

  @override
  String get nfcUriRequired => 'URI target link is required';

  @override
  String get nfcTextContent => 'Text Content';

  @override
  String get nfcTextContentHint => 'Enter note content...';

  @override
  String get nfcTextContentRequired => 'Text content is required';

  @override
  String get nfcLanguageCode => 'Language Code';

  @override
  String get nfcLanguageCodeHelper =>
      'Standard BCP 47 language identifier (e.g. en, fr, de, es).';

  @override
  String get nfcLanguageCodeRequired => 'Language code is required';

  @override
  String get nfcMimeType => 'MIME Type';

  @override
  String get nfcMimeTypeHelper =>
      'Official media type (e.g. application/json, text/vcard, image/png).';

  @override
  String get nfcMimeTypeRequired =>
      'A valid MIME type (e.g., type/subtype) is required';

  @override
  String get nfcMimePayloadData => 'MIME Payload Data';

  @override
  String get nfcMimePayloadHint =>
      'Enter JSON, vCard, or custom raw contents...';

  @override
  String get nfcPayloadRequired => 'Payload data is required';

  @override
  String get nfcGetHex => 'Get Hex';

  @override
  String get nfcWriteTag => 'Write Tag';

  @override
  String get nfcWriteTagHint =>
      'Write Tag active only when scanning a writable tag.';

  @override
  String get nfcHexInspectorTitle => 'NDEF Hex Inspector';

  @override
  String get nfcHexInspectorSubtitle =>
      'Validate, parse, or generate raw NDEF hex codes.';

  @override
  String get nfcPasteHexData => 'Paste NDEF Hex Data';

  @override
  String get nfcClearInput => 'Clear Input';

  @override
  String get nfcPasteHexToParsePrompt =>
      'Please paste some NDEF hex data to parse.';

  @override
  String get nfcParseHex => 'Parse Hex';

  @override
  String get nfcGeneratedHex => 'Generated NDEF Hex';

  @override
  String get nfcCopyGeneratedHex => 'Copy Generated Hex';

  @override
  String get nfcHexCopied => 'Generated NDEF Hex copied to clipboard.';

  @override
  String get nfcNoRecordsFound => 'No Records Found';

  @override
  String get nfcNoRecordsSubtitle =>
      'NDEF payload is empty or not scanned yet.';

  @override
  String nfcNdefRecords(int count) {
    return 'NDEF Records ($count)';
  }

  @override
  String get nfcRecordIndex => 'Record Index:';

  @override
  String get nfcLoadIntoEditor => 'Load into Editor';

  @override
  String get nfcRecordLoaded => 'Record loaded into Editor Form.';

  @override
  String get nfcCopyPayloadHex => 'Copy Payload Hex';

  @override
  String get nfcPayloadHexCopied => 'Payload Hex copied to clipboard.';

  @override
  String get nfcRawPayloadHex => 'Raw Payload (Hex):';

  @override
  String nfcSubtitleText(String lang, String encoding) {
    return 'Well-known Text [$lang | $encoding]';
  }

  @override
  String get nfcSubtitleUri => 'Well-known URI';

  @override
  String get nfcSubtitleCustom => 'Custom / Non-NDEF';

  @override
  String get nfcStop => 'Stop';

  @override
  String get nfcScan => 'Scan';

  @override
  String get nfcNoHardware => 'No Hardware';

  @override
  String get nfcScannerTitle => 'NFC Scanner';

  @override
  String get nfcScanningPrompt => 'Approach an NFC tag to scan';

  @override
  String get nfcScannerInactive => 'Scanner is inactive';

  @override
  String get nfcCardBrand => 'Card Brand';

  @override
  String get nfcCardNumber => 'Card Number';

  @override
  String get nfcCardholderName => 'Cardholder Name';

  @override
  String get nfcExpirationDate => 'Expiration Date';

  @override
  String get nfcApplicationAid => 'Application AID';

  @override
  String get nfcUidSerial => 'UID / Serial';

  @override
  String get nfcTechnologies => 'Technologies';

  @override
  String get nfcCapacity => 'Capacity';

  @override
  String get nfcWritable => 'Writable';

  @override
  String get nfcCardholderLabel => 'CARDHOLDER';

  @override
  String get nfcExpiresLabel => 'EXPIRES';

  @override
  String get nfcPaymentCard => 'Payment Card';

  @override
  String nfcSessionError(String message) {
    return 'NFC scan session error: $message';
  }

  @override
  String nfcTagDetected(String label) {
    return 'Tag detected — $label';
  }

  @override
  String nfcScanFailed(String error) {
    return 'Scan failed: $error';
  }

  @override
  String get nfcNoActiveTag => 'No active tag. Scan a tag first.';

  @override
  String get nfcTagNotWritable => 'Tag is not writable or NDEF is unsupported.';

  @override
  String get nfcWritingToTag => 'Writing to NFC tag...';

  @override
  String get nfcWriteSuccess => 'NDEF record written successfully!';

  @override
  String nfcWriteFailed(String error) {
    return 'Failed to write: $error';
  }

  @override
  String get nfcHexGenerated => 'NDEF hex generated! Copy it below.';

  @override
  String nfcHexGenerateError(String error) {
    return 'Error generating hex: $error';
  }

  @override
  String get nfcHexParsed => 'NDEF Hex parsed successfully!';

  @override
  String nfcHexParseFailed(String error) {
    return 'Failed to parse hex: $error';
  }

  @override
  String get nfcNoHardwareInfo =>
      'NFC hardware scanning is only supported on mobile devices. You can still paste, parse, edit, and generate NDEF hexadecimal configurations locally.';

  @override
  String get nfcHexEmulator => 'Hex Emulator';

  @override
  String nfcRecordsParsed(int count) {
    return '$count records parsed';
  }

  @override
  String notesFailedToLoadSharedFile(String error) {
    return 'Failed to load shared file: $error';
  }

  @override
  String get notesNoteSaved => 'Note saved';

  @override
  String notesFailedToSaveNote(String error) {
    return 'Failed to save note: $error';
  }

  @override
  String get notesDeleteNoteTitle => 'Delete Note';

  @override
  String get notesDeleteNoteMessage =>
      'Are you sure you want to delete this note?';

  @override
  String get notesNoteDeleted => 'Note deleted';

  @override
  String notesFailedToDeleteNote(String error) {
    return 'Failed to delete note: $error';
  }

  @override
  String notesImportedNoteFrom(String name) {
    return 'Imported note from \"$name\"';
  }

  @override
  String notesFailedToImportDroppedFile(String error) {
    return 'Failed to import dropped file: $error';
  }

  @override
  String get notesViewNoteTitle => 'View Note';

  @override
  String notesFailedToReadFile(String error) {
    return 'Failed to read file: $error';
  }

  @override
  String get notesBackupImportedSuccessfully => 'Backup imported successfully';

  @override
  String notesImportFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String notesFailedToExportNotes(String error) {
    return 'Failed to export notes: $error';
  }

  @override
  String get notesSyncConfigureServerUrl =>
      'Configure server URL in Cloud settings first';

  @override
  String notesSyncFinished(int pulled, int pushed, int deleted) {
    return 'Sync finished. Pulled: $pulled, Pushed: $pushed, Deleted: $deleted.';
  }

  @override
  String get notesSyncFailedEmpty => 'Sync failed: URL or User ID empty';

  @override
  String notesSyncFailed(String error) {
    return 'Sync failed: $error';
  }

  @override
  String get notesSearchHint => 'Search notes...';

  @override
  String get notesEmptyTitle => 'No Notes Found';

  @override
  String get notesEmptyDescription =>
      'Create a new note or drag and drop a Markdown (.md) file to import.';

  @override
  String notesArchiveEntryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes',
      one: '1 note',
    );
    return '$_temp0';
  }

  @override
  String get notesSyncWithCloud => 'Sync with Cloud';

  @override
  String get notesImportMarkdownFile => 'Import Markdown file';

  @override
  String get notesImportJsonBackup => 'Import JSON Backup';

  @override
  String get notesExportJsonBackup => 'Export JSON Backup';

  @override
  String get notesEditorHint => 'Write notes here... (Markdown supported)';

  @override
  String get notesEditorNoPreview => 'Nothing to preview yet';

  @override
  String get notesUnsavedChangesTitle => 'Unsaved Changes';

  @override
  String get notesUnsavedChangesMessage =>
      'You have unsaved changes. Do you want to discard them?';

  @override
  String get notesKeepEditing => 'Keep Editing';

  @override
  String get notesDiscard => 'Discard';

  @override
  String get notesExportPdf => 'Export PDF';

  @override
  String get notesCreateNoteTitle => 'Create Note';

  @override
  String get notesEditNoteTitle => 'Edit Note';

  @override
  String get notesEditorToolbarTitle => 'Formatting Tools';

  @override
  String get notesEditorTagsTitle => 'Tags';

  @override
  String get notesTabWrite => 'Write';

  @override
  String get notesTabPreview => 'Preview';

  @override
  String get notesToggleSourceMode => 'Show Markdown Source';

  @override
  String get notesToggleLiveMode => 'Show Styled Preview';

  @override
  String get notesModeLiveTooltip => 'Live Editor (with markdown syntax)';

  @override
  String get notesModeSourceTooltip => 'Markdown Source (raw text)';

  @override
  String get notesModePreviewTooltip => 'Preview (without markdown syntax)';

  @override
  String get notesToolbarImage => 'Insert Image';

  @override
  String get notesImageSourceTitle => 'Insert Image';

  @override
  String get notesImageSourceGallery => 'Choose from Gallery';

  @override
  String get notesImageSourceCamera => 'Take Photo';

  @override
  String get notesImageSourceClipboard => 'Paste from Clipboard';

  @override
  String get notesImageSourceClipboardEmpty => 'No image in clipboard';

  @override
  String get notesImageProcessing => 'Processing image...';

  @override
  String get notesToolbarBold => 'Bold';

  @override
  String get notesToolbarItalic => 'Italic';

  @override
  String get notesToolbarStrikethrough => 'Strikethrough';

  @override
  String get notesToolbarH1 => 'H1';

  @override
  String get notesToolbarH2 => 'H2';

  @override
  String get notesToolbarH3 => 'H3';

  @override
  String get notesToolbarList => 'List';

  @override
  String get notesToolbarTodo => 'Todo';

  @override
  String get notesToolbarLink => 'Link';

  @override
  String get notesToolbarCode => 'Code';

  @override
  String get notesToolbarCodeBlock => 'Code Block';

  @override
  String get notesUntitledNote => 'Untitled Note';

  @override
  String get notesExportMd => 'Export MD';

  @override
  String notesUpdatedAt(String date) {
    return 'Updated: $date';
  }

  @override
  String get notesDropZoneUnsupportedFile =>
      'Only Markdown (.md) or Text (.txt) files are supported';

  @override
  String get notesDropZoneTitle => 'Drop Markdown file here';

  @override
  String get notesAddTagHint => 'Add tag...';

  @override
  String get pdfEditDownload => 'Download';

  @override
  String get pdfEditOpenInViewer => 'Open in Viewer';

  @override
  String pdfEditSignTitle(String fileName) {
    return 'Sign: $fileName';
  }

  @override
  String pdfEditSignOpenError(String error) {
    return 'Failed to open PDF: $error';
  }

  @override
  String pdfEditSignFailed(String error) {
    return 'Signing failed: $error';
  }

  @override
  String get pdfEditSignPrevPage => 'Previous page';

  @override
  String get pdfEditSignNextPage => 'Next page';

  @override
  String pdfEditSignPageOf(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String get pdfEditSignDragHint =>
      'Drag to position · resize/rotate at the handles';

  @override
  String get pdfEditSignTapHint => 'Tap a signature above';

  @override
  String get pdfEditSignStamping => 'Stamping signature…';

  @override
  String get pdfEditSignDoneTitle => 'Signature Placed';

  @override
  String pdfEditSignDoneSize(String size) {
    return 'Signed PDF size: $size';
  }

  @override
  String pdfEditFlattenTitle(String fileName) {
    return 'Flatten: $fileName';
  }

  @override
  String get pdfEditFlattenHeadline => 'Flatten PDF to Images';

  @override
  String get pdfEditFlattenDescription =>
      'Each page will be rendered as an image and embedded into a new PDF. This makes the content non-selectable and prevents text extraction.';

  @override
  String pdfEditFlattenDpi(int dpi) {
    return 'Resolution (DPI): $dpi';
  }

  @override
  String get pdfEditFlattenDpiHint =>
      'Higher DPI = larger file size but better quality';

  @override
  String pdfEditFlattenJpegQuality(int quality) {
    return 'JPEG Quality: $quality%';
  }

  @override
  String get pdfEditFlattenJpegQualityHint =>
      'Higher quality = larger file size';

  @override
  String get pdfEditFlattenStart => 'Start Flattening';

  @override
  String pdfEditFlattenProgress(int done, int total) {
    return 'Rendering page $done of $total…';
  }

  @override
  String pdfEditFlattenPagesTotal(int count) {
    return '$count pages total';
  }

  @override
  String pdfEditFlattenFailed(String error) {
    return 'Flatten failed: $error';
  }

  @override
  String get pdfEditFlattenDoneTitle => 'Flattening Complete';

  @override
  String pdfEditFlattenDoneSize(String size) {
    return 'New PDF size: $size';
  }

  @override
  String pdfEditRedactTitle(String fileName) {
    return 'Redact: $fileName';
  }

  @override
  String pdfEditRedactFailed(String error) {
    return 'Redaction failed: $error';
  }

  @override
  String pdfEditRedactPageOf(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String get pdfEditRedactDrawHint => 'Drag to draw a redaction rectangle';

  @override
  String get pdfEditRedactModeDraw => 'Draw';

  @override
  String get pdfEditRedactModeNavigate => 'Navigate';

  @override
  String get pdfEditRedactModeSelect => 'Select Text';

  @override
  String get pdfEditRedactProcessing => 'Applying redactions…';

  @override
  String get pdfEditRedactDoneTitle => 'Redaction Complete';

  @override
  String pdfEditRedactDoneSize(String size) {
    return 'Redacted PDF size: $size';
  }

  @override
  String get pdfEditRedactRedactSelected => 'Redact Selected';

  @override
  String get pdfEditRedactSelectHint =>
      'Select text in the document, then tap \"Redact Selected\"';

  @override
  String pdfEditMetaTitle2(String fileName) {
    return 'Metadata: $fileName';
  }

  @override
  String get pdfEditMetaReload => 'Reload metadata';

  @override
  String get pdfEditMetaLoadFailed => 'Failed to load metadata';

  @override
  String pdfEditMetaLoadError(String error) {
    return 'Failed to load metadata: $error';
  }

  @override
  String pdfEditMetaRemoveSecurityError(String error) {
    return 'Failed to remove security: $error';
  }

  @override
  String pdfEditMetaSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get pdfEditMetaSpecsTitle => 'Document Specifications';

  @override
  String get pdfEditMetaFileName => 'File Name';

  @override
  String get pdfEditMetaFileSize => 'File Size';

  @override
  String get pdfEditMetaPageCount => 'Page Count';

  @override
  String get pdfEditMetaPdfVersion => 'PDF Version';

  @override
  String get pdfEditMetaPageDimensions => 'Page Dimensions';

  @override
  String get pdfEditMetaMetadataTitle => 'Document Metadata';

  @override
  String get pdfEditMetaTitle => 'Title';

  @override
  String get pdfEditMetaAuthor => 'Author';

  @override
  String get pdfEditMetaSubject => 'Subject';

  @override
  String get pdfEditMetaKeywords => 'Keywords';

  @override
  String get pdfEditMetaCreator => 'Creator';

  @override
  String get pdfEditMetaProducer => 'Producer';

  @override
  String get pdfEditMetaCreationDate => 'Creation Date';

  @override
  String get pdfEditMetaModDate => 'Modification Date';

  @override
  String get pdfEditMetaTrapped => 'Trapped';

  @override
  String get pdfEditMetaSecurityTitle => 'Security & Restrictions';

  @override
  String get pdfEditMetaEncrypted => 'Encrypted';

  @override
  String pdfEditMetaEncryptedYes(String revision) {
    return 'Yes (Revision $revision)';
  }

  @override
  String get pdfEditMetaUnknown => 'unknown';

  @override
  String get pdfEditMetaRestrictions => 'Restrictions';

  @override
  String get pdfEditMetaPermAllowed => 'Allowed';

  @override
  String get pdfEditMetaPermRestricted => 'Restricted';

  @override
  String get pdfEditMetaPermPrintLow => 'Printing (Low Resolution)';

  @override
  String get pdfEditMetaPermPrintHigh => 'High-Quality Printing';

  @override
  String get pdfEditMetaPermModifyContent => 'Modifying Document Content';

  @override
  String get pdfEditMetaPermCopyExtract => 'Content Copying & Extraction';

  @override
  String get pdfEditMetaPermAnnotations => 'Adding/Modifying Annotations';

  @override
  String get pdfEditMetaPermForms => 'Filling Interactive Forms';

  @override
  String get pdfEditMetaPermAccessibility => 'Accessibility Extraction';

  @override
  String get pdfEditMetaPermAssembly => 'Document Assembly';

  @override
  String get pdfEditMetaRemovePassword => 'Remove Password & Save Copy';

  @override
  String get pdfEditMetaDoneTitle => 'Security Removal Complete';

  @override
  String pdfEditExtractTitle(String fileName) {
    return 'Extract Images: $fileName';
  }

  @override
  String pdfEditExtractSelectionCount(int selected, int total) {
    return '$selected selected / $total total';
  }

  @override
  String get pdfEditExtractHideControls => 'Hide controls';

  @override
  String get pdfEditExtractShowControls => 'Show controls';

  @override
  String get pdfEditExtractSelectAll => 'Select All';

  @override
  String get pdfEditExtractClearSelection => 'Clear Selection';

  @override
  String get pdfEditExtractDownloadSelected => 'Download Selected';

  @override
  String get pdfEditExtractDownloadAllZip => 'Download All (ZIP)';

  @override
  String get pdfEditExtractEmpty => 'No embedded images found in this PDF';

  @override
  String get pdfEditExtractScanning => 'Scanning PDF…';

  @override
  String pdfEditExtractScanningObjects(int done, int total) {
    return 'Scanning PDF objects $done of $total…';
  }

  @override
  String pdfEditExtractPreparingImages(int done, int total) {
    return 'Preparing images $done of $total…';
  }

  @override
  String pdfEditExtractImagesFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count images found',
      one: '1 image found',
    );
    return '$_temp0';
  }

  @override
  String pdfEditExtractFailed(String error) {
    return 'Image extraction failed: $error';
  }

  @override
  String pdfEditExtractCreatingZip(int done, int total) {
    return 'Creating ZIP $done of $total…';
  }

  @override
  String get pdfEditExtractZipReady => 'ZIP ready';

  @override
  String pdfEditExtractZipFailed(String error) {
    return 'ZIP export failed: $error';
  }

  @override
  String pdfEditExtractImagePageDimensions(int page, int width, int height) {
    return 'Page $page - ${width}x$height';
  }

  @override
  String pdfEditExtractImageBpp(String value) {
    return 'BPP: $value';
  }

  @override
  String pdfEditExtractImageFilter(String filter) {
    return 'Filter: $filter';
  }

  @override
  String get pdfEditExtractPreview => 'Preview';

  @override
  String get pdfNavPasswordTitle => 'Password Protected PDF';

  @override
  String pdfNavPasswordMessage(String fileName) {
    return 'Enter password for $fileName.';
  }

  @override
  String get pdfNavOpenCanceled =>
      'PDF open canceled. Select another file or try again.';

  @override
  String get pdfNavTypeLabel => 'PDFs';

  @override
  String get pdfNavDropZoneTitle => 'Open a PDF File';

  @override
  String get pdfNavDropZoneSubtitle => 'Drag & drop a .pdf file here';

  @override
  String get pdfNavDocumentFallback => 'Document';

  @override
  String get pdfNavBookmarks => 'Bookmarks';

  @override
  String get pdfNavNoBookmarks => 'No bookmarks available';

  @override
  String get pdfNavSearchText => 'Search Text';

  @override
  String get pdfNavMore => 'More';

  @override
  String get pdfNavModeView => 'View';

  @override
  String get pdfNavModePlaceSignature => 'Place Signature';

  @override
  String get pdfNavModeOrganizePages => 'Organize Pages';

  @override
  String get pdfNavModeFlattenPdf => 'Flatten PDF';

  @override
  String get pdfNavModeExtractImages => 'Extract Images';

  @override
  String get pdfNavModeExtractText => 'Extract Text';

  @override
  String pdfExtractTextTitle(String fileName) {
    return 'Extract Text: $fileName';
  }

  @override
  String pdfExtractTextProgress(int current, int total) {
    return 'Extracting text… $current/$total';
  }

  @override
  String get pdfExtractTextEmpty =>
      'No extractable text found in this PDF. It may be scanned or image-only.';

  @override
  String pdfExtractTextFailed(String error) {
    return 'Failed to extract text: $error';
  }

  @override
  String get pdfExtractTextCopy => 'Copy';

  @override
  String get pdfExtractTextCopied => 'Text copied to clipboard';

  @override
  String get pdfExtractTextSave => 'Save as .txt';

  @override
  String get pdfExtractTextAskHint => 'Ask a question about this text…';

  @override
  String get pdfExtractTextAskSend => 'Ask';

  @override
  String get pdfExtractTextThinking => 'Thinking…';

  @override
  String get pdfExtractTextTruncatedNote =>
      'Note: only the first part of the text is sent to the on-device AI.';

  @override
  String get textToolsSummarize => 'Summarize';

  @override
  String get textToolsKeywords => 'Keywords';

  @override
  String get textToolsSourceAi => 'AI answer';

  @override
  String get textToolsSourceOffline =>
      'Offline result — best-matching passages';

  @override
  String get textToolsSummaryTitle => 'Summary (offline)';

  @override
  String get textToolsKeywordsTitle => 'Keywords (offline)';

  @override
  String get genaiOfflineAnalysisActive =>
      'On-device AI unavailable — offline text analysis is active.';

  @override
  String get pdfNavModeMetadata => 'Metadata';

  @override
  String get pdfNavModeRedact => 'Redact PDF';

  @override
  String get pdfNavCloseSearch => 'Close Search';

  @override
  String get pdfNavSearchHint => 'Search text...';

  @override
  String get pdfNavPrevMatch => 'Previous Match';

  @override
  String get pdfNavNextMatch => 'Next Match';

  @override
  String get pdfNavShareFile => 'Share File';

  @override
  String get pdfNavSaveToDownloads => 'Save to Downloads';

  @override
  String pdfNavPageOf(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String pdfNavPageLoading(int current) {
    return 'Page $current...';
  }

  @override
  String get pdfNavPrevPage => 'Previous Page';

  @override
  String get pdfNavNextPage => 'Next Page';

  @override
  String get pdfNavZoomOut => 'Zoom Out';

  @override
  String get pdfNavZoomReset => 'Reset Zoom';

  @override
  String get pdfNavZoomIn => 'Zoom In';

  @override
  String pdfNavOrganizeTitle(String fileName) {
    return 'Organize: $fileName';
  }

  @override
  String get pdfNavOrganizeInsertTooltip => 'Insert pages from another PDF';

  @override
  String get pdfNavOrganizeApplyTooltip => 'Apply changes';

  @override
  String pdfNavOrganizePageCountHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return '$_temp0 - drag to reorder, tap to preview';
  }

  @override
  String get pdfNavOrganizeNoPages => 'No pages';

  @override
  String pdfViewerShareFailed(String error) {
    return 'Failed to share file: $error';
  }

  @override
  String pdfNavOrganizeLoadFailed(String error) {
    return 'Failed to load PDF: $error';
  }

  @override
  String pdfNavOrganizeOpenFailed(String error) {
    return 'Failed to open PDF: $error';
  }

  @override
  String pdfNavOrganizeReorganizeFailed(String error) {
    return 'Failed to reorganize: $error';
  }

  @override
  String get pdfNavOrganizeCannotDeleteLastPage =>
      'Cannot delete the last page';

  @override
  String get pdfNavOrganizeRemovePageTitle => 'Remove Page';

  @override
  String pdfNavOrganizeRemovePageMessage(int pageNumber) {
    return 'Remove page $pageNumber?';
  }

  @override
  String pdfNavOrganizeInsertDialogTitle(String srcName) {
    return 'Insert Pages from \"$srcName\"';
  }

  @override
  String get pdfNavOrganizeNoPagesFound => 'No pages found';

  @override
  String pdfNavOrganizePageNumber(int pageNumber) {
    return 'Page $pageNumber';
  }

  @override
  String get pdfNavOrientationPortrait => 'Portrait';

  @override
  String get pdfNavOrientationLandscape => 'Landscape';

  @override
  String get pdfNavDeselectAll => 'Deselect All';

  @override
  String get pdfNavSelectAll => 'Select All';

  @override
  String pdfNavOrganizeInsertCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Insert $count pages',
      one: 'Insert 1 page',
    );
    return '$_temp0';
  }

  @override
  String get pdfNavOrganizeComplete => 'Organizing Complete';

  @override
  String pdfNavOrganizeNewSize(String size) {
    return 'New PDF size: $size';
  }

  @override
  String get pdfNavDownload => 'Download';

  @override
  String get pdfNavOpenInViewer => 'Open in Viewer';

  @override
  String get sigAdvancedSettings => 'Advanced settings';

  @override
  String get sigTabDraw => 'Draw';

  @override
  String get sigTabSaved => 'Saved';

  @override
  String get sigSavedToDownloads => 'Signature saved to Downloads';

  @override
  String get sigCopiedToClipboard => 'Signature copied to clipboard';

  @override
  String get sigSaved => 'Signature saved';

  @override
  String get sigDeleteTitle => 'Delete signature?';

  @override
  String get sigDeleteContent => 'This signature will be removed.';

  @override
  String get sigUndo => 'Undo';

  @override
  String get sigRedo => 'Redo';

  @override
  String get sigPng => 'PNG';

  @override
  String get sigSvg => 'SVG';

  @override
  String get sigAdvanced => 'Advanced';

  @override
  String get sigReduceLines => 'Reduce lines (RDP)';

  @override
  String get sigMoveTolerance => 'Move tolerance';

  @override
  String get sigMinWidthFactor => 'Min width factor';

  @override
  String get sigMaxWidthFactor => 'Max width factor';

  @override
  String get sigVelocitySensitivity => 'Velocity sensitivity';

  @override
  String get sigVelocityInfluence => 'Velocity influence';

  @override
  String get sigPressureInfluence => 'Pressure influence';

  @override
  String get sigWidthSmoothing => 'Width smoothing';

  @override
  String get sigExportDpi => 'Export DPI';

  @override
  String get sigLoad => 'Load';

  @override
  String get widgetPasswordLabel => 'Password';

  @override
  String get widgetPasswordShow => 'Show password';

  @override
  String get widgetPasswordHide => 'Hide password';

  @override
  String widgetFileDropFailedToSelect(String error) {
    return 'Failed to select file: $error';
  }

  @override
  String widgetFileDropOnlyFilesSupported(String extensions) {
    return 'Only $extensions files are supported';
  }

  @override
  String get widgetFileDropReleaseToLoad => 'Release to load file';

  @override
  String get widgetMarkdownExportMarkdown => 'Export Markdown';

  @override
  String get widgetMarkdownExportPdf => 'Export PDF';

  @override
  String widgetMarkdownUpdated(String date) {
    return 'Updated: $date';
  }

  @override
  String get widgetMarkdownNoContent => 'No additional content';

  @override
  String get widgetMarkdownImageEnlarge => 'Tap to enlarge';

  @override
  String get widgetMarkdownFrontmatter => 'Frontmatter';

  @override
  String widgetMarkdownFrontmatterInvalid(String error) {
    return 'Invalid frontmatter YAML: $error';
  }

  @override
  String get widgetMarkdownCodeCopy => 'Copy code';

  @override
  String get widgetMarkdownCodeCopied => 'Code copied';

  @override
  String widgetMarkdownCodeLanguageAuto(String language) {
    return '$language · auto';
  }

  @override
  String get widgetMarkdownCodeCollapse => 'Collapse code';

  @override
  String get widgetMarkdownCodeExpand => 'Expand code';

  @override
  String widgetMarkdownCodeLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines',
      one: '1 line',
    );
    return '$_temp0';
  }

  @override
  String get widgetToolChooserOpenFile => 'Open File';

  @override
  String get widgetToolChooserChooseTool => 'Choose a tool to open:';

  @override
  String get widgetToolChooserAlwaysUseTool =>
      'Always use this tool for this file type';

  @override
  String get widgetShortcutHomeTitle => 'Home Screen Shortcut';

  @override
  String get widgetShortcutHomeSubtitle =>
      'Add shortcut to your home launcher screen';

  @override
  String get widgetShortcutDrawerTitle => 'App Drawer Icon';

  @override
  String get widgetShortcutDrawerSubtitle =>
      'Show separate launcher icon in App Drawer';

  @override
  String get sectionTitleSensors => 'Sensors';

  @override
  String get sectionTitleUtilities => 'Utilities';

  @override
  String get sectionTitleInfo => 'Information';

  @override
  String get toolNameCalculator => 'Calculator';

  @override
  String get toolDescCalculator => 'Basic and scientific calculations';

  @override
  String get toolNameBubbleLevel => 'Bubble Level';

  @override
  String get toolDescBubbleLevel => 'Precision spirit level using sensors';

  @override
  String get toolNameEmfDetector => 'EMF Detector';

  @override
  String get toolDescEmfDetector => 'Detect electromagnetic fields';

  @override
  String get toolNameDeviceInfo => 'Device Info';

  @override
  String get toolDescDeviceInfo => 'Battery, sensors, and system information';

  @override
  String get toolNameNfcTagLab => 'NFC Tag Lab';

  @override
  String get toolDescNfcTagLab =>
      'Scan NFC targets, decode NDEF, classify signatures, and write tags.';

  @override
  String get toolNamePdfViewer => 'PDF Viewer';

  @override
  String get toolDescPdfViewer => 'View PDF files fullscreen with ease';

  @override
  String get toolNameNotes => 'Notes';

  @override
  String get toolDescNotes =>
      'Simple note taking tool with Markdown support and backend sync';

  @override
  String get toolNameGroceryList => 'Grocery List';

  @override
  String get toolDescGroceryList =>
      'Create grocery lists with quantities, reusable items, and check-off tracking';

  @override
  String get groceryNoItems => 'No items in your grocery list';

  @override
  String get groceryAddItem => 'Add Item';

  @override
  String get groceryEditItem => 'Edit Item';

  @override
  String get groceryItemName => 'Item name';

  @override
  String get groceryAmount => 'Qty';

  @override
  String get groceryUnit => 'Unit';

  @override
  String get groceryAdd => 'Add';

  @override
  String get groceryUpdate => 'Update';

  @override
  String get groceryClearBought => 'Clear bought';

  @override
  String get groceryReAddBought => 'Re-add bought';

  @override
  String get groceryExport => 'Export';

  @override
  String get groceryImport => 'Import';

  @override
  String groceryConfirmClearBought(int count) {
    return 'Remove $count bought item(s)?';
  }

  @override
  String groceryConfirmDelete(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String groceryImportComplete(int imported, int skipped) {
    return 'Import complete! Imported: $imported, Skipped: $skipped (duplicates).';
  }

  @override
  String groceryImportFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String groceryItemsCount(int unchecked, int checked) {
    return '$unchecked to buy, $checked bought';
  }

  @override
  String get groceryAllBoughtMovedBack =>
      'All bought items moved back to list.';

  @override
  String get grocerySync => 'Sync';

  @override
  String get toolNameMarkdownViewer => 'Markdown Viewer';

  @override
  String get toolDescMarkdownViewer =>
      'View Markdown files fullscreen with ease';

  @override
  String get toolNameImageViewer => 'Image Viewer';

  @override
  String get toolDescImageViewer =>
      'View, zoom, resize, and convert image formats';

  @override
  String get toolNameFastDrop => 'Fast Drop';

  @override
  String get toolDescFastDrop =>
      'Quickly drop files or paste clipboard data to the server for temporary storage and sharing';

  @override
  String get toolNameImagesToPdf => 'Images to PDF';

  @override
  String get toolDescImagesToPdf =>
      'Convert multiple images into a single PDF document';

  @override
  String get toolNameChiptune => 'Chiptune Player';

  @override
  String get toolDescChiptune => 'Play tracker modules and audio files';

  @override
  String get toolNameFocusNoise => 'Focus Noise & Breathing';

  @override
  String get toolDescFocusNoise =>
      'Ambient noise player with guided breathing patterns';

  @override
  String get toolNameSignatures => 'Signature Creator';

  @override
  String get toolDescSignatures =>
      'Draw signatures and export them as transparent PNG or SVG';

  @override
  String get toolNameQrCode => 'QR Code';

  @override
  String get toolDescQrCode =>
      'Scan QR codes with the camera or an image, and create your own';

  @override
  String get qrTabScan => 'Scan';

  @override
  String get qrTabCreate => 'Create';

  @override
  String get qrModeCamera => 'Camera';

  @override
  String get qrModeImage => 'Image';

  @override
  String get qrScannerEngineZxing => 'ZXing';

  @override
  String get qrScannerEngineMlKit => 'ML Kit';

  @override
  String get qrCameraZoom => 'Zoom';

  @override
  String get qrCameraTorch => 'Flashlight';

  @override
  String get qrImagesLabel => 'Images';

  @override
  String get qrScanDropTitle => 'Scan a QR code from an image';

  @override
  String get qrScanDropSubtitle => 'Drop an image here, or browse to pick one';

  @override
  String get qrBrowseImage => 'Browse image';

  @override
  String get qrPasteImage => 'Paste image';

  @override
  String get qrPickFromGallery => 'Pick from gallery';

  @override
  String get qrNoCodeFound => 'No QR code found in the image';

  @override
  String get qrNoImageInClipboard => 'No image in the clipboard';

  @override
  String get qrScanAgain => 'Scan again';

  @override
  String get qrResultOpen => 'Open';

  @override
  String get qrActionCopy => 'Copy';

  @override
  String get qrActionShare => 'Share';

  @override
  String get qrCopied => 'Copied to clipboard';

  @override
  String get qrOpenFailed => 'Could not open this content';

  @override
  String get qrKindLink => 'Link';

  @override
  String get qrKindWifi => 'Wi-Fi network';

  @override
  String get qrKindEmail => 'Email';

  @override
  String get qrKindPhone => 'Phone number';

  @override
  String get qrKindSms => 'SMS';

  @override
  String get qrKindLocation => 'Location';

  @override
  String get qrKindContact => 'Contact';

  @override
  String get qrKindText => 'Text';

  @override
  String get qrKindFido => 'Passkey Request';

  @override
  String get qrKindOtp => '2FA / Authenticator';

  @override
  String get qrKindMath => 'Mathematical Expression';

  @override
  String get qrKindCoordinate => 'Coordinates';

  @override
  String get qrKindNumber => 'Numeric Value';

  @override
  String get qrResultFulfillPasskey => 'Fulfill Passkey';

  @override
  String get qrResultOpenAuthenticator => 'Add to Authenticator';

  @override
  String get qrResultCalculate => 'Calculate';

  @override
  String get qrResultShowOnMap => 'Show on Map';

  @override
  String get qrResultConvertUnit => 'Convert Unit';

  @override
  String get qrResultUseInCalc => 'Use in Calculator';

  @override
  String get qrResultSimulatePasskey => 'Simulate Passkey';

  @override
  String get qrPasskeySimTitle => 'Passkey Simulator';

  @override
  String get qrPasskeySimSuccess =>
      'Mock Passkey successfully signed the request!';

  @override
  String get qrPasskeySimPrompt =>
      'Confirm biometric fingerprint or PIN to authorize authentication.';

  @override
  String get qrPasskeySimUser => 'User: alice@example.com';

  @override
  String get qrPasskeySimDomain => 'Domain: secure.login';

  @override
  String get qrTypeText => 'Text';

  @override
  String get qrTypeUrl => 'URL';

  @override
  String get qrTypeWifi => 'Wi-Fi';

  @override
  String get qrTypeEmail => 'Email';

  @override
  String get qrTypePhone => 'Phone';

  @override
  String get qrTypeSms => 'SMS';

  @override
  String get qrTypeGeo => 'Location';

  @override
  String get qrTypeVcard => 'Contact';

  @override
  String get qrFieldText => 'Text';

  @override
  String get qrFieldUrl => 'URL';

  @override
  String get qrFieldSsid => 'Network name (SSID)';

  @override
  String get qrFieldPassword => 'Password';

  @override
  String get qrFieldEncryption => 'Encryption';

  @override
  String get qrFieldHidden => 'Hidden network';

  @override
  String get qrEncWpa => 'WPA/WPA2';

  @override
  String get qrEncWep => 'WEP';

  @override
  String get qrEncNone => 'None';

  @override
  String get qrFieldEmail => 'Email address';

  @override
  String get qrFieldSubject => 'Subject';

  @override
  String get qrFieldBody => 'Message';

  @override
  String get qrFieldPhone => 'Phone number';

  @override
  String get qrFieldMessage => 'Message';

  @override
  String get qrFieldLatitude => 'Latitude';

  @override
  String get qrFieldLongitude => 'Longitude';

  @override
  String get qrFieldName => 'Full name';

  @override
  String get qrFieldOrganization => 'Organization';

  @override
  String get qrCreatePlaceholder => 'Fill in the fields to generate a QR code';

  @override
  String get qrEncodeFailed => 'Content is too long to encode as a QR code';

  @override
  String get qrActionSave => 'Save';

  @override
  String get qrActionCopyImage => 'Copy image';

  @override
  String get qrImageCopied => 'QR image copied to clipboard';

  @override
  String get qrCopyImageFailed => 'Could not copy the QR image';

  @override
  String get qrSavedToDownloads => 'QR code saved to Downloads folder';

  @override
  String qrSavedTo(String path) {
    return 'QR code saved to $path';
  }

  @override
  String qrSaveFailed(String error) {
    return 'Failed to save QR code: $error';
  }

  @override
  String get toolNameDocumentScanner => 'Document Scanner';

  @override
  String get toolDescDocumentScanner =>
      'Scan documents via camera, adjust crop/skew, apply filters, and compile to PDF';

  @override
  String get docScanNoPages => 'No scanned pages yet';

  @override
  String get docScanAddHint => 'Add pages using the camera or gallery';

  @override
  String docScanPageTitle(int number) {
    return 'Page $number';
  }

  @override
  String docScanFilterLabel(String filter) {
    return 'Filter: $filter';
  }

  @override
  String docScanRotationLabel(int rotation) {
    return 'Rot: $rotation°';
  }

  @override
  String docScanSizeLabel(int width, int height) {
    return 'Size: ${width}x$height';
  }

  @override
  String docScanEditPageTitle(int number) {
    return 'Edit Page $number';
  }

  @override
  String get docScanRotateL => 'Rotate L';

  @override
  String get docScanRotateR => 'Rotate R';

  @override
  String get docScanCropWarp => 'Crop & Warp';

  @override
  String get docScanFiltersHeading => 'Filters';

  @override
  String get docScanFilterOriginal => 'Original';

  @override
  String get docScanFilterGrayscale => 'Grayscale';

  @override
  String get docScanFilterBw => 'B&W';

  @override
  String get docScanFilterClean => 'Clean Doc';

  @override
  String get docScanClearTitle => 'Clear All Pages';

  @override
  String get docScanClearMessage =>
      'Are you sure you want to delete all scanned pages? This cannot be undone.';

  @override
  String get docScanClearConfirm => 'Delete All';

  @override
  String get docScanActionScan => 'Scan Page';

  @override
  String get docScanActionGallery => 'Import from Gallery';

  @override
  String get docScanActionSave => 'Save PDF Document';

  @override
  String get docScanGeneratingPdf => 'Generating PDF Document...';

  @override
  String docScanSavedPdf(String path) {
    return 'PDF saved to $path';
  }

  @override
  String docScanFailedPdf(String error) {
    return 'Failed to save PDF: $error';
  }

  @override
  String docScanFailedCreate(String error) {
    return 'PDF creation failed: $error';
  }

  @override
  String docScanFailedCamera(String error) {
    return 'Camera capture failed: $error';
  }

  @override
  String docScanFailedGallery(String error) {
    return 'Failed to pick image: $error';
  }

  @override
  String get docScanCropReset => 'Reset to Full';

  @override
  String get docScanCropUndo => 'Undo';

  @override
  String get docScanCropApply => 'Apply';

  @override
  String get docScanCropCancel => 'Cancel';

  @override
  String get docScanActionScanMlKit => 'Scan Page (ML Kit)';

  @override
  String get docScanActionScanStandard => 'Scan Page (Standard)';

  @override
  String get docScanMethodTitle => 'Select Scan Method';

  @override
  String docScanFailedMlKit(String error) {
    return 'ML Kit scan failed: $error';
  }

  @override
  String get docScanMlKitUnavailableFallback =>
      'Document scanner unavailable, using the camera instead.';

  @override
  String get toolNameGpsLocationStore => 'GPS Location Store';

  @override
  String get toolDescGpsLocationStore =>
      'Capture and store your current location with notes and map links';

  @override
  String get gpsStoreLocateButton => 'Show current location';

  @override
  String get gpsStoreCurrentTitle => 'Current location';

  @override
  String get gpsStoreSaveThis => 'Save this location';

  @override
  String get gpsStoreLastSavedTitle => 'Last saved location';

  @override
  String get gpsStoreHistoryTitle => 'History';

  @override
  String get gpsStoreOpenGoogleMaps => 'Google Maps';

  @override
  String get gpsStoreOpenOsm => 'OpenStreetMap';

  @override
  String get gpsStoreSourceGps => 'GPS';

  @override
  String get gpsStoreSourceApproxIp => 'Approx (IP)';

  @override
  String gpsStoreAccuracyMeters(int meters) {
    return '±$meters m';
  }

  @override
  String get gpsStoreSaveLocationTitle => 'Save location';

  @override
  String get gpsStoreEditDescription => 'Edit description';

  @override
  String get gpsStoreDescriptionLabel => 'Description';

  @override
  String get gpsStoreDescriptionHint => 'Add a short note (optional)';

  @override
  String get gpsStoreIpFallbackNote =>
      'Precise GPS was unavailable — this is an approximate position based on your IP address.';

  @override
  String get gpsStoreLocationSaved => 'Location saved';

  @override
  String get gpsStoreCaptureFailed =>
      'Could not determine a location. Check location permissions and connectivity.';

  @override
  String get gpsStoreDeleteTitle => 'Delete location';

  @override
  String get gpsStoreDeleteMessage =>
      'This location will be permanently removed.';

  @override
  String get gpsStoreEmptyTitle => 'No locations yet';

  @override
  String get gpsStoreEmptyMessage =>
      'Tap \"Show current location\" to find where you are, then save it.';

  @override
  String get gpsStoreDistanceFromHere =>
      'Distance and direction from your current position';

  @override
  String get gpsStoreCompassN => 'N';

  @override
  String get gpsStoreCompassNE => 'NE';

  @override
  String get gpsStoreCompassE => 'E';

  @override
  String get gpsStoreCompassSE => 'SE';

  @override
  String get gpsStoreCompassS => 'S';

  @override
  String get gpsStoreCompassSW => 'SW';

  @override
  String get gpsStoreCompassW => 'W';

  @override
  String get gpsStoreCompassNW => 'NW';

  @override
  String get gpsInfoButtonTooltip => 'GPS Hardware Details';

  @override
  String get gpsInfoTitle => 'GPS & Satellite Info';

  @override
  String get gpsInfoLatitude => 'Latitude';

  @override
  String get gpsInfoLongitude => 'Longitude';

  @override
  String get gpsInfoAltitude => 'Altitude';

  @override
  String get gpsInfoSpeed => 'Speed';

  @override
  String get gpsInfoHeading => 'Heading';

  @override
  String get gpsInfoAccuracy => 'Accuracy';

  @override
  String get gpsInfoTimestamp => 'Last Fix Time';

  @override
  String get gpsInfoProvider => 'Source Provider';

  @override
  String get gpsInfoMocked => 'Mocked Location';

  @override
  String get gpsInfoPositionDetails => 'Current Position Data';

  @override
  String get gpsInfoHardwareDetails => 'GNSS Constellations & Hardware';

  @override
  String get gpsInfoSatelliteCount => 'Visible Satellites';

  @override
  String get gpsInfoSatelliteCountUsed => 'Satellites Used in Fix';

  @override
  String get gpsInfoLocationProviders => 'System Location Providers';

  @override
  String get gpsInfoConstellationGps => 'GPS (USA)';

  @override
  String get gpsInfoConstellationGlonass => 'GLONASS (Russia)';

  @override
  String get gpsInfoConstellationGalileo => 'Galileo (EU)';

  @override
  String get gpsInfoConstellationBeidou => 'BeiDou (China)';

  @override
  String get gpsInfoConstellationQzss => 'QZSS (Japan)';

  @override
  String get gpsInfoConstellationSbas => 'SBAS';

  @override
  String get gpsInfoConstellationIrnss => 'NavIC / IRNSS (India)';

  @override
  String get gpsInfoConstellationUnknown => 'Unknown Constellation';

  @override
  String get gpsInfoStatusScanning => 'Acquiring satellite signals...';

  @override
  String get gpsInfoStatusNotAvailable =>
      'Satellite status not supported on this platform.';

  @override
  String get gpsInfoSatelliteList => 'Satellite Details';

  @override
  String gpsInfoSatelliteSvid(int svid) {
    return 'SVID: $svid';
  }

  @override
  String gpsInfoSatelliteCn0(double cn0) {
    return 'SNR: $cn0 dB-Hz';
  }

  @override
  String get gpsInfoSatelliteUsed => 'Used in Fix';

  @override
  String gpsInfoSatelliteElevation(double elevation) {
    return 'El: $elevation°';
  }

  @override
  String gpsInfoSatelliteAzimuth(double azimuth) {
    return 'Az: $azimuth°';
  }

  @override
  String get gpsInfoProviderEnabled => 'Enabled';

  @override
  String get gpsInfoProviderDisabled => 'Disabled';

  @override
  String get toolNameChatAi => 'AI Chat';

  @override
  String get toolDescChatAi =>
      'Chat with on-device AI model Gemini Nano using ML Kit';

  @override
  String get chatAiUnsupportedPlatform =>
      'On-device AI Chat is only supported on Android. Desktop and iOS platforms are not supported by the ML Kit GenAI Prompt API.';

  @override
  String get chatAiNewChat => 'New Chat';

  @override
  String chatAiModelStatus(String status) {
    return 'Model Status: $status';
  }

  @override
  String get chatAiModelLoading =>
      'Downloading model... This may take a while.';

  @override
  String get chatAiModelReady => 'Model ready';

  @override
  String get chatAiModelNotDownloaded =>
      'Model not downloaded. Tap Download to start.';

  @override
  String get chatAiDownloadButton => 'Download Model';

  @override
  String get chatAiInputPlaceholder => 'Type a message...';

  @override
  String get chatAiDeleteSession => 'Delete Session';

  @override
  String get chatAiDeleteSessionConfirm =>
      'Are you sure you want to delete this chat session and all its messages?';

  @override
  String get chatAiAttachImage => 'Attach Image';

  @override
  String get chatAiAttachDocument => 'Attach Document';

  @override
  String get chatAiAttachTooltip => 'Attach file or image';

  @override
  String get chatAiPrepareButton => 'Prepare AI Core';

  @override
  String get chatAiClearHistory => 'Clear History';

  @override
  String get chatAiClearHistoryConfirm =>
      'Are you sure you want to clear all messages in this chat?';

  @override
  String get chatAiThinking => 'Thinking...';

  @override
  String get chatAiSystemPromptTitle => 'System Prompt';

  @override
  String get chatAiSystemPromptDescription =>
      'Customize the instructions for the AI model. Leave empty to use the default.';

  @override
  String get toolNameHexEditor => 'Hex Editor';

  @override
  String get toolDescHexEditor =>
      'Inspect and edit files in hexadecimal and ASCII views';

  @override
  String get hexEditorTypeLabel => 'Any file';

  @override
  String get hexEditorOpenTitle => 'Open any file';

  @override
  String get hexEditorDropSubtitle => 'Drop any file here';

  @override
  String get hexEditorStringsTitle => 'Printable Strings';

  @override
  String get hexEditorMinLength => 'Minimum Length';

  @override
  String get hexEditorScan => 'Scan';

  @override
  String get hexEditorScanning => 'Scanning...';

  @override
  String hexEditorScannedBytes(String scanned, String total) {
    return 'Scanned $scanned / $total bytes';
  }

  @override
  String hexEditorFoundStrings(int count) {
    return 'Found $count strings';
  }

  @override
  String get hexEditorCancelled => 'Cancelled';

  @override
  String get hexEditorNoStringsFound => 'No strings found';

  @override
  String get hexEditorExportStarted => 'Export started';

  @override
  String hexEditorExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String hexEditorFailedToLoad(String error) {
    return 'Failed to load file: $error';
  }

  @override
  String get hexEditorOffset => 'Offset';

  @override
  String hexEditorSize(String size) {
    return 'Size: $size bytes';
  }

  @override
  String get hexEditorSearchType => 'Search type';

  @override
  String get hexEditorSearchHex => 'Hexadecimal';

  @override
  String get hexEditorSearchText => 'Text';

  @override
  String get hexEditorSearchPlaceholder => 'Search pattern';

  @override
  String get hexEditorShowAscii => 'Show ASCII View';

  @override
  String get hexEditorReset => 'Reset';

  @override
  String get hexEditorStringsTooltip => 'Strings';

  @override
  String get hexEditorSearchNext => 'Next Match';

  @override
  String get hexEditorSearchPrev => 'Prev Match';

  @override
  String get hexEditorInvalidHex => 'Invalid hex pattern';

  @override
  String get hexEditorHexLengthEven => 'Hex search must be even length';

  @override
  String get hexEditorPatternNotFound => 'Pattern not found';

  @override
  String hexEditorEditByteTitle(String offset) {
    return 'Edit Byte at $offset';
  }

  @override
  String get hexEditorEditByteHex => 'Hex';

  @override
  String get hexEditorEditByteAscii => 'ASCII';

  @override
  String get hexEditorSave => 'Save';

  @override
  String get hexEditorDiscardChangesTitle => 'Discard changes?';

  @override
  String get hexEditorDiscardChangesMessage =>
      'Do you want to discard your modifications?';

  @override
  String get hexEditorKeepEditing => 'Keep editing';

  @override
  String get hexEditorDiscard => 'Discard';

  @override
  String get toolNameFileConverter => 'File Converter';

  @override
  String get toolDescFileConverter =>
      'Convert documents between DOCX, PDF, HTML, Markdown and text';

  @override
  String get fileConverterTypeLabel => 'Documents';

  @override
  String get fileConverterOpenTitle => 'Open a document';

  @override
  String get fileConverterDropSubtitle =>
      'Drop a DOCX, PDF, HTML, Markdown or text file here';

  @override
  String get fileConverterConvertTo => 'Convert to';

  @override
  String get fileConverterConvert => 'Convert';

  @override
  String get fileConverterConverting => 'Converting…';

  @override
  String get fileConverterUnsupported => 'This file type can\'t be converted';

  @override
  String fileConverterError(String error) {
    return 'Conversion failed: $error';
  }

  @override
  String get fileConverterFormatDocx => 'Word (DOCX)';

  @override
  String get fileConverterFormatPdf => 'PDF';

  @override
  String get fileConverterFormatHtml => 'HTML';

  @override
  String get fileConverterFormatMd => 'Markdown';

  @override
  String get fileConverterFormatTxt => 'Plain text';

  @override
  String get toolNameSketchBoard => 'Sketch Board';

  @override
  String get toolDescSketchBoard =>
      'Infinite-canvas whiteboard with freehand, shapes, text and saved drawings';

  @override
  String get sketchTabDraw => 'Draw';

  @override
  String get sketchTabSaved => 'Saved';

  @override
  String get sketchToolSelect => 'Select';

  @override
  String get sketchToolPan => 'Pan';

  @override
  String get sketchToolPen => 'Pen';

  @override
  String get sketchToolLine => 'Line';

  @override
  String get sketchToolArrow => 'Arrow';

  @override
  String get sketchToolRect => 'Rectangle';

  @override
  String get sketchToolEllipse => 'Ellipse';

  @override
  String get sketchToolDiamond => 'Diamond';

  @override
  String get sketchToolTriangle => 'Triangle';

  @override
  String get sketchToolHexagon => 'Hexagon';

  @override
  String get sketchToolDoubleArrow => 'Double arrow';

  @override
  String get sketchToolSpeechBubble => 'Speech bubble';

  @override
  String get sketchToolCheckmark => 'Checkmark';

  @override
  String get sketchToolText => 'Text';

  @override
  String get sketchPropStroke => 'Stroke';

  @override
  String get sketchPropFill => 'Fill';

  @override
  String get sketchPropWidth => 'Width';

  @override
  String get sketchPropText => 'Text';

  @override
  String get sketchEmptyHint => 'Pick a tool and start drawing';

  @override
  String get sketchGalleryEmpty => 'No drawings saved yet.';

  @override
  String sketchElementCount(int count) {
    return '$count elements';
  }

  @override
  String get sketchTextTitle => 'Add text';

  @override
  String get sketchTextHint => 'Type text…';

  @override
  String get sketchSaveTitle => 'Save drawing';

  @override
  String get sketchSaveHint => 'Drawing name';

  @override
  String sketchDefaultName(String date) {
    return 'Drawing $date';
  }

  @override
  String get sketchSaved => 'Drawing saved';

  @override
  String get sketchNothingToExport => 'Nothing to draw yet';

  @override
  String get sketchExportTitle => 'Export image';

  @override
  String get sketchExportFormat => 'Format';

  @override
  String get sketchExportQuality => 'Quality';

  @override
  String get sketchExportLossless => 'PNG is lossless — no quality setting.';

  @override
  String get sketchExportResolution => 'Resolution';

  @override
  String get sketchExportEstimatedSize => 'Estimated size';

  @override
  String get sketchCopied => 'Copied to clipboard';

  @override
  String get sketchDeleteTitle => 'Delete drawing';

  @override
  String get sketchDeleteContent =>
      'This will permanently remove the saved drawing.';

  @override
  String get sketchClearTitle => 'Clear canvas';

  @override
  String get sketchClearContent => 'Remove everything from the canvas?';

  @override
  String get sketchBackgroundTitle => 'Background';

  @override
  String get sketchBgCheckerboard => 'Checkerboard';

  @override
  String get sketchBgWhite => 'White';

  @override
  String get sketchBgBlack => 'Black';

  @override
  String get sketchMenuBackground => 'Background';

  @override
  String get sketchMenuResetView => 'Reset view';

  @override
  String get sketchUndo => 'Undo';

  @override
  String get sketchRedo => 'Redo';

  @override
  String get sketchToolShapes => 'Shapes';

  @override
  String get sketchColorTitle => 'Color';

  @override
  String get sketchColorOpacity => 'Opacity';

  @override
  String get sketchDiscardTitle => 'Discard changes?';

  @override
  String get sketchDiscardMessage => 'You have unsaved changes. Discard them?';

  @override
  String get sketchDiscard => 'Discard';

  @override
  String get sketchKeepEditing => 'Keep editing';

  @override
  String get sketchBringToFront => 'Bring to front';

  @override
  String get sketchSendToBack => 'Send to back';

  @override
  String get sketchGroup => 'Group';

  @override
  String get sketchUngroup => 'Ungroup';

  @override
  String get sketchResetRotation => 'Reset rotation';

  @override
  String get sketchInsertImage => 'Insert image';

  @override
  String get sketchPasteImage => 'Paste image';

  @override
  String get sketchNoClipboardImage => 'No image in clipboard';

  @override
  String get sketchPropBrush => 'Brush';

  @override
  String get sketchBrushNormal => 'Normal';

  @override
  String get sketchBrushShaky => 'Shaky';

  @override
  String get sketchBrushNatural => 'Natural';

  @override
  String get sketchSelectBox => 'Box select';

  @override
  String get sketchSelectLasso => 'Lasso select';

  @override
  String get sketchResetImageSize => 'Reset image size';

  @override
  String get sketchMenuInfo => 'Board info';

  @override
  String get sketchInfoTitle => 'Sketch Board Information';

  @override
  String get sketchInfoViewportSize => 'Viewport Size';

  @override
  String get sketchInfoContentBounds => 'Content Dimensions';

  @override
  String get sketchInfoTotalElements => 'Total Elements';

  @override
  String get sketchInfoZoomLevel => 'Zoom Level';

  @override
  String get sketchInfoElementsBreakdown => 'Elements Breakdown';

  @override
  String get sketchInfoPenElements => 'Pen Elements';

  @override
  String get sketchInfoShapeElements => 'Shape Elements';

  @override
  String get sketchInfoTextElements => 'Text Elements';

  @override
  String get sketchInfoImageElements => 'Image Elements';

  @override
  String get sketchInfoGroupElements => 'Group Elements';

  @override
  String get sketchInfoViewOffset => 'Camera Position';

  @override
  String get sketchInfoUnsavedChanges => 'Unsaved Changes';

  @override
  String get toolNameUnitConverter => 'Unit Converter';

  @override
  String get toolDescUnitConverter =>
      'Convert between units across many categories';

  @override
  String get ucFrom => 'From';

  @override
  String get ucTo => 'To';

  @override
  String get ucSwap => 'Swap units';

  @override
  String get ucCopyResult => 'Copy result';

  @override
  String get ucCopied => 'Copied to clipboard';

  @override
  String get ucValueHint => 'Enter value';

  @override
  String get ucAllUnits => 'All units';

  @override
  String get ucCatLength => 'Length';

  @override
  String get ucCatMass => 'Mass';

  @override
  String get ucCatTemperature => 'Temperature';

  @override
  String get ucCatArea => 'Area';

  @override
  String get ucCatVolume => 'Volume';

  @override
  String get ucCatSpeed => 'Speed';

  @override
  String get ucCatTime => 'Time';

  @override
  String get ucCatData => 'Data';

  @override
  String get ucCatPressure => 'Pressure';

  @override
  String get ucCatEnergy => 'Energy';

  @override
  String get ucCatPower => 'Power';

  @override
  String get ucCatAngle => 'Angle';

  @override
  String get ucCatFrequency => 'Frequency';

  @override
  String get ucCatDataRate => 'Data Rate';

  @override
  String get ucCatFuel => 'Fuel Economy';

  @override
  String get ucuMeter => 'Meter';

  @override
  String get ucuKilometer => 'Kilometer';

  @override
  String get ucuCentimeter => 'Centimeter';

  @override
  String get ucuMillimeter => 'Millimeter';

  @override
  String get ucuMile => 'Mile';

  @override
  String get ucuYard => 'Yard';

  @override
  String get ucuFoot => 'Foot';

  @override
  String get ucuInch => 'Inch';

  @override
  String get ucuKilogram => 'Kilogram';

  @override
  String get ucuGram => 'Gram';

  @override
  String get ucuMilligram => 'Milligram';

  @override
  String get ucuMetricTon => 'Metric ton';

  @override
  String get ucuPound => 'Pound';

  @override
  String get ucuOunce => 'Ounce';

  @override
  String get ucuStone => 'Stone';

  @override
  String get ucuUsTon => 'US ton';

  @override
  String get ucuCelsius => 'Celsius';

  @override
  String get ucuFahrenheit => 'Fahrenheit';

  @override
  String get ucuKelvin => 'Kelvin';

  @override
  String get ucuRankine => 'Rankine';

  @override
  String get ucuSquareMeter => 'Square meter';

  @override
  String get ucuSquareKilometer => 'Square kilometer';

  @override
  String get ucuSquareCentimeter => 'Square centimeter';

  @override
  String get ucuHectare => 'Hectare';

  @override
  String get ucuSquareMile => 'Square mile';

  @override
  String get ucuAcre => 'Acre';

  @override
  String get ucuSquareFoot => 'Square foot';

  @override
  String get ucuLiter => 'Liter';

  @override
  String get ucuMilliliter => 'Milliliter';

  @override
  String get ucuCubicMeter => 'Cubic meter';

  @override
  String get ucuGallonUs => 'Gallon (US)';

  @override
  String get ucuQuartUs => 'Quart (US)';

  @override
  String get ucuPintUs => 'Pint (US)';

  @override
  String get ucuCupUs => 'Cup (US)';

  @override
  String get ucuFluidOunceUs => 'Fluid ounce (US)';

  @override
  String get ucuMeterPerSecond => 'Meter per second';

  @override
  String get ucuKilometerPerHour => 'Kilometer per hour';

  @override
  String get ucuMilePerHour => 'Mile per hour';

  @override
  String get ucuFootPerSecond => 'Foot per second';

  @override
  String get ucuKnot => 'Knot';

  @override
  String get ucuMach => 'Mach';

  @override
  String get ucuSecond => 'Second';

  @override
  String get ucuMillisecond => 'Millisecond';

  @override
  String get ucuMinute => 'Minute';

  @override
  String get ucuHour => 'Hour';

  @override
  String get ucuDay => 'Day';

  @override
  String get ucuWeek => 'Week';

  @override
  String get ucuMonth => 'Month';

  @override
  String get ucuYear => 'Year';

  @override
  String get ucuByte => 'Byte';

  @override
  String get ucuKilobyte => 'Kilobyte';

  @override
  String get ucuMegabyte => 'Megabyte';

  @override
  String get ucuGigabyte => 'Gigabyte';

  @override
  String get ucuTerabyte => 'Terabyte';

  @override
  String get ucuKibibyte => 'Kibibyte';

  @override
  String get ucuMebibyte => 'Mebibyte';

  @override
  String get ucuGibibyte => 'Gibibyte';

  @override
  String get ucuBit => 'Bit';

  @override
  String get ucuMegabit => 'Megabit';

  @override
  String get ucuPascal => 'Pascal';

  @override
  String get ucuKilopascal => 'Kilopascal';

  @override
  String get ucuBar => 'Bar';

  @override
  String get ucuMillibar => 'Millibar';

  @override
  String get ucuAtmosphere => 'Atmosphere';

  @override
  String get ucuTorr => 'Torr';

  @override
  String get ucuPsi => 'Pounds per square inch';

  @override
  String get ucuMmhg => 'Millimeter of mercury';

  @override
  String get ucuJoule => 'Joule';

  @override
  String get ucuKilojoule => 'Kilojoule';

  @override
  String get ucuCalorie => 'Calorie';

  @override
  String get ucuKilocalorie => 'Kilocalorie';

  @override
  String get ucuWattHour => 'Watt hour';

  @override
  String get ucuKilowattHour => 'Kilowatt hour';

  @override
  String get ucuElectronvolt => 'Electronvolt';

  @override
  String get ucuBtu => 'British thermal unit';

  @override
  String get ucuWatt => 'Watt';

  @override
  String get ucuKilowatt => 'Kilowatt';

  @override
  String get ucuMegawatt => 'Megawatt';

  @override
  String get ucuMilliwatt => 'Milliwatt';

  @override
  String get ucuHorsepower => 'Horsepower';

  @override
  String get ucuMetricHorsepower => 'Metric horsepower';

  @override
  String get ucuDegree => 'Degree';

  @override
  String get ucuRadian => 'Radian';

  @override
  String get ucuGradian => 'Gradian';

  @override
  String get ucuArcminute => 'Arcminute';

  @override
  String get ucuArcsecond => 'Arcsecond';

  @override
  String get ucuTurn => 'Turn';

  @override
  String get ucuHertz => 'Hertz';

  @override
  String get ucuKilohertz => 'Kilohertz';

  @override
  String get ucuMegahertz => 'Megahertz';

  @override
  String get ucuGigahertz => 'Gigahertz';

  @override
  String get ucuRpm => 'Revolutions per minute';

  @override
  String get ucuBitPerSecond => 'Bit per second';

  @override
  String get ucuKilobitPerSecond => 'Kilobit per second';

  @override
  String get ucuMegabitPerSecond => 'Megabit per second';

  @override
  String get ucuGigabitPerSecond => 'Gigabit per second';

  @override
  String get ucuBytePerSecond => 'Byte per second';

  @override
  String get ucuKilobytePerSecond => 'Kilobyte per second';

  @override
  String get ucuMegabytePerSecond => 'Megabyte per second';

  @override
  String get ucuGigabytePerSecond => 'Gigabyte per second';

  @override
  String get ucuKmPerLiter => 'Kilometers per liter';

  @override
  String get ucuLiterPer100km => 'Liters per 100 km';

  @override
  String get ucuMpgUs => 'Miles per gallon (US)';

  @override
  String get ucuMpgUk => 'Miles per gallon (UK)';

  @override
  String get focusBreathingBox => 'Box 4-4-4-4';

  @override
  String get focusBreathingRelax => 'Relax 4-7-8';

  @override
  String get focusBreathingCalm => 'Calm 5-5';

  @override
  String get focusBreathingInhale => 'Inhale';

  @override
  String get focusBreathingHold => 'Hold';

  @override
  String get focusBreathingExhale => 'Exhale';

  @override
  String get focusReady => 'Ready';

  @override
  String get hexEditorModified => 'MODIFIED';

  @override
  String get sketchCopyFailed => 'Copy to clipboard failed';

  @override
  String sketchExportLabelImage(String format) {
    return '$format image';
  }

  @override
  String get sketchImageLabel => 'Image';

  @override
  String get sigPngImage => 'PNG image';

  @override
  String get sigSvgImage => 'SVG image';

  @override
  String get sigCopyFailed => 'Copy to clipboard failed';

  @override
  String get chatAiDocumentsLabel => 'Documents';

  @override
  String get toolNameCodeHighlight => 'Code Highlight & Edit';

  @override
  String get toolDescCodeHighlight => 'Highlight syntax and edit code files';

  @override
  String get codeHighlightPasteCode => 'Paste Code';

  @override
  String get codeHighlightLoadFile => 'Load File';

  @override
  String get codeHighlightLanguage => 'Language';

  @override
  String get codeHighlightTheme => 'Theme';

  @override
  String get codeHighlightEditorTitle => 'Code Editor';

  @override
  String get codeHighlightEmptyText =>
      'Paste code or drop a file here to get started';

  @override
  String codeHighlightFailedToLoad(String error) {
    return 'Failed to load code: $error';
  }

  @override
  String get codeHighlightCopied => 'Code copied to clipboard';

  @override
  String codeHighlightFailedToCopy(String error) {
    return 'Failed to copy code: $error';
  }

  @override
  String get codeHighlightTypeLabel => 'Text or source code files';

  @override
  String get codeHighlightOpenTitle => 'Open code file';

  @override
  String get codeHighlightDropSubtitle => 'Drop file here or click to choose';

  @override
  String get codeHighlightOpenInViewer => 'Open in Code Highlighter';

  @override
  String get codeHighlightThemeLight => 'Light Theme';

  @override
  String get codeHighlightThemeDark => 'Dark Theme';

  @override
  String get codeHighlightExportTitle => 'Export Option';

  @override
  String get codeHighlightExportText => 'Export as Raw Text File';

  @override
  String get codeHighlightExportImage => 'Export as Colored Image';

  @override
  String get codeHighlightSaveImage => 'Save Image';

  @override
  String get codeHighlightCopyImage => 'Copy Image';

  @override
  String get codeHighlightCopiedImage => 'Image copied to clipboard';

  @override
  String codeHighlightFailedToCopyImage(String error) {
    return 'Failed to copy image: $error';
  }

  @override
  String get codeHighlightFormat => 'Format';

  @override
  String codeHighlightFailedToSaveImage(String error) {
    return 'Failed to save image: $error';
  }

  @override
  String get codeHighlightExportWarningTitle => 'Large Image Warning';

  @override
  String codeHighlightExportWarningMessage(int lines) {
    return 'This file contains $lines lines. Exporting very long code files as an image may fail to render due to memory limits, or the text might be too small to be readable. We recommend exporting as a raw text file instead.';
  }

  @override
  String get toolNameBluetoothScanner => 'Bluetooth Scanner';

  @override
  String get toolDescBluetoothScanner =>
      'Scan for nearby Bluetooth Low Energy devices and identify them.';

  @override
  String get bleStartScan => 'Start Scan';

  @override
  String get bleStopScan => 'Stop';

  @override
  String get bleStartScanning =>
      'Start scanning to discover nearby BLE devices';

  @override
  String get bleNoDevicesFound => 'No devices found';

  @override
  String get bleClearHistory => 'Clear History';

  @override
  String get bleFilterHighConfidence => 'High Confidence';

  @override
  String get bleFilterBeacons => 'Beacons';

  @override
  String get bleFilterUnknown => 'Unknown';

  @override
  String get bleFilterRecent => 'Recent';

  @override
  String get bleFilterStrongSignal => 'Strong Signal';

  @override
  String get bleBluetoothOff => 'Bluetooth Off';

  @override
  String bleDeviceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count devices',
      one: '1 device',
    );
    return '$_temp0';
  }

  @override
  String get bleCategoryAudio => 'Audio';

  @override
  String get bleCategoryWearables => 'Wearables';

  @override
  String get bleCategoryHealth => 'Health';

  @override
  String get bleCategoryFitness => 'Fitness';

  @override
  String get bleCategoryIoT => 'IoT';

  @override
  String get bleCategoryPhones => 'Phones';

  @override
  String get bleCategoryComputers => 'Computers';

  @override
  String get bleCategoryInput => 'Input';

  @override
  String get bleCategoryGaming => 'Gaming';

  @override
  String get bleCategoryVehicle => 'Vehicle';

  @override
  String get bleCategoryUnidentified => 'Unidentified';

  @override
  String get bleConfidenceMedium => 'Medium';

  @override
  String get bleConfidenceLow => 'Low';

  @override
  String get bleDetailConfidence => 'Confidence';

  @override
  String get bleDetailCategory => 'Category';

  @override
  String get bleDetailType => 'Type';

  @override
  String get bleDetailRole => 'Role';

  @override
  String get bleDetailRSSI => 'RSSI';

  @override
  String get bleDetailDistance => 'Distance';

  @override
  String get bleDetailManufacturer => 'Manufacturer';

  @override
  String get bleDetailIdentifiedAs => 'Identified As';

  @override
  String get bleDetailFirstSeen => 'First seen';

  @override
  String get bleDetailLastSeen => 'Last seen';

  @override
  String get bleDetailSightings => 'Sightings';

  @override
  String get bleDetailStrongestRSSI => 'Strongest RSSI';

  @override
  String get bleDetailSensorData => 'Sensor Data';

  @override
  String get bleDetailTemperature => 'Temperature';

  @override
  String get bleDetailHumidity => 'Humidity';

  @override
  String get bleDetailBattery => 'Battery';

  @override
  String get bleDetailBeacons => 'Beacons';

  @override
  String get bleDetailServices => 'Services';

  @override
  String get bleDetailWhyIdentified => 'Why identified';

  @override
  String get bleDetailRawData => 'Raw Data';

  @override
  String get bleTimeJustNow => 'Just now';

  @override
  String bleTimeMinutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String bleTimeHoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String bleTimeDaysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String get toolNameStringTransformer => 'String Transformer';

  @override
  String get toolDescStringTransformer =>
      'Convert text between various formats: camelCase, snake_case, kebab-case, PascalCase, URL slugs, Base64, Hex, and decode ad URLs.';

  @override
  String get stringTransformerInputLabel => 'Input Text';

  @override
  String get stringTransformerOutputLabel => 'Output Text';

  @override
  String get stringTransformerSelectTransform => 'Select Transformation';

  @override
  String stringTransformerCharsCount(int count) {
    return '$count chars';
  }

  @override
  String get stringTransformerSwap => 'Swap Input/Output';

  @override
  String get stringTransformerTypeCamel => 'camelCase';

  @override
  String get stringTransformerTypeSnake => 'snake_case';

  @override
  String get stringTransformerTypeKebab => 'kebab-case';

  @override
  String get stringTransformerTypePascal => 'PascalCase';

  @override
  String get stringTransformerTypeUrlSlug => 'URL Slug';

  @override
  String get stringTransformerTypeBase64Encode => 'Base64 Encode';

  @override
  String get stringTransformerTypeBase64Decode => 'Base64 Decode';

  @override
  String get stringTransformerTypeHexEncode => 'Hex Encode';

  @override
  String get stringTransformerTypeHexDecode => 'Hex Decode';

  @override
  String get stringTransformerTypeAdUrlDecode => 'Ad URL Decode';

  @override
  String get stringTransformerPlaceholderInput => 'Type or paste text here...';

  @override
  String get stringTransformerPlaceholderOutput => 'Result will appear here...';

  @override
  String get stringTransformerCopied => 'Copied to clipboard';

  @override
  String stringTransformerFailedToCopy(String error) {
    return 'Failed to copy: $error';
  }

  @override
  String stringTransformerInvalidInput(String message) {
    return 'Error: $message';
  }

  @override
  String get stringTransformerNoEmbeddedUrl => 'No embedded URL detected.';

  @override
  String get toolNameTreadmillControl => 'Treadmill Control';

  @override
  String get toolDescTreadmillControl =>
      'Control your treadmill and monitor heart rate via Bluetooth';

  @override
  String get speedLabel => 'Speed';

  @override
  String get inclineLabel => 'Incline';

  @override
  String get hrLabel => 'Heart Rate';

  @override
  String get elapsedTime => 'Duration';

  @override
  String get distance => 'Distance';

  @override
  String get calories => 'Calories';

  @override
  String get steps => 'Steps';

  @override
  String get historyTitle => 'Workout History';

  @override
  String get workoutStart => 'Start';

  @override
  String get workoutPause => 'Pause';

  @override
  String get workoutResume => 'Resume';

  @override
  String get workoutStop => 'Stop';

  @override
  String get importHistory => 'Import Workouts';

  @override
  String get exportHistory => 'Export Workouts';

  @override
  String get treadmillHistorySync => 'Sync now';

  @override
  String get treadmillHistorySyncDisabled =>
      'Sync is not enabled. Turn it on in Settings.';

  @override
  String treadmillHistorySyncSuccess(int pushed, int pulled) {
    return 'Synced: $pushed pushed, $pulled pulled';
  }

  @override
  String treadmillHistorySyncFailed(String error) {
    return 'Sync failed: $error';
  }

  @override
  String get treadmillConnectDevices => 'Connect devices';

  @override
  String get treadmillSessionRunningTitle => 'Workout still running';

  @override
  String get treadmillSessionRunningMessage =>
      'Leaving this screen keeps recording in the background - the session is saved automatically and can be recovered even if the app is closed. Stop it now to file it in the history.';

  @override
  String get treadmillKeepRecording => 'Leave, keep recording';

  @override
  String get treadmillStopAndSave => 'Stop and save';

  @override
  String get treadmillRecoveredTitle => 'Unfinished workout found';

  @override
  String treadmillRecoveredMessage(String duration, String distance) {
    return 'A workout of $duration with $distance km was still recording when the app closed.';
  }

  @override
  String get treadmillRecoveredResume => 'Continue';

  @override
  String get treadmillRecoveredSave => 'Save to history';

  @override
  String get treadmillRecoveredDiscard => 'Discard';

  @override
  String get treadmillRecoveredSaved => 'Workout saved to history';

  @override
  String get treadmillPublishNow => 'Publish now';

  @override
  String get treadmillPublishNowSubtitle =>
      'Workouts go to Health Connect when one ends, on a manual sync and when the health dashboard opens, at most once every five minutes.';

  @override
  String treadmillPublishDone(int count) {
    return 'Published $count workout(s) to Health Connect';
  }

  @override
  String get treadmillPublishNothing => 'Health Connect is already up to date';

  @override
  String treadmillPublishFailed(int count) {
    return '$count workout(s) could not be published to Health Connect';
  }

  @override
  String get treadmillPublishNoPermission =>
      'Health Connect did not grant write access';

  @override
  String get treadmillPublishThrottled =>
      'Just published — nothing new to send';

  @override
  String get treadmillPublishDisabled =>
      'Publishing to Health Connect is switched off';

  @override
  String get treadmillPublishUnsupported =>
      'Health Connect is only available on Android';

  @override
  String get treadmillRemoveFromHealthConnect =>
      'Remove workouts from Health Connect';

  @override
  String get treadmillRemoveFromHealthConnectSubtitle =>
      'Deletes everything this app wrote there and publishes it again on the next run.';

  @override
  String get treadmillRemoveFromHealthConnectConfirm =>
      'Every treadmill record ToolLab wrote is deleted from Health Connect. Records from other apps are not touched. Distance records are the exception: Health Connect offers no way to delete them here, so they are overwritten on the next publish. Your local workout history stays and is published again on the next run.';

  @override
  String get treadmillRemoveFromHealthConnectAction => 'Delete';

  @override
  String treadmillRemoveFromHealthConnectDone(int count) {
    return 'Removed — $count workout(s) will be published again';
  }

  @override
  String get treadmillRemoveFromHealthConnectFailed =>
      'Removing the Health Connect data failed';

  @override
  String get treadmillHistoryDashboard => 'Dashboard';

  @override
  String get treadmillHistoryWorkouts => 'Workouts';

  @override
  String get treadmillHistoryEmpty => 'No workouts saved yet';

  @override
  String get treadmillHistoryOverview => 'Your running story';

  @override
  String get treadmillHistoryOverviewSubtitle =>
      'Every recorded workout, in one place.';

  @override
  String get treadmillHistoryLastSevenDays => 'Last 7 days';

  @override
  String get treadmillHistoryDistanceLastSevenDays =>
      'Distance in the last 7 days';

  @override
  String get treadmillHistoryDistanceChartSubtitle =>
      'Daily distance with a seven-day trend';

  @override
  String get treadmillHistoryTotalDistance => 'Total distance';

  @override
  String get treadmillHistoryTotalDuration => 'Total duration';

  @override
  String get treadmillHistoryTotalCalories => 'Total calories';

  @override
  String get treadmillHistoryAverageSpeed => 'Average speed';

  @override
  String get treadmillHistoryWorkoutCount => 'Total workouts';

  @override
  String get treadmillHistoryScreenshot => 'Dashboard screenshot';

  @override
  String get treadmillHistorySaveScreenshot => 'Save screenshot';

  @override
  String get treadmillHistoryShareScreenshot => 'Share screenshot';

  @override
  String get treadmillHistoryScreenshotFailed =>
      'Could not create dashboard screenshot';

  @override
  String get treadmillHistoryGenerateReport => 'Generate PDF report';

  @override
  String get treadmillHistoryReportTitle => 'Treadmill Workout Report';

  @override
  String get treadmillHistoryReportGenerated => 'Generated';

  @override
  String get treadmillHistoryReportDate => 'Date';

  @override
  String get treadmillHistoryReportFailed =>
      'Could not generate workout report';

  @override
  String get treadmillHistoryTotalWorkouts => 'Total workouts';

  @override
  String get treadmillHistoryLongestDuration => 'Longest duration';

  @override
  String get treadmillHistoryMostCalories => 'Most calories';

  @override
  String get treadmillHistoryMostSteps => 'Most steps';

  @override
  String get treadmillHistoryHeartRateLastSevenDays =>
      'Average heart rate in the last 7 days';

  @override
  String get treadmillHistoryAllTime => 'All time';

  @override
  String get treadmillHistoryPersonalBests => 'Personal bests';

  @override
  String get treadmillHistoryLongestRun => 'Longest run';

  @override
  String get treadmillHistoryTopSpeed => 'Top speed';

  @override
  String get treadmillHistoryAverage => 'Average';

  @override
  String get treadmillHistoryAverageHr => 'Avg HR';

  @override
  String get treadmillHistoryHeartRate => 'Heart rate';

  @override
  String get treadmillHistoryHeartRateSubtitle =>
      'All-time workout intensity, with a last 7-day trend below';

  @override
  String get treadmillHistoryRestingAverage => 'Workout average';

  @override
  String get treadmillHistoryPeakHeartRate => 'Highest peak';

  @override
  String get treadmillHistoryImportNoNewWorkouts =>
      'All workouts from this backup are already saved';

  @override
  String treadmillHistoryImportSuccess(int count) {
    return 'Successfully imported $count workouts';
  }

  @override
  String get treadmillDetailsTitle => 'Workout Details';

  @override
  String get treadmillScreenshotCopy => 'Copy to clipboard';

  @override
  String get treadmillScreenshotCopied => 'Screenshot copied to clipboard';

  @override
  String get treadmillScreenshotCopyFailed =>
      'Could not copy screenshot to clipboard';

  @override
  String get treadmillDetailsScreenshot => 'Workout screenshot';

  @override
  String get treadmillDetailsScreenshotFailed =>
      'Could not create workout screenshot';

  @override
  String get treadmillDetailsDuration => 'Duration';

  @override
  String get treadmillDetailsPaceUnit => 'min/km';

  @override
  String get treadmillDetailsAvgSpeed => 'Avg speed';

  @override
  String get treadmillDetailsMaxSpeed => 'Max speed';

  @override
  String get treadmillDetailsAvgHr => 'Avg heart rate';

  @override
  String get treadmillDetailsMaxHr => 'Max heart rate';

  @override
  String get treadmillDetailsMinHr => 'Min heart rate';

  @override
  String get treadmillDetailsCalories => 'Calories';

  @override
  String get treadmillDetailsSteps => 'Steps';

  @override
  String get treadmillDetailsAvgIncline => 'Avg incline';

  @override
  String get treadmillDetailsMaxIncline => 'Max incline';

  @override
  String get treadmillDetailsSpeed => 'Speed';

  @override
  String get treadmillDetailsChart => 'Speed & heart rate';

  @override
  String get treadmillDetailsIncline => 'Incline';

  @override
  String get treadmillDetailsZones => 'Heart rate zones';

  @override
  String get treadmillDetailsZone1 => 'Recovery';

  @override
  String get treadmillDetailsZone2 => 'Easy';

  @override
  String get treadmillDetailsZone3 => 'Aerobic';

  @override
  String get treadmillDetailsZone4 => 'Threshold';

  @override
  String get treadmillDetailsZone5 => 'Maximum';

  @override
  String get treadmillDetailsSplits => 'Kilometer splits';

  @override
  String get treadmillDetailsSplitKm => 'Km';

  @override
  String get treadmillDetailsSplitTime => 'Time';

  @override
  String get treadmillDetailsSplitPace => 'Pace';

  @override
  String get treadmillDetailsSplitHr => 'HR';

  @override
  String get treadmillDetailsNoSamples =>
      'No detailed samples were recorded for this workout';

  @override
  String get toolNameAudioLab => 'Audio Lab';

  @override
  String get toolDescAudioLab =>
      'Locate, mask, analyze, and generate audio signals';

  @override
  String get sfTitleFinder => 'Finder';

  @override
  String get sfTitleCounter => 'Counter';

  @override
  String get sfTitleGenerator => 'Generator';

  @override
  String get sfModeTracker => 'Locate';

  @override
  String get sfModeCounter => 'Counter';

  @override
  String get sfModeGenerator => 'Generator';

  @override
  String get sfStop => 'Stop';

  @override
  String get sfPlayTone => 'Play tone';

  @override
  String get sfPlayCounter => 'Play counter tone';

  @override
  String get sfMicDeniedTitle => 'Microphone permission needed';

  @override
  String get sfMicDeniedBody =>
      'Grant microphone access to locate and analyze room sounds.';

  @override
  String get sfMicUnavailableTitle => 'Microphone capture unavailable';

  @override
  String get sfMicUnavailableBody =>
      'Live microphone analysis isn\'t supported on this platform. The frequency generator still works.';

  @override
  String get sfGrantPermission => 'Grant access';

  @override
  String get sfOpenGenerator => 'Open generator';

  @override
  String get sfTrackerTitle => 'Locate the source';

  @override
  String get sfLevel => 'Level';

  @override
  String get sfDominant => 'Dominant';

  @override
  String get sfPeakHold => 'Peak';

  @override
  String get sfGuidanceHotter => 'Getting warmer — closer to the source';

  @override
  String get sfGuidanceColder => 'Getting colder — moving away';

  @override
  String get sfGuidanceSteady => 'Steady — move to change the reading';

  @override
  String get sfGuidanceSilent => 'Too quiet — no clear sound detected';

  @override
  String get sfSetReference => 'Mark spot';

  @override
  String get sfClearReference => 'Clear';

  @override
  String get sfResetPeak => 'Reset peak';

  @override
  String get sfVsReference => 'vs. marked spot';

  @override
  String get sfSpectrum => 'Spectrum';

  @override
  String get sfCounterTitle => 'Counter / mask tone';

  @override
  String get sfCounterDisclaimer =>
      'A phone speaker can\'t truly cancel room noise. This plays a matching tone (optionally phase-inverted) plus optional masking noise to make the sound less noticeable.';

  @override
  String get sfDetected => 'Detected';

  @override
  String get sfUseDetected => 'Use detected';

  @override
  String get sfCounterMicOff =>
      'Microphone analysis is off — set the target frequency manually below.';

  @override
  String get sfTargetFrequency => 'Target frequency';

  @override
  String get sfWaveform => 'Waveform';

  @override
  String get sfPhase => 'Phase';

  @override
  String get sfInvertPhase => 'Invert phase (180°)';

  @override
  String get sfMaskNoise => 'Masking noise';

  @override
  String get sfVolume => 'Volume';

  @override
  String get sfGeneratorTitle => 'Frequency generator';

  @override
  String get sfGeneratorHint =>
      'Pick a frequency and waveform to generate a pure test tone.';

  @override
  String get sfTitleDoppler => 'Doppler';

  @override
  String get sfModeDoppler => 'Doppler';

  @override
  String get sfDopplerTitle => 'Doppler Effect Analysis';

  @override
  String get sfDopplerExplanation =>
      'Record a passing tone (like a car horn or siren) to estimate its speed, frequency, and distance, or load a previously saved WAV audio clip.';

  @override
  String get sfDopplerLoadClip => 'Load WAV Clip';

  @override
  String get sfDopplerVelocity => 'Velocity';

  @override
  String get sfDopplerDistance => 'Closest Distance';

  @override
  String get sfDopplerSourceFreq => 'Source Frequency';

  @override
  String get sfDopplerInflection => 'Inflection Time';

  @override
  String get sfDopplerTemp => 'Air Temperature';

  @override
  String get sfDopplerSpeedOfSound => 'Speed of Sound';

  @override
  String get sfDopplerParameters => 'Model Parameters';

  @override
  String get sfDopplerStatusNoData =>
      'No audio clip recorded yet. Start recording above or load a demo.';

  @override
  String get sfDopplerStatusAnalyzing => 'Analyzing audio clip...';

  @override
  String get sfDopplerStatusSuccess =>
      'Analysis complete. Adjust markers to align the theoretical model (solid line) with the recorded peak frequencies (purple dots).';

  @override
  String get sfDopplerGraphTitle => 'Frequency vs. Time';

  @override
  String get sfDopplerInfoTitle => 'Understanding the Doppler Graph';

  @override
  String get sfDopplerInfoContent =>
      '• X-Axis (Horizontal): Time in seconds.\n• Y-Axis (Vertical): Frequency in Hertz (Hz).\n• Dots: Detected peak frequencies from the recorded clip.\n• Solid Line: Theoretical Doppler model curve.\n• Vertical Line (t₀): Time of closest approach.\n\nGoal: Adjust the parameters to align the solid line with the dots.';

  @override
  String get sfWaveSine => 'Sine';

  @override
  String get sfWaveSquare => 'Square';

  @override
  String get sfWaveTriangle => 'Triangle';

  @override
  String get sfWaveSawtooth => 'Sawtooth';

  @override
  String get sfToneNotificationTitle => 'Tone active';

  @override
  String get sfToneNotificationText => 'ToolLab is generating a tone';

  @override
  String get sfMicDefault => 'Default microphone';

  @override
  String get sfRefreshMics => 'Rescan microphones';

  @override
  String get sfMicGain => 'Mic gain';

  @override
  String get sfInputSettings => 'Input settings';

  @override
  String get sfSaveClipButton => 'Save clip';

  @override
  String get sfSpectrumSettings => 'Spectrum settings';

  @override
  String get sfRecordClip => 'Record clip';

  @override
  String get sfStopAndSave => 'Stop & save';

  @override
  String get sfClipSavedAndroid => 'Audio clip saved to Downloads';

  @override
  String sfClipSaved(String path) {
    return 'Clip saved to $path';
  }

  @override
  String get sfClipSaveError => 'Couldn\'t save the audio clip';

  @override
  String get sfEnlargeSpectrum => 'Enlarge spectrum';

  @override
  String get sfMaxHold => 'Max hold';

  @override
  String get sfResetZoom => 'Reset zoom';

  @override
  String get sfRange => 'Range';

  @override
  String get sfScreenshot => 'Screenshot';

  @override
  String get sfCopyImage => 'Copy to clipboard';

  @override
  String get sfSaveImage => 'Save image';

  @override
  String get sfImageCopied => 'Spectrum copied to clipboard';

  @override
  String get sfImageCopyFailed => 'Couldn\'t copy the spectrum image';

  @override
  String get sfSpectrogram => 'Spectrogram';

  @override
  String get sfStopRecording => 'Stop recording';

  @override
  String get sfRecordingLabel => 'REC';

  @override
  String get sfSavingClip => 'Saving clip…';

  @override
  String get sfResFast => 'Fast';

  @override
  String get sfResBalanced => 'Balanced';

  @override
  String get sfResFine => 'Fine';

  @override
  String sfBinWidth(String hz) {
    return '≈ $hz Hz per bin';
  }

  @override
  String get sfTitleMorse => 'Morse Code';

  @override
  String get sfMorseGenTab => 'Generate';

  @override
  String get sfMorseAnalTab => 'Analyze';

  @override
  String get sfMorseWpm => 'Morse Speed';

  @override
  String get sfMorsePlayMode => 'Signal Mode';

  @override
  String get sfMorsePlayBoth => 'Sound & Flash';

  @override
  String get sfMorsePlaySound => 'Sound only';

  @override
  String get sfMorsePlayFlash => 'Flash only';

  @override
  String get sfMorsePlaceholder => 'Message to encode...';

  @override
  String get sfMorseDecodedOutput => 'Decoded Text';

  @override
  String get sfMorseLiveListening => 'Listening...';

  @override
  String get sfMorseExportSuccess => 'Morse audio exported successfully';

  @override
  String get toolNameCompass => 'Compass';

  @override
  String get toolDescCompass =>
      'Tilt-compensated heading dial with magnetic status';

  @override
  String get compassHeading => 'Heading';

  @override
  String get compassMagneticField => 'Magnetic Field';

  @override
  String get compassInterferenceNormal => 'Normal';

  @override
  String get compassInterferenceWarning => 'Interference Detected';

  @override
  String get compassCalibrateTip =>
      'Keep away from metal or magnets if heading feels inaccurate.';

  @override
  String get compassInfoTooltip => 'How to use';

  @override
  String get compassInfoTitle => 'Using the Compass';

  @override
  String get compassInfoIntro =>
      'The compass shows your heading — the direction the top edge of your device is pointing — from the built-in magnetometer and accelerometer.';

  @override
  String get compassStepLevelTitle => '1. Hold the device flat';

  @override
  String get compassStepLevelBody =>
      'Keep the screen facing up and roughly level with the ground. The level indicator turns green when you are flat enough for an accurate reading. Reading it while tilted or held upright is unreliable.';

  @override
  String get compassStepCalibrateTitle => '2. Calibrate with a figure-8';

  @override
  String get compassStepCalibrateBody =>
      'If the heading drifts, spins, or never settles, wave the device slowly through a figure-8 motion a few times. This recalibrates the magnetometer — the most common cause of a jumpy compass.';

  @override
  String get compassStepMetalTitle => '3. Stay clear of metal';

  @override
  String get compassStepMetalBody =>
      'Magnets, speakers, laptops, phone cases, cars and steel furniture bend the magnetic field. The Magnetic Field panel warns you when interference is detected.';

  @override
  String get compassStepReadTitle => '4. Read the heading';

  @override
  String get compassStepReadBody =>
      'The red needle stays pointing up; the dial rotates so N sits at magnetic north. The large number and letters (e.g. 214° SW) are your current heading.';

  @override
  String get compassSimNote =>
      'On devices without magnetic sensors the compass runs in simulation — swipe horizontally on the dial to turn it.';

  @override
  String get compassLevelGood => 'Level';

  @override
  String get compassLevelHoldFlat => 'Hold flat';

  @override
  String compassTiltLabel(String deg) {
    return 'Tilt $deg°';
  }

  @override
  String get compassHoldFlatHint =>
      'Hold the device flat and level for an accurate heading.';

  @override
  String get compassCalibrateHint =>
      'Heading unstable? Wave the device in a figure-8 to recalibrate.';

  @override
  String get toolNameFileManager => 'File Manager';

  @override
  String get toolDescFileManager =>
      'Browse local files and FTP or SMB network shares';

  @override
  String get fileManagerAppFiles => 'Default folder';

  @override
  String get fileManagerConnections => 'Connections';

  @override
  String get fileManagerAddConnection => 'Connections';

  @override
  String get fileManagerRefresh => 'Refresh';

  @override
  String get fileManagerNewFolder => 'New folder';

  @override
  String get fileManagerFavorite => 'Favorite folder';

  @override
  String get fileManagerEmptyFolder => 'This folder is empty';

  @override
  String get fileManagerBrokenLink =>
      'Broken link - the target no longer exists';

  @override
  String get fileManagerFtp => 'FTP';

  @override
  String get fileManagerSmb => 'SMB';

  @override
  String get fileManagerConnectionName => 'Connection name';

  @override
  String get fileManagerHost => 'Host';

  @override
  String get fileManagerPort => 'Port';

  @override
  String get fileManagerShare => 'Share';

  @override
  String get fileManagerUsername => 'Username';

  @override
  String get fileManagerPassword => 'Password';

  @override
  String get fileManagerInitialPath => 'Initial path';

  @override
  String get fileManagerAllFilesAccess => 'Allow access to all files';

  @override
  String get fileManagerCut => 'Cut';

  @override
  String get fileManagerPaste => 'Paste';

  @override
  String get fileManagerDiscoverShares => 'Discover shares';

  @override
  String get fileManagerDeleteTitle => 'Delete selected files?';

  @override
  String fileManagerDeleteMessage(int count) {
    return 'Delete $count selected item(s), including all contents of selected folders? This cannot be undone.';
  }

  @override
  String fileManagerSelected(int count) {
    return '$count selected';
  }

  @override
  String get fileManagerSelect => 'Select files';

  @override
  String get fileManagerSelectAll => 'Select all';

  @override
  String get fileManagerCopying => 'Copying files';

  @override
  String get fileManagerMoving => 'Moving files';

  @override
  String get fileManagerDeleting => 'Deleting files';

  @override
  String fileManagerOperationProgress(int completed, int total) {
    return '$completed of $total files processed';
  }

  @override
  String get fileManagerOperationBackground =>
      'Continues while ToolLab is in the background';

  @override
  String fileManagerMoveBuffer(int count) {
    return '$count item(s) ready to move';
  }

  @override
  String fileManagerCopyBuffer(int count) {
    return '$count item(s) ready to copy';
  }

  @override
  String get fileManagerDropActionTitle => 'Add dropped files';

  @override
  String get fileManagerDropActionMessage =>
      'Choose whether to copy or move the dropped files.';

  @override
  String get fileManagerMove => 'Move';

  @override
  String get fileManagerSettings => 'File Manager settings';

  @override
  String get fileManagerSortBy => 'Sort files by';

  @override
  String get fileManagerSortName => 'Name';

  @override
  String get fileManagerSortDate => 'Modified date';

  @override
  String get fileManagerSortSize => 'Size';

  @override
  String get fileManagerSortAscending => 'Ascending order';

  @override
  String get fileManagerRemoveConnectionTitle => 'Remove connection?';

  @override
  String fileManagerRemoveConnectionMessage(String name) {
    return 'Remove saved connection \"$name\" and its stored password?';
  }

  @override
  String get fileManagerClearClipboard => 'Clear clipboard';

  @override
  String get fileManagerOpenChooser => 'Ask every time';

  @override
  String get fileManagerOpenImages => 'Open images with';

  @override
  String get fileManagerOpenPdf => 'Open PDFs with';

  @override
  String get fileManagerOpenAudio => 'Open audio with';

  @override
  String get fileManagerOpenVideo => 'Open video with';

  @override
  String get fileManagerOpenInternalPlayer => 'Internal player';

  @override
  String get fileManagerOpenMarkdown => 'Open Markdown with';

  @override
  String get fileManagerOpenSqlite => 'Open SQLite databases with';

  @override
  String get fileManagerOpenWithSystem => 'Open with system default';

  @override
  String get fileManagerDownloads => 'Downloads';

  @override
  String get fileManagerGrantFileAccess => 'Allow access to device files';

  @override
  String get fileManagerDetails => 'Details';

  @override
  String get fileManagerDetailSize => 'Size';

  @override
  String get fileManagerDetailModified => 'Modified';

  @override
  String get fileManagerDetailType => 'File type';

  @override
  String get fileManagerDetailPath => 'Path';

  @override
  String get fileManagerFolder => 'Folder';

  @override
  String get fileManagerStartupFolder => 'Startup folder';

  @override
  String get fileManagerCurrentFolder => 'Current folder';

  @override
  String get fileManagerSorting => 'Sorting';

  @override
  String get fileManagerOpenWith => 'Open with';

  @override
  String get fileManagerFoldersFirst => 'Folders before files';

  @override
  String get fileManagerFileExistsTitle => 'File already exists';

  @override
  String fileManagerFileExistsMessage(String names) {
    return '$names already exists in this folder.';
  }

  @override
  String get fileManagerKeepBoth => 'Keep both';

  @override
  String get fileManagerOverwrite => 'Overwrite';

  @override
  String get fileManagerRecentLocations => 'Recent';

  @override
  String get fileManagerFolderItems => 'Items';

  @override
  String fileManagerFolderFileCount(int count) {
    return '$count files';
  }

  @override
  String fileManagerFolderItemCount(int count) {
    return '$count items';
  }

  @override
  String get fileManagerInstallApk => 'Install APK';

  @override
  String get fileManagerStorage => 'Storage';

  @override
  String get fileManagerCompressZip => 'Compress to ZIP';

  @override
  String get fileManagerCompressing => 'Creating ZIP archive';

  @override
  String get fileManagerExtract => 'Extract';

  @override
  String get fileManagerExtracting => 'Extracting archive';

  @override
  String get fileManagerArchiveConflictTitle => 'Archive files already exist';

  @override
  String fileManagerArchiveConflictMessage(int count) {
    return '$count extracted files already exist.';
  }

  @override
  String fileManagerItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String fileManagerMoreEntries(int count) {
    return 'and $count more';
  }

  @override
  String get fileManagerSkip => 'Skip';

  @override
  String get fileManagerApplyToAll => 'Apply to all conflicts';

  @override
  String get fileManagerDocuments => 'Documents';

  @override
  String get toolNameHealthDashboard => 'Health Dashboard';

  @override
  String get toolDescHealthDashboard =>
      'Bring your health data and workouts together';

  @override
  String get healthDashboardRefresh => 'Sync health data and the backend';

  @override
  String get healthDashboardHeadline => 'Your health, in focus';

  @override
  String get healthDashboardSubtitle =>
      'A single private view of your activity and recovery.';

  @override
  String get healthDashboardDistance => 'Distance';

  @override
  String get healthDashboardDistanceAllTime => 'Distance · all time';

  @override
  String get healthDashboardCaloriesAllTime => 'Calories · all time';

  @override
  String get healthDashboardActiveTimeAllTime => 'Active time · all time';

  @override
  String get healthDashboardStepsAllTime => 'Steps · all time';

  @override
  String get healthDashboardWorkoutsAllTime => 'Workouts · all time';

  @override
  String get healthDashboardDistanceLastSevenDays => 'Distance · last 7 days';

  @override
  String get healthDashboardCaloriesLastSevenDays => 'Calories · last 7 days';

  @override
  String get healthDashboardActiveTimeLastSevenDays =>
      'Active time · last 7 days';

  @override
  String get healthDashboardStepsLastSevenDays => 'Steps · last 7 days';

  @override
  String get healthDashboardLatestRestingHeartRate =>
      'Latest resting heart rate';

  @override
  String get healthDashboardLatestHeartRate => 'Latest heart rate';

  @override
  String get healthDashboardCalories => 'Calories';

  @override
  String get healthDashboardActiveTime => 'Active time';

  @override
  String get healthDashboardWorkouts => 'Workouts';

  @override
  String get healthDashboardStepsToday => 'Steps today';

  @override
  String get healthDashboardWeight => 'Latest weight';

  @override
  String get healthDashboardRestingHeartRate => 'Resting heart rate';

  @override
  String get healthDashboardLastSleep => 'Latest sleep';

  @override
  String get healthDashboardWorkoutTrend => 'Distance · last 7 days';

  @override
  String get healthDashboardHeartRateTrend =>
      'Average heart rate · last 7 days';

  @override
  String get healthDashboardRecentActivity => 'Recent activity';

  @override
  String get healthDashboardNoData =>
      'No health data yet. Sync a treadmill workout or connect Health Connect on Android.';

  @override
  String get healthDashboardTreadmillRun => 'Treadmill run';

  @override
  String get healthDashboardConnectHealthConnect =>
      'Connect and import Health Connect';

  @override
  String get healthDashboardImportHealthConnect => 'Import Health Connect now';

  @override
  String get healthDashboardManageHealthConnect => 'Manage Health Connect';

  @override
  String get healthDashboardManageHealthConnectSubtitle =>
      'Open Android permissions or Health Connect system settings.';

  @override
  String get healthDashboardHealthConnectImported =>
      'Health Connect data imported';

  @override
  String get healthDashboardHealthConnectRepaired =>
      'Health Connect cache repaired';

  @override
  String get healthDashboardSyncInProgress => 'Sync already in progress';

  @override
  String get healthDashboardSyncInProgressBody =>
      'A Health Connect import or cloud sync is still running. Wait for it to finish before starting another one.';

  @override
  String get healthDashboardSyncNoChanges => 'No health data changes to sync';

  @override
  String get healthDashboardRepairHealthConnect =>
      'Start Health Connect import over';

  @override
  String get healthDashboardRepairHealthConnectSubtitle =>
      'Clear locally imported Health Connect data and import history again.';

  @override
  String get healthDashboardResetHealthConnectDescription =>
      'This removes all locally imported Health Connect cache and canonical records on this device. It does not affect Health Connect or cloud data. The next import starts from the beginning and can take a long time. Regular imports resume from the last successful sync.';

  @override
  String get healthDashboardStartOver => 'Start over';

  @override
  String get healthDashboardConnectHealthConnectSubtitle =>
      'Requests access and imports all available historical data from Health Connect.';

  @override
  String get healthDashboardHealthConnectAnalysis =>
      'Export Health Connect analysis';

  @override
  String get healthDashboardHealthConnectAnalysisSubtitle =>
      'Read every supported type and save raw records, metadata, sessions, routes, and per-type errors to a separate SQLite database.';

  @override
  String get healthDashboardHealthConnectAnalysisFailed =>
      'Health Connect analysis export failed';

  @override
  String get healthDashboardHealthConnectDiscovery =>
      'Export Health Connect discovery';

  @override
  String get healthDashboardHealthConnectDiscoverySubtitle =>
      'Quickly inspect every supported type with one sample page each. This does not export full history.';

  @override
  String get healthDashboardHealthConnectDiscoveryFailed =>
      'Health Connect discovery export failed';

  @override
  String get healthDashboardHealthConnectComparison =>
      'Export source comparison';

  @override
  String get healthDashboardHealthConnectComparisonSubtitle =>
      'Export 90 days of compact Zepp, Google Fit, and Renpho values. Excludes raw records, routes, and other sources.';

  @override
  String get healthDashboardHealthConnectComparisonDone =>
      'Source comparison saved to Downloads';

  @override
  String get healthDashboardHealthConnectComparisonFailed =>
      'Source comparison export failed';

  @override
  String get healthDashboardHealthConnectComparisonProgressTitle =>
      'Exporting source comparison';

  @override
  String get healthDashboardHealthConnectComparisonProgressStatus =>
      'Preparing source comparison...';

  @override
  String healthDashboardHealthConnectComparisonProgressCount(int count) {
    return '$count Health Connect records processed';
  }

  @override
  String get healthDashboardHealthConnectComparisonProgressHint =>
      'The export keeps running in the background with a notification. You can switch away or turn the screen off.';

  @override
  String get healthDashboardAutoHealthConnectSync =>
      'Sync Health Connect on open';

  @override
  String get healthDashboardAutoHealthConnectSyncSubtitle =>
      'Import Health Connect data whenever the dashboard opens.';

  @override
  String get healthDashboardSettings => 'Health dashboard settings';

  @override
  String get healthDashboardDataToShow => 'Data to show';

  @override
  String get healthDashboardSectionAccess => 'Access';

  @override
  String get healthDashboardSectionSelect => 'What to collect';

  @override
  String get healthDashboardSectionSelectHint =>
      'Nothing is pulled unless you enable it here.';

  @override
  String get healthDashboardSectionCollect => 'Collect';

  @override
  String get healthDashboardSectionCollectHint =>
      'Fills the new typed store. Not shown on the dashboard yet.';

  @override
  String get healthDashboardSectionCurrent => 'Dashboard data';

  @override
  String get healthDashboardSectionCurrentHint =>
      'The older import that still feeds the dashboard you see.';

  @override
  String get healthDashboardDataTypes => 'Data types';

  @override
  String get healthDashboardDataTypesSubtitle =>
      'Choose what to pull from Health Connect';

  @override
  String get healthDashboardDataSources => 'Sources';

  @override
  String get healthDashboardDataSourcesSubtitle =>
      'Choose which app each type is pulled from';

  @override
  String get healthDashboardScanSources => 'Scan available data';

  @override
  String get healthDashboardScanSourcesSubtitle =>
      'Finds which types hold data and which apps wrote it';

  @override
  String get healthDashboardImportSelected => 'Import selected data';

  @override
  String get healthDashboardImportSelectedSubtitle =>
      'Full history for every enabled type';

  @override
  String get healthDashboardImportRestart => 'Re-import from scratch';

  @override
  String get healthDashboardImportRestartSubtitle =>
      'Clears stored data and reads all history again';

  @override
  String get healthDashboardSyncChanges => 'Sync changes now';

  @override
  String get healthDashboardSyncChangesSubtitle =>
      'Fetches only what changed since the last sync';

  @override
  String get healthDashboardNoTypesFound =>
      'Nothing scanned yet. Run a scan to see what is available.';

  @override
  String get healthDashboardNoSourcesFound =>
      'No apps found for this type yet.';

  @override
  String healthDashboardTypeRecordCount(int count) {
    return '$count imported';
  }

  @override
  String get healthDashboardDataSourcesHint =>
      'Apps this data type is read from. Switching one off keeps what it already contributed - it only stops being read and stops counting towards totals.';

  @override
  String get healthDashboardApps => 'Apps';

  @override
  String get healthDashboardAppsSubtitle =>
      'Switch writing apps on or off and set which one wins';

  @override
  String get healthDashboardNoAppsFound =>
      'No writing apps known yet. Scan for sources first.';

  @override
  String get healthDashboardAppPriority => 'Priority order';

  @override
  String get healthDashboardAppPriorityHint =>
      'The topmost app with data for a day is the one that day\'s totals are computed from. Apps below it stay as a fallback for days it did not cover.';

  @override
  String healthDashboardAppRowCount(int count) {
    return '$count rows stored';
  }

  @override
  String healthDashboardAppTypeCount(int count) {
    return '$count data types';
  }

  @override
  String get healthDashboardAppMoveUp => 'Higher priority';

  @override
  String get healthDashboardAppMoveDown => 'Lower priority';

  @override
  String get healthDashboardAppDeleteData => 'Delete stored data';

  @override
  String get healthDashboardAppDeleteDataConfirm =>
      'Delete every row this app contributed and shrink the database. Switching the app off instead keeps its data and costs nothing to undo.';

  @override
  String get healthDashboardAppDeleteHere => 'Free up space on this device';

  @override
  String get healthDashboardAppDeleteHereHint =>
      'Removes the rows here only. Other devices keep their copy, and this one gets it back on the next sync unless the app is switched off.';

  @override
  String get healthDashboardAppDeleteEverywhere => 'Remove from every device';

  @override
  String get healthDashboardAppDeleteEverywhereHint =>
      'Says the data is wrong and deletes the server copy too, so every device drops it. This cannot be undone.';

  @override
  String get healthDashboardAutoSync => 'Sync changes on open';

  @override
  String get healthDashboardAutoSyncSubtitle =>
      'Fetch what Health Connect reports as changed each time the tool opens. Off means data only arrives when you import manually.';

  @override
  String get healthDashboardImportConfirmTitle => 'Import full history?';

  @override
  String healthDashboardImportConfirmBody(int count) {
    return '$count data types are selected. Reading their full history can take hours on a large store. It continues in the background and can be interrupted.';
  }

  @override
  String get healthDashboardImportConfirmNoTypes =>
      'No data types are selected, so an import would store nothing. Scan for sources first, then pick what to collect.';

  @override
  String get healthDashboardScanFirstHint =>
      'Nothing has been discovered yet. Scan Health Connect to find which data types hold data and which apps wrote them.';

  @override
  String healthDashboardSourceRecordCount(int count) {
    return '$count seen';
  }

  @override
  String healthDashboardStoreSummary(int points, int sessions) {
    return '$points measurements, $sessions sessions';
  }

  @override
  String get healthDashboardStoreEmptyHint =>
      'Nothing stored yet. Scan, then import.';

  @override
  String healthDashboardStoreRollupRows(int rows) {
    return '$rows daily summary rows';
  }

  @override
  String get healthDashboardBaselineEstablished =>
      'Change tracking started. Run an import to load history.';

  @override
  String healthDashboardSyncChangesResult(int updated, int removed) {
    return '$updated updated, $removed removed';
  }

  @override
  String get healthDashboardFullImportNeeded =>
      'Change tracking expired and recovery failed. A full import is needed.';

  @override
  String healthDashboardSyncRecovered(int imported) {
    return 'Change tracking expired. Re-read recent history: $imported records.';
  }

  @override
  String get healthDashboardShowTreadmill => 'Treadmill workouts';

  @override
  String get healthDashboardShowTreadmillSubtitle =>
      'Include local treadmill runs in dashboard totals and activity.';

  @override
  String get healthDashboardSync => 'Sync';

  @override
  String get healthDashboardSyncNow => 'Sync now';

  @override
  String get healthDashboardSyncEnabled =>
      'Sync health records with your configured backend.';

  @override
  String get healthDashboardSyncDisabled =>
      'Enable backend sync in Settings first.';

  @override
  String healthDashboardSyncSuccess(int pushed, int pulled) {
    return 'Synced: $pushed pushed, $pulled pulled';
  }

  @override
  String get healthDashboardSyncFailed => 'Health data sync failed';

  @override
  String get healthDashboardHealthConnectWorkout => 'Health Connect workout';

  @override
  String get healthDashboardLastSevenDays => 'Last 7 days';

  @override
  String get healthDashboardHistory => 'History';

  @override
  String get healthDashboardDetails => 'Details';

  @override
  String get healthDashboardDate => 'Date';

  @override
  String get healthDashboardTime => 'Time';

  @override
  String get healthDashboardSource => 'Source';

  @override
  String get healthDashboardData => 'Data';

  @override
  String get healthDashboardHuaweiHealth => 'Huawei Health';

  @override
  String get healthDashboardAmazfit => 'Amazfit / Zepp';

  @override
  String get healthDashboardGoogleFit => 'Google Fit';

  @override
  String get healthDashboardSamsungHealth => 'Samsung Health';

  @override
  String get healthDashboardFitbit => 'Fitbit';

  @override
  String get healthDashboardGarmin => 'Garmin';

  @override
  String get healthDashboardWithings => 'Withings';

  @override
  String get healthDashboardRenpho => 'Renpho';

  @override
  String get healthDashboardMiFitness => 'Mi Fitness';

  @override
  String get healthDashboardSourceHealthConnect => 'Health Connect';

  @override
  String get healthDashboardSourceUnknown => 'Unknown app';

  @override
  String get healthDashboardSourcePreferences => 'Preferred data sources';

  @override
  String get healthDashboardSourcePreferencesSubtitle =>
      'Use a preferred app for each metric when records overlap.';

  @override
  String get healthDashboardAnySource => 'Any source';

  @override
  String get healthDashboardNap => 'Nap';

  @override
  String get healthDashboardNaps => 'Naps';

  @override
  String get healthDashboardAllData => 'All Health Data';

  @override
  String get healthDashboardSleepDetails => 'Sleep details';

  @override
  String get healthDashboardSleepDuration => 'Duration';

  @override
  String get healthDashboardSleepStart => 'Start';

  @override
  String get healthDashboardSleepEnd => 'End';

  @override
  String healthDashboardSleepStageTimes(int count) {
    return '×$count';
  }

  @override
  String healthDashboardSleepStageDuration(Object duration, Object count) {
    return '$duration ($count times)';
  }

  @override
  String get healthDashboardSleepStages => 'Sleep stages';

  @override
  String get healthDashboardTrends => 'Trends';

  @override
  String get healthDashboardWeightTrend => 'Weight · last 7 days';

  @override
  String get healthDashboardPreviousDay => 'Previous day';

  @override
  String get healthDashboardNextDay => 'Next day';

  @override
  String get healthDashboardSleepAwake => 'Awake';

  @override
  String get healthDashboardSleepRem => 'REM';

  @override
  String get healthDashboardSleepLight => 'Light';

  @override
  String get healthDashboardSleepDeep => 'Deep';

  @override
  String get healthDashboardHeartRate => 'Heart rate';

  @override
  String get healthDashboardNoSleepHeartRate =>
      'No heart-rate samples during this sleep session';

  @override
  String get healthDashboardBackup => 'Data backup';

  @override
  String get healthDashboardExportBackup => 'Export health database';

  @override
  String get healthDashboardExportBackupSubtitle =>
      'Save Health Dashboard records as a SQLite database.';

  @override
  String get healthDashboardExportBackupWarning =>
      'Exporting a large health database can take a while. It keeps running if you leave the app, and the file is saved when it finishes.';

  @override
  String get healthDashboardExportBackupProgressTitle =>
      'Exporting health database';

  @override
  String get healthDashboardExportBackupProgressStatus =>
      'Measuring the database...';

  @override
  String get healthDashboardExportBackupStatusWriting =>
      'Writing the backup file...';

  @override
  String get healthDashboardExportBackupStatusSaving =>
      'Saving to the Downloads folder...';

  @override
  String healthDashboardExportBackupProgressCount(int processed, int total) {
    return 'Written $processed of $total rows';
  }

  @override
  String get healthDashboardExportBackupProgressHint =>
      'You can leave the app; the backup keeps being written in the background.';

  @override
  String get healthDashboardExportBackupFailed =>
      'Could not export health database';

  @override
  String get healthDashboardExportBackupSavedDownloads =>
      'Health database saved to the Downloads folder';

  @override
  String healthDashboardExportBackupSavedTo(String path) {
    return 'Health database saved to $path';
  }

  @override
  String get healthDashboardImportBackup => 'Import health database';

  @override
  String get healthDashboardImportBackupSubtitle =>
      'Replace all stored records with a Health Dashboard SQLite backup.';

  @override
  String get healthDashboardImportBackupWarning =>
      'This deletes all stored health data and replaces it with the backup\'s contents. Anything collected since the backup was taken is lost. Health Connect is not touched, so a new import can fetch that data again.';

  @override
  String get healthDashboardImportBackupReplace => 'Delete and restore';

  @override
  String get healthDashboardImportBackupTooNew =>
      'This backup comes from a newer app version and cannot be restored';

  @override
  String healthDashboardImportBackupSuccess(int count) {
    return 'Restored $count health records';
  }

  @override
  String get healthDashboardImportBackupFailed =>
      'Could not import health database';

  @override
  String get healthDashboardSelectedDay => 'Selected day';

  @override
  String get healthDashboardImportBackupProgressTitle =>
      'Restoring health database';

  @override
  String healthDashboardImportBackupProgressStatus(int processed, int total) {
    return 'Replacing table $processed of $total...';
  }

  @override
  String healthDashboardImportBackupProgressCount(int processed, int total) {
    return 'Restored $processed of $total tables';
  }

  @override
  String get healthDashboardImportBackupProgressHint =>
      'You can leave the app; the restore keeps running in the background.';

  @override
  String get healthDashboardImportHealthConnectProgressTitle =>
      'Importing health data';

  @override
  String get healthDashboardImportHealthConnectProgressStatus =>
      'Fetching records from Health Connect...';

  @override
  String healthDashboardImportHealthConnectProgressCount(int count) {
    return 'Fetched $count records so far';
  }

  @override
  String get healthDashboardImportHealthConnectProgressHint =>
      'The import keeps running in the background with a notification. You can switch away or turn the screen off.';

  @override
  String get healthDashboardHealthConnectAnalysisProgressTitle =>
      'Exporting Health Connect analysis';

  @override
  String get healthDashboardHealthConnectAnalysisProgressStatus =>
      'Reading Health Connect records...';

  @override
  String healthDashboardHealthConnectAnalysisProgressCount(int count) {
    return 'Analyzed $count records';
  }

  @override
  String get healthDashboardHealthConnectAnalysisProgressHint =>
      'This does not change dashboard data. The export keeps running in the background with a notification.';

  @override
  String get healthDashboardSevenDayTotal => '7-Day Total';

  @override
  String get healthDashboardSevenDayAvg => '7-Day Avg';

  @override
  String get healthDashboardSevenDayMin => '7-Day Min';

  @override
  String get healthDashboardSevenDayMax => '7-Day Max';

  @override
  String get healthDashboardNightAvg => 'Night Avg';

  @override
  String get healthDashboardNightMin => 'Night Min';

  @override
  String get healthDashboardNightMax => 'Night Max';

  @override
  String get healthDashboardDayTotal => 'Day Total';

  @override
  String get healthDashboardDayAvg => 'Day Avg';

  @override
  String get healthDashboardDayMin => 'Day Min';

  @override
  String get healthDashboardDayMax => 'Day Max';

  @override
  String get healthDashboardWorkoutDayTotals => 'Day total';

  @override
  String get healthDashboardWorkoutSessions => 'Sessions';

  @override
  String get healthDashboardPace => 'Pace';

  @override
  String get healthDashboardAverage => 'Average';

  @override
  String get healthDashboardMinimum => 'Minimum';

  @override
  String get healthDashboardMaximum => 'Maximum';

  @override
  String get healthDashboardAvgHeartRate => 'Avg heart rate';

  @override
  String get healthDashboardMaxHeartRate => 'Max heart rate';

  @override
  String get healthDashboardAvgSpeed => 'Avg speed';

  @override
  String get healthDashboardMaxSpeed => 'Max speed';

  @override
  String get healthDashboardCadence => 'Cadence';

  @override
  String get healthDashboardPower => 'Power';

  @override
  String get healthDashboardDuringWorkout => 'During the workout';

  @override
  String get healthDashboardLaps => 'Laps';

  @override
  String healthDashboardLap(int number) {
    return 'Lap $number';
  }

  @override
  String get healthDashboardSpeed => 'Speed';

  @override
  String get healthDashboardCount => 'Count';

  @override
  String get healthDashboardBloodPressure => 'Blood Pressure';

  @override
  String get healthDashboardPercentage => 'Percentage';

  @override
  String get healthDashboardFloors => 'Floors';

  @override
  String get healthDashboardDuration => 'Duration';

  @override
  String get treadmillSyncToHealthConnect => 'Sync workouts to Health Connect';

  @override
  String get treadmillSyncToHealthConnectSubtitle =>
      'Write treadmill run sessions to Health Connect when finished.';

  @override
  String get healthDashboardCloudBackendSync => 'Cloud Backend Sync';

  @override
  String get healthDashboardHealthConnectSettings => 'Health Connect';

  @override
  String get healthDashboardHealthConnectSettingsSubtitle =>
      'Permissions, import, automatic sync on open, and starting the import over.';

  @override
  String get healthDashboardHealthConnectOpenFailed =>
      'Could not open Health Connect settings';

  @override
  String get healthDashboardHealthConnectImportFailed =>
      'Health Connect import failed';

  @override
  String get healthDashboardHealthConnectRepairFailed =>
      'Health Connect repair failed';

  @override
  String get healthDashboardHrv => 'HRV (RMSSD)';

  @override
  String get healthDashboardOxygenSaturation => 'Oxygen Saturation';

  @override
  String get healthDashboardRespiratoryRate => 'Respiratory Rate';

  @override
  String get healthDashboardBodyFat => 'Body Fat';

  @override
  String get healthDashboardBloodGlucose => 'Blood Glucose';

  @override
  String get healthDashboardBmr => 'BMR';

  @override
  String get healthDashboardVo2Max => 'VO2 Max';

  @override
  String get healthDashboardLatestOxygenSaturation =>
      'Latest Oxygen Saturation';

  @override
  String get healthDashboardLatestRespiratoryRate => 'Latest Respiratory Rate';

  @override
  String get healthDashboardLatestBodyFat => 'Latest Body Fat';

  @override
  String get healthDashboardHrvTrend => 'HRV (RMSSD) · last 7 days';

  @override
  String get healthDashboardOxygenSaturationTrend =>
      'Oxygen Saturation (SpO2) · last 7 days';

  @override
  String get healthDashboardRespiratoryRateTrend =>
      'Respiratory Rate · last 7 days';

  @override
  String get healthDashboardWeightBodyFatTrend =>
      'Weight & Body Fat · last 7 days';

  @override
  String get healthDashboardChartNoData => 'No data';

  @override
  String get healthDashboardLoadMore => 'Load more';

  @override
  String get healthDashboardScrollToTop => 'Scroll to top';

  @override
  String healthDashboardShowMoreRecords(int count) {
    return 'Show 100 more ($count remaining)';
  }

  @override
  String get healthDashboardLoadMoreRecords => 'Load more records…';

  @override
  String get healthDashboardHeight => 'Height';

  @override
  String get healthDashboardHydration => 'Hydration';

  @override
  String get healthDashboardBmi => 'BMI';

  @override
  String healthDashboardNoMetricDataInWeek(String metric) {
    return 'No $metric in these 7 days';
  }

  @override
  String get healthDashboardNoMetricDataInWeekHint =>
      'Pick another day, or check that the type and its source are switched on.';

  @override
  String get healthDashboardBackToToday => 'Back to today';

  @override
  String healthDashboardNoMetricHistory(String metric) {
    return 'Nothing stored for $metric';
  }

  @override
  String get healthDashboardNoMetricHistoryHint =>
      'Import this type from Health Connect to fill the history.';

  @override
  String get healthDashboardNoWorkoutsOnDay => 'No workouts on this day';

  @override
  String get healthDashboardNoSleepOnDay => 'No sleep recorded for this day';

  @override
  String get healthDashboardSleepQuality => 'Sleep quality';

  @override
  String get healthDashboardSleepQualityDisclaimer =>
      'Compared against general adult sleep-study ranges. Not a medical assessment.';

  @override
  String get healthDashboardSleepRatingGood => 'Good';

  @override
  String get healthDashboardSleepRatingFair => 'Fair';

  @override
  String get healthDashboardSleepRatingPoor => 'Poor';

  @override
  String healthDashboardSleepScore(int score) {
    return '$score of 100';
  }

  @override
  String get healthDashboardSleepAsleep => 'Asleep';

  @override
  String get healthDashboardSleepTimeInBed => 'In bed';

  @override
  String get healthDashboardSleepEfficiency => 'Efficiency';

  @override
  String get healthDashboardSleepAwakenings => 'Awake';

  @override
  String get healthDashboardSleepFindingAllInRange =>
      'Duration, efficiency and stage shares are all in their usual ranges.';

  @override
  String get healthDashboardSleepFindingDurationShort =>
      'Less than 7 h asleep. Adults usually need 7-9 h.';

  @override
  String get healthDashboardSleepFindingDurationLong =>
      'More than 10 h asleep, well above the usual 7-9 h.';

  @override
  String get healthDashboardSleepFindingEfficiencyLow =>
      'Sleep efficiency below 85 %: a lot of the time in bed was spent awake.';

  @override
  String get healthDashboardSleepFindingDeepLow =>
      'Deep sleep below 13 % of the night (usual range 13-23 %).';

  @override
  String get healthDashboardSleepFindingDeepHigh =>
      'Deep sleep above 23 % of the night (usual range 13-23 %).';

  @override
  String get healthDashboardSleepFindingRemLow =>
      'REM below 20 % of the night (usual range 20-25 %).';

  @override
  String get healthDashboardSleepFindingRemHigh =>
      'REM above 25 % of the night (usual range 20-25 %).';

  @override
  String get healthDashboardSleepFindingAwakeHigh =>
      'More than 30 minutes awake after falling asleep.';

  @override
  String get healthDashboardSectionMaintenance => 'Maintenance';

  @override
  String get healthDashboardSectionMaintenanceHint =>
      'Reclaims space. These actions delete stored rows.';

  @override
  String get healthDashboardPruneUnused => 'Clean up and shrink database';

  @override
  String get healthDashboardPruneUnusedSubtitle =>
      'Deletes rows nothing reads any more, then rewrites the file';

  @override
  String healthDashboardPruneUnusedConfirm(String apps) {
    return 'Deletes every row written by switched-off apps ($apps), plus orphaned rows and unused labels, then rewrites the database file. Switching those apps back on will not bring the data back - only a fresh import will. This cannot be undone.';
  }

  @override
  String get healthDashboardPruneUnusedConfirmNoApps =>
      'No app is switched off, so only orphaned rows and unused labels are removed before the database file is rewritten. This cannot be undone.';

  @override
  String get healthDashboardPruneUnusedConfirmAction => 'Clean up';

  @override
  String healthDashboardPruneUnusedDone(int rows) {
    return '$rows rows removed, database rewritten';
  }

  @override
  String get healthDashboardPruneUnusedFailed =>
      'Cleaning up the health database failed';

  @override
  String get healthDashboardManageFellBack =>
      'Health Connect has no settings screen on this device, so app info opened instead.';

  @override
  String get healthDashboardPermissionNeeded => 'Health Connect access needed';

  @override
  String get healthDashboardPermissionNeededBody =>
      'Nothing was granted, so there is nothing to read. Grant read access in Health Connect, then start the import again.';

  @override
  String get healthDashboardOpenHealthConnect => 'Open Health Connect';

  @override
  String get healthDashboardMetaApp => 'App';

  @override
  String get healthDashboardMetaPackage => 'Package';

  @override
  String get healthDashboardMetaOurType => 'Our type';

  @override
  String get healthDashboardMetaMetricKey => 'Metric key';

  @override
  String get healthDashboardMetaRecordType => 'Health Connect type';

  @override
  String get healthDashboardMetaActivity => 'Activity';

  @override
  String get healthDashboardMetaUnit => 'Stored unit';

  @override
  String get healthDashboardMetaAggregation => 'Daily aggregation';

  @override
  String get healthDashboardMetaShape => 'Storage shape';

  @override
  String get healthDashboardMetaSource => 'Ingested via';

  @override
  String get healthDashboardMetaRowId => 'Row id';

  @override
  String get healthDashboardMetaOrigin => 'Health Connect record id';

  @override
  String get healthDashboardMetaClientId => 'Client record id';

  @override
  String get healthDashboardMetaDevice => 'Device';

  @override
  String get healthDashboardMetaDuplicateOf => 'Duplicate of';

  @override
  String get healthDashboardMetaStart => 'Starts';

  @override
  String get healthDashboardMetaEnd => 'Ends';

  @override
  String get healthDashboardMetaDuration => 'Spans';

  @override
  String get healthDashboardMetaAggregateIncluded => 'Counts in totals';

  @override
  String get healthDashboardMetaSynced => 'Synced to backend';

  @override
  String get healthDashboardMetaDeleted => 'Deleted';

  @override
  String get healthDashboardMetaRawValues => 'Stored values';

  @override
  String get healthDashboardSectionDebug => 'Debug';

  @override
  String get healthDebugSourceGenerated => 'Generated test data';

  @override
  String get healthDebugSeedTitle => 'Generated test data';

  @override
  String get healthDebugSeedSubtitle =>
      'Fill Health Connect with a synthetic history';

  @override
  String get healthDebugSeedWarning =>
      'Debug builds only. Records are written into Health Connect as this app, marked as generated, and can be removed again below.';

  @override
  String get healthDebugSeedRange => 'Time range';

  @override
  String healthDebugSeedDays(int count) {
    return '$count days';
  }

  @override
  String get healthDebugSeedPresets => 'Presets';

  @override
  String get healthDebugSeedPresetsHint =>
      'A preset only picks a set of groups — adjust them below.';

  @override
  String get healthDebugSeedGroups => 'Data groups';

  @override
  String get healthDebugSeedActions => 'Actions';

  @override
  String get healthDebugSeedGenerate => 'Generate data';

  @override
  String get healthDebugSeedGenerateSubtitle =>
      'Writes day by day and replaces days already generated';

  @override
  String healthDebugSeedGenerateConfirm(int days, int groups) {
    return 'Write $days day(s) of generated data across $groups group(s) into Health Connect?';
  }

  @override
  String get healthDebugSeedGenerateAction => 'Generate';

  @override
  String healthDebugSeedProgress(int count) {
    return '$count record(s)...';
  }

  @override
  String healthDebugSeedDone(int count) {
    return 'Wrote $count record(s)';
  }

  @override
  String healthDebugSeedPartial(int written, int failed) {
    return 'Wrote $written record(s), $failed failed';
  }

  @override
  String get healthDebugSeedClear => 'Remove generated data';

  @override
  String get healthDebugSeedClearSubtitle =>
      'Deletes only records this generator wrote';

  @override
  String get healthDebugSeedClearConfirm =>
      'Delete every generated record from Health Connect and drop its rows from the store? Real data stays.';

  @override
  String get healthDebugSeedClearAction => 'Remove';

  @override
  String healthDebugSeedClearDone(int count) {
    return 'Removed $count record(s)';
  }

  @override
  String get healthDebugSeedNoGroups => 'Select at least one data group';

  @override
  String get healthDebugSeedNoPermission =>
      'Health Connect access was declined';

  @override
  String get healthDebugSeedFailed =>
      'Health Connect refused the run — check the log';

  @override
  String get healthDebugSeedUnsupported =>
      'Health Connect is only available on Android';

  @override
  String get healthDebugSeedImportHint =>
      'Generated data lands in Health Connect, not in the dashboard. Run Scan sources, then Restart import, to pull it in.';

  @override
  String get healthDebugPresetEveryday => 'Everyday';

  @override
  String get healthDebugPresetAthlete => 'Athlete';

  @override
  String get healthDebugPresetClinical => 'Clinical';

  @override
  String get healthDebugPresetEverything => 'Everything';

  @override
  String get healthDebugGroupActivity =>
      'Activity — steps, distance, energy, floors';

  @override
  String get healthDebugGroupHeart => 'Heart — rate series, resting rate, HRV';

  @override
  String get healthDebugGroupSleep => 'Sleep — one night per day with stages';

  @override
  String get healthDebugGroupWorkouts => 'Workouts — three sessions a week';

  @override
  String get healthDebugGroupBody =>
      'Body — weight, body fat, lean mass, height';

  @override
  String get healthDebugGroupVitals =>
      'Vitals — oxygen, breathing, pressure, glucose';

  @override
  String get healthDebugGroupHydration =>
      'Hydration — drinks spread over the day';

  @override
  String get toolNameSqliteViewer => 'SQLite Viewer';

  @override
  String get toolDescSqliteViewer =>
      'Inspect SQLite databases: schema, tables and free SQL';

  @override
  String get sqliteViewerOpenTitle => 'Open a SQLite database';

  @override
  String get sqliteViewerDropSubtitle =>
      'Drop a .db file here or browse for one';

  @override
  String get sqliteViewerTypeLabel => 'SQLite database';

  @override
  String get sqliteViewerInternalTitle => 'ToolLab databases';

  @override
  String get sqliteViewerInternalSubtitle =>
      'Opened as a read-only copy so the running app is not disturbed';

  @override
  String get sqliteViewerNoInternal => 'No ToolLab databases found';

  @override
  String get sqliteViewerAppDatabase => 'app database';

  @override
  String get sqliteViewerErrorMissing => 'The file no longer exists.';

  @override
  String get sqliteViewerErrorNotSqlite =>
      'This file is not a SQLite database.';

  @override
  String get sqliteViewerErrorLocked =>
      'The database is locked or cannot be read.';

  @override
  String sqliteViewerErrorUnknown(String detail) {
    return 'The database could not be opened: $detail';
  }

  @override
  String get sqliteViewerTabOverview => 'Overview';

  @override
  String get sqliteViewerTabData => 'Data';

  @override
  String get sqliteViewerTabSql => 'SQL';

  @override
  String get sqliteViewerSectionFile => 'File';

  @override
  String get sqliteViewerSectionPragmas => 'Database parameters';

  @override
  String get sqliteViewerFileName => 'Name';

  @override
  String get sqliteViewerFileSize => 'Size';

  @override
  String get sqliteViewerFilePath => 'Path';

  @override
  String get sqliteViewerSqliteVersion => 'SQLite version';

  @override
  String get sqliteViewerPageSize => 'Page size';

  @override
  String get sqliteViewerPageCount => 'Pages';

  @override
  String get sqliteViewerFreelistPages => 'Free pages';

  @override
  String get sqliteViewerEncoding => 'Encoding';

  @override
  String get sqliteViewerJournalMode => 'Journal mode';

  @override
  String get sqliteViewerAutoVacuum => 'Auto vacuum';

  @override
  String get sqliteViewerUserVersion => 'User version';

  @override
  String get sqliteViewerApplicationId => 'Application ID';

  @override
  String get sqliteViewerObjects => 'Objects';

  @override
  String get sqliteViewerTables => 'Tables';

  @override
  String get sqliteViewerViews => 'Views';

  @override
  String get sqliteViewerIndexes => 'Indexes';

  @override
  String get sqliteViewerTriggers => 'Triggers';

  @override
  String get sqliteViewerNoObjects => 'This database has no tables or views.';

  @override
  String get sqliteViewerSelectObject => 'Select a table or view.';

  @override
  String get sqliteViewerIntegrityTitle => 'Integrity';

  @override
  String get sqliteViewerRunIntegrityCheck => 'Run integrity check';

  @override
  String get sqliteViewerIntegrityOk => 'Intact';

  @override
  String get sqliteViewerIntegrityFailed => 'Problems found';

  @override
  String get sqliteViewerIntegrityEmpty => 'Not checked yet';

  @override
  String get sqliteViewerSchema => 'Schema';

  @override
  String get sqliteViewerDdl => 'Definition (DDL)';

  @override
  String get sqliteViewerForeignKeys => 'Foreign keys';

  @override
  String get sqliteViewerPrimaryKey => 'PK';

  @override
  String get sqliteViewerNotNull => 'NOT NULL';

  @override
  String get sqliteViewerUnique => 'UNIQUE';

  @override
  String sqliteViewerDefaultValue(String value) {
    return 'default $value';
  }

  @override
  String get sqliteViewerSearchHint => 'Filter rows…';

  @override
  String sqliteViewerRowRange(String start, String end, String total) {
    return '$start – $end of $total';
  }

  @override
  String get sqliteViewerPreviousPage => 'Previous page';

  @override
  String get sqliteViewerNextPage => 'Next page';

  @override
  String get sqliteViewerNoRows => 'No rows';

  @override
  String get sqliteViewerAddRow => 'Insert row';

  @override
  String get sqliteViewerDeleteRow => 'Delete row';

  @override
  String get sqliteViewerDeleteRowConfirm =>
      'Delete this row? This cannot be undone.';

  @override
  String get sqliteViewerWriteFailed => 'The change could not be written.';

  @override
  String get sqliteViewerNull => 'NULL';

  @override
  String get sqliteViewerSetNull => 'Set NULL';

  @override
  String get sqliteViewerEmptyValue => 'Empty value';

  @override
  String get sqliteViewerShowImage => 'Open image';

  @override
  String get sqliteViewerEditModeOn => 'Edit mode on';

  @override
  String get sqliteViewerEditModeOff => 'Read-only';

  @override
  String get sqliteViewerEditModeBanner =>
      'Edit mode: changes are written immediately and cannot be undone.';

  @override
  String get sqliteViewerReadOnlyNotice =>
      'Read-only. Enable edit mode to change data.';

  @override
  String get sqliteViewerSnapshotNotice =>
      'Working on a copy — changes do not reach the original file.';

  @override
  String get sqliteViewerInternalNotice =>
      'A ToolLab database, opened read-only as a copy.';

  @override
  String get sqliteViewerEnableEditTitle => 'Enable edit mode?';

  @override
  String get sqliteViewerEnableEditMessage =>
      'Writes go straight into the database file and cannot be undone.';

  @override
  String get sqliteViewerEnableEditMessageCopy =>
      'Writes go into the working copy, not the original file. Save a copy afterwards to keep the changes.';

  @override
  String get sqliteViewerEnable => 'Enable';

  @override
  String get sqliteViewerEditNotPossible =>
      'This database cannot be opened for writing.';

  @override
  String get sqliteViewerEditNotAllowedInternal =>
      'ToolLab\'s own databases stay read-only here.';

  @override
  String get sqliteViewerSaveCopy => 'Save modified copy';

  @override
  String get sqliteViewerSaveCopyFailed =>
      'The working copy is no longer available.';

  @override
  String get sqliteViewerSqlHint => 'SELECT * FROM ...';

  @override
  String get sqliteViewerSqlIdle => 'Run a statement to see its result.';

  @override
  String get sqliteViewerRun => 'Run';

  @override
  String get sqliteViewerQueryEmpty => 'Enter a statement first.';

  @override
  String get sqliteViewerReadOnlyRefusal =>
      'Read-only: only SELECT, EXPLAIN and reading PRAGMA statements run.';

  @override
  String get sqliteViewerConfirmWriteTitle => 'Run this statement?';

  @override
  String get sqliteViewerConfirmWriteMessage =>
      'It modifies the database and cannot be undone.';

  @override
  String sqliteViewerRowsReturned(String count, String ms) {
    return '$count rows in $ms ms';
  }

  @override
  String sqliteViewerRowsAffected(String count, String ms) {
    return '$count rows affected in $ms ms';
  }

  @override
  String sqliteViewerStatementDone(String ms) {
    return 'Statement executed in $ms ms';
  }

  @override
  String sqliteViewerTruncated(String count) {
    return 'Only the first $count rows are shown.';
  }

  @override
  String get sqliteViewerSqlError => 'SQL error';
}
