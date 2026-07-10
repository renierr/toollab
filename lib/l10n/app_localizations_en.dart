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
  String get imgViewDropZoneSubtitle => 'Supports PNG, JPEG, WebP, BMP, GIF';

  @override
  String get imgViewTypeLabel => 'Images';

  @override
  String get imgViewBrowseFiles => 'Browse Files';

  @override
  String get imgViewPasteFromClipboard => 'Paste from Clipboard';

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
  String get notesTabWrite => 'Write';

  @override
  String get notesTabPreview => 'Preview';

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
  String get toolDescChiptune =>
      'Play MOD, XM, IT tracker modules and WAV, MP3, OGG audio';

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
  String get toolNameSoundFinder => 'Sound Finder';

  @override
  String get toolDescSoundFinder =>
      'Locate, mask and generate room sounds with the microphone';

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
  String get sfTrackerHint =>
      'Slowly walk around the room. The meter and guidance react to how loud the sound gets — louder means you\'re closer.';

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
  String get sfZoomHint =>
      'Pinch or scroll to zoom · drag to pan · double-tap to reset';

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
  String get sfResFast => 'Fast';

  @override
  String get sfResBalanced => 'Balanced';

  @override
  String get sfResFine => 'Fine';

  @override
  String sfBinWidth(String hz) {
    return '≈ $hz Hz per bin';
  }
}
