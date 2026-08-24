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
  String get settingsLowLatencyAudio => 'Audio mit geringer Latenz';

  @override
  String get settingsLowLatencyAudioSubtitle =>
      'Ermöglicht eine schnellere Audiowiedergabe. Deaktivieren, wenn die Bildschirmaufnahme stumm ist';

  @override
  String get settingsSortBy => 'Sortieren nach';

  @override
  String get settingsSortRecent => 'Zuletzt verwendet';

  @override
  String get settingsSortDefaultOrder => 'Standardreihenfolge';

  @override
  String get settingsSortName => 'Name';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get commonClose => 'Schließen';

  @override
  String get commonOk => 'OK';

  @override
  String get commonYes => 'Ja';

  @override
  String get commonNo => 'Nein';

  @override
  String get commonClear => 'Leeren';

  @override
  String get commonEdit => 'Bearbeiten';

  @override
  String get commonShare => 'Teilen';

  @override
  String get commonExport => 'Exportieren';

  @override
  String get commonImport => 'Importieren';

  @override
  String get commonCopy => 'Kopieren';

  @override
  String get commonError => 'Fehler';

  @override
  String get commonLoading => 'Wird geladen…';

  @override
  String get commonRetry => 'Erneut versuchen';

  @override
  String get commonRename => 'Umbenennen';

  @override
  String get commonAdd => 'Hinzufügen';

  @override
  String get commonRemove => 'Entfernen';

  @override
  String get commonReset => 'Zurücksetzen';

  @override
  String get commonDone => 'Fertig';

  @override
  String get commonApply => 'Anwenden';

  @override
  String get commonOpen => 'Öffnen';

  @override
  String get commonSettings => 'Einstellungen';

  @override
  String get commonSearch => 'Suchen';

  @override
  String get commonConfirm => 'Bestätigen';

  @override
  String get commonBack => 'Zurück';

  @override
  String get commonHome => 'Startseite';

  @override
  String get commonBrowseFiles => 'Dateien durchsuchen';

  @override
  String get backgroundTaskOff => 'Aus';

  @override
  String backgroundTaskEveryMinutes(int minutes) {
    return 'Alle $minutes Minuten';
  }

  @override
  String backgroundTaskEveryHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Alle $hours Stunden',
      one: 'Jede Stunde',
    );
    return '$_temp0';
  }

  @override
  String get backgroundTaskEveryDay => 'Einmal täglich';

  @override
  String get backgroundTaskRunNow => 'Jetzt ausführen';

  @override
  String get backgroundTaskNeverRun => 'Noch nicht gelaufen';

  @override
  String backgroundTaskLastRun(String when, String detail) {
    return 'Letzter Lauf $when: $detail';
  }

  @override
  String get backgroundTaskDozeHint =>
      'Wann ein Hintergrundlauf wirklich stattfindet, entscheidet Android. Das Intervall ist eine Obergrenze, keine Zusage - im Tiefschlaf kann ein Lauf Stunden zu spät kommen.';

  @override
  String chipFailedToParseModule(Object error) {
    return 'Modul konnte nicht geladen werden: $error';
  }

  @override
  String chipFailedToOpenSharedFile(Object error) {
    return 'Geteilte Datei konnte nicht geöffnet werden: $error';
  }

  @override
  String get chipUnsupportedAudioOpenedInternally =>
      'Mit dem internen Audioplayer geöffnet';

  @override
  String get chipUnsupportedAudioFormat =>
      'Dieses Audioformat kann auf diesem Gerät nicht abgespielt werden';

  @override
  String chipAudioPlaybackFailed(Object error) {
    return 'Audiowiedergabe fehlgeschlagen: $error';
  }

  @override
  String get chipHideVisualizer => 'Visualisierung ausblenden';

  @override
  String get chipShowVisualizer => 'Visualisierung einblenden';

  @override
  String get chipLoadFiles => 'Dateien laden';

  @override
  String get chipModuleArchived => 'Modul archiviert';

  @override
  String get chipAlreadyInArchive => 'Bereits im Archiv';

  @override
  String get chipArchivedModuleNotFound => 'Archiviertes Modul nicht gefunden';

  @override
  String get chipModuleDataNotAvailable => 'Moduldaten nicht verfügbar';

  @override
  String get chipDeleteModuleTitle => 'Modul löschen';

  @override
  String get chipDeleteModuleMessage =>
      'Dieses Modul aus dem Archiv entfernen?';

  @override
  String chipSyncedResult(Object pulled, Object pushed) {
    return 'Synchronisiert: $pulled empfangen, $pushed gesendet';
  }

  @override
  String chipSyncFailed(Object error) {
    return 'Synchronisierung fehlgeschlagen: $error';
  }

  @override
  String chipArchiveTitle(Object count) {
    return 'Archiv ($count)';
  }

  @override
  String get chipSyncTooltip => 'Synchronisieren';

  @override
  String get chipNoArchivedModules => 'Keine archivierten Module';

  @override
  String get chipDownloadTooltip => 'Herunterladen';

  @override
  String get chipUntitled => 'Ohne Titel';

  @override
  String get chipMetricChannels => 'Kanäle';

  @override
  String get chipMetricPatterns => 'Muster';

  @override
  String get chipMetricOrders => 'Positionen';

  @override
  String get chipMetricInstruments => 'Instrumente';

  @override
  String get chipMetricBpm => 'BPM';

  @override
  String get chipMetricSpeed => 'Tempo';

  @override
  String get chipEmptyDropTitle => 'Tracker-Modul hier ablegen';

  @override
  String get chipEmptyDropSubtitle => 'MOD- · XM- · IT-Dateien';

  @override
  String get chipEmptyTypeLabel => 'Tracker-Modul';

  @override
  String get chipNotificationTitle => 'Chiptune-Wiedergabe aktiv';

  @override
  String get chipNotificationText =>
      'ToolLab hält die Audiowiedergabe im Hintergrund aufrecht';

  @override
  String get treadmillNotificationTitle => 'Laufband-Training aktiv';

  @override
  String get treadmillNotificationText =>
      'ToolLab zeichnet deine Sitzung weiter auf';

  @override
  String get chipPauseTooltip => 'Pause';

  @override
  String get chipPlayTooltip => 'Abspielen';

  @override
  String get chipStopTooltip => 'Stopp';

  @override
  String get chipLoopingTooltip => 'Schleife aktiv';

  @override
  String get chipLoopOffTooltip => 'Schleife aus';

  @override
  String get chipRandomTooltip => 'Zufälliges Stück von The Mod Archive';

  @override
  String get chipNextRandomTooltip => 'Nächstes Zufallsstück';

  @override
  String get chipNextTrackTooltip => 'Nächster Titel';

  @override
  String get chipMiniPlayerTooltip => 'Läuft gerade';

  @override
  String get chipMiniOpenPlayer => 'Player öffnen';

  @override
  String get chipRandomMenuTooltip => 'Zufälliges Stück';

  @override
  String get chipRandomSourceLabel => 'Quelle';

  @override
  String get chipRandomSourceModArchive => 'The Mod Archive';

  @override
  String get chipRandomSourceServer => 'Meine Sammlung (Server)';

  @override
  String chipServerRandomFailed(Object error) {
    return 'Sammlung konnte nicht geladen werden: $error';
  }

  @override
  String chipPlaylistTitle(Object count) {
    return 'Wiedergabeliste ($count)';
  }

  @override
  String get chipFolderTooltip => 'Ordner abspielen';

  @override
  String get chipFolderEmpty =>
      'Keine abspielbaren Moduldateien in diesem Ordner';

  @override
  String get chipPlaylistNoSupported =>
      'Keine unterstützten Moduldateien ausgewählt';

  @override
  String get chipSelectOutputDevice => 'Ausgabegerät auswählen';

  @override
  String get chipTweaks => 'Feineinstellungen';

  @override
  String get chipInterpolation => 'Interpolation';

  @override
  String get chipInterpolationSinc => 'Sinc (am klarsten)';

  @override
  String get chipInterpolationCubic => 'Kubisch (weich)';

  @override
  String get chipInterpolationLinear => 'Linear (hell)';

  @override
  String get chipInterpolationNone => 'Keine (roh)';

  @override
  String get chipPreAmp => 'Vorverstärkung';

  @override
  String get chipAmigaFilter => 'Amiga-Filter';

  @override
  String get chipAmigaFilterAuto => 'Auto';

  @override
  String get chipAmigaFilterOn => 'An';

  @override
  String get chipAmigaFilterOff => 'Aus';

  @override
  String get chipVolumeRamping => 'Lautstärke-Rampe';

  @override
  String get chipRampOff => 'Aus';

  @override
  String get chipRampFast => 'Schnell';

  @override
  String get chipRampSmooth => 'Weich';

  @override
  String get chipStereoSeparation => 'Stereo-Trennung';

  @override
  String get chipDefaultDevice => 'Standardgerät';

  @override
  String chipOutputDeviceChanged(Object name) {
    return 'Ausgabegerät geändert auf $name';
  }

  @override
  String get chipRandomTitle => 'Zufälliges Stück';

  @override
  String get chipRandomFetching =>
      'Zufälliges Stück von The Mod Archive wird geladen…';

  @override
  String chipRandomFetchFailed(Object error) {
    return 'Zufälliges Stück konnte nicht geladen werden: $error';
  }

  @override
  String get chipRandomRetry => 'Erneut versuchen';

  @override
  String get chipRandomShuffleAgain => 'Neu mischen';

  @override
  String get chipRandomCredits =>
      'Quelle: The Mod Archive — eine freie Sammlung von Tracker-Musik. Alle Rechte liegen bei den ursprünglichen Künstlern.';

  @override
  String chipRandomSourceLink(Object moduleId) {
    return 'Modul #$moduleId auf modarchive.org ansehen';
  }

  @override
  String get chipMetricFormat => 'Format';

  @override
  String get chipMetricGenre => 'Genre';

  @override
  String get chipMetricSize => 'Größe';

  @override
  String get chipMetricDuration => 'Dauer';

  @override
  String get chipAudioFile => 'Audiodatei';

  @override
  String get chipStereoWidth => 'Stereobreite';

  @override
  String get chipExportToWav => 'Nach WAV exportieren';

  @override
  String get chipExportingToWav => 'Nach WAV exportieren…';

  @override
  String get chipExportSuccess => 'WAV-Datei erfolgreich exportiert';

  @override
  String chipExportFailed(String error) {
    return 'WAV-Export fehlgeschlagen: $error';
  }

  @override
  String coreNoToolsFoundToOpen(String name) {
    return 'Keine Tools gefunden zum Öffnen von \"$name\"';
  }

  @override
  String get coreAboutTitle => 'Über';

  @override
  String coreAboutVersion(String version) {
    return 'v$version';
  }

  @override
  String get coreAboutDescription =>
      'ToolLab ist eine Sammlung von Dienstprogrammen für Ihr Gerät. Es umfasst Sensoren, Rechner, Geräteinformationen, NFC-Tag-Lesen/-Schreiben, PDF-Anzeige, Notizen und vieles mehr – alles in einer App.';

  @override
  String get coreAboutDisclaimer => 'Haftungsausschluss';

  @override
  String get coreAboutDisclaimerText =>
      'Diese App wird ohne jegliche Gewährleistung bereitgestellt. Der Entwickler haftet nicht für Schäden, Datenverluste oder Probleme, die aus der Nutzung dieser Software entstehen.';

  @override
  String get coreAboutThirdPartyLicenses => 'Drittanbieter-Lizenzen';

  @override
  String get coreMaintenanceTitle => 'Wartungseinstellungen';

  @override
  String get coreDatabaseExportedAndroid =>
      'Datenbank erfolgreich in den Downloads-Ordner exportiert.';

  @override
  String coreDatabaseExportedGeneral(String path) {
    return 'Datenbank erfolgreich nach $path exportiert.';
  }

  @override
  String coreDatabaseExportFailed(String error) {
    return 'Datenbankexport fehlgeschlagen: $error';
  }

  @override
  String get coreSettingsExportedAndroid =>
      'Einstellungen erfolgreich in den Downloads-Ordner exportiert.';

  @override
  String coreSettingsExportedGeneral(String path) {
    return 'Einstellungen erfolgreich nach $path exportiert.';
  }

  @override
  String coreSettingsExportFailed(String error) {
    return 'Einstellungsexport fehlgeschlagen: $error';
  }

  @override
  String get coreDangerZoneTitle => 'Gefahrenzone';

  @override
  String get coreDatabaseImportButton => 'Datenbank importieren (.db)';

  @override
  String get coreDatabaseImportDescription =>
      'Stellt eine zuvor exportierte Datenbank wieder her. Dabei werden alle aktuellen Tool-Daten und Einstellungen unwiderruflich überschrieben.';

  @override
  String get coreDatabaseImportConfirmTitle => 'Datenbank importieren?';

  @override
  String get coreDatabaseImportConfirmMessage =>
      'Dadurch werden alle aktuellen Daten und Einstellungen unwiderruflich durch den Inhalt des ausgewählten Backups überschrieben und die App wird neu geladen. Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String coreDatabaseImportInvalid(String error) {
    return 'Ungültige oder inkompatible Datenbankdatei: $error';
  }

  @override
  String get coreDatabaseImportSuccess =>
      'Datenbank erfolgreich importiert. Deine Daten und Einstellungen wurden wiederhergestellt.';

  @override
  String coreDatabaseImportFailed(String error) {
    return 'Datenbankimport fehlgeschlagen: $error';
  }

  @override
  String coreDatabaseSize(String size) {
    return 'Aktuelle Datenbankgröße: $size';
  }

  @override
  String get coreDatabaseSizeLoading =>
      'Aktuelle Datenbankgröße: Wird geladen...';

  @override
  String get coreTempFilesTitle => 'Temporäre Dateien';

  @override
  String coreTempFilesUsage(int count, String size) {
    return '$count Datei(en), $size belegt';
  }

  @override
  String get coreTempFilesCleanUp => 'Temporäre Dateien bereinigen';

  @override
  String get coreTempFilesCleanedUp => 'Temporäre Dateien wurden bereinigt';

  @override
  String get coreShortcutsTitle => 'Tool-Verknüpfungen';

  @override
  String get coreShortcutsDirectAccessTitle => 'Direktzugriff-Starter';

  @override
  String get coreShortcutsDirectAccessSubtitle =>
      'Fügen Sie separate Home-Screen-Symbole oder App-Drawer-Einträge für Ihre Lieblingstools hinzu. Ein Tippen auf eine Verknüpfung öffnet die App direkt in diesem Tool.';

  @override
  String get coreShortcutsAndroidRequired =>
      'Android wird benötigt, um native Verknüpfungen anzuheften oder App-Drawer-Symbole zu verwalten. Änderungen werden lokal gespeichert, aber keine nativen Symbole werden verändert.';

  @override
  String get coreShortcutsSelectTools => 'Tools zur Konfiguration auswählen';

  @override
  String coreShortcutsPinRequested(String name) {
    return 'Verknüpfung für $name angefordert! Systemmeldung bestätigen.';
  }

  @override
  String coreShortcutsDrawerDisabled(String name) {
    return 'App-Drawer-Symbol für $name deaktiviert';
  }

  @override
  String coreShortcutsDrawerEnabled(String name) {
    return 'App-Drawer-Symbol für $name aktiviert (Aktualisierung in wenigen Sekunden).';
  }

  @override
  String get coreSyncTitle => 'Cloud-Synchronisierung';

  @override
  String get coreSyncAcrossDevicesTitle =>
      'Daten geräteübergreifend synchronisieren';

  @override
  String get coreSyncAcrossDevicesSubtitle =>
      'Mit der Cloud-Synchronisierung können Sie Ihre Tool-Daten sichern und nahtlos mit einem zentralen Server abgleichen.';

  @override
  String get coreSyncEnableTitle => 'Synchronisierung aktivieren';

  @override
  String get coreSyncActive => 'Synchronisierung aktiv';

  @override
  String get coreSyncDisabled => 'Synchronisierung deaktiviert';

  @override
  String get coreSyncStatsTitle => 'Server-Statistik';

  @override
  String get coreSyncStatsSubtitle => 'Was das Backend pro Tool speichert';

  @override
  String get coreSyncStatsRefresh => 'Aktualisieren';

  @override
  String get coreSyncStatsItems => 'Einträge';

  @override
  String get coreSyncStatsDeleted => 'Grabsteine';

  @override
  String get coreSyncStatsData => 'Daten';

  @override
  String get coreSyncStatsTotalSize => 'Gesamt';

  @override
  String get coreSyncStatsEmpty => 'Der Server speichert noch nichts.';

  @override
  String get coreSyncStatsUnsupported =>
      'Dieser Server liefert keine Statistik. Aktualisiere das Backend auf eine Version mit /api/sync/stats.';

  @override
  String coreSyncStatsBinary(int count) {
    return 'Binär ($count)';
  }

  @override
  String coreSyncStatsTotals(int count) {
    return '$count Tools auf dem Server';
  }

  @override
  String get coreSyncToolsTitle => 'Zu synchronisierende Tools';

  @override
  String get coreSyncToolsSubtitle =>
      'Wähle aus, welche Tools teilnehmen. Neue Tools sind aktiviert.';

  @override
  String get coreSyncToolsDisabledHint =>
      'Ein deaktiviertes Tool synchronisiert nicht mehr, behält seine Daten auf dem Server aber.';

  @override
  String get coreSyncToolDisabled =>
      'Die Synchronisierung ist für dieses Tool in den Sync-Einstellungen deaktiviert.';

  @override
  String get coreSyncBackgroundTitle => 'Hintergrund-Synchronisierung';

  @override
  String get coreSyncBackgroundSubtitle =>
      'Wie oft im Hintergrund eine vollständige Synchronisierung aller aktivierten Tools läuft, während die App geschlossen ist.';

  @override
  String get coreSyncServerCredentials => 'Server-Zugangsdaten';

  @override
  String get coreSyncServerBaseUrl => 'Server-Basis-URL';

  @override
  String get coreSyncServerUrlRequired =>
      'Server-URL ist erforderlich, wenn die Synchronisierung aktiviert ist';

  @override
  String get coreSyncUserId => 'Benutzer-ID (optional)';

  @override
  String get coreSyncUserIdHint =>
      'Benutzername oder Benutzer-ID eingeben (optional)';

  @override
  String get coreSyncStatusTitle => 'Synchronisierungsstatus';

  @override
  String get coreSyncNeverSynced => 'Noch nie synchronisiert';

  @override
  String coreSyncLastSynced(String dateTime) {
    return 'Zuletzt synchronisiert: $dateTime';
  }

  @override
  String get coreSyncSyncing => 'Synchronisierung läuft...';

  @override
  String get coreSyncNow => 'Jetzt synchronisieren';

  @override
  String coreSyncCompleted(String pulled, String pushed, String deleted) {
    return 'Synchronisierung abgeschlossen. Empfangen: $pulled, Gesendet: $pushed, Gelöscht: $deleted.';
  }

  @override
  String get coreSyncFailedNoUrl =>
      'Synchronisierung fehlgeschlagen. Server-URL ist leer.';

  @override
  String coreSyncFailed(String error) {
    return 'Synchronisierung fehlgeschlagen: $error';
  }

  @override
  String get coreSyncSaveConfiguration => 'Konfiguration speichern';

  @override
  String get coreSyncSettingsSaved => 'Einstellungen erfolgreich gespeichert';

  @override
  String coreSyncSettingsSaveFailed(String error) {
    return 'Einstellungen konnten nicht gespeichert werden: $error';
  }

  @override
  String get coreOverviewSearchHint => 'Tools suchen...';

  @override
  String get coreOverviewNoToolsFound => 'Keine Tools gefunden';

  @override
  String get coreSettingsDialogTitle => 'Übersichtseinstellungen';

  @override
  String get coreSettingsDialogSyncSubtitle =>
      'Tool-Daten sichern und mit der Cloud synchronisieren';

  @override
  String get coreSettingsDialogMaintenanceSubtitle =>
      'Datenbank-Backups und Einstellungen als JSON herunterladen';

  @override
  String get coreSettingsDialogShortcutsSubtitle =>
      'Verknüpfungen anheften oder App-Drawer-Symbole verwalten';

  @override
  String get coreSettingsDialogOpenWithSubtitle =>
      'Standard-Toolzuordnungen für geteilte Dateien verwalten';

  @override
  String get coreSettingsDialogAppearanceSubtitle =>
      'Design, kompakte Ansicht, Benachrichtigungen, Sortierung';

  @override
  String get coreSettingsDialogAboutSubtitle =>
      'Version, Lizenzen und App-Informationen';

  @override
  String get coreOpenWithDefaultsTitle => 'Standardmäßig öffnen mit';

  @override
  String get coreOpenWithResetTitle => 'Alle Standards zurücksetzen?';

  @override
  String get coreOpenWithResetContent =>
      'Dadurch werden alle „Immer öffnen mit“-Zuordnungen gelöscht. Beim nächsten Öffnen einer geteilten Datei erscheint wieder der Auswahldialog.';

  @override
  String get coreOpenWithNoDefaults => 'Keine Standardzuordnungen festgelegt.';

  @override
  String get coreOpenWithAssociationsLabel =>
      'Standard-Toolzuordnungen für geteilte Dateien:';

  @override
  String get coreOpenWithResetButton => 'Alle Standards zurücksetzen';

  @override
  String get coreOpenWithResetting => 'Wird zurückgesetzt...';

  @override
  String get coreOpenWithCleared => 'Standardzuordnungen wurden gelöscht';

  @override
  String get emfStartScanning => 'SCAN STARTEN';

  @override
  String get emfStopScanning => 'SCAN STOPPEN';

  @override
  String get emfAudioTick => 'AUDIO-TICK';

  @override
  String get emfScreenOn => 'DISPLAY AN';

  @override
  String get emfCableTriggerThreshold => 'KABEL-AUSLÖSESCHWELLE';

  @override
  String get emfScannerTitle => 'EMF-SCANNER';

  @override
  String get emfPro => 'PRO';

  @override
  String get emfWallCurrentSubtitle => 'STROMLEITUNGSORTUNG & FELDMESSUNG';

  @override
  String get emfSimulator => 'SIMULATOR';

  @override
  String get emfHardwareSensor => 'HARDWARE-SENSOR';

  @override
  String get emfOpenVirtualSensorToolbox =>
      'VIRTUELLES SENSOR-TOOLBOX ÖFFNEN (ENTWICKLER)';

  @override
  String get emfDeveloperSimulationLab => '🛠️ ENTWICKLER-SIMULATIONSLABOR';

  @override
  String get emfExitSim => 'SIM BEENDEN';

  @override
  String get emfSelectFieldScenarioPreset => 'FELDSZENARIO AUSWÄHLEN';

  @override
  String get emfPresetEarthNormal => 'Erdfeld Normal';

  @override
  String get emfPresetMainsWire => 'Stromleitung (AC)';

  @override
  String get emfPresetMagnetProximity => 'Magnetannäherung';

  @override
  String get emfPresetWalkDrift => 'Bewegungsdrift (Drift)';

  @override
  String get emfManualVectorAdjustments => 'MANUELLE X,Y,Z-VEKTORANPASSUNGEN';

  @override
  String get emfManualActive => 'MANUELL AKTIV';

  @override
  String get emfXOffset => 'X Versatz';

  @override
  String get emfYOffset => 'Y Versatz';

  @override
  String get emfZOffset => 'Z Versatz';

  @override
  String get emfThreeAxisVectorReadout => '3-ACHSEN-VEKTORANZEIGE';

  @override
  String get emfLiveSensors => 'LIVE-SENSOREN';

  @override
  String get emfPaused => 'PAUSIERT';

  @override
  String get fastDropPastingText => 'Text aus Zwischenablage wird eingefügt...';

  @override
  String get fastDropPastingImage =>
      'Bild aus Zwischenablage wird eingefügt...';

  @override
  String get fastDropClipboardEmpty =>
      'Kein Text- oder Bildinhalt in der Zwischenablage gefunden';

  @override
  String get fastDropUploadedSuccessfully => 'Erfolgreich hochgeladen!';

  @override
  String fastDropUploadingFiles(int count) {
    return '$count Dateien werden hochgeladen...';
  }

  @override
  String fastDropUploadingFileProgress(int current, int total, String name) {
    return '$current von $total wird hochgeladen: $name...';
  }

  @override
  String get fastDropSharedFilesUploaded =>
      'Geteilte Dateien erfolgreich hochgeladen!';

  @override
  String get fastDropDeleteTitle => 'Drop löschen';

  @override
  String fastDropDeleteMessage(String filename) {
    return 'Möchten Sie \"$filename\" wirklich löschen?';
  }

  @override
  String get fastDropDeletedSuccessfully => 'Erfolgreich gelöscht';

  @override
  String fastDropDeleteFailed(String error) {
    return 'Drop konnte nicht gelöscht werden: $error';
  }

  @override
  String fastDropDownloadingFile(String filename) {
    return '$filename wird heruntergeladen...';
  }

  @override
  String fastDropDownloadingFileToOpen(String filename) {
    return '$filename wird zum Öffnen heruntergeladen...';
  }

  @override
  String get fastDropDescriptionUpdated => 'Beschreibung aktualisiert';

  @override
  String get fastDropRetentionUpdated => 'Aufbewahrungsdauer aktualisiert';

  @override
  String get fastDropTitle => 'Fast Drop';

  @override
  String get fastDropStatusOnline => 'Online';

  @override
  String get fastDropStatusOffline => 'Offline';

  @override
  String get fastDropStatusSyncDisabled => 'Sync deaktiviert';

  @override
  String get fastDropStatusNotConfigured => 'Nicht konfiguriert';

  @override
  String get fastDropRefreshList => 'Liste aktualisieren';

  @override
  String get fastDropProgressUploading => 'Wird hochgeladen';

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
  String get fastDropProgressDownloading => 'Wird heruntergeladen';

  @override
  String get fastDropSectionTitle => 'ABGELEGTE DATEIEN';

  @override
  String get fastDropEditRetentionTitle => 'Aufbewahrungsdauer bearbeiten';

  @override
  String get fastDropEditDescriptionTitle => 'Beschreibung bearbeiten';

  @override
  String get fastDropDescriptionHint => 'Beschreibung hinzufügen...';

  @override
  String fastDropExpires(String date) {
    return 'Läuft ab: $date';
  }

  @override
  String get fastDropIndefiniteRetention => 'Unbegrenzte Aufbewahrung';

  @override
  String get fastDropClipboardBadge => 'ZWISCHENABLAGE';

  @override
  String fastDropUploaded(String date) {
    return 'Hochgeladen: $date';
  }

  @override
  String get fastDropAddDescriptionPlaceholder => 'Beschreibung hinzufügen...';

  @override
  String get fastDropPreviewTooltip => 'Vorschau';

  @override
  String get fastDropOpenShare => 'Öffnen / Teilen';

  @override
  String get fastDropDownload => 'Herunterladen';

  @override
  String get fastDropConnectionStatus => 'Verbindungsstatus';

  @override
  String get fastDropRetryConnection => 'Verbindung erneut versuchen';

  @override
  String get fastDropNoDropsTitle => 'Noch keine Drops';

  @override
  String get fastDropNoDropsSubtitle =>
      'Dateien hierher ziehen oder Inhalt aus der Zwischenablage einfügen, um ihn vorübergehend zu speichern.';

  @override
  String get fastDropDownloadingForPreview =>
      'Datei für Vorschau wird heruntergeladen...';

  @override
  String fastDropPreviewFailed(String error) {
    return 'Vorschau konnte nicht geladen werden:\n$error';
  }

  @override
  String fastDropReadFileFailed(String error) {
    return 'Fehler beim Lesen der Datei: $error';
  }

  @override
  String get fastDropPreviewNotAvailable =>
      'Für diesen Dateityp ist keine Vorschau verfügbar.';

  @override
  String get fastDropOpenWithApp => 'Mit App öffnen';

  @override
  String get fastDropNotConfiguredTitle => 'Sync-Server nicht konfiguriert';

  @override
  String get fastDropNotConfiguredBody =>
      'Fast Drop benötigt eine Verbindung zum Backend-Server. Bitte konfigurieren Sie die Sync-Server-URL in den Einstellungen, um Dateien zu teilen.';

  @override
  String get fastDropConfigureServer => 'Server konfigurieren';

  @override
  String get fastDropSyncDisabledTitle => 'Cloud-Sync ist deaktiviert';

  @override
  String get fastDropSyncDisabledBody =>
      'Fast Drop erfordert, dass Cloud-Sync in den Einstellungen aktiviert ist.';

  @override
  String get fastDropEnableButton => 'Aktivieren';

  @override
  String get fastDropConfigureServerBody =>
      'Bitte zuerst die Server-URL in den Cloud-Einstellungen konfigurieren.';

  @override
  String get fastDropServerUnreachable => 'Sync-Server nicht erreichbar';

  @override
  String get fastDropAllFiles => 'Alle Dateien';

  @override
  String get fastDropSelectFilesAndroid => 'Dateien zum Hochladen auswählen';

  @override
  String get fastDropDropFilesHere => 'Dateien hier ablegen';

  @override
  String get fastDropOrClickToBrowse => 'oder tippen, um zu durchsuchen';

  @override
  String get fastDropPasteClipboard => 'Zwischenablage einfügen';

  @override
  String get fastDropOpenFile => 'Öffnen';

  @override
  String get fastDropDownloadFile => 'Speichern';

  @override
  String get fastDropModeCloud => 'Cloud';

  @override
  String get fastDropModeNearby => 'In der Nähe';

  @override
  String get fastDropP2pStartReceiving => 'Empfang starten';

  @override
  String get fastDropP2pStopReceiving => 'Empfang stoppen';

  @override
  String get fastDropP2pWaitingForSender =>
      'Warte auf ein Gerät in der Nähe, das eine Datei sendet...';

  @override
  String get fastDropP2pAbortSend => 'Senden abbrechen';

  @override
  String get fastDropP2pWaitingForReceiver =>
      'Warte auf ein Gerät in der Nähe, das den Empfang startet...';

  @override
  String get fastDropP2pPeersFoundPickOne =>
      'Gerät gefunden — zum Senden unten auswählen';

  @override
  String fastDropP2pEstimateWifi(String duration) {
    return 'WLAN: $duration';
  }

  @override
  String fastDropP2pEstimateBluetooth(String duration) {
    return 'Bluetooth: $duration';
  }

  @override
  String get fastDropP2pSendSectionTitle => 'DATEI SENDEN';

  @override
  String get fastDropP2pReceivedSectionTitle => 'EMPFANGENE DATEIEN';

  @override
  String get fastDropP2pPickFileToSend => 'Datei zum Senden auswählen';

  @override
  String get fastDropP2pScanningForPeers => 'Suche nach Geräten in der Nähe...';

  @override
  String get fastDropP2pNoPeersFound =>
      'Noch keine Geräte gefunden. Stelle sicher, dass das andere Gerät auf \"Empfang starten\" getippt hat.';

  @override
  String fastDropP2pSignalStrength(int rssi) {
    return 'Signal: $rssi dBm';
  }

  @override
  String get fastDropP2pLocalNetwork => 'Lokales Netzwerk';

  @override
  String get fastDropP2pSend => 'Senden';

  @override
  String get fastDropP2pTransferringLan => 'Übertragung über WLAN';

  @override
  String get fastDropP2pTransferringBle => 'Übertragung über Bluetooth';

  @override
  String get fastDropP2pBleFallbackWarning =>
      'Kein gemeinsames Netzwerk gefunden — Übertragung über Bluetooth, was deutlich langsamer ist. Verbinde beide Geräte mit demselben WLAN für schnellere Übertragungen.';

  @override
  String get fastDropP2pIncomingTitle => 'Eingehende Datei';

  @override
  String fastDropP2pIncomingMessage(
    String sender,
    String filename,
    String size,
  ) {
    return '$sender möchte dir \"$filename\" ($size) senden. Übertragung annehmen?';
  }

  @override
  String get fastDropP2pAccept => 'Annehmen';

  @override
  String get fastDropP2pDecline => 'Ablehnen';

  @override
  String get fastDropP2pErrorBleConnect =>
      'Bluetooth-Verbindung zum Gerät konnte nicht aufgebaut werden. Bringe die Geräte näher zusammen, stelle sicher, dass das andere Gerät noch auf einen Sender wartet, und versuche es erneut.';

  @override
  String get fastDropP2pErrorDeclined =>
      'Das andere Gerät hat die Übertragung abgelehnt.';

  @override
  String get fastDropP2pErrorStalled =>
      'Die Bluetooth-Übertragung kam nicht mehr voran und wurde abgebrochen. Halte beide Geräte nah beieinander und wach, und starte die Übertragung erneut.';

  @override
  String get fastDropP2pDismissFile => 'Verwerfen';

  @override
  String get focusAutoStopTimer => 'Auto-Stopp-Timer';

  @override
  String get focusStartPlaybackToEnableTimer =>
      'Wiedergabe starten, um Timer zu aktivieren';

  @override
  String focusCustomMinutes(int minutes) {
    return 'Benutzerdefiniert: $minutes Min.';
  }

  @override
  String get focusSetTimer => 'Festlegen';

  @override
  String get focusCancelTimer => 'Timer abbrechen';

  @override
  String get focusBreathingGuide => 'Atemführung';

  @override
  String get focusStartBreathing => 'Atmung starten';

  @override
  String get focusStopBreathing => 'Atmung stoppen';

  @override
  String get focusSoundLibrary => 'Klangbibliothek';

  @override
  String get focusPlayback => 'Wiedergabe';

  @override
  String get focusStart => 'Start';

  @override
  String get focusStop => 'Stopp';

  @override
  String get focusNotificationTitle => 'Fokus-Geräusch aktiv';

  @override
  String get focusNotificationText =>
      'ToolLab hält die Hintergrundgeräusche aktiv';

  @override
  String get focusNoTimerSet => 'Kein Timer gesetzt';

  @override
  String get focusStopping => 'Wird gestoppt …';

  @override
  String focusWillStopIn(String time) {
    return 'Stoppt in $time';
  }

  @override
  String focusPlayingSound(String name) {
    return '$name wird abgespielt';
  }

  @override
  String focusPausedSound(String name) {
    return '$name pausiert';
  }

  @override
  String focusSelectedSound(String name) {
    return '$name ausgewählt';
  }

  @override
  String get img2pdfNoImageInClipboard =>
      'Kein Bild in der Zwischenablage gefunden';

  @override
  String img2pdfFailedReadClipboard(String error) {
    return 'Fehler beim Lesen der Zwischenablage: $error';
  }

  @override
  String get img2pdfSettingsTooltip => 'PDF-Einstellungen';

  @override
  String get img2pdfImagesLabel => 'Bilder';

  @override
  String get img2pdfDropTitle => 'Bilder hier ablegen';

  @override
  String get img2pdfDropSubtitle => 'Unterstützt PNG, JPEG, WebP, BMP, GIF';

  @override
  String get img2pdfBrowseFiles => 'Dateien durchsuchen';

  @override
  String get img2pdfPasteFromClipboard => 'Aus Zwischenablage einfügen';

  @override
  String get img2pdfPickFromGallery => 'Aus Galerie auswählen';

  @override
  String get img2pdfNoImagesYet => 'Noch keine Bilder hinzugefügt';

  @override
  String get img2pdfNoImagesHint =>
      'Bilder hier ablegen oder „Weitere hinzufügen“ wählen';

  @override
  String img2pdfPageNumber(int page) {
    return 'Seite $page';
  }

  @override
  String get img2pdfPdfSettings => 'PDF-Einstellungen';

  @override
  String get img2pdfPageSize => 'Seitengröße';

  @override
  String get img2pdfFitToImage => 'An Bild anpassen';

  @override
  String get img2pdfOrientation => 'Ausrichtung';

  @override
  String get img2pdfLandscape => 'Querformat';

  @override
  String get img2pdfJpegQuality => 'JPEG-Qualität';

  @override
  String get img2pdfImageCountSingle => '1 Bild';

  @override
  String img2pdfImageCountPlural(int count) {
    return '$count Bilder';
  }

  @override
  String get img2pdfAddMore => 'Weitere hinzufügen';

  @override
  String get img2pdfCreatePdf => 'PDF erstellen';

  @override
  String get img2pdfPreparing => 'Wird vorbereitet…';

  @override
  String img2pdfProcessingImage(int done, int total) {
    return 'Bild $done von $total wird verarbeitet…';
  }

  @override
  String get img2pdfSavingPdf => 'PDF wird gespeichert…';

  @override
  String img2pdfSavedTo(String path) {
    return 'PDF gespeichert unter $path';
  }

  @override
  String img2pdfSaveFailed(String error) {
    return 'PDF konnte nicht gespeichert werden: $error';
  }

  @override
  String img2pdfCreateFailed(String error) {
    return 'PDF konnte nicht erstellt werden: $error';
  }

  @override
  String get imgViewDiscardChangesTitle => 'Änderungen verwerfen?';

  @override
  String get imgViewDiscardChangesMessage =>
      'Dieses Bild hat ungespeicherte Änderungen. Beim Verlassen werden sie verworfen.';

  @override
  String get imgViewDiscard => 'Verwerfen';

  @override
  String get imgViewKeepEditing => 'Weiter bearbeiten';

  @override
  String get imgViewImageCopied => 'Bild in Zwischenablage kopiert';

  @override
  String get imgViewHideSettings => 'Einstellungen ausblenden';

  @override
  String get imgViewShowSettings => 'Einstellungen einblenden';

  @override
  String get imgViewEditImageTooltip => 'Bild bearbeiten';

  @override
  String get imgViewCloseImage => 'Bild schließen';

  @override
  String get imgViewEditImageDrawerTitle => 'Bild bearbeiten';

  @override
  String get imgViewUndo => 'Rückgängig';

  @override
  String get imgViewRedo => 'Wiederholen';

  @override
  String get imgViewCopyToClipboard => 'In Zwischenablage kopieren';

  @override
  String get imgViewDropZoneTitle => 'Bild hier ablegen';

  @override
  String get imgViewDropZoneSubtitle =>
      'Unterstützt PNG, JPEG, WebP, BMP, GIF, TIFF, ICO';

  @override
  String get imgViewTypeLabel => 'Bilder';

  @override
  String get imgViewBrowseFiles => 'Dateien durchsuchen';

  @override
  String get imgViewPasteFromClipboard => 'Aus Zwischenablage einfügen';

  @override
  String get imgViewUnsupportedTitle => 'Format kann nicht angezeigt werden';

  @override
  String imgViewUnsupportedMessage(String name) {
    return '„$name“ verwendet ein Bildformat, das der Betrachter nicht dekodieren kann. Öffne es stattdessen mit einer System-App.';
  }

  @override
  String get imgViewOpenExternally => 'Mit System-App öffnen';

  @override
  String get imgViewChooseAnother => 'Anderes Bild wählen';

  @override
  String get imgViewOriginalFileDetails => 'Originaldatei-Details';

  @override
  String get imgViewMoreInformation => 'Weitere Informationen';

  @override
  String get imgViewTransform => 'Transformieren';

  @override
  String get imgViewCroppingActive =>
      'Zuschneiden aktiv. Steuerung auf dem Bild anpassen.';

  @override
  String get imgViewRedactingActive =>
      'Schwärzen aktiv. Steuerung auf dem Bild anpassen.';

  @override
  String get imgViewRotateLeft => '90° nach links drehen';

  @override
  String get imgViewRotateRight => '90° nach rechts drehen';

  @override
  String get imgViewFlipHorizontal => 'Horizontal spiegeln';

  @override
  String get imgViewFlipVertical => 'Vertikal spiegeln';

  @override
  String get imgViewCrop => 'Zuschneiden';

  @override
  String get imgViewRedact => 'Schwärzen';

  @override
  String get imgViewResizeImage => 'Bild skalieren';

  @override
  String get imgViewWidthLabel => 'Breite (px)';

  @override
  String get imgViewAspectRatioLocked => 'Seitenverhältnis gesperrt';

  @override
  String get imgViewAspectRatioUnlocked => 'Seitenverhältnis entsperrt';

  @override
  String get imgViewHeightLabel => 'Höhe (px)';

  @override
  String get imgViewPreviewResize => 'Vorschau anzeigen';

  @override
  String get imgViewOutputFormat => 'Ausgabeformat';

  @override
  String get imgViewPreserveExif => 'EXIF-Metadaten beibehalten';

  @override
  String get imgViewPreserveExifSubtitle =>
      'GPS, Kamera-Tags und Datum beibehalten (nur JPEG)';

  @override
  String imgViewCompressionQuality(int quality) {
    return 'Kompressionsqualität: $quality%';
  }

  @override
  String get imgViewSaveImage => 'Bild speichern';

  @override
  String get imgViewShareImage => 'Bild teilen';

  @override
  String get imgViewDimensions => 'Abmessungen';

  @override
  String get imgViewFileSize => 'Dateigröße';

  @override
  String get imgViewRedactStyleHeader => 'Schwärzungsstil und Form';

  @override
  String get imgViewShapeLabel => 'Form: ';

  @override
  String get imgViewShapeRectangle => 'Rechteck';

  @override
  String get imgViewShapeFreehand => 'Freihand';

  @override
  String get imgViewRedraw => 'Neu zeichnen';

  @override
  String get imgViewStyleSolid => 'Einfarbig';

  @override
  String get imgViewStylePixelate => 'Verpixeln';

  @override
  String get imgViewStyleBlur => 'Weichzeichnen';

  @override
  String get imgViewColorLabel => 'Farbe: ';

  @override
  String imgViewBlockSize(int size) {
    return 'Blockgröße: $size px';
  }

  @override
  String imgViewBlurRadius(int radius) {
    return 'Unschärferadius: $radius px';
  }

  @override
  String get imgViewRedactHint =>
      'Pfad über den zu schwärzenden Bereich zeichnen';

  @override
  String get imgViewApplyRedaction => 'Schwärzung anwenden';

  @override
  String get imgViewCropPresetsHeader => 'Zuschnitt-Vorlagen';

  @override
  String get imgViewCropPresetFree => 'Frei';

  @override
  String get imgViewCropPreset1x1 => '1:1 Quadrat';

  @override
  String get imgViewCropPreset16x9 => '16:9 Breitbild';

  @override
  String get imgViewCropPreset4x3 => '4:3 Standard';

  @override
  String get imgViewCropPreset3x2 => '3:2 Foto';

  @override
  String get imgViewApplyCrop => 'Zuschnitt anwenden';

  @override
  String get imgViewZoomOut => 'Herauszoomen';

  @override
  String get imgViewZoomIn => 'Hineinzoomen';

  @override
  String get imgViewPreviousImage => 'Vorheriges Bild';

  @override
  String get imgViewNextImage => 'Nächstes Bild';

  @override
  String get imgViewGpsTitle => 'GPS-Standortinformationen';

  @override
  String get imgViewGpsLatitude => 'Breitengrad';

  @override
  String get imgViewGpsLongitude => 'Längengrad';

  @override
  String get imgViewGpsCoordinatesDms => 'Koordinaten (DMS)';

  @override
  String get imgViewOpenInMaps => 'In Karte öffnen';

  @override
  String get imgViewBrowseGallery => 'Galerie durchsuchen';

  @override
  String get imgViewTakePhoto => 'Foto aufnehmen';

  @override
  String get imgViewExifThumbnailTitle => 'Eingebettetes EXIF-Vorschaubild';

  @override
  String get imgViewMetadataDialogTitle => 'Metadaten & EXIF-Informationen';

  @override
  String get imgViewNoExifData =>
      'Keine EXIF-Metadaten in diesem Bild gefunden.';

  @override
  String get imgViewSegmentSubject => 'Motiv ausschneiden';

  @override
  String get imgViewSegmentSubjectTooltip =>
      'Isoliert das Motiv mithilfe von ML vom Hintergrund';

  @override
  String get imgViewSegmentSubjectUnsupported =>
      'Motiv-Segmentierung wird nur auf Android unterstützt';

  @override
  String imgViewSegmentSubjectFailed(String error) {
    return 'Fehler beim Ausschneiden des Motivs: $error';
  }

  @override
  String get imgViewSegmentSubjectDownloading =>
      'Google Play Services lädt das benötigte Machine-Learning-Modell herunter. Bitte warte eine Minute und versuche es erneut.';

  @override
  String get imgViewExtractText => 'Text extrahieren';

  @override
  String get imgViewExtractTextTooltip =>
      'Text mithilfe von ML aus dem Bild extrahieren';

  @override
  String get imgViewExtractTextTitle => 'Extrahierter Text';

  @override
  String get imgViewExtractTextNoText => 'Kein Text im Bild erkannt.';

  @override
  String imgViewExtractTextFailed(String error) {
    return 'Fehler beim Extrahieren des Textes: $error';
  }

  @override
  String get imgViewTextCopied => 'Text in die Zwischenablage kopiert';

  @override
  String get levelSensorsUnavailable =>
      'Sensoren auf diesem Gerät nicht verfügbar.';

  @override
  String get levelCalibratedToZero => 'Oberfläche auf null kalibriert.';

  @override
  String get levelCalibrationReset => 'Kalibrierung zurückgesetzt.';

  @override
  String get levelMode2Axis => '2-Achsen';

  @override
  String get levelModeBeam => 'Strahl';

  @override
  String get levelRuler => 'Lineal';

  @override
  String get levelCalibrateRuler => 'Lineal kalibrieren';

  @override
  String get levelRotationLocked => 'Gesperrt';

  @override
  String get levelLockRotation => 'Rot. sperren';

  @override
  String get levelWakeLock => 'Display aktiv';

  @override
  String get levelTolerance => 'TOLERANZ';

  @override
  String get levelSetZero => 'Null setzen';

  @override
  String get levelRulerCalibration => 'Lineal kalibrieren';

  @override
  String get levelRulerCalibrationHint =>
      'Halte ein physisches Lineal an den Bildschirmrand. Passe die Skala an, bis die Markierungen genau übereinstimmen.';

  @override
  String get levelPitch => 'Neigung';

  @override
  String get levelRoll => 'Rolle';

  @override
  String get miscCalculatorCopied => 'Kopiert';

  @override
  String get miscCalculatorSciLabel => 'SCI';

  @override
  String get miscCalculatorHistLabel => 'HIST';

  @override
  String get miscCalculatorCopyResultTooltip => 'Ergebnis kopieren';

  @override
  String get miscCalculatorPasteTooltip => 'Aus Zwischenablage einfügen';

  @override
  String get miscCalculatorPasteInvalid =>
      'Zwischenablage enthält keine nutzbare Zahl';

  @override
  String get miscCalculatorBackspaceTooltip => 'Rücktaste';

  @override
  String get miscCalculatorHistoryTitle => 'Verlauf';

  @override
  String get miscCalculatorNoHistory => 'Noch keine Berechnungen';

  @override
  String get miscBatteryPowerStatus => 'Energiestatus';

  @override
  String get miscBatteryFullyCharged => 'Vollständig geladen';

  @override
  String get miscBatteryCharging => 'Wird geladen';

  @override
  String get miscBatteryDischarging => 'Entlädt sich';

  @override
  String get miscBatterySaverActive => 'Energiesparen aktiv';

  @override
  String get miscBatteryChargingSlow => 'Langsames Laden';

  @override
  String get miscBatteryChargingNormal => 'Laden';

  @override
  String get miscBatteryChargingFast => 'Schnellladen';

  @override
  String get miscBatteryVoltage => 'Spannung';

  @override
  String get miscBatteryCurrent => 'Stromstärke';

  @override
  String get miscBatteryPower => 'Leistung';

  @override
  String get miscDeviceInfoSystemOs => 'System & Betriebssystem';

  @override
  String get miscDeviceInfoHardwareSpecs => 'Hardware-Details';

  @override
  String get miscDeviceInfoDisplayDetails => 'Anzeige-Details';

  @override
  String get miscDeviceInfoWindowsDisplayResolution =>
      'Aktuelle Anzeigeauflösung';

  @override
  String get miscDeviceInfoAppViewSize => 'App-Ansichtsgröße';

  @override
  String get miscDeviceInfoAppViewPixels => 'App-Ansichtspixel';

  @override
  String get miscDeviceInfoDisplayScale => 'Anzeigeskalierung';

  @override
  String get miscDeviceInfoOrientation => 'Ausrichtung';

  @override
  String get miscDeviceInfoRefreshRate => 'Bildwiederholrate';

  @override
  String get miscDeviceInfoCpuModel => 'CPU-Modell';

  @override
  String get miscDeviceInfoCpuArchitecture => 'CPU-Architektur';

  @override
  String get miscDeviceInfoGpuModel => 'GPU-Modell';

  @override
  String get miscDeviceInfoGpuVram => 'GPU-VRAM';

  @override
  String get miscDeviceInfoSystemUptime => 'Systemlaufzeit';

  @override
  String get miscDeviceInfoWindowsUptime =>
      'Laufzeit seit letztem vollständigen Neustart';

  @override
  String miscDeviceInfoUptimeDays(int days, int hours) {
    return '$days T. $hours Std.';
  }

  @override
  String miscDeviceInfoUptimeHours(int hours, int minutes) {
    return '$hours Std. $minutes Min.';
  }

  @override
  String miscDeviceInfoStorageVolume(Object name) {
    return 'Speicher: $name';
  }

  @override
  String get miscDeviceInfoFree => 'frei';

  @override
  String get miscDeviceInfoWifiSsid => 'WLAN-SSID';

  @override
  String get miscDeviceInfoWifiSignal => 'Signal';

  @override
  String get miscDeviceInfoWifiLinkSpeed => 'Verbindungsrate';

  @override
  String get miscDeviceInfoWifiFrequency => 'Frequenz';

  @override
  String get miscDeviceInfoGeneralSettings => 'Allgemeine Einstellungen';

  @override
  String get miscDeviceInfoStorage => 'Speicher & Arbeitsspeicher';

  @override
  String get miscDeviceInfoNetwork => 'Netzwerkverbindung';

  @override
  String get miscDeviceInfoSensors => 'Verfügbare Sensoren';

  @override
  String get miscDeviceInfoAppInfo => 'Anwendungsinformationen';

  @override
  String miscMarkdownFailedToLoad(String error) {
    return 'Datei konnte nicht geladen werden: $error';
  }

  @override
  String miscMarkdownFailedToRead(String error) {
    return 'Datei konnte nicht gelesen werden: $error';
  }

  @override
  String get miscMarkdownOpenTitle => 'Markdown-Datei öffnen';

  @override
  String get miscMarkdownDropSubtitle =>
      'Lege eine .md- oder .txt-Datei hier ab';

  @override
  String get miscMarkdownTypeLabel => 'Markdown';

  @override
  String get miscMarkdownReloaded => 'Neu geladen';

  @override
  String get miscMarkdownReloadNoChange => 'Datei unverändert';

  @override
  String get miscMarkdownReloadMissing => 'Datei existiert nicht mehr';

  @override
  String get nfcEditorFormTitle => 'NDEF-Datensatz erstellen';

  @override
  String get nfcTemplatePreset => 'Vorlage';

  @override
  String get nfcTemplateCustomRecord => 'Benutzerdefiniert';

  @override
  String get nfcTemplateUrlHomepage => 'URL: Homepage-Link';

  @override
  String get nfcTemplateTextNote => 'Text: Einfache Notiz';

  @override
  String get nfcTemplateMimeJson => 'MIME: JSON-Konfiguration';

  @override
  String get nfcTemplateMimeVcard => 'MIME: vCard-Kontakt';

  @override
  String get nfcRecordType => 'Datensatztyp (NDEF-Format)';

  @override
  String get nfcRecordTypeUri => 'Bekannte URI (URL)';

  @override
  String get nfcRecordTypeText => 'Bekannter Text';

  @override
  String get nfcRecordTypeMime => 'MIME-Medieninhalt';

  @override
  String get nfcUriTargetLink => 'URI-Ziellink';

  @override
  String get nfcUriHelperText =>
      'Erkennt gängige Präfixe automatisch (https://, http://, mailto:, file://), um Tag-Speicher zu sparen.';

  @override
  String get nfcUriRequired => 'URI-Ziellink ist erforderlich';

  @override
  String get nfcTextContent => 'Textinhalt';

  @override
  String get nfcTextContentHint => 'Notizinhalt eingeben...';

  @override
  String get nfcTextContentRequired => 'Textinhalt ist erforderlich';

  @override
  String get nfcLanguageCode => 'Sprachcode';

  @override
  String get nfcLanguageCodeHelper =>
      'Standardmäßiger BCP-47-Sprachbezeichner (z. B. en, fr, de, es).';

  @override
  String get nfcLanguageCodeRequired => 'Sprachcode ist erforderlich';

  @override
  String get nfcMimeType => 'MIME-Typ';

  @override
  String get nfcMimeTypeHelper =>
      'Offizieller Medientyp (z. B. application/json, text/vcard, image/png).';

  @override
  String get nfcMimeTypeRequired =>
      'Ein gültiger MIME-Typ (z. B. typ/subtyp) ist erforderlich';

  @override
  String get nfcMimePayloadData => 'MIME-Nutzlastdaten';

  @override
  String get nfcMimePayloadHint =>
      'JSON, vCard oder benutzerdefinierte Rohdaten eingeben...';

  @override
  String get nfcPayloadRequired => 'Nutzlastdaten sind erforderlich';

  @override
  String get nfcGetHex => 'Hex erzeugen';

  @override
  String get nfcWriteTag => 'Tag schreiben';

  @override
  String get nfcWriteTagHint =>
      '\"Tag schreiben\" ist nur beim Scannen eines beschreibbaren Tags aktiv.';

  @override
  String get nfcHexInspectorTitle => 'NDEF-Hex-Inspektor';

  @override
  String get nfcHexInspectorSubtitle =>
      'Rohe NDEF-Hex-Codes validieren, parsen oder erzeugen.';

  @override
  String get nfcPasteHexData => 'NDEF-Hex-Daten einfügen';

  @override
  String get nfcClearInput => 'Eingabe löschen';

  @override
  String get nfcPasteHexToParsePrompt =>
      'Bitte NDEF-Hex-Daten zum Parsen einfügen.';

  @override
  String get nfcParseHex => 'Hex parsen';

  @override
  String get nfcGeneratedHex => 'Erzeugter NDEF-Hex';

  @override
  String get nfcCopyGeneratedHex => 'Erzeugten Hex kopieren';

  @override
  String get nfcHexCopied =>
      'Erzeugter NDEF-Hex in die Zwischenablage kopiert.';

  @override
  String get nfcNoRecordsFound => 'Keine Datensätze gefunden';

  @override
  String get nfcNoRecordsSubtitle =>
      'NDEF-Nutzlast ist leer oder wurde noch nicht gescannt.';

  @override
  String nfcNdefRecords(int count) {
    return 'NDEF-Datensätze ($count)';
  }

  @override
  String get nfcRecordIndex => 'Datensatz-Index:';

  @override
  String get nfcLoadIntoEditor => 'In Editor laden';

  @override
  String get nfcRecordLoaded => 'Datensatz in das Editor-Formular geladen.';

  @override
  String get nfcCopyPayloadHex => 'Nutzlast-Hex kopieren';

  @override
  String get nfcPayloadHexCopied =>
      'Nutzlast-Hex in die Zwischenablage kopiert.';

  @override
  String get nfcRawPayloadHex => 'Rohe Nutzlast (Hex):';

  @override
  String nfcSubtitleText(String lang, String encoding) {
    return 'Bekannter Text [$lang | $encoding]';
  }

  @override
  String get nfcSubtitleUri => 'Bekannte URI';

  @override
  String get nfcSubtitleCustom => 'Benutzerdefiniert / Kein NDEF';

  @override
  String get nfcStop => 'Stopp';

  @override
  String get nfcScan => 'Scannen';

  @override
  String get nfcNoHardware => 'Keine Hardware';

  @override
  String get nfcScannerTitle => 'NFC-Scanner';

  @override
  String get nfcScanningPrompt => 'NFC-Tag zum Scannen annähern';

  @override
  String get nfcScannerInactive => 'Scanner ist inaktiv';

  @override
  String get nfcCardBrand => 'Kartenmarke';

  @override
  String get nfcCardNumber => 'Kartennummer';

  @override
  String get nfcCardholderName => 'Karteninhaber';

  @override
  String get nfcExpirationDate => 'Ablaufdatum';

  @override
  String get nfcApplicationAid => 'Anwendungs-AID';

  @override
  String get nfcUidSerial => 'UID / Seriennummer';

  @override
  String get nfcTechnologies => 'Technologien';

  @override
  String get nfcCapacity => 'Kapazität';

  @override
  String get nfcWritable => 'Beschreibbar';

  @override
  String get nfcCardholderLabel => 'KARTENINHABER';

  @override
  String get nfcExpiresLabel => 'GÜLTIG BIS';

  @override
  String get nfcPaymentCard => 'Zahlungskarte';

  @override
  String nfcSessionError(String message) {
    return 'NFC-Scan-Sitzungsfehler: $message';
  }

  @override
  String nfcTagDetected(String label) {
    return 'Tag erkannt — $label';
  }

  @override
  String nfcScanFailed(String error) {
    return 'Scan fehlgeschlagen: $error';
  }

  @override
  String get nfcNoActiveTag =>
      'Kein aktives Tag. Bitte zuerst ein Tag scannen.';

  @override
  String get nfcTagNotWritable =>
      'Tag ist nicht beschreibbar oder NDEF wird nicht unterstützt.';

  @override
  String get nfcWritingToTag => 'Schreibe auf NFC-Tag...';

  @override
  String get nfcWriteSuccess => 'NDEF-Datensatz erfolgreich geschrieben!';

  @override
  String nfcWriteFailed(String error) {
    return 'Schreiben fehlgeschlagen: $error';
  }

  @override
  String get nfcHexGenerated => 'NDEF-Hex erzeugt! Unten kopieren.';

  @override
  String nfcHexGenerateError(String error) {
    return 'Fehler beim Erzeugen des Hex: $error';
  }

  @override
  String get nfcHexParsed => 'NDEF-Hex erfolgreich geparst!';

  @override
  String nfcHexParseFailed(String error) {
    return 'Hex parsen fehlgeschlagen: $error';
  }

  @override
  String get nfcNoHardwareInfo =>
      'NFC-Hardware-Scanning wird nur auf Mobilgeräten unterstützt. Sie können dennoch NDEF-Hexadezimalkonfigurationen lokal einfügen, parsen, bearbeiten und erzeugen.';

  @override
  String get nfcHexEmulator => 'Hex-Emulator';

  @override
  String nfcRecordsParsed(int count) {
    return '$count Datensätze geparst';
  }

  @override
  String notesFailedToLoadSharedFile(String error) {
    return 'Gemeinsame Datei konnte nicht geladen werden: $error';
  }

  @override
  String get notesSaveKeepEditing => 'Speichern und weiter bearbeiten';

  @override
  String get notesNoteSaved => 'Notiz gespeichert';

  @override
  String notesFailedToSaveNote(String error) {
    return 'Notiz konnte nicht gespeichert werden: $error';
  }

  @override
  String get notesDeleteNoteTitle => 'Notiz löschen';

  @override
  String get notesDeleteNoteMessage => 'Diese Notiz wirklich löschen?';

  @override
  String get notesNoteDeleted => 'Notiz gelöscht';

  @override
  String notesFailedToDeleteNote(String error) {
    return 'Notiz konnte nicht gelöscht werden: $error';
  }

  @override
  String notesImportedNoteFrom(String name) {
    return 'Notiz importiert aus \"$name\"';
  }

  @override
  String notesFailedToImportDroppedFile(String error) {
    return 'Abgelegte Datei konnte nicht importiert werden: $error';
  }

  @override
  String get notesViewNoteTitle => 'Notiz anzeigen';

  @override
  String notesFailedToReadFile(String error) {
    return 'Datei konnte nicht gelesen werden: $error';
  }

  @override
  String get notesBackupImportedSuccessfully =>
      'Sicherung erfolgreich importiert';

  @override
  String notesImportFailed(String error) {
    return 'Import fehlgeschlagen: $error';
  }

  @override
  String notesFailedToExportNotes(String error) {
    return 'Notizen konnten nicht exportiert werden: $error';
  }

  @override
  String get notesSyncConfigureServerUrl =>
      'Bitte zuerst die Server-URL in den Cloud-Einstellungen konfigurieren';

  @override
  String notesSyncFinished(int pulled, int pushed, int deleted) {
    return 'Synchronisierung abgeschlossen. Empfangen: $pulled, Gesendet: $pushed, Gelöscht: $deleted.';
  }

  @override
  String get notesSyncFailedEmpty =>
      'Synchronisierung fehlgeschlagen: URL oder Benutzer-ID fehlt';

  @override
  String notesSyncFailed(String error) {
    return 'Synchronisierung fehlgeschlagen: $error';
  }

  @override
  String get notesSearchHint => 'Notizen suchen...';

  @override
  String get notesEmptyTitle => 'Keine Notizen gefunden';

  @override
  String get notesEmptyDescription =>
      'Erstelle eine neue Notiz oder ziehe eine Markdown-Datei (.md) zum Import hierher.';

  @override
  String notesArchiveEntryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Notizen',
      one: '1 Notiz',
    );
    return '$_temp0';
  }

  @override
  String get notesSyncWithCloud => 'Mit Cloud synchronisieren';

  @override
  String get notesImportMarkdownFile => 'Markdown-Datei importieren';

  @override
  String get notesImportJsonBackup => 'JSON-Sicherung importieren';

  @override
  String get notesExportJsonBackup => 'JSON-Sicherung exportieren';

  @override
  String get notesEditorHint =>
      'Notizen hier schreiben... (Markdown wird unterstützt)';

  @override
  String get notesEditorNoPreview => 'Noch keine Vorschau verfügbar';

  @override
  String get notesUnsavedChangesTitle => 'Nicht gespeicherte Änderungen';

  @override
  String get notesUnsavedChangesMessage =>
      'Du hast nicht gespeicherte Änderungen. Wirklich verwerfen?';

  @override
  String get notesKeepEditing => 'Weiter bearbeiten';

  @override
  String get notesDiscard => 'Verwerfen';

  @override
  String get notesExportPdf => 'Als PDF exportieren';

  @override
  String get notesCreateNoteTitle => 'Notiz erstellen';

  @override
  String get notesEditNoteTitle => 'Notiz bearbeiten';

  @override
  String get notesEditorToolbarTitle => 'Formatierungswerkzeuge';

  @override
  String get notesEditorTagsTitle => 'Tags';

  @override
  String get notesTabWrite => 'Schreiben';

  @override
  String get notesTabPreview => 'Vorschau';

  @override
  String get notesToggleSourceMode => 'Markdown-Quelltext anzeigen';

  @override
  String get notesToggleLiveMode => 'Formatierte Vorschau anzeigen';

  @override
  String get notesModeLiveTooltip => 'Live-Editor (mit Markdown-Syntax)';

  @override
  String get notesModeSourceTooltip => 'Markdown-Quelltext (Rohdaten)';

  @override
  String get notesModePreviewTooltip => 'Vorschau (ohne Markdown-Syntax)';

  @override
  String get notesToolbarImage => 'Bild einfügen';

  @override
  String get notesImageSourceTitle => 'Bild einfügen';

  @override
  String get notesImageSourceGallery => 'Aus Galerie auswählen';

  @override
  String get notesImageSourceCamera => 'Foto aufnehmen';

  @override
  String get notesImageSourceClipboard => 'Aus Zwischenablage einfügen';

  @override
  String get notesImageSourceClipboardEmpty =>
      'Kein Bild in der Zwischenablage';

  @override
  String get notesImageProcessing => 'Bild wird verarbeitet...';

  @override
  String get notesToolbarBold => 'Fett';

  @override
  String get notesToolbarItalic => 'Kursiv';

  @override
  String get notesToolbarStrikethrough => 'Durchgestrichen';

  @override
  String get notesToolbarH1 => 'H1';

  @override
  String get notesToolbarH2 => 'H2';

  @override
  String get notesToolbarH3 => 'H3';

  @override
  String get notesToolbarList => 'Liste';

  @override
  String get notesToolbarTodo => 'Aufgabe';

  @override
  String get notesToolbarLink => 'Link';

  @override
  String get notesToolbarCode => 'Code';

  @override
  String get notesToolbarCodeBlock => 'Codeblock';

  @override
  String get notesUntitledNote => 'Unbenannte Notiz';

  @override
  String get notesExportMd => 'Als MD exportieren';

  @override
  String notesUpdatedAt(String date) {
    return 'Aktualisiert: $date';
  }

  @override
  String get notesDropZoneUnsupportedFile =>
      'Nur Markdown- (.md) oder Textdateien (.txt) werden unterstützt';

  @override
  String get notesDropZoneTitle => 'Markdown-Datei hier ablegen';

  @override
  String get notesAddTagHint => 'Tag hinzufügen...';

  @override
  String get pdfEditDownload => 'Herunterladen';

  @override
  String get pdfEditOpenInViewer => 'Im Viewer öffnen';

  @override
  String pdfEditSignTitle(String fileName) {
    return 'Signieren: $fileName';
  }

  @override
  String pdfEditSignOpenError(String error) {
    return 'PDF konnte nicht geöffnet werden: $error';
  }

  @override
  String pdfEditSignFailed(String error) {
    return 'Signieren fehlgeschlagen: $error';
  }

  @override
  String get pdfEditSignPrevPage => 'Vorherige Seite';

  @override
  String get pdfEditSignNextPage => 'Nächste Seite';

  @override
  String pdfEditSignPageOf(int current, int total) {
    return 'Seite $current von $total';
  }

  @override
  String get pdfEditSignDragHint =>
      'Ziehen zum Positionieren · Größe/Drehung an den Griffen ändern';

  @override
  String get pdfEditSignTapHint => 'Signatur oben antippen';

  @override
  String get pdfEditSignStamping => 'Signatur wird eingefügt…';

  @override
  String get pdfEditSignDoneTitle => 'Signatur eingefügt';

  @override
  String pdfEditSignDoneSize(String size) {
    return 'Größe des signierten PDF: $size';
  }

  @override
  String pdfEditFlattenTitle(String fileName) {
    return 'Reduzieren: $fileName';
  }

  @override
  String get pdfEditFlattenHeadline => 'PDF auf Bilder reduzieren';

  @override
  String get pdfEditFlattenDescription =>
      'Jede Seite wird als Bild gerendert und in ein neues PDF eingebettet. Der Inhalt kann dadurch nicht mehr ausgewählt oder extrahiert werden.';

  @override
  String pdfEditFlattenDpi(int dpi) {
    return 'Auflösung (DPI): $dpi';
  }

  @override
  String get pdfEditFlattenDpiHint =>
      'Höherer DPI-Wert = größere Datei, aber bessere Qualität';

  @override
  String pdfEditFlattenJpegQuality(int quality) {
    return 'JPEG-Qualität: $quality %';
  }

  @override
  String get pdfEditFlattenJpegQualityHint => 'Höhere Qualität = größere Datei';

  @override
  String get pdfEditFlattenStart => 'Reduzieren starten';

  @override
  String pdfEditFlattenProgress(int done, int total) {
    return 'Seite $done von $total wird gerendert…';
  }

  @override
  String pdfEditFlattenPagesTotal(int count) {
    return '$count Seiten gesamt';
  }

  @override
  String pdfEditFlattenFailed(String error) {
    return 'Reduzieren fehlgeschlagen: $error';
  }

  @override
  String get pdfEditFlattenDoneTitle => 'Reduzieren abgeschlossen';

  @override
  String pdfEditFlattenDoneSize(String size) {
    return 'Neue PDF-Größe: $size';
  }

  @override
  String pdfEditRedactTitle(String fileName) {
    return 'Schwärzen: $fileName';
  }

  @override
  String pdfEditRedactFailed(String error) {
    return 'Schwärzen fehlgeschlagen: $error';
  }

  @override
  String pdfEditRedactPageOf(int current, int total) {
    return 'Seite $current von $total';
  }

  @override
  String get pdfEditRedactDrawHint =>
      'Zum Zeichnen eines Schwärzungsrechtecks ziehen';

  @override
  String get pdfEditRedactModeDraw => 'Zeichnen';

  @override
  String get pdfEditRedactModeNavigate => 'Navigieren';

  @override
  String get pdfEditRedactModeSelect => 'Text auswählen';

  @override
  String get pdfEditRedactProcessing => 'Schwärzungen werden angewendet…';

  @override
  String get pdfEditRedactDoneTitle => 'Schwärzung abgeschlossen';

  @override
  String pdfEditRedactDoneSize(String size) {
    return 'Neue PDF-Größe: $size';
  }

  @override
  String get pdfEditRedactRedactSelected => 'Auswahl schwärzen';

  @override
  String get pdfEditRedactSelectHint =>
      'Text im Dokument auswählen, dann auf \"Auswahl schwärzen\" tippen';

  @override
  String get pdfEditRedactFindTooltip => 'Text suchen';

  @override
  String get pdfEditRedactFindTitle => 'Zu schwärzenden Text finden';

  @override
  String get pdfEditRedactFindFieldLabel => 'Suchtext';

  @override
  String get pdfEditRedactFindMarkAll => 'Alle markieren';

  @override
  String pdfEditRedactFoundCount(int count) {
    return '$count Fundstelle(n) markiert';
  }

  @override
  String pdfEditMetaTitle2(String fileName) {
    return 'Metadaten: $fileName';
  }

  @override
  String get pdfEditMetaReload => 'Metadaten neu laden';

  @override
  String get pdfEditMetaLoadFailed => 'Metadaten konnten nicht geladen werden';

  @override
  String pdfEditMetaLoadError(String error) {
    return 'Metadaten konnten nicht geladen werden: $error';
  }

  @override
  String pdfEditMetaRemoveSecurityError(String error) {
    return 'Sicherheitsschutz konnte nicht entfernt werden: $error';
  }

  @override
  String pdfEditMetaSaveFailed(String error) {
    return 'Speichern fehlgeschlagen: $error';
  }

  @override
  String get pdfEditMetaSpecsTitle => 'Dokumenteigenschaften';

  @override
  String get pdfEditMetaFileName => 'Dateiname';

  @override
  String get pdfEditMetaFileSize => 'Dateigröße';

  @override
  String get pdfEditMetaPageCount => 'Seitenanzahl';

  @override
  String get pdfEditMetaPdfVersion => 'PDF-Version';

  @override
  String get pdfEditMetaPageDimensions => 'Seitenabmessungen';

  @override
  String get pdfEditMetaMetadataTitle => 'Dokumentmetadaten';

  @override
  String get pdfEditMetaTitle => 'Titel';

  @override
  String get pdfEditMetaAuthor => 'Autor';

  @override
  String get pdfEditMetaSubject => 'Betreff';

  @override
  String get pdfEditMetaKeywords => 'Stichwörter';

  @override
  String get pdfEditMetaCreator => 'Ersteller';

  @override
  String get pdfEditMetaProducer => 'Erzeuger';

  @override
  String get pdfEditMetaCreationDate => 'Erstellungsdatum';

  @override
  String get pdfEditMetaModDate => 'Änderungsdatum';

  @override
  String get pdfEditMetaTrapped => 'Trapped';

  @override
  String get pdfEditMetaSecurityTitle => 'Sicherheit & Einschränkungen';

  @override
  String get pdfEditMetaEncrypted => 'Verschlüsselt';

  @override
  String pdfEditMetaEncryptedYes(String revision) {
    return 'Ja (Revision $revision)';
  }

  @override
  String get pdfEditMetaUnknown => 'unbekannt';

  @override
  String get pdfEditMetaRestrictions => 'Einschränkungen';

  @override
  String get pdfEditMetaPermAllowed => 'Erlaubt';

  @override
  String get pdfEditMetaPermRestricted => 'Eingeschränkt';

  @override
  String get pdfEditMetaPermPrintLow => 'Drucken (niedrige Auflösung)';

  @override
  String get pdfEditMetaPermPrintHigh => 'Drucken in hoher Qualität';

  @override
  String get pdfEditMetaPermModifyContent => 'Dokumentinhalt bearbeiten';

  @override
  String get pdfEditMetaPermCopyExtract => 'Inhalt kopieren & extrahieren';

  @override
  String get pdfEditMetaPermAnnotations => 'Anmerkungen hinzufügen/bearbeiten';

  @override
  String get pdfEditMetaPermForms => 'Interaktive Formulare ausfüllen';

  @override
  String get pdfEditMetaPermAccessibility => 'Barrierefreiheits-Extraktion';

  @override
  String get pdfEditMetaPermAssembly => 'Dokumentzusammenstellung';

  @override
  String get pdfEditMetaRemovePassword =>
      'Passwort entfernen & Kopie speichern';

  @override
  String get pdfEditMetaDoneTitle => 'Sicherheitsschutz entfernt';

  @override
  String pdfEditExtractTitle(String fileName) {
    return 'Bilder extrahieren: $fileName';
  }

  @override
  String pdfEditExtractSelectionCount(int selected, int total) {
    return '$selected ausgewählt / $total gesamt';
  }

  @override
  String get pdfEditExtractHideControls => 'Steuerelemente ausblenden';

  @override
  String get pdfEditExtractShowControls => 'Steuerelemente einblenden';

  @override
  String get pdfEditExtractSelectAll => 'Alle auswählen';

  @override
  String get pdfEditExtractClearSelection => 'Auswahl aufheben';

  @override
  String get pdfEditExtractDownloadSelected => 'Auswahl herunterladen';

  @override
  String get pdfEditExtractDownloadAllZip => 'Alle herunterladen (ZIP)';

  @override
  String get pdfEditExtractEmpty =>
      'Keine eingebetteten Bilder in dieser PDF gefunden';

  @override
  String get pdfEditExtractScanning => 'PDF wird gescannt…';

  @override
  String pdfEditExtractScanningObjects(int done, int total) {
    return 'PDF-Objekte $done von $total werden gescannt…';
  }

  @override
  String pdfEditExtractPreparingImages(int done, int total) {
    return 'Bilder $done von $total werden vorbereitet…';
  }

  @override
  String pdfEditExtractImagesFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Bilder gefunden',
      one: '1 Bild gefunden',
    );
    return '$_temp0';
  }

  @override
  String pdfEditExtractFailed(String error) {
    return 'Bildextraktion fehlgeschlagen: $error';
  }

  @override
  String pdfEditExtractCreatingZip(int done, int total) {
    return 'ZIP wird erstellt $done von $total…';
  }

  @override
  String get pdfEditExtractZipReady => 'ZIP bereit';

  @override
  String pdfEditExtractZipFailed(String error) {
    return 'ZIP-Export fehlgeschlagen: $error';
  }

  @override
  String pdfEditExtractImagePageDimensions(int page, int width, int height) {
    return 'Seite $page – ${width}x$height';
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
  String get pdfEditExtractPreview => 'Vorschau';

  @override
  String get pdfNavPasswordTitle => 'Passwortgeschütztes PDF';

  @override
  String pdfNavPasswordMessage(String fileName) {
    return 'Passwort für $fileName eingeben.';
  }

  @override
  String get pdfNavOpenCanceled =>
      'PDF-Öffnen abgebrochen. Andere Datei auswählen oder erneut versuchen.';

  @override
  String get pdfNavTypeLabel => 'PDFs';

  @override
  String get pdfNavDropZoneTitle => 'PDF-Datei öffnen';

  @override
  String get pdfNavDropZoneSubtitle => '.pdf-Datei hier ablegen';

  @override
  String get pdfNavDocumentFallback => 'Dokument';

  @override
  String get pdfNavBookmarks => 'Lesezeichen';

  @override
  String get pdfNavNoBookmarks => 'Keine Lesezeichen vorhanden';

  @override
  String get pdfNavSearchText => 'Text suchen';

  @override
  String get pdfNavMore => 'Mehr';

  @override
  String get pdfNavModeView => 'Ansicht';

  @override
  String get pdfNavModePlaceSignature => 'Unterschrift platzieren';

  @override
  String get pdfNavModeOrganizePages => 'Seiten anordnen';

  @override
  String get pdfNavModeFlattenPdf => 'PDF reduzieren';

  @override
  String get pdfNavModeExtractImages => 'Bilder extrahieren';

  @override
  String get pdfNavModeExtractText => 'Text extrahieren';

  @override
  String pdfExtractTextTitle(String fileName) {
    return 'Text extrahieren: $fileName';
  }

  @override
  String pdfExtractTextProgress(int current, int total) {
    return 'Text wird extrahiert … $current/$total';
  }

  @override
  String get pdfExtractTextEmpty =>
      'Kein extrahierbarer Text in diesem PDF gefunden. Es ist möglicherweise gescannt oder enthält nur Bilder.';

  @override
  String pdfExtractTextFailed(String error) {
    return 'Text konnte nicht extrahiert werden: $error';
  }

  @override
  String get pdfExtractTextCopy => 'Kopieren';

  @override
  String get pdfExtractTextCopied => 'Text in die Zwischenablage kopiert';

  @override
  String get pdfExtractTextSave => 'Als .txt speichern';

  @override
  String get pdfExtractTextAskHint => 'Stelle eine Frage zu diesem Text …';

  @override
  String get pdfExtractTextAskSend => 'Fragen';

  @override
  String get pdfExtractTextThinking => 'Denkt nach …';

  @override
  String get pdfExtractTextTruncatedNote =>
      'Hinweis: Nur der erste Teil des Textes wird an die On-Device-KI gesendet.';

  @override
  String get textToolsSummarize => 'Zusammenfassen';

  @override
  String get textToolsKeywords => 'Schlüsselwörter';

  @override
  String get textToolsSourceAi => 'KI-Antwort';

  @override
  String get textToolsSourceOffline =>
      'Offline-Ergebnis – am besten passende Textstellen';

  @override
  String get textToolsSummaryTitle => 'Zusammenfassung (offline)';

  @override
  String get textToolsKeywordsTitle => 'Schlüsselwörter (offline)';

  @override
  String get genaiOfflineAnalysisActive =>
      'On-Device-KI nicht verfügbar – Offline-Textanalyse ist aktiv.';

  @override
  String get pdfNavModeMetadata => 'Metadaten';

  @override
  String get pdfNavModeRedact => 'PDF schwärzen';

  @override
  String get pdfNavCloseSearch => 'Suche schließen';

  @override
  String get pdfNavSearchHint => 'Text suchen …';

  @override
  String get pdfNavPrevMatch => 'Vorheriger Treffer';

  @override
  String get pdfNavNextMatch => 'Nächster Treffer';

  @override
  String get pdfNavShareFile => 'Datei teilen';

  @override
  String get pdfNavSaveToDownloads => 'In Downloads speichern';

  @override
  String pdfNavPageOf(int current, int total) {
    return 'Seite $current von $total';
  }

  @override
  String pdfNavPageLoading(int current) {
    return 'Seite $current …';
  }

  @override
  String get pdfNavPrevPage => 'Vorherige Seite';

  @override
  String get pdfNavNextPage => 'Nächste Seite';

  @override
  String get pdfNavZoomOut => 'Verkleinern';

  @override
  String get pdfNavZoomReset => 'Zoom zurücksetzen';

  @override
  String get pdfNavZoomIn => 'Vergrößern';

  @override
  String pdfNavOrganizeTitle(String fileName) {
    return 'Anordnen: $fileName';
  }

  @override
  String get pdfNavOrganizeInsertTooltip => 'Seiten aus anderem PDF einfügen';

  @override
  String get pdfNavOrganizeApplyTooltip => 'Änderungen übernehmen';

  @override
  String pdfNavOrganizePageCountHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Seiten',
      one: '1 Seite',
    );
    return '$_temp0 – ziehen zum Sortieren, tippen zur Vorschau';
  }

  @override
  String get pdfNavOrganizeNoPages => 'Keine Seiten';

  @override
  String pdfViewerShareFailed(String error) {
    return 'Datei konnte nicht geteilt werden: $error';
  }

  @override
  String pdfNavOrganizeLoadFailed(String error) {
    return 'PDF konnte nicht geladen werden: $error';
  }

  @override
  String pdfNavOrganizeOpenFailed(String error) {
    return 'PDF konnte nicht geöffnet werden: $error';
  }

  @override
  String pdfNavOrganizeReorganizeFailed(String error) {
    return 'Neuanordnung fehlgeschlagen: $error';
  }

  @override
  String get pdfNavOrganizeCannotDeleteLastPage =>
      'Die letzte Seite kann nicht gelöscht werden';

  @override
  String get pdfNavOrganizeRemovePageTitle => 'Seite entfernen';

  @override
  String pdfNavOrganizeRemovePageMessage(int pageNumber) {
    return 'Seite $pageNumber entfernen?';
  }

  @override
  String pdfNavOrganizeInsertDialogTitle(String srcName) {
    return 'Seiten aus \"$srcName\" einfügen';
  }

  @override
  String get pdfNavOrganizeNoPagesFound => 'Keine Seiten gefunden';

  @override
  String pdfNavOrganizePageNumber(int pageNumber) {
    return 'Seite $pageNumber';
  }

  @override
  String get pdfNavOrientationPortrait => 'Hochformat';

  @override
  String get pdfNavOrientationLandscape => 'Querformat';

  @override
  String get pdfNavDeselectAll => 'Alle abwählen';

  @override
  String get pdfNavSelectAll => 'Alle auswählen';

  @override
  String pdfNavOrganizeInsertCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Seiten einfügen',
      one: '1 Seite einfügen',
    );
    return '$_temp0';
  }

  @override
  String get pdfNavOrganizeComplete => 'Anordnung abgeschlossen';

  @override
  String pdfNavOrganizeNewSize(String size) {
    return 'Neue PDF-Größe: $size';
  }

  @override
  String get pdfNavDownload => 'Herunterladen';

  @override
  String get pdfNavOpenInViewer => 'Im Viewer öffnen';

  @override
  String get sigAdvancedSettings => 'Erweiterte Einstellungen';

  @override
  String get sigTabDraw => 'Zeichnen';

  @override
  String get sigTabSaved => 'Gespeichert';

  @override
  String get sigSavedToDownloads => 'Unterschrift in Downloads gespeichert';

  @override
  String get sigCopiedToClipboard =>
      'Unterschrift in die Zwischenablage kopiert';

  @override
  String get sigSaved => 'Unterschrift gespeichert';

  @override
  String get sigDeleteTitle => 'Unterschrift löschen?';

  @override
  String get sigDeleteContent => 'Diese Unterschrift wird entfernt.';

  @override
  String get sigUndo => 'Rückgängig';

  @override
  String get sigRedo => 'Wiederholen';

  @override
  String get sigPng => 'PNG';

  @override
  String get sigSvg => 'SVG';

  @override
  String get sigAdvanced => 'Erweitert';

  @override
  String get sigReduceLines => 'Linien reduzieren (RDP)';

  @override
  String get sigMoveTolerance => 'Bewegungstoleranz';

  @override
  String get sigMinWidthFactor => 'Minimaler Breitenfaktor';

  @override
  String get sigMaxWidthFactor => 'Maximaler Breitenfaktor';

  @override
  String get sigVelocitySensitivity => 'Geschwindigkeitsempfindlichkeit';

  @override
  String get sigVelocityInfluence => 'Geschwindigkeitseinfluss';

  @override
  String get sigPressureInfluence => 'Druckeinfluss';

  @override
  String get sigWidthSmoothing => 'Breitenglättung';

  @override
  String get sigExportDpi => 'Export-DPI';

  @override
  String get sigLoad => 'Laden';

  @override
  String get widgetPasswordLabel => 'Passwort';

  @override
  String get widgetPasswordShow => 'Passwort anzeigen';

  @override
  String get widgetPasswordHide => 'Passwort verbergen';

  @override
  String widgetFileDropFailedToSelect(String error) {
    return 'Datei konnte nicht ausgewählt werden: $error';
  }

  @override
  String widgetFileDropOnlyFilesSupported(String extensions) {
    return 'Nur $extensions-Dateien werden unterstützt';
  }

  @override
  String get widgetFileDropReleaseToLoad => 'Loslassen zum Laden';

  @override
  String get widgetMarkdownReload => 'Von Datenträger neu laden';

  @override
  String get widgetMarkdownExportMarkdown => 'Markdown exportieren';

  @override
  String get widgetMarkdownExportPdf => 'PDF exportieren';

  @override
  String widgetMarkdownUpdated(String date) {
    return 'Aktualisiert: $date';
  }

  @override
  String get widgetMarkdownNoContent => 'Kein weiterer Inhalt';

  @override
  String get widgetMarkdownImageEnlarge => 'Zum Vergrößern tippen';

  @override
  String get widgetMarkdownFrontmatter => 'Frontmatter';

  @override
  String widgetMarkdownFrontmatterInvalid(String error) {
    return 'Ungültiges Frontmatter-YAML: $error';
  }

  @override
  String get widgetMarkdownCodeCopy => 'Code kopieren';

  @override
  String get widgetMarkdownCodeCopied => 'Code kopiert';

  @override
  String widgetMarkdownCodeLanguageAuto(String language) {
    return '$language · auto';
  }

  @override
  String get widgetMarkdownCodeCollapse => 'Code einklappen';

  @override
  String get widgetMarkdownCodeExpand => 'Code ausklappen';

  @override
  String widgetMarkdownCodeLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Zeilen',
      one: '1 Zeile',
    );
    return '$_temp0';
  }

  @override
  String get widgetToolChooserOpenFile => 'Datei öffnen';

  @override
  String get widgetToolChooserChooseTool => 'Tool zum Öffnen wählen:';

  @override
  String get widgetToolChooserAlwaysUseTool =>
      'Dieses Tool immer für diesen Dateityp verwenden';

  @override
  String get widgetShortcutHomeTitle => 'Startbildschirm-Verknüpfung';

  @override
  String get widgetShortcutHomeSubtitle =>
      'Verknüpfung zum Startbildschirm hinzufügen';

  @override
  String get widgetShortcutDrawerTitle => 'App-Drawer-Symbol';

  @override
  String get widgetShortcutDrawerSubtitle =>
      'Separates Symbol im App-Drawer anzeigen';

  @override
  String get sectionTitleSensors => 'Sensoren';

  @override
  String get sectionTitleUtilities => 'Werkzeuge';

  @override
  String get sectionTitleInfo => 'Information';

  @override
  String get toolNameCalculator => 'Rechner';

  @override
  String get toolDescCalculator =>
      'Einfache und wissenschaftliche Berechnungen';

  @override
  String get toolNameBubbleLevel => 'Wasserwaage';

  @override
  String get toolDescBubbleLevel => 'Präzise Wasserwaage über Gerätesensoren';

  @override
  String get toolNameEmfDetector => 'EMF-Detektor';

  @override
  String get toolDescEmfDetector => 'Elektromagnetische Felder erkennen';

  @override
  String get toolNameDeviceInfo => 'Geräteinfo';

  @override
  String get toolDescDeviceInfo => 'Akku-, Sensor- und Systeminformationen';

  @override
  String get toolNameNfcTagLab => 'NFC Tag Lab';

  @override
  String get toolDescNfcTagLab =>
      'NFC-Ziele scannen, NDEF dekodieren, Signaturen klassifizieren und Tags beschreiben.';

  @override
  String get toolNamePdfViewer => 'PDF-Viewer';

  @override
  String get toolDescPdfViewer => 'PDF-Dateien einfach im Vollbild ansehen';

  @override
  String get toolNameNotes => 'Notizen';

  @override
  String get toolDescNotes =>
      'Einfaches Notiz-Tool mit Markdown-Unterstützung und Backend-Sync';

  @override
  String get toolNameGroceryList => 'Einkaufsliste';

  @override
  String get toolDescGroceryList =>
      'Erstelle Einkaufslisten mit Mengen, wiederverwendbaren Artikeln und Abhakkontrolle';

  @override
  String get groceryNoItems => 'Keine Artikel in deiner Einkaufsliste';

  @override
  String get groceryAddItem => 'Artikel hinzufügen';

  @override
  String get groceryEditItem => 'Artikel bearbeiten';

  @override
  String get groceryItemName => 'Artikelname';

  @override
  String get groceryAmount => 'Menge';

  @override
  String get groceryUnit => 'Einheit';

  @override
  String get groceryAdd => 'Hinzufügen';

  @override
  String get groceryUpdate => 'Aktualisieren';

  @override
  String get groceryClearBought => 'Gekaufte löschen';

  @override
  String get groceryReAddBought => 'Gekaufte wieder hinzufügen';

  @override
  String get groceryExport => 'Exportieren';

  @override
  String get groceryImport => 'Importieren';

  @override
  String groceryConfirmClearBought(int count) {
    return '$count gekaufte(n) Artikel entfernen?';
  }

  @override
  String groceryConfirmDelete(String name) {
    return '\"$name\" löschen?';
  }

  @override
  String groceryImportComplete(int imported, int skipped) {
    return 'Import abgeschlossen! Importiert: $imported, Übersprungen: $skipped (Duplikate).';
  }

  @override
  String groceryImportFailed(String error) {
    return 'Import fehlgeschlagen: $error';
  }

  @override
  String groceryItemsCount(int unchecked, int checked) {
    return '$unchecked zu kaufen, $checked gekauft';
  }

  @override
  String get groceryAllBoughtMovedBack =>
      'Alle gekauften Artikel wieder zur Liste hinzugefügt.';

  @override
  String get grocerySync => 'Synchronisieren';

  @override
  String get toolNameMarkdownViewer => 'Markdown-Viewer';

  @override
  String get toolDescMarkdownViewer =>
      'Markdown-Dateien einfach im Vollbild ansehen';

  @override
  String get toolNameImageViewer => 'Bildbetrachter';

  @override
  String get toolDescImageViewer =>
      'Bilder ansehen, zoomen, skalieren und Formate konvertieren';

  @override
  String get toolNameFastDrop => 'Fast Drop';

  @override
  String get toolDescFastDrop =>
      'Dateien oder Zwischenablage schnell zur temporären Ablage und Freigabe auf den Server übertragen';

  @override
  String get toolNameImagesToPdf => 'Bilder zu PDF';

  @override
  String get toolDescImagesToPdf =>
      'Mehrere Bilder in ein einzelnes PDF-Dokument umwandeln';

  @override
  String get toolNameChiptune => 'Chiptune-Player';

  @override
  String get toolDescChiptune => 'Tracker-Module und Audiodateien abspielen';

  @override
  String get toolNameFocusNoise => 'Fokus-Rauschen & Atmung';

  @override
  String get toolDescFocusNoise =>
      'Player für Umgebungsgeräusche mit geführten Atemübungen';

  @override
  String get toolNameSignatures => 'Unterschriften-Ersteller';

  @override
  String get toolDescSignatures =>
      'Unterschriften zeichnen und als transparentes PNG oder SVG exportieren';

  @override
  String get toolNameQrCode => 'QR-Code';

  @override
  String get toolDescQrCode =>
      'QR-Codes mit der Kamera oder einem Bild scannen und eigene erstellen';

  @override
  String get qrTabScan => 'Scannen';

  @override
  String get qrTabCreate => 'Erstellen';

  @override
  String get qrModeCamera => 'Kamera';

  @override
  String get qrModeImage => 'Bild';

  @override
  String get qrScannerEngineZxing => 'ZXing';

  @override
  String get qrScannerEngineMlKit => 'ML Kit';

  @override
  String get qrCameraZoom => 'Zoom';

  @override
  String get qrCameraTorch => 'Taschenlampe';

  @override
  String get qrImagesLabel => 'Bilder';

  @override
  String get qrScanDropTitle => 'QR-Code aus einem Bild scannen';

  @override
  String get qrScanDropSubtitle => 'Bild hierher ziehen oder eines auswählen';

  @override
  String get qrBrowseImage => 'Bild auswählen';

  @override
  String get qrPasteImage => 'Bild einfügen';

  @override
  String get qrPickFromGallery => 'Aus Galerie wählen';

  @override
  String get qrNoCodeFound => 'Kein QR-Code im Bild gefunden';

  @override
  String get qrNoImageInClipboard => 'Kein Bild in der Zwischenablage';

  @override
  String get qrScanAgain => 'Erneut scannen';

  @override
  String get qrResultOpen => 'Öffnen';

  @override
  String get qrActionCopy => 'Kopieren';

  @override
  String get qrActionShare => 'Teilen';

  @override
  String get qrCopied => 'In die Zwischenablage kopiert';

  @override
  String get qrOpenFailed => 'Inhalt konnte nicht geöffnet werden';

  @override
  String get qrKindLink => 'Link';

  @override
  String get qrKindWifi => 'WLAN-Netzwerk';

  @override
  String get qrKindEmail => 'E-Mail';

  @override
  String get qrKindPhone => 'Telefonnummer';

  @override
  String get qrKindSms => 'SMS';

  @override
  String get qrKindLocation => 'Standort';

  @override
  String get qrKindContact => 'Kontakt';

  @override
  String get qrKindText => 'Text';

  @override
  String get qrKindFido => 'Passkey-Anfrage';

  @override
  String get qrKindOtp => '2FA / Authentifikator';

  @override
  String get qrKindMath => 'Mathematischer Ausdruck';

  @override
  String get qrKindCoordinate => 'Koordinaten';

  @override
  String get qrKindNumber => 'Numerischer Wert';

  @override
  String get qrResultFulfillPasskey => 'Passkey ausführen';

  @override
  String get qrResultOpenAuthenticator => 'Zum Authentifikator hinzufügen';

  @override
  String get qrResultCalculate => 'Berechnen';

  @override
  String get qrResultShowOnMap => 'Auf Karte zeigen';

  @override
  String get qrResultConvertUnit => 'Einheit umrechnen';

  @override
  String get qrResultUseInCalc => 'Im Rechner verwenden';

  @override
  String get qrResultSimulatePasskey => 'Passkey simulieren';

  @override
  String get qrPasskeySimTitle => 'Passkey-Simulator';

  @override
  String get qrPasskeySimSuccess =>
      'Mock-Passkey hat die Anfrage erfolgreich signiert!';

  @override
  String get qrPasskeySimPrompt =>
      'Bestätigen Sie Ihren Fingerabdruck oder PIN, um die Authentifizierung freizugeben.';

  @override
  String get qrPasskeySimUser => 'Benutzer: alice@example.com';

  @override
  String get qrPasskeySimDomain => 'Domain: secure.login';

  @override
  String get qrTypeText => 'Text';

  @override
  String get qrTypeUrl => 'URL';

  @override
  String get qrTypeWifi => 'WLAN';

  @override
  String get qrTypeEmail => 'E-Mail';

  @override
  String get qrTypePhone => 'Telefon';

  @override
  String get qrTypeSms => 'SMS';

  @override
  String get qrTypeGeo => 'Standort';

  @override
  String get qrTypeVcard => 'Kontakt';

  @override
  String get qrFieldText => 'Text';

  @override
  String get qrFieldUrl => 'URL';

  @override
  String get qrFieldSsid => 'Netzwerkname (SSID)';

  @override
  String get qrFieldPassword => 'Passwort';

  @override
  String get qrFieldEncryption => 'Verschlüsselung';

  @override
  String get qrFieldHidden => 'Verstecktes Netzwerk';

  @override
  String get qrEncWpa => 'WPA/WPA2';

  @override
  String get qrEncWep => 'WEP';

  @override
  String get qrEncNone => 'Keine';

  @override
  String get qrFieldEmail => 'E-Mail-Adresse';

  @override
  String get qrFieldSubject => 'Betreff';

  @override
  String get qrFieldBody => 'Nachricht';

  @override
  String get qrFieldPhone => 'Telefonnummer';

  @override
  String get qrFieldMessage => 'Nachricht';

  @override
  String get qrFieldLatitude => 'Breitengrad';

  @override
  String get qrFieldLongitude => 'Längengrad';

  @override
  String get qrFieldName => 'Vollständiger Name';

  @override
  String get qrFieldOrganization => 'Organisation';

  @override
  String get qrCreatePlaceholder =>
      'Felder ausfüllen, um einen QR-Code zu erzeugen';

  @override
  String get qrEncodeFailed => 'Inhalt ist zu lang für einen QR-Code';

  @override
  String get qrActionSave => 'Speichern';

  @override
  String get qrActionCopyImage => 'Bild kopieren';

  @override
  String get qrImageCopied => 'QR-Bild in die Zwischenablage kopiert';

  @override
  String get qrCopyImageFailed => 'QR-Bild konnte nicht kopiert werden';

  @override
  String get qrSavedToDownloads => 'QR-Code im Downloads-Ordner gespeichert';

  @override
  String qrSavedTo(String path) {
    return 'QR-Code gespeichert unter $path';
  }

  @override
  String qrSaveFailed(String error) {
    return 'QR-Code konnte nicht gespeichert werden: $error';
  }

  @override
  String get toolNameDocumentScanner => 'Dokumentenscanner';

  @override
  String get toolDescDocumentScanner =>
      'Dokumente per Kamera scannen, Zuschnitt/Verzerrung anpassen, Filter anwenden und als PDF zusammenstellen';

  @override
  String get docScanNoPages => 'Noch keine gescannten Seiten';

  @override
  String get docScanAddHint =>
      'Fügen Sie Seiten mit der Kamera oder Galerie hinzu';

  @override
  String docScanPageTitle(int number) {
    return 'Seite $number';
  }

  @override
  String docScanFilterLabel(String filter) {
    return 'Filter: $filter';
  }

  @override
  String docScanRotationLabel(int rotation) {
    return 'Drehung: $rotation°';
  }

  @override
  String docScanSizeLabel(int width, int height) {
    return 'Größe: ${width}x$height';
  }

  @override
  String docScanEditPageTitle(int number) {
    return 'Seite $number bearbeiten';
  }

  @override
  String get docScanRotateL => 'Links drehen';

  @override
  String get docScanRotateR => 'Rechts drehen';

  @override
  String get docScanCropWarp => 'Zuschneiden & Entzerren';

  @override
  String get docScanFiltersHeading => 'Filter';

  @override
  String get docScanFilterOriginal => 'Original';

  @override
  String get docScanFilterGrayscale => 'Graustufen';

  @override
  String get docScanFilterBw => 'Schwarz-Weiß';

  @override
  String get docScanFilterClean => 'Dokument bereinigen';

  @override
  String get docScanClearTitle => 'Alle Seiten löschen';

  @override
  String get docScanClearMessage =>
      'Sind Sie sicher, dass Sie alle gescannten Seiten löschen möchten? Dies kann nicht rückgängig gemacht werden.';

  @override
  String get docScanClearConfirm => 'Alle löschen';

  @override
  String get docScanActionScan => 'Seite scannen';

  @override
  String get docScanActionGallery => 'Aus Galerie importieren';

  @override
  String get docScanActionSave => 'PDF-Dokument speichern';

  @override
  String get docScanGeneratingPdf => 'PDF-Dokument wird erstellt...';

  @override
  String docScanSavedPdf(String path) {
    return 'PDF gespeichert unter $path';
  }

  @override
  String docScanFailedPdf(String error) {
    return 'PDF konnte nicht gespeichert werden: $error';
  }

  @override
  String docScanFailedCreate(String error) {
    return 'PDF-Erstellung fehlgeschlagen: $error';
  }

  @override
  String docScanFailedCamera(String error) {
    return 'Kameraaufnahme fehlgeschlagen: $error';
  }

  @override
  String docScanFailedGallery(String error) {
    return 'Bildauswahl fehlgeschlagen: $error';
  }

  @override
  String get docScanCropReset => 'Zurücksetzen';

  @override
  String get docScanCropUndo => 'Rückgängig';

  @override
  String get docScanCropApply => 'Anwenden';

  @override
  String get docScanCropCancel => 'Abbrechen';

  @override
  String get docScanActionScanMlKit => 'Seite scannen (ML Kit)';

  @override
  String get docScanActionScanStandard => 'Seite scannen (Standard)';

  @override
  String get docScanMethodTitle => 'Scan-Methode auswählen';

  @override
  String docScanFailedMlKit(String error) {
    return 'ML Kit Scan fehlgeschlagen: $error';
  }

  @override
  String get docScanMlKitUnavailableFallback =>
      'Dokumentenscanner nicht verfügbar, Kamera wird stattdessen verwendet.';

  @override
  String get toolNameGpsLocationStore => 'GPS-Standortspeicher';

  @override
  String get toolDescGpsLocationStore =>
      'Aktuellen Standort mit Notizen und Kartenlinks erfassen und speichern';

  @override
  String get gpsStoreLocateButton => 'Aktuellen Standort anzeigen';

  @override
  String get gpsStoreCurrentTitle => 'Aktueller Standort';

  @override
  String get gpsStoreSaveThis => 'Diesen Standort speichern';

  @override
  String get gpsStoreLastSavedTitle => 'Zuletzt gespeicherter Standort';

  @override
  String get gpsStoreHistoryTitle => 'Verlauf';

  @override
  String get gpsStoreOpenGoogleMaps => 'Google Maps';

  @override
  String get gpsStoreOpenOsm => 'OpenStreetMap';

  @override
  String get gpsStoreSourceGps => 'GPS';

  @override
  String get gpsStoreSourceApproxIp => 'Ungefähr (IP)';

  @override
  String gpsStoreAccuracyMeters(int meters) {
    return '±$meters m';
  }

  @override
  String get gpsStoreSaveLocationTitle => 'Standort speichern';

  @override
  String get gpsStoreEditDescription => 'Beschreibung bearbeiten';

  @override
  String get gpsStoreDescriptionLabel => 'Beschreibung';

  @override
  String get gpsStoreDescriptionHint => 'Kurze Notiz hinzufügen (optional)';

  @override
  String get gpsStoreIpFallbackNote =>
      'Genaues GPS war nicht verfügbar — dies ist eine ungefähre Position basierend auf deiner IP-Adresse.';

  @override
  String get gpsStoreLocationSaved => 'Standort gespeichert';

  @override
  String get gpsStoreCaptureFailed =>
      'Standort konnte nicht ermittelt werden. Berechtigungen und Verbindung prüfen.';

  @override
  String get gpsStoreDeleteTitle => 'Standort löschen';

  @override
  String get gpsStoreDeleteMessage =>
      'Dieser Standort wird dauerhaft entfernt.';

  @override
  String get gpsStoreEmptyTitle => 'Noch keine Standorte';

  @override
  String get gpsStoreEmptyMessage =>
      'Tippe auf \"Aktuellen Standort anzeigen\", um deine Position zu ermitteln und anschließend zu speichern.';

  @override
  String get gpsStoreDistanceFromHere =>
      'Entfernung und Richtung von deiner aktuellen Position';

  @override
  String get gpsStoreCompassN => 'N';

  @override
  String get gpsStoreCompassNE => 'NO';

  @override
  String get gpsStoreCompassE => 'O';

  @override
  String get gpsStoreCompassSE => 'SO';

  @override
  String get gpsStoreCompassS => 'S';

  @override
  String get gpsStoreCompassSW => 'SW';

  @override
  String get gpsStoreCompassW => 'W';

  @override
  String get gpsStoreCompassNW => 'NW';

  @override
  String get gpsInfoButtonTooltip => 'GPS-Hardware-Details';

  @override
  String get gpsInfoTitle => 'GPS- & Satelliteninfo';

  @override
  String get gpsInfoLatitude => 'Breitengrad';

  @override
  String get gpsInfoLongitude => 'Längengrad';

  @override
  String get gpsInfoAltitude => 'Höhe';

  @override
  String get gpsInfoSpeed => 'Geschwindigkeit';

  @override
  String get gpsInfoHeading => 'Kurs';

  @override
  String get gpsInfoAccuracy => 'Genauigkeit';

  @override
  String get gpsInfoTimestamp => 'Letzter Fix-Zeitpunkt';

  @override
  String get gpsInfoProvider => 'Quell-Provider';

  @override
  String get gpsInfoMocked => 'Simulierter Standort';

  @override
  String get gpsInfoPositionDetails => 'Aktuelle Positionsdaten';

  @override
  String get gpsInfoHardwareDetails => 'GNSS-Konstellationen & Hardware';

  @override
  String get gpsInfoSatelliteCount => 'Sichtbare Satelliten';

  @override
  String get gpsInfoSatelliteCountUsed => 'Verwendete Satelliten';

  @override
  String get gpsInfoLocationProviders => 'System-Standortanbieter';

  @override
  String get gpsInfoConstellationGps => 'GPS (USA)';

  @override
  String get gpsInfoConstellationGlonass => 'GLONASS (Russland)';

  @override
  String get gpsInfoConstellationGalileo => 'Galileo (EU)';

  @override
  String get gpsInfoConstellationBeidou => 'BeiDou (China)';

  @override
  String get gpsInfoConstellationQzss => 'QZSS (Japan)';

  @override
  String get gpsInfoConstellationSbas => 'SBAS';

  @override
  String get gpsInfoConstellationIrnss => 'NavIC / IRNSS (Indien)';

  @override
  String get gpsInfoConstellationUnknown => 'Unbekannte Konstellation';

  @override
  String get gpsInfoStatusScanning => 'Satellitensignale werden erfasst...';

  @override
  String get gpsInfoStatusNotAvailable =>
      'Satellitenstatus auf dieser Plattform nicht unterstützt.';

  @override
  String get gpsInfoSatelliteList => 'Satelliten-Details';

  @override
  String gpsInfoSatelliteSvid(int svid) {
    return 'SVID: $svid';
  }

  @override
  String gpsInfoSatelliteCn0(double cn0) {
    return 'SNR: $cn0 dB-Hz';
  }

  @override
  String get gpsInfoSatelliteUsed => 'In Fix verwendet';

  @override
  String gpsInfoSatelliteElevation(double elevation) {
    return 'H: $elevation°';
  }

  @override
  String gpsInfoSatelliteAzimuth(double azimuth) {
    return 'Az: $azimuth°';
  }

  @override
  String get gpsInfoProviderEnabled => 'Aktiviert';

  @override
  String get gpsInfoProviderDisabled => 'Deaktiviert';

  @override
  String get toolNameChatAi => 'KI Chat';

  @override
  String get toolDescChatAi =>
      'Chatten Sie mit dem geräteinternen KI-Modell Gemini Nano über ML Kit';

  @override
  String get chatAiUnsupportedPlatform =>
      'On-Device AI Chat wird nur unter Android unterstützt. Desktop- und iOS-Plattformen werden von der ML Kit GenAI Prompt API nicht unterstützt.';

  @override
  String get chatAiNewChat => 'Neuer Chat';

  @override
  String chatAiModelStatus(String status) {
    return 'Modellstatus: $status';
  }

  @override
  String get chatAiModelLoading =>
      'Modell wird heruntergeladen... Dies kann eine Weile dauern.';

  @override
  String get chatAiModelReady => 'Modell bereit';

  @override
  String get chatAiModelNotDownloaded =>
      'Modell nicht heruntergeladen. Tippen Sie auf Herunterladen, um zu starten.';

  @override
  String get chatAiDownloadButton => 'Modell herunterladen';

  @override
  String get chatAiInputPlaceholder => 'Schreiben Sie eine Nachricht...';

  @override
  String get chatAiDeleteSession => 'Sitzung löschen';

  @override
  String get chatAiDeleteSessionConfirm =>
      'Sind Sie sicher, dass Sie diese Chatsitzung und alle ihre Nachrichten löschen möchten?';

  @override
  String get chatAiAttachImage => 'Bild anfügen';

  @override
  String get chatAiAttachDocument => 'Dokument anfügen';

  @override
  String get chatAiAttachTooltip => 'Datei oder Bild anfügen';

  @override
  String get chatAiPrepareButton => 'KI Core vorbereiten';

  @override
  String get chatAiClearHistory => 'Verlauf löschen';

  @override
  String get chatAiClearHistoryConfirm =>
      'Sind Sie sicher, dass Sie alle Nachrichten in diesem Chat löschen möchten?';

  @override
  String get chatAiThinking => 'Überlegt...';

  @override
  String get chatAiSystemPromptTitle => 'System-Prompt';

  @override
  String get chatAiSystemPromptDescription =>
      'Passen Sie die Anweisungen für das KI-Modell an. Leer lassen, um den Standard zu verwenden.';

  @override
  String get toolNameHexEditor => 'Hex-Editor';

  @override
  String get toolDescHexEditor =>
      'Dateien in Hexadezimal- und ASCII-Ansichten inspizieren und bearbeiten';

  @override
  String get hexEditorTypeLabel => 'Jede Datei';

  @override
  String get hexEditorOpenTitle => 'Beliebige Datei öffnen';

  @override
  String get hexEditorDropSubtitle => 'Ziehen Sie eine beliebige Datei hierher';

  @override
  String get hexEditorStringsTitle => 'Druckbare Zeichenketten';

  @override
  String get hexEditorMinLength => 'Mindestlänge';

  @override
  String get hexEditorScan => 'Scannen';

  @override
  String get hexEditorScanning => 'Scannen...';

  @override
  String hexEditorScannedBytes(String scanned, String total) {
    return '$scanned / $total Bytes gescannt';
  }

  @override
  String hexEditorFoundStrings(int count) {
    return '$count Zeichenketten gefunden';
  }

  @override
  String get hexEditorCancelled => 'Abgebrochen';

  @override
  String get hexEditorNoStringsFound => 'Keine Zeichenketten gefunden';

  @override
  String get hexEditorExportStarted => 'Export gestartet';

  @override
  String hexEditorExportFailed(String error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String hexEditorFailedToLoad(String error) {
    return 'Datei konnte nicht geladen werden: $error';
  }

  @override
  String get hexEditorOffset => 'Offset';

  @override
  String hexEditorSize(String size) {
    return 'Größe: $size Bytes';
  }

  @override
  String get hexEditorSearchType => 'Suchtyp';

  @override
  String get hexEditorSearchHex => 'Hexadezimal';

  @override
  String get hexEditorSearchText => 'Text';

  @override
  String get hexEditorSearchPlaceholder => 'Suchmuster';

  @override
  String get hexEditorShowAscii => 'ASCII-Ansicht anzeigen';

  @override
  String get hexEditorReset => 'Zurücksetzen';

  @override
  String get hexEditorStringsTooltip => 'Strings';

  @override
  String get hexEditorSearchNext => 'Nächster Treffer';

  @override
  String get hexEditorSearchPrev => 'Vorheriger Treffer';

  @override
  String get hexEditorInvalidHex => 'Ungültiges Hex-Muster';

  @override
  String get hexEditorHexLengthEven => 'Hex-Suche muss eine gerade Länge haben';

  @override
  String get hexEditorPatternNotFound => 'Muster nicht gefunden';

  @override
  String hexEditorEditByteTitle(String offset) {
    return 'Byte bearbeiten bei $offset';
  }

  @override
  String get hexEditorEditByteHex => 'Hex';

  @override
  String get hexEditorEditByteAscii => 'ASCII';

  @override
  String get hexEditorSave => 'Speichern';

  @override
  String get hexEditorDiscardChangesTitle => 'Änderungen verwerfen?';

  @override
  String get hexEditorDiscardChangesMessage =>
      'Möchten Sie Ihre Änderungen verwerfen?';

  @override
  String get hexEditorKeepEditing => 'Weiter bearbeiten';

  @override
  String get hexEditorDiscard => 'Verwerfen';

  @override
  String get toolNameFileConverter => 'Datei-Konverter';

  @override
  String get toolDescFileConverter =>
      'Dokumente zwischen DOCX, PDF, HTML, Markdown und Text konvertieren';

  @override
  String get fileConverterTypeLabel => 'Dokumente';

  @override
  String get fileConverterOpenTitle => 'Dokument öffnen';

  @override
  String get fileConverterDropSubtitle =>
      'DOCX-, PDF-, HTML-, Markdown- oder Textdatei hierher ziehen';

  @override
  String get fileConverterConvertTo => 'Konvertieren zu';

  @override
  String get fileConverterConvert => 'Konvertieren';

  @override
  String get fileConverterConverting => 'Konvertiere…';

  @override
  String get fileConverterUnsupported =>
      'Dieser Dateityp kann nicht konvertiert werden';

  @override
  String fileConverterError(String error) {
    return 'Konvertierung fehlgeschlagen: $error';
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
  String get fileConverterFormatTxt => 'Nur Text';

  @override
  String get toolNameSketchBoard => 'Skizzenbrett';

  @override
  String get toolDescSketchBoard =>
      'Unendliche Zeichenfläche mit Freihand, Formen, Text und gespeicherten Zeichnungen';

  @override
  String get sketchTabDraw => 'Zeichnen';

  @override
  String get sketchTabSaved => 'Gespeichert';

  @override
  String get sketchToolSelect => 'Auswählen';

  @override
  String get sketchToolPan => 'Verschieben';

  @override
  String get sketchToolPen => 'Stift';

  @override
  String get sketchToolLine => 'Linie';

  @override
  String get sketchToolArrow => 'Pfeil';

  @override
  String get sketchToolRect => 'Rechteck';

  @override
  String get sketchToolEllipse => 'Ellipse';

  @override
  String get sketchToolDiamond => 'Raute';

  @override
  String get sketchToolTriangle => 'Dreieck';

  @override
  String get sketchToolHexagon => 'Sechseck';

  @override
  String get sketchToolDoubleArrow => 'Doppelpfeil';

  @override
  String get sketchToolSpeechBubble => 'Sprechblase';

  @override
  String get sketchToolCheckmark => 'Häkchen';

  @override
  String get sketchToolText => 'Text';

  @override
  String get sketchPropStroke => 'Linie';

  @override
  String get sketchPropFill => 'Füllung';

  @override
  String get sketchPropWidth => 'Breite';

  @override
  String get sketchPropText => 'Text';

  @override
  String get sketchEmptyHint => 'Werkzeug wählen und loszeichnen';

  @override
  String get sketchGalleryEmpty => 'Noch keine Zeichnungen gespeichert.';

  @override
  String sketchElementCount(int count) {
    return '$count Elemente';
  }

  @override
  String get sketchTextTitle => 'Text hinzufügen';

  @override
  String get sketchTextHint => 'Text eingeben…';

  @override
  String get sketchSaveTitle => 'Zeichnung speichern';

  @override
  String get sketchSaveHint => 'Name der Zeichnung';

  @override
  String sketchDefaultName(String date) {
    return 'Zeichnung $date';
  }

  @override
  String get sketchSaved => 'Zeichnung gespeichert';

  @override
  String get sketchNothingToExport => 'Noch nichts zu zeichnen';

  @override
  String get sketchExportTitle => 'Bild exportieren';

  @override
  String get sketchExportFormat => 'Format';

  @override
  String get sketchExportQuality => 'Qualität';

  @override
  String get sketchExportLossless =>
      'PNG ist verlustfrei — keine Qualitätseinstellung.';

  @override
  String get sketchExportResolution => 'Auflösung';

  @override
  String get sketchExportEstimatedSize => 'Geschätzte Größe';

  @override
  String get sketchCopied => 'In Zwischenablage kopiert';

  @override
  String get sketchDeleteTitle => 'Zeichnung löschen';

  @override
  String get sketchDeleteContent =>
      'Die gespeicherte Zeichnung wird endgültig entfernt.';

  @override
  String get sketchClearTitle => 'Leinwand leeren';

  @override
  String get sketchClearContent => 'Alles von der Leinwand entfernen?';

  @override
  String get sketchBackgroundTitle => 'Hintergrund';

  @override
  String get sketchBgCheckerboard => 'Schachbrett';

  @override
  String get sketchBgWhite => 'Weiß';

  @override
  String get sketchBgBlack => 'Schwarz';

  @override
  String get sketchMenuBackground => 'Hintergrund';

  @override
  String get sketchMenuResetView => 'Ansicht zurücksetzen';

  @override
  String get sketchUndo => 'Rückgängig';

  @override
  String get sketchRedo => 'Wiederholen';

  @override
  String get sketchToolShapes => 'Formen';

  @override
  String get sketchColorTitle => 'Farbe';

  @override
  String get sketchColorOpacity => 'Deckkraft';

  @override
  String get sketchDiscardTitle => 'Änderungen verwerfen?';

  @override
  String get sketchDiscardMessage =>
      'Es gibt ungespeicherte Änderungen. Verwerfen?';

  @override
  String get sketchDiscard => 'Verwerfen';

  @override
  String get sketchKeepEditing => 'Weiter bearbeiten';

  @override
  String get sketchBringToFront => 'In den Vordergrund';

  @override
  String get sketchSendToBack => 'In den Hintergrund';

  @override
  String get sketchGroup => 'Gruppieren';

  @override
  String get sketchUngroup => 'Gruppierung aufheben';

  @override
  String get sketchResetRotation => 'Drehung zurücksetzen';

  @override
  String get sketchInsertImage => 'Bild einfügen';

  @override
  String get sketchPasteImage => 'Bild aus Zwischenablage';

  @override
  String get sketchNoClipboardImage => 'Kein Bild in der Zwischenablage';

  @override
  String get sketchPropBrush => 'Pinsel';

  @override
  String get sketchBrushNormal => 'Normal';

  @override
  String get sketchBrushShaky => 'Wackelig';

  @override
  String get sketchBrushNatural => 'Natürlich';

  @override
  String get sketchSelectBox => 'Rechteckauswahl';

  @override
  String get sketchSelectLasso => 'Lasso-Auswahl';

  @override
  String get sketchResetImageSize => 'Bildgröße zurücksetzen';

  @override
  String get sketchMenuInfo => 'Board-Info';

  @override
  String get sketchInfoTitle => 'Sketch-Board-Informationen';

  @override
  String get sketchInfoViewportSize => 'Viewport-Größe';

  @override
  String get sketchInfoContentBounds => 'Inhaltsabmessungen';

  @override
  String get sketchInfoTotalElements => 'Gesamte Elemente';

  @override
  String get sketchInfoZoomLevel => 'Zoom-Stufe';

  @override
  String get sketchInfoElementsBreakdown => 'Elemente-Aufteilung';

  @override
  String get sketchInfoPenElements => 'Stift-Elemente';

  @override
  String get sketchInfoShapeElements => 'Form-Elemente';

  @override
  String get sketchInfoTextElements => 'Text-Elemente';

  @override
  String get sketchInfoImageElements => 'Bild-Elemente';

  @override
  String get sketchInfoGroupElements => 'Gruppen-Elemente';

  @override
  String get sketchInfoViewOffset => 'Kameraposition';

  @override
  String get sketchInfoUnsavedChanges => 'Ungespeicherte Änderungen';

  @override
  String get toolNameUnitConverter => 'Einheitenumrechner';

  @override
  String get toolDescUnitConverter =>
      'Einheiten in vielen Kategorien umrechnen';

  @override
  String get ucFrom => 'Von';

  @override
  String get ucTo => 'Nach';

  @override
  String get ucSwap => 'Einheiten tauschen';

  @override
  String get ucCopyResult => 'Ergebnis kopieren';

  @override
  String get ucCopied => 'In Zwischenablage kopiert';

  @override
  String get ucValueHint => 'Wert eingeben';

  @override
  String get ucAllUnits => 'Alle Einheiten';

  @override
  String get ucCatLength => 'Länge';

  @override
  String get ucCatMass => 'Masse';

  @override
  String get ucCatTemperature => 'Temperatur';

  @override
  String get ucCatArea => 'Fläche';

  @override
  String get ucCatVolume => 'Volumen';

  @override
  String get ucCatSpeed => 'Geschwindigkeit';

  @override
  String get ucCatTime => 'Zeit';

  @override
  String get ucCatData => 'Daten';

  @override
  String get ucCatPressure => 'Druck';

  @override
  String get ucCatEnergy => 'Energie';

  @override
  String get ucCatPower => 'Leistung';

  @override
  String get ucCatAngle => 'Winkel';

  @override
  String get ucCatFrequency => 'Frequenz';

  @override
  String get ucCatDataRate => 'Datenrate';

  @override
  String get ucCatFuel => 'Verbrauch';

  @override
  String get ucuMeter => 'Meter';

  @override
  String get ucuKilometer => 'Kilometer';

  @override
  String get ucuCentimeter => 'Zentimeter';

  @override
  String get ucuMillimeter => 'Millimeter';

  @override
  String get ucuMile => 'Meile';

  @override
  String get ucuYard => 'Yard';

  @override
  String get ucuFoot => 'Fuß';

  @override
  String get ucuInch => 'Zoll';

  @override
  String get ucuKilogram => 'Kilogramm';

  @override
  String get ucuGram => 'Gramm';

  @override
  String get ucuMilligram => 'Milligramm';

  @override
  String get ucuMetricTon => 'Tonne';

  @override
  String get ucuPound => 'Pfund';

  @override
  String get ucuOunce => 'Unze';

  @override
  String get ucuStone => 'Stone';

  @override
  String get ucuUsTon => 'US-Tonne';

  @override
  String get ucuCelsius => 'Celsius';

  @override
  String get ucuFahrenheit => 'Fahrenheit';

  @override
  String get ucuKelvin => 'Kelvin';

  @override
  String get ucuRankine => 'Rankine';

  @override
  String get ucuSquareMeter => 'Quadratmeter';

  @override
  String get ucuSquareKilometer => 'Quadratkilometer';

  @override
  String get ucuSquareCentimeter => 'Quadratzentimeter';

  @override
  String get ucuHectare => 'Hektar';

  @override
  String get ucuSquareMile => 'Quadratmeile';

  @override
  String get ucuAcre => 'Acre';

  @override
  String get ucuSquareFoot => 'Quadratfuß';

  @override
  String get ucuLiter => 'Liter';

  @override
  String get ucuMilliliter => 'Milliliter';

  @override
  String get ucuCubicMeter => 'Kubikmeter';

  @override
  String get ucuGallonUs => 'Gallone (US)';

  @override
  String get ucuQuartUs => 'Quart (US)';

  @override
  String get ucuPintUs => 'Pint (US)';

  @override
  String get ucuCupUs => 'Tasse (US)';

  @override
  String get ucuFluidOunceUs => 'Flüssigunze (US)';

  @override
  String get ucuMeterPerSecond => 'Meter pro Sekunde';

  @override
  String get ucuKilometerPerHour => 'Kilometer pro Stunde';

  @override
  String get ucuMilePerHour => 'Meile pro Stunde';

  @override
  String get ucuFootPerSecond => 'Fuß pro Sekunde';

  @override
  String get ucuKnot => 'Knoten';

  @override
  String get ucuMach => 'Mach';

  @override
  String get ucuSecond => 'Sekunde';

  @override
  String get ucuMillisecond => 'Millisekunde';

  @override
  String get ucuMinute => 'Minute';

  @override
  String get ucuHour => 'Stunde';

  @override
  String get ucuDay => 'Tag';

  @override
  String get ucuWeek => 'Woche';

  @override
  String get ucuMonth => 'Monat';

  @override
  String get ucuYear => 'Jahr';

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
  String get ucuAtmosphere => 'Atmosphäre';

  @override
  String get ucuTorr => 'Torr';

  @override
  String get ucuPsi => 'Pound pro Quadratzoll';

  @override
  String get ucuMmhg => 'Millimeter Quecksilbersäule';

  @override
  String get ucuJoule => 'Joule';

  @override
  String get ucuKilojoule => 'Kilojoule';

  @override
  String get ucuCalorie => 'Kalorie';

  @override
  String get ucuKilocalorie => 'Kilokalorie';

  @override
  String get ucuWattHour => 'Wattstunde';

  @override
  String get ucuKilowattHour => 'Kilowattstunde';

  @override
  String get ucuElectronvolt => 'Elektronenvolt';

  @override
  String get ucuBtu => 'Britische Wärmeeinheit';

  @override
  String get ucuWatt => 'Watt';

  @override
  String get ucuKilowatt => 'Kilowatt';

  @override
  String get ucuMegawatt => 'Megawatt';

  @override
  String get ucuMilliwatt => 'Milliwatt';

  @override
  String get ucuHorsepower => 'Pferdestärke';

  @override
  String get ucuMetricHorsepower => 'Metrische Pferdestärke';

  @override
  String get ucuDegree => 'Grad';

  @override
  String get ucuRadian => 'Radiant';

  @override
  String get ucuGradian => 'Gon';

  @override
  String get ucuArcminute => 'Bogenminute';

  @override
  String get ucuArcsecond => 'Bogensekunde';

  @override
  String get ucuTurn => 'Umdrehung';

  @override
  String get ucuHertz => 'Hertz';

  @override
  String get ucuKilohertz => 'Kilohertz';

  @override
  String get ucuMegahertz => 'Megahertz';

  @override
  String get ucuGigahertz => 'Gigahertz';

  @override
  String get ucuRpm => 'Umdrehungen pro Minute';

  @override
  String get ucuBitPerSecond => 'Bit pro Sekunde';

  @override
  String get ucuKilobitPerSecond => 'Kilobit pro Sekunde';

  @override
  String get ucuMegabitPerSecond => 'Megabit pro Sekunde';

  @override
  String get ucuGigabitPerSecond => 'Gigabit pro Sekunde';

  @override
  String get ucuBytePerSecond => 'Byte pro Sekunde';

  @override
  String get ucuKilobytePerSecond => 'Kilobyte pro Sekunde';

  @override
  String get ucuMegabytePerSecond => 'Megabyte pro Sekunde';

  @override
  String get ucuGigabytePerSecond => 'Gigabyte pro Sekunde';

  @override
  String get ucuKmPerLiter => 'Kilometer pro Liter';

  @override
  String get ucuLiterPer100km => 'Liter pro 100 km';

  @override
  String get ucuMpgUs => 'Meilen pro Gallone (US)';

  @override
  String get ucuMpgUk => 'Meilen pro Gallone (UK)';

  @override
  String get focusBreathingBox => 'Box 4-4-4-4';

  @override
  String get focusBreathingRelax => 'Entspannung 4-7-8';

  @override
  String get focusBreathingCalm => 'Ruhe 5-5';

  @override
  String get focusBreathingInhale => 'Einatmen';

  @override
  String get focusBreathingHold => 'Anhalten';

  @override
  String get focusBreathingExhale => 'Ausatmen';

  @override
  String get focusReady => 'Bereit';

  @override
  String get hexEditorModified => 'MODIFIZIERT';

  @override
  String get sketchCopyFailed => 'In Zwischenablage kopieren fehlgeschlagen';

  @override
  String sketchExportLabelImage(String format) {
    return '$format-Bild';
  }

  @override
  String get sketchImageLabel => 'Bild';

  @override
  String get sigPngImage => 'PNG-Bild';

  @override
  String get sigSvgImage => 'SVG-Bild';

  @override
  String get sigCopyFailed => 'In Zwischenablage kopieren fehlgeschlagen';

  @override
  String get chatAiDocumentsLabel => 'Dokumente';

  @override
  String get toolNameCodeHighlight => 'Code Highlight & Edit';

  @override
  String get toolDescCodeHighlight =>
      'Syntax-Hervorhebung und Bearbeitung von Code-Dateien';

  @override
  String get codeHighlightPasteCode => 'Code einfügen';

  @override
  String get codeHighlightLoadFile => 'Datei laden';

  @override
  String get codeHighlightLanguage => 'Sprache';

  @override
  String get codeHighlightTheme => 'Design';

  @override
  String get codeHighlightEditorTitle => 'Code-Editor';

  @override
  String get codeHighlightEmptyText =>
      'Code einfügen oder eine Datei hierher ziehen, um zu beginnen';

  @override
  String codeHighlightFailedToLoad(String error) {
    return 'Code konnte nicht geladen werden: $error';
  }

  @override
  String get codeHighlightCopied => 'Code in die Zwischenablage kopiert';

  @override
  String codeHighlightFailedToCopy(String error) {
    return 'Fehler beim Kopieren des Codes: $error';
  }

  @override
  String get codeHighlightTypeLabel => 'Text- oder Quellcodedateien';

  @override
  String get codeHighlightOpenTitle => 'Codedatei öffnen';

  @override
  String get codeHighlightDropSubtitle =>
      'Datei hierher ziehen oder zum Auswählen klicken';

  @override
  String get codeHighlightOpenInViewer => 'Im Code-Highlighter öffnen';

  @override
  String get codeHighlightThemeLight => 'Helles Design';

  @override
  String get codeHighlightThemeDark => 'Dunkles Design';

  @override
  String get codeHighlightExportTitle => 'Export-Option';

  @override
  String get codeHighlightExportText => 'Als reine Textdatei exportieren';

  @override
  String get codeHighlightExportImage => 'Als farbiges Bild exportieren';

  @override
  String get codeHighlightSaveImage => 'Bild speichern';

  @override
  String get codeHighlightCopyImage => 'Bild kopieren';

  @override
  String get codeHighlightCopiedImage => 'Bild in die Zwischenablage kopiert';

  @override
  String codeHighlightFailedToCopyImage(String error) {
    return 'Fehler beim Kopieren des Bildes: $error';
  }

  @override
  String get codeHighlightFormat => 'Format';

  @override
  String codeHighlightFailedToSaveImage(String error) {
    return 'Fehler beim Speichern des Bildes: $error';
  }

  @override
  String get codeHighlightExportWarningTitle => 'Warnung: Großes Bild';

  @override
  String codeHighlightExportWarningMessage(int lines) {
    return 'Diese Datei enthält $lines Zeilen. Der Export sehr langer Codedateien als Bild schlägt möglicherweise aufgrund von Speicherbeschränkungen fehl oder der Text ist zu klein, um lesbar zu sein. Wir empfehlen stattdessen den Export als reine Textdatei.';
  }

  @override
  String get toolNameBluetoothScanner => 'Bluetooth-Scanner';

  @override
  String get toolDescBluetoothScanner =>
      'Scannen Sie nach nahegelegenen Bluetooth Low Energy Geräten und identifizieren Sie diese.';

  @override
  String get bleStartScan => 'Scan starten';

  @override
  String get bleStopScan => 'Stop';

  @override
  String get bleStartScanning =>
      'Starte Scan, um nahegelegene BLE-Geräte zu finden';

  @override
  String get bleNoDevicesFound => 'Keine Geräte gefunden';

  @override
  String get bleClearHistory => 'Verlauf löschen';

  @override
  String get bleFilterHighConfidence => 'Hohe Zuverlässigkeit';

  @override
  String get bleFilterBeacons => 'Beacons';

  @override
  String get bleFilterUnknown => 'Unbekannt';

  @override
  String get bleFilterRecent => 'Kürzlich';

  @override
  String get bleFilterStrongSignal => 'Starkes Signal';

  @override
  String get bleBluetoothOff => 'Bluetooth aus';

  @override
  String bleDeviceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Geräte',
      one: '1 Gerät',
    );
    return '$_temp0';
  }

  @override
  String get bleCategoryAudio => 'Audio';

  @override
  String get bleCategoryWearables => 'Wearables';

  @override
  String get bleCategoryHealth => 'Gesundheit';

  @override
  String get bleCategoryFitness => 'Fitness';

  @override
  String get bleCategoryIoT => 'IoT';

  @override
  String get bleCategoryPhones => 'Telefone';

  @override
  String get bleCategoryComputers => 'Computer';

  @override
  String get bleCategoryInput => 'Eingabegeräte';

  @override
  String get bleCategoryGaming => 'Gaming';

  @override
  String get bleCategoryVehicle => 'Fahrzeuge';

  @override
  String get bleCategoryUnidentified => 'Nicht identifiziert';

  @override
  String get bleConfidenceMedium => 'Mittel';

  @override
  String get bleConfidenceLow => 'Niedrig';

  @override
  String get bleDetailConfidence => 'Zuverlässigkeit';

  @override
  String get bleDetailCategory => 'Kategorie';

  @override
  String get bleDetailType => 'Typ';

  @override
  String get bleDetailRole => 'Rolle';

  @override
  String get bleDetailRSSI => 'RSSI';

  @override
  String get bleDetailDistance => 'Entfernung';

  @override
  String get bleDetailManufacturer => 'Hersteller';

  @override
  String get bleDetailIdentifiedAs => 'Identifiziert als';

  @override
  String get bleDetailFirstSeen => 'Zuerst gesehen';

  @override
  String get bleDetailLastSeen => 'Zuletzt gesehen';

  @override
  String get bleDetailSightings => 'Sichtungen';

  @override
  String get bleDetailStrongestRSSI => 'Stärkste RSSI';

  @override
  String get bleDetailSensorData => 'Sensordaten';

  @override
  String get bleDetailTemperature => 'Temperatur';

  @override
  String get bleDetailHumidity => 'Luftfeuchtigkeit';

  @override
  String get bleDetailBattery => 'Batterie';

  @override
  String get bleDetailBeacons => 'Beacons';

  @override
  String get bleDetailServices => 'Dienste';

  @override
  String get bleDetailWhyIdentified => 'Grund für Identifizierung';

  @override
  String get bleDetailRawData => 'Rohdaten';

  @override
  String get bleTimeJustNow => 'Gerade eben';

  @override
  String bleTimeMinutesAgo(int minutes) {
    return 'vor $minutes Min.';
  }

  @override
  String bleTimeHoursAgo(int hours) {
    return 'vor $hours Std.';
  }

  @override
  String bleTimeDaysAgo(int days) {
    return 'vor $days Tagen';
  }

  @override
  String get toolNameStringTransformer => 'String-Transformer';

  @override
  String get toolDescStringTransformer =>
      'Konvertieren Sie Text zwischen verschiedenen Formaten: camelCase, snake_case, kebab-case, PascalCase, URL-Slugs, Base64, Hex und dekodieren Sie Werbe-URLs.';

  @override
  String get stringTransformerInputLabel => 'Eingabetext';

  @override
  String get stringTransformerOutputLabel => 'Ausgabetext';

  @override
  String get stringTransformerSelectTransform => 'Transformation auswählen';

  @override
  String stringTransformerCharsCount(int count) {
    return '$count Zeichen';
  }

  @override
  String get stringTransformerSwap => 'Eingabe/Ausgabe vertauschen';

  @override
  String get stringTransformerTypeCamel => 'camelCase';

  @override
  String get stringTransformerTypeSnake => 'snake_case';

  @override
  String get stringTransformerTypeKebab => 'kebab-case';

  @override
  String get stringTransformerTypePascal => 'PascalCase';

  @override
  String get stringTransformerTypeUrlSlug => 'URL-Slug';

  @override
  String get stringTransformerTypeBase64Encode => 'Base64 kodieren';

  @override
  String get stringTransformerTypeBase64Decode => 'Base64 dekodieren';

  @override
  String get stringTransformerTypeHexEncode => 'Hex kodieren';

  @override
  String get stringTransformerTypeHexDecode => 'Hex dekodieren';

  @override
  String get stringTransformerTypeAdUrlDecode => 'Werbe-URL dekodieren';

  @override
  String get stringTransformerPlaceholderInput =>
      'Text hier eingeben oder einfügen...';

  @override
  String get stringTransformerPlaceholderOutput =>
      'Das Ergebnis wird hier angezeigt...';

  @override
  String get stringTransformerCopied => 'In die Zwischenablage kopiert';

  @override
  String stringTransformerFailedToCopy(String error) {
    return 'Kopieren fehlgeschlagen: $error';
  }

  @override
  String stringTransformerInvalidInput(String message) {
    return 'Fehler: $message';
  }

  @override
  String get stringTransformerNoEmbeddedUrl =>
      'Keine eingebettete URL erkannt.';

  @override
  String get toolNameTreadmillControl => 'Laufband-Steuerung';

  @override
  String get toolDescTreadmillControl =>
      'Steuere dein Laufband und überwache deine Herzfrequenz über Bluetooth';

  @override
  String get speedLabel => 'Geschwindigkeit';

  @override
  String get inclineLabel => 'Steigung';

  @override
  String get hrLabel => 'Herzfrequenz';

  @override
  String get elapsedTime => 'Dauer';

  @override
  String get distance => 'Distanz';

  @override
  String get calories => 'Kalorien';

  @override
  String get steps => 'Schritte';

  @override
  String get historyTitle => 'Trainingsverlauf';

  @override
  String get workoutStart => 'Start';

  @override
  String get workoutPause => 'Pause';

  @override
  String get workoutResume => 'Fortsetzen';

  @override
  String get workoutStop => 'Stopp';

  @override
  String get importHistory => 'Workouts importieren';

  @override
  String get exportHistory => 'Workouts exportieren';

  @override
  String get treadmillHistorySync => 'Jetzt synchronisieren';

  @override
  String get treadmillHistorySyncDisabled =>
      'Synchronisierung ist nicht aktiviert. Aktiviere sie in den Einstellungen.';

  @override
  String treadmillHistorySyncSuccess(int pushed, int pulled) {
    return 'Synchronisiert: $pushed gesendet, $pulled empfangen';
  }

  @override
  String treadmillHistorySyncFailed(String error) {
    return 'Synchronisierung fehlgeschlagen: $error';
  }

  @override
  String get treadmillConnectDevices => 'Geräte verbinden';

  @override
  String get treadmillBadgeTreadmill => 'Laufband';

  @override
  String get treadmillStatusConnected => 'Verbunden';

  @override
  String get treadmillStatusConnecting => 'Verbindet…';

  @override
  String get treadmillStatusDisconnected => 'Getrennt';

  @override
  String get treadmillSessionRunningTitle => 'Training läuft noch';

  @override
  String get treadmillSessionRunningMessage =>
      'Wenn du diese Seite verlässt, wird im Hintergrund weiter aufgezeichnet - die Einheit wird automatisch gesichert und lässt sich auch nach einem Schließen der App wiederherstellen. Beende sie jetzt, um sie im Verlauf abzulegen.';

  @override
  String get treadmillKeepRecording => 'Verlassen, weiter aufzeichnen';

  @override
  String get treadmillStopAndSave => 'Beenden und speichern';

  @override
  String get treadmillRecoveredTitle => 'Unvollständiges Training gefunden';

  @override
  String treadmillRecoveredMessage(String duration, String distance) {
    return 'Ein Training über $duration mit $distance km wurde noch aufgezeichnet, als die App geschlossen wurde.';
  }

  @override
  String get treadmillRecoveredResume => 'Fortsetzen';

  @override
  String get treadmillRecoveredSave => 'Im Verlauf speichern';

  @override
  String get treadmillRecoveredDiscard => 'Verwerfen';

  @override
  String get treadmillRecoveredSaved => 'Training im Verlauf gespeichert';

  @override
  String get treadmillPublishNow => 'Jetzt senden';

  @override
  String get treadmillPublishNowSubtitle =>
      'Workouts gehen nach dem Ende, bei einer manuellen Synchronisierung und beim Öffnen des Gesundheits-Dashboards an Health Connect, höchstens alle fünf Minuten.';

  @override
  String treadmillPublishDone(int count) {
    return '$count Workout(s) an Health Connect gesendet';
  }

  @override
  String get treadmillPublishNothing => 'Health Connect ist bereits aktuell';

  @override
  String treadmillPublishFailed(int count) {
    return '$count Workout(s) konnten nicht an Health Connect gesendet werden';
  }

  @override
  String get treadmillPublishNoPermission =>
      'Health Connect hat keinen Schreibzugriff erteilt';

  @override
  String get treadmillPublishThrottled =>
      'Gerade erst gesendet — nichts Neues vorhanden';

  @override
  String get treadmillPublishDisabled =>
      'Das Senden an Health Connect ist ausgeschaltet';

  @override
  String get treadmillPublishUnsupported =>
      'Health Connect gibt es nur unter Android';

  @override
  String get treadmillRemoveFromHealthConnect =>
      'Workouts aus Health Connect entfernen';

  @override
  String get treadmillRemoveFromHealthConnectSubtitle =>
      'Löscht alles, was diese App dort geschrieben hat, und sendet es beim nächsten Lauf erneut.';

  @override
  String get treadmillRemoveFromHealthConnectConfirm =>
      'Alle Laufband-Einträge, die ToolLab in Health Connect geschrieben hat, werden gelöscht. Einträge anderer Apps bleiben unberührt. Ausnahme sind Distanz-Einträge: Health Connect bietet hier keine Möglichkeit, sie zu löschen, sie werden beim nächsten Senden überschrieben. Dein lokaler Verlauf bleibt erhalten und wird beim nächsten Lauf erneut gesendet.';

  @override
  String get treadmillRemoveFromHealthConnectAction => 'Löschen';

  @override
  String treadmillRemoveFromHealthConnectDone(int count) {
    return 'Entfernt — $count Workout(s) werden erneut gesendet';
  }

  @override
  String get treadmillRemoveFromHealthConnectFailed =>
      'Das Entfernen der Health-Connect-Daten ist fehlgeschlagen';

  @override
  String get treadmillHistoryDashboard => 'Dashboard';

  @override
  String get treadmillHistoryWorkouts => 'Workouts';

  @override
  String get treadmillHistoryEmpty => 'Noch keine Workouts gespeichert';

  @override
  String get treadmillHistoryOverview => 'Deine Laufgeschichte';

  @override
  String get treadmillHistoryOverviewSubtitle =>
      'Alle aufgezeichneten Workouts an einem Ort.';

  @override
  String get treadmillHistoryLastSevenDays => 'Letzte 7 Tage';

  @override
  String get treadmillHistoryDistanceLastSevenDays =>
      'Distanz in den letzten 7 Tagen';

  @override
  String get treadmillHistoryDistanceChartSubtitle =>
      'Tagesdistanz mit einem Sieben-Tage-Trend';

  @override
  String get treadmillHistoryTotalDistance => 'Gesamtdistanz';

  @override
  String get treadmillHistoryTotalDuration => 'Gesamtdauer';

  @override
  String get treadmillHistoryTotalCalories => 'Kalorien insgesamt';

  @override
  String get treadmillHistoryAverageSpeed => 'Durchschnittsgeschwindigkeit';

  @override
  String get treadmillHistoryWorkoutCount => 'Workouts insgesamt';

  @override
  String get treadmillHistoryScreenshot => 'Dashboard-Screenshot';

  @override
  String get treadmillHistorySaveScreenshot => 'Screenshot speichern';

  @override
  String get treadmillHistoryShareScreenshot => 'Screenshot teilen';

  @override
  String get treadmillHistoryScreenshotFailed =>
      'Dashboard-Screenshot konnte nicht erstellt werden';

  @override
  String get treadmillHistoryGenerateReport => 'PDF-Bericht erstellen';

  @override
  String get treadmillHistoryReportTitle => 'Laufband-Trainingsbericht';

  @override
  String get treadmillHistoryReportGenerated => 'Erstellt';

  @override
  String get treadmillHistoryReportDate => 'Datum';

  @override
  String get treadmillHistoryReportFailed =>
      'Trainingsbericht konnte nicht erstellt werden';

  @override
  String get treadmillHistoryTotalWorkouts => 'Workouts insgesamt';

  @override
  String get treadmillHistoryLongestDuration => 'Längste Dauer';

  @override
  String get treadmillHistoryMostCalories => 'Meiste Kalorien';

  @override
  String get treadmillHistoryMostSteps => 'Meiste Schritte';

  @override
  String get treadmillHistoryHeartRateLastSevenDays =>
      'Durchschnittliche Herzfrequenz der letzten 7 Tage';

  @override
  String get treadmillHistoryAllTime => 'Alle Zeiten';

  @override
  String get treadmillHistoryPersonalBests => 'Persönliche Bestleistungen';

  @override
  String get treadmillHistoryLongestRun => 'Längster Lauf';

  @override
  String get treadmillHistoryTopSpeed => 'Höchstgeschwindigkeit';

  @override
  String get treadmillHistoryAverage => 'Durchschnitt';

  @override
  String get treadmillHistoryAverageHr => 'Durchschn. HF';

  @override
  String get treadmillHistoryHeartRate => 'Herzfrequenz';

  @override
  String get treadmillHistoryHeartRateSubtitle =>
      'Trainingsintensität aller Zeiten mit einem Sieben-Tage-Trend darunter';

  @override
  String get treadmillHistoryRestingAverage => 'Workout-Durchschnitt';

  @override
  String get treadmillHistoryPeakHeartRate => 'Höchster Wert';

  @override
  String get treadmillHistoryImportNoNewWorkouts =>
      'Alle Workouts aus diesem Backup sind bereits gespeichert';

  @override
  String treadmillHistoryImportSuccess(int count) {
    return '$count Workouts erfolgreich importiert';
  }

  @override
  String get treadmillDetailsTitle => 'Trainingsdetails';

  @override
  String get treadmillScreenshotCopy => 'In Zwischenablage kopieren';

  @override
  String get treadmillScreenshotCopied =>
      'Screenshot wurde in die Zwischenablage kopiert';

  @override
  String get treadmillScreenshotCopyFailed =>
      'Screenshot konnte nicht in die Zwischenablage kopiert werden';

  @override
  String get treadmillDetailsScreenshot => 'Trainings-Screenshot';

  @override
  String get treadmillDetailsScreenshotFailed =>
      'Trainings-Screenshot konnte nicht erstellt werden';

  @override
  String get treadmillDetailsDuration => 'Dauer';

  @override
  String get treadmillDetailsPaceUnit => 'min/km';

  @override
  String get treadmillDetailsAvgSpeed => 'Ø Geschwindigkeit';

  @override
  String get treadmillDetailsMaxSpeed => 'Max. Geschwindigkeit';

  @override
  String get treadmillDetailsAvgHr => 'Ø Herzfrequenz';

  @override
  String get treadmillDetailsMaxHr => 'Max. Herzfrequenz';

  @override
  String get treadmillDetailsMinHr => 'Min. Herzfrequenz';

  @override
  String get treadmillDetailsCalories => 'Kalorien';

  @override
  String get treadmillDetailsSteps => 'Schritte';

  @override
  String get treadmillDetailsAvgIncline => 'Ø Steigung';

  @override
  String get treadmillDetailsMaxIncline => 'Max. Steigung';

  @override
  String get treadmillDetailsSpeed => 'Geschwindigkeit';

  @override
  String get treadmillDetailsChart => 'Geschwindigkeit & Herzfrequenz';

  @override
  String get treadmillDetailsIncline => 'Steigung';

  @override
  String get treadmillDetailsZones => 'Herzfrequenzzonen';

  @override
  String get treadmillDetailsZone1 => 'Erholung';

  @override
  String get treadmillDetailsZone2 => 'Leicht';

  @override
  String get treadmillDetailsZone3 => 'Aerob';

  @override
  String get treadmillDetailsZone4 => 'Schwelle';

  @override
  String get treadmillDetailsZone5 => 'Maximum';

  @override
  String get treadmillDetailsSplits => 'Kilometer-Splits';

  @override
  String get treadmillDetailsSplitKm => 'km';

  @override
  String get treadmillDetailsSplitTime => 'Zeit';

  @override
  String get treadmillDetailsSplitPace => 'Pace';

  @override
  String get treadmillDetailsSplitHr => 'HF';

  @override
  String get treadmillDetailsNoSamples =>
      'Für dieses Training wurden keine Detaildaten aufgezeichnet';

  @override
  String get toolNameAudioLab => 'Audio Lab';

  @override
  String get toolDescAudioLab =>
      'Audio-Signale lokalisieren, maskieren, analysieren und generieren';

  @override
  String get sfTitleFinder => 'Finder';

  @override
  String get sfTitleCounter => 'Gegen';

  @override
  String get sfTitleGenerator => 'Generator';

  @override
  String get sfModeTracker => 'Orten';

  @override
  String get sfModeCounter => 'Gegenschall';

  @override
  String get sfModeGenerator => 'Generator';

  @override
  String get sfStop => 'Stopp';

  @override
  String get sfPlayTone => 'Ton abspielen';

  @override
  String get sfPlayCounter => 'Gegenton abspielen';

  @override
  String get sfMicDeniedTitle => 'Mikrofonberechtigung nötig';

  @override
  String get sfMicDeniedBody =>
      'Erlaube den Mikrofonzugriff, um Raumgeräusche zu orten und zu analysieren.';

  @override
  String get sfMicUnavailableTitle => 'Mikrofonaufnahme nicht verfügbar';

  @override
  String get sfMicUnavailableBody =>
      'Live-Mikrofonanalyse wird auf dieser Plattform nicht unterstützt. Der Frequenzgenerator funktioniert weiterhin.';

  @override
  String get sfGrantPermission => 'Zugriff erlauben';

  @override
  String get sfOpenGenerator => 'Generator öffnen';

  @override
  String get sfTrackerTitle => 'Quelle orten';

  @override
  String get sfLevel => 'Pegel';

  @override
  String get sfDominant => 'Dominant';

  @override
  String get sfPeakHold => 'Spitze';

  @override
  String get sfGuidanceHotter => 'Wärmer – näher an der Quelle';

  @override
  String get sfGuidanceColder => 'Kälter – du entfernst dich';

  @override
  String get sfGuidanceSteady => 'Konstant – bewege dich für neue Werte';

  @override
  String get sfGuidanceSilent => 'Zu leise – kein klares Geräusch erkannt';

  @override
  String get sfSetReference => 'Punkt merken';

  @override
  String get sfClearReference => 'Löschen';

  @override
  String get sfResetPeak => 'Spitze zurücksetzen';

  @override
  String get sfVsReference => 'ggü. Merkpunkt';

  @override
  String get sfSpectrum => 'Spektrum';

  @override
  String get sfCounterTitle => 'Gegen-/Maskierton';

  @override
  String get sfCounterDisclaimer =>
      'Ein Handylautsprecher kann Raumlärm nicht wirklich auslöschen. Dies spielt einen passenden Ton (optional phaseninvertiert) plus optionales Maskierrauschen, um das Geräusch weniger auffällig zu machen.';

  @override
  String get sfDetected => 'Erkannt';

  @override
  String get sfUseDetected => 'Übernehmen';

  @override
  String get sfCounterMicOff =>
      'Mikrofonanalyse ist aus – stelle die Zielfrequenz unten manuell ein.';

  @override
  String get sfTargetFrequency => 'Zielfrequenz';

  @override
  String get sfWaveform => 'Wellenform';

  @override
  String get sfPhase => 'Phase';

  @override
  String get sfInvertPhase => 'Phase invertieren (180°)';

  @override
  String get sfMaskNoise => 'Maskierrauschen';

  @override
  String get sfVolume => 'Lautstärke';

  @override
  String get sfGeneratorTitle => 'Frequenzgenerator';

  @override
  String get sfGeneratorHint =>
      'Wähle Frequenz und Wellenform, um einen reinen Testton zu erzeugen.';

  @override
  String get sfTitleDoppler => 'Doppler';

  @override
  String get sfModeDoppler => 'Doppler-Analyse';

  @override
  String get sfDopplerTitle => 'Doppler-Effekt-Analyse';

  @override
  String get sfDopplerExplanation =>
      'Nimm ein vorbeifahrendes Geräusch (wie eine Autohupe oder Sirene) auf, um Geschwindigkeit, Frequenz und Abstand zu schätzen, oder lade einen zuvor gespeicherten WAV-Audioclip.';

  @override
  String get sfDopplerLoadClip => 'WAV-Clip laden';

  @override
  String get sfDopplerVelocity => 'Geschwindigkeit';

  @override
  String get sfDopplerDistance => 'Kürzester Abstand';

  @override
  String get sfDopplerSourceFreq => 'Quellfrequenz';

  @override
  String get sfDopplerInflection => 'Wendepunkt (Zeit)';

  @override
  String get sfDopplerTemp => 'Lufttemperatur';

  @override
  String get sfDopplerSpeedOfSound => 'Schallgeschwindigkeit';

  @override
  String get sfDopplerParameters => 'Modell-Parameter';

  @override
  String get sfDopplerStatusNoData =>
      'Noch kein Audioclip aufgenommen. Starte die Aufnahme oben oder lade eine Demo.';

  @override
  String get sfDopplerStatusAnalyzing => 'Analysiere Audioclip...';

  @override
  String get sfDopplerStatusSuccess =>
      'Analyse abgeschlossen. Passe die Schieberegler an, um das theoretische Modell (durchgezogene Linie) mit den gemessenen Frequenzen (lila Punkte) in Deckung zu bringen.';

  @override
  String get sfDopplerGraphTitle => 'Frequenz über Zeit';

  @override
  String get sfDopplerInfoTitle => 'Doppler-Grafik verstehen';

  @override
  String get sfDopplerInfoContent =>
      '• X-Achse (Horizontal): Zeit in Sekunden.\n• Y-Achse (Vertikal): Frequenz in Hertz (Hz).\n• Punkte: Erkannte Spitzenfrequenzen der Aufnahme.\n• Linie: Theoretische Kurve des Doppler-Modells.\n• Vertikale Linie (t₀): Zeitpunkt des geringsten Abstands.\n\nZiel: Passe die Parameter so an, dass die Linie mit den Punkten übereinstimmt.';

  @override
  String get sfWaveSine => 'Sinus';

  @override
  String get sfWaveSquare => 'Rechteck';

  @override
  String get sfWaveTriangle => 'Dreieck';

  @override
  String get sfWaveSawtooth => 'Sägezahn';

  @override
  String get sfToneNotificationTitle => 'Ton aktiv';

  @override
  String get sfToneNotificationText => 'ToolLab erzeugt einen Ton';

  @override
  String get sfMicDefault => 'Standardmikrofon';

  @override
  String get sfRefreshMics => 'Mikrofone neu suchen';

  @override
  String get sfMicGain => 'Mikrofonverstärkung';

  @override
  String get sfInputSettings => 'Eingangseinstellungen';

  @override
  String get sfSaveClipButton => 'Clip speichern';

  @override
  String get sfSpectrumSettings => 'Spektrum-Einstellungen';

  @override
  String get sfRecordClip => 'Clip aufnehmen';

  @override
  String get sfStopAndSave => 'Stopp & speichern';

  @override
  String get sfClipSavedAndroid => 'Audioclip in Downloads gespeichert';

  @override
  String sfClipSaved(String path) {
    return 'Clip gespeichert unter $path';
  }

  @override
  String get sfClipSaveError => 'Audioclip konnte nicht gespeichert werden';

  @override
  String get sfEnlargeSpectrum => 'Spektrum vergrößern';

  @override
  String get sfMaxHold => 'Maximum halten';

  @override
  String get sfResetZoom => 'Zoom zurücksetzen';

  @override
  String get sfRange => 'Bereich';

  @override
  String get sfScreenshot => 'Screenshot';

  @override
  String get sfCopyImage => 'In Zwischenablage kopieren';

  @override
  String get sfSaveImage => 'Bild speichern';

  @override
  String get sfImageCopied => 'Spektrum in die Zwischenablage kopiert';

  @override
  String get sfImageCopyFailed => 'Spektrumbild konnte nicht kopiert werden';

  @override
  String get sfSpectrogram => 'Spektrogramm';

  @override
  String get sfStopRecording => 'Aufnahme stoppen';

  @override
  String get sfRecordingLabel => 'REC';

  @override
  String get sfSavingClip => 'Clip wird gespeichert…';

  @override
  String get sfResFast => 'Schnell';

  @override
  String get sfResBalanced => 'Ausgewogen';

  @override
  String get sfResFine => 'Fein';

  @override
  String sfBinWidth(String hz) {
    return '≈ $hz Hz pro Bin';
  }

  @override
  String get sfTitleMorse => 'Morsecode';

  @override
  String get sfMorseGenTab => 'Senden';

  @override
  String get sfMorseAnalTab => 'Empfangen';

  @override
  String get sfMorseWpm => 'Geschwindigkeit';

  @override
  String get sfMorsePlayMode => 'Signalmodus';

  @override
  String get sfMorsePlayBoth => 'Ton & Licht';

  @override
  String get sfMorsePlaySound => 'Nur Ton';

  @override
  String get sfMorsePlayFlash => 'Nur Licht';

  @override
  String get sfMorsePlaceholder => 'Nachricht zum Codieren...';

  @override
  String get sfMorseDecodedOutput => 'Decodierter Text';

  @override
  String get sfMorseLiveListening => 'Empfange...';

  @override
  String get sfMorseExportSuccess => 'Morse-Audio erfolgreich exportiert';

  @override
  String get toolNameCompass => 'Kompass';

  @override
  String get toolDescCompass =>
      'Kompensierter Richtungskompass mit Magnetfeld-Status';

  @override
  String get compassHeading => 'Kurs';

  @override
  String get compassMagneticField => 'Magnetfeld';

  @override
  String get compassInterferenceNormal => 'Normal';

  @override
  String get compassInterferenceWarning => 'Störung Erkannt';

  @override
  String get compassCalibrateTip =>
      'Von Metall oder Magneten fernhalten, wenn der Kurs ungenau erscheint.';

  @override
  String get compassInfoTooltip => 'Bedienung';

  @override
  String get compassInfoTitle => 'Kompass verwenden';

  @override
  String get compassInfoIntro =>
      'Der Kompass zeigt deinen Kurs — die Richtung, in die die Oberkante des Geräts zeigt — anhand von Magnetometer und Beschleunigungssensor.';

  @override
  String get compassStepLevelTitle => '1. Gerät flach halten';

  @override
  String get compassStepLevelBody =>
      'Halte den Bildschirm nach oben und ungefähr waagerecht zum Boden. Die Wasserwaage wird grün, sobald du flach genug für eine genaue Anzeige hältst. Geneigt oder aufrecht gehalten ist die Anzeige unzuverlässig.';

  @override
  String get compassStepCalibrateTitle => '2. Mit einer Acht kalibrieren';

  @override
  String get compassStepCalibrateBody =>
      'Wenn der Kurs driftet, springt oder sich nie einpendelt, bewege das Gerät langsam mehrmals in einer liegenden Acht. Das kalibriert das Magnetometer neu — die häufigste Ursache für einen zappelnden Kompass.';

  @override
  String get compassStepMetalTitle => '3. Abstand zu Metall halten';

  @override
  String get compassStepMetalBody =>
      'Magnete, Lautsprecher, Laptops, Handyhüllen, Autos und Stahlmöbel verzerren das Magnetfeld. Das Magnetfeld-Panel warnt dich bei erkannten Störungen.';

  @override
  String get compassStepReadTitle => '4. Kurs ablesen';

  @override
  String get compassStepReadBody =>
      'Die rote Nadel zeigt immer nach oben; die Skala dreht sich, sodass N zum magnetischen Norden zeigt. Die große Zahl und die Buchstaben (z. B. 214° SW) sind dein aktueller Kurs.';

  @override
  String get compassSimNote =>
      'Auf Geräten ohne Magnetsensor läuft der Kompass in der Simulation — wische waagerecht über die Skala, um sie zu drehen.';

  @override
  String get compassLevelGood => 'Waagerecht';

  @override
  String get compassLevelHoldFlat => 'Flach halten';

  @override
  String compassTiltLabel(String deg) {
    return 'Neigung $deg°';
  }

  @override
  String get compassHoldFlatHint =>
      'Halte das Gerät flach und waagerecht für einen genauen Kurs.';

  @override
  String get compassCalibrateHint =>
      'Kurs instabil? Bewege das Gerät in einer Acht zum Neukalibrieren.';

  @override
  String get toolNameFileManager => 'Dateimanager';

  @override
  String get toolDescFileManager =>
      'Lokale Dateien sowie FTP- und SMB-Netzwerkfreigaben durchsuchen';

  @override
  String get fileManagerAppFiles => 'Home';

  @override
  String get fileManagerConnections => 'Verbindungen';

  @override
  String get fileManagerAddConnection => 'Verbindung hinzufügen';

  @override
  String get fileManagerRefresh => 'Aktualisieren';

  @override
  String get fileManagerNewFolder => 'Neuer Ordner';

  @override
  String get fileManagerFavorite => 'Ordner favorisieren';

  @override
  String get fileManagerEmptyFolder => 'Dieser Ordner ist leer';

  @override
  String get fileManagerBrokenLink =>
      'Ungültige Verknüpfung - das Ziel existiert nicht mehr';

  @override
  String get fileManagerFtp => 'FTP';

  @override
  String get fileManagerSmb => 'SMB';

  @override
  String get fileManagerConnectionName => 'Verbindungsname';

  @override
  String get fileManagerHost => 'Host';

  @override
  String get fileManagerPort => 'Port';

  @override
  String get fileManagerShare => 'Freigabe';

  @override
  String get fileManagerUsername => 'Benutzername';

  @override
  String get fileManagerPassword => 'Passwort';

  @override
  String get fileManagerInitialPath => 'Startpfad';

  @override
  String get fileManagerAllFilesAccess => 'Zugriff auf alle Dateien erlauben';

  @override
  String get fileManagerCut => 'Ausschneiden';

  @override
  String get fileManagerPaste => 'Einfügen';

  @override
  String get fileManagerDiscoverShares => 'Freigaben suchen';

  @override
  String get fileManagerDeleteTitle => 'Ausgewählte Dateien löschen?';

  @override
  String fileManagerDeleteMessage(int count) {
    return '$count ausgewählte Elemente und alle Inhalte ausgewählter Ordner löschen? Dies kann nicht rückgängig gemacht werden.';
  }

  @override
  String fileManagerSelected(int count) {
    return '$count ausgewählt';
  }

  @override
  String get fileManagerSelect => 'Dateien auswählen';

  @override
  String get fileManagerSelectAll => 'Alle auswählen';

  @override
  String get fileManagerCopying => 'Dateien werden kopiert';

  @override
  String get fileManagerMoving => 'Dateien werden verschoben';

  @override
  String get fileManagerDeleting => 'Dateien werden gelöscht';

  @override
  String fileManagerOperationProgress(int completed, int total) {
    return '$completed von $total Dateien verarbeitet';
  }

  @override
  String get fileManagerOperationBackground =>
      'Wird fortgesetzt, wenn ToolLab im Hintergrund ist';

  @override
  String fileManagerMoveBuffer(int count) {
    return '$count Element(e) zum Verschieben bereit';
  }

  @override
  String fileManagerCopyBuffer(int count) {
    return '$count Element(e) zum Kopieren bereit';
  }

  @override
  String get fileManagerDropActionTitle => 'Abgelegte Dateien hinzufuegen';

  @override
  String get fileManagerDropActionMessage =>
      'Waehle, ob die abgelegten Dateien kopiert oder verschoben werden sollen.';

  @override
  String get fileManagerMove => 'Verschieben';

  @override
  String get fileManagerSettings => 'Dateimanager-Einstellungen';

  @override
  String get fileManagerSortBy => 'Dateien sortieren nach';

  @override
  String get fileManagerSortName => 'Name';

  @override
  String get fileManagerSortDate => 'Änderungsdatum';

  @override
  String get fileManagerSortSize => 'Größe';

  @override
  String get fileManagerSortAscending => 'Aufsteigende Reihenfolge';

  @override
  String get fileManagerRemoveConnectionTitle => 'Verbindung entfernen?';

  @override
  String fileManagerRemoveConnectionMessage(String name) {
    return 'Gespeicherte Verbindung \"$name\" und das gespeicherte Passwort entfernen?';
  }

  @override
  String get fileManagerClearClipboard => 'Zwischenablage leeren';

  @override
  String get fileManagerOpenChooser => 'Jedes Mal fragen';

  @override
  String get fileManagerOpenImages => 'Bilder öffnen mit';

  @override
  String get fileManagerOpenPdf => 'PDFs öffnen mit';

  @override
  String get fileManagerOpenAudio => 'Audio öffnen mit';

  @override
  String get fileManagerOpenVideo => 'Video öffnen mit';

  @override
  String get fileManagerOpenInternalPlayer => 'Interner Player';

  @override
  String get fileManagerOpenMarkdown => 'Markdown öffnen mit';

  @override
  String get fileManagerOpenText => 'Textdateien öffnen mit';

  @override
  String get fileManagerOpenSqlite => 'SQLite-Datenbanken öffnen mit';

  @override
  String get fileManagerOpenWithSystem => 'Mit Systemstandard öffnen';

  @override
  String get fileManagerDownloads => 'Downloads';

  @override
  String get fileManagerGrantFileAccess => 'Zugriff auf Gerätedateien erlauben';

  @override
  String get fileManagerDetails => 'Details';

  @override
  String get fileManagerDetailSize => 'Größe';

  @override
  String get fileManagerDetailModified => 'Geändert';

  @override
  String get fileManagerDetailType => 'Dateityp';

  @override
  String get fileManagerDetailPath => 'Pfad';

  @override
  String get fileManagerFolder => 'Ordner';

  @override
  String get fileManagerStartupFolder => 'Startordner';

  @override
  String get fileManagerCurrentFolder => 'Aktueller Ordner';

  @override
  String get fileManagerSorting => 'Sortierung';

  @override
  String get fileManagerOpenWith => 'Öffnen mit';

  @override
  String get fileManagerFoldersFirst => 'Ordner vor Dateien';

  @override
  String get fileManagerFileExistsTitle => 'Datei existiert bereits';

  @override
  String fileManagerFileExistsMessage(String names) {
    return '$names existiert bereits in diesem Ordner.';
  }

  @override
  String get fileManagerKeepBoth => 'Beide behalten';

  @override
  String get fileManagerOverwrite => 'Überschreiben';

  @override
  String get fileManagerRecentLocations => 'Zuletzt';

  @override
  String get fileManagerCategories => 'Kategorien';

  @override
  String get fileManagerCategoryImages => 'Bilder';

  @override
  String get fileManagerCategoryApps => 'Apps';

  @override
  String get fileManagerCategorySystem => 'Systemdateien';

  @override
  String get fileManagerNoImages => 'Keine Bilder gefunden';

  @override
  String get fileManagerNoApps => 'Keine Apps gefunden';

  @override
  String get fileManagerNoSystemPaths => 'Keine Systemordner verfügbar';

  @override
  String fileManagerAppCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Apps',
      one: '1 App',
    );
    return '$_temp0';
  }

  @override
  String fileManagerStorageUsed(String used, String total) {
    return '$used von $total belegt';
  }

  @override
  String fileManagerStorageFree(String free) {
    return '$free frei';
  }

  @override
  String get fileManagerOpenAppInfo => 'App-Info';

  @override
  String get fileManagerFolderItems => 'Elemente';

  @override
  String fileManagerFolderFileCount(int count) {
    return '$count Dateien';
  }

  @override
  String fileManagerFolderItemCount(int count) {
    return '$count Elemente';
  }

  @override
  String get fileManagerInstallApk => 'APK installieren';

  @override
  String get fileManagerStorage => 'Speicher';

  @override
  String get fileManagerCompressZip => 'Als ZIP komprimieren';

  @override
  String get fileManagerCompressing => 'ZIP-Archiv wird erstellt';

  @override
  String get fileManagerExtract => 'Entpacken';

  @override
  String get fileManagerExtracting => 'Archiv wird entpackt';

  @override
  String get fileManagerArchiveConflictTitle =>
      'Archivdateien existieren bereits';

  @override
  String fileManagerArchiveConflictMessage(int count) {
    return '$count entpackte Dateien existieren bereits.';
  }

  @override
  String fileManagerItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge',
      one: '1 Eintrag',
    );
    return '$_temp0';
  }

  @override
  String get fileManagerCollapseGroup => 'Ordner einklappen';

  @override
  String get fileManagerExpandGroup => 'Ordner ausklappen';

  @override
  String get fileManagerOpenFolder => 'Ordner im Explorer öffnen';

  @override
  String fileManagerMoreEntries(int count) {
    return 'und $count weitere';
  }

  @override
  String get fileManagerSkip => 'Überspringen';

  @override
  String get fileManagerApplyToAll => 'Auf alle Konflikte anwenden';

  @override
  String get fileManagerDocuments => 'Dokumente';

  @override
  String get toolNameHealthDashboard => 'Gesundheits-Dashboard';

  @override
  String get toolDescHealthDashboard =>
      'Gesundheitsdaten und Workouts zusammenführen';

  @override
  String get healthDashboardRefresh =>
      'Gesundheitsdaten und Backend abgleichen';

  @override
  String get healthDashboardHeadline => 'Deine Gesundheit im Blick';

  @override
  String get healthDashboardSubtitle =>
      'Eine private Ansicht für Aktivität und Erholung.';

  @override
  String get healthDashboardDistance => 'Distanz';

  @override
  String get healthDashboardDistanceAllTime => 'Distanz · Gesamt';

  @override
  String get healthDashboardCaloriesAllTime => 'Kalorien · Gesamt';

  @override
  String get healthDashboardActiveTimeAllTime => 'Aktive Zeit · Gesamt';

  @override
  String get healthDashboardStepsAllTime => 'Schritte · Gesamt';

  @override
  String get healthDashboardWorkoutsAllTime => 'Workouts · Gesamt';

  @override
  String get healthDashboardDistanceLastSevenDays => 'Distanz · letzte 7 Tage';

  @override
  String get healthDashboardCaloriesLastSevenDays => 'Kalorien · letzte 7 Tage';

  @override
  String get healthDashboardActiveTimeLastSevenDays =>
      'Aktive Zeit · letzte 7 Tage';

  @override
  String get healthDashboardStepsLastSevenDays => 'Schritte · letzte 7 Tage';

  @override
  String get healthDashboardLatestRestingHeartRate => 'Letzter Ruhepuls';

  @override
  String get healthDashboardLatestHeartRate => 'Letzter Puls';

  @override
  String get healthDashboardCalories => 'Kalorien';

  @override
  String get healthDashboardCaloriesIntakeAllTime =>
      'Kalorienaufnahme · Gesamt';

  @override
  String get healthDashboardCaloriesIntakeLastSevenDays =>
      'Kalorienaufnahme · letzte 7 Tage';

  @override
  String get healthDashboardCaloriesIntakeToday => 'Kalorienaufnahme · heute';

  @override
  String get healthDashboardCaloriesToday => 'Kalorien · heute';

  @override
  String get healthDashboardNutrition => 'Ernährung';

  @override
  String get healthDashboardMeal => 'Mahlzeit';

  @override
  String healthDashboardMealsOnDay(String date) {
    return 'Mahlzeiten am $date';
  }

  @override
  String get healthDashboardNoMeals => 'Keine Mahlzeiten erfasst.';

  @override
  String get healthDashboardMealTimeline => 'Mahlzeitenverlauf';

  @override
  String get healthDashboardProtein => 'Protein';

  @override
  String get healthDashboardCarbohydrates => 'Kohlenhydrate';

  @override
  String get healthDashboardFat => 'Fett';

  @override
  String get healthDashboardActiveTime => 'Aktive Zeit';

  @override
  String get healthDashboardWorkouts => 'Workouts';

  @override
  String get healthDashboardStepsToday => 'Schritte heute';

  @override
  String get healthDashboardWeight => 'Letztes Gewicht';

  @override
  String get healthDashboardRestingHeartRate => 'Ruhepuls';

  @override
  String get healthDashboardLastSleep => 'Letzter Schlaf';

  @override
  String get healthDashboardWorkoutTrend => 'Distanz · letzte 7 Tage';

  @override
  String get healthDashboardHeartRateTrend =>
      'Durchschnittlicher Puls · letzte 7 Tage';

  @override
  String get healthDashboardRecentActivity => 'Letzte Aktivitäten';

  @override
  String get healthDashboardNoData =>
      'Noch keine Gesundheitsdaten. Synchronisiere ein Laufband-Workout oder verbinde Health Connect auf Android.';

  @override
  String get healthDashboardTreadmillRun => 'Laufbandlauf';

  @override
  String get healthDashboardConnectHealthConnect =>
      'Health Connect verbinden und importieren';

  @override
  String get healthDashboardImportHealthConnect =>
      'Health Connect jetzt importieren';

  @override
  String get healthDashboardManageHealthConnect => 'Health Connect verwalten';

  @override
  String get healthDashboardManageHealthConnectSubtitle =>
      'Android-Berechtigungen oder Health-Connect-Systemeinstellungen öffnen.';

  @override
  String get healthDashboardHealthConnectImported =>
      'Health-Connect-Daten importiert';

  @override
  String get healthDashboardHealthConnectRepaired =>
      'Health-Connect-Zwischenspeicher repariert';

  @override
  String get healthDashboardSyncInProgress => 'Synchronisierung läuft bereits';

  @override
  String get healthDashboardSyncInProgressBody =>
      'Ein Health-Connect-Import oder eine Cloud-Synchronisierung läuft noch. Warte bis sie abgeschlossen ist, bevor du eine neue startest.';

  @override
  String get healthDashboardSyncNoChanges =>
      'Keine Gesundheitsdatenänderungen zum Synchronisieren';

  @override
  String get healthDashboardRepairHealthConnect =>
      'Health-Connect-Import neu starten';

  @override
  String get healthDashboardRepairHealthConnectSubtitle =>
      'Lokal importierte Health-Connect-Daten löschen und Historie erneut importieren.';

  @override
  String get healthDashboardResetHealthConnectDescription =>
      'Dies entfernt alle lokal importierten Health-Connect-Cache- und kanonischen Daten auf diesem Gerät. Health Connect und Cloud-Daten bleiben unverändert. Der nächste Import beginnt von vorn und kann lange dauern. Normale Importe werden ab der letzten erfolgreichen Synchronisierung fortgesetzt.';

  @override
  String get healthDashboardStartOver => 'Neu starten';

  @override
  String get healthDashboardConnectHealthConnectSubtitle =>
      'Fordert Zugriff an und importiert alle verfügbaren historischen Daten aus Health Connect.';

  @override
  String get healthDashboardHealthConnectAnalysis =>
      'Health-Connect-Analyse exportieren';

  @override
  String get healthDashboardHealthConnectAnalysisSubtitle =>
      'Liest jeden unterstützten Typ und speichert Rohdaten, Metadaten, Sessions, Routen und Fehler je Typ in einer separaten SQLite-Datenbank.';

  @override
  String get healthDashboardHealthConnectAnalysisFailed =>
      'Health-Connect-Analyseexport fehlgeschlagen';

  @override
  String get healthDashboardHealthConnectDiscovery =>
      'Health-Connect-Erkundung exportieren';

  @override
  String get healthDashboardHealthConnectDiscoverySubtitle =>
      'Untersucht schnell jeden unterstützten Typ mit einer Beispielseite. Es wird kein vollständiger Verlauf exportiert.';

  @override
  String get healthDashboardHealthConnectDiscoveryFailed =>
      'Health-Connect-Erkundungsexport fehlgeschlagen';

  @override
  String get healthDashboardHealthConnectComparison =>
      'Quellenvergleich exportieren';

  @override
  String get healthDashboardHealthConnectComparisonSubtitle =>
      'Exportiert 90 Tage kompakte Zepp-, Google-Fit- und Renpho-Werte. Rohdaten, Routen und andere Quellen werden ausgeschlossen.';

  @override
  String get healthDashboardHealthConnectComparisonDone =>
      'Quellenvergleich in Downloads gespeichert';

  @override
  String get healthDashboardHealthConnectComparisonFailed =>
      'Quellenvergleichsexport fehlgeschlagen';

  @override
  String get healthDashboardHealthConnectComparisonProgressTitle =>
      'Quellenvergleich wird exportiert';

  @override
  String get healthDashboardHealthConnectComparisonProgressStatus =>
      'Quellenvergleich wird vorbereitet...';

  @override
  String healthDashboardHealthConnectComparisonProgressCount(int count) {
    return '$count Health-Connect-Datensätze verarbeitet';
  }

  @override
  String get healthDashboardHealthConnectComparisonProgressHint =>
      'Der Export läuft mit einer Benachrichtigung im Hintergrund weiter. Du kannst wechseln oder den Bildschirm ausschalten.';

  @override
  String get healthDashboardAutoHealthConnectSync =>
      'Health Connect beim Öffnen synchronisieren';

  @override
  String get healthDashboardAutoHealthConnectSyncSubtitle =>
      'Health-Connect-Daten bei jedem Öffnen des Dashboards importieren.';

  @override
  String get healthDashboardSettings =>
      'Einstellungen für Gesundheits-Dashboard';

  @override
  String get healthDashboardDataToShow => 'Anzuzeigende Daten';

  @override
  String get healthDashboardSectionAccess => 'Zugriff';

  @override
  String get healthDashboardSectionSelect => 'Was gesammelt wird';

  @override
  String get healthDashboardSectionSelectHint =>
      'Es wird nichts geladen, was hier nicht aktiviert ist.';

  @override
  String get healthDashboardSectionCollect => 'Sammeln';

  @override
  String get healthDashboardSectionCollectHint =>
      'Füllt den neuen Datenspeicher. Wird im Dashboard noch nicht angezeigt.';

  @override
  String get healthDashboardSectionCurrent => 'Dashboard-Daten';

  @override
  String get healthDashboardSectionCurrentHint =>
      'Der ältere Import, der das aktuell sichtbare Dashboard füllt.';

  @override
  String get healthDashboardDataTypes => 'Datentypen';

  @override
  String get healthDashboardDataTypesSubtitle =>
      'Auswählen, was aus Health Connect geladen wird';

  @override
  String get healthDashboardDataSources => 'Quellen';

  @override
  String get healthDashboardDataSourcesSubtitle =>
      'Auswählen, aus welcher App jeder Typ geladen wird';

  @override
  String get healthDashboardScanSources => 'Verfügbare Daten suchen';

  @override
  String get healthDashboardScanSourcesSubtitle =>
      'Findet, welche Typen Daten haben und welche Apps sie geschrieben haben';

  @override
  String get healthDashboardImportSelected => 'Ausgewählte Daten importieren';

  @override
  String get healthDashboardImportSelectedSubtitle =>
      'Vollständige Historie für jeden aktivierten Typ';

  @override
  String get healthDashboardImportRestart => 'Neu importieren';

  @override
  String get healthDashboardImportRestartSubtitle =>
      'Löscht gespeicherte Daten und liest die gesamte Historie erneut';

  @override
  String get healthDashboardSyncChanges => 'Änderungen jetzt abgleichen';

  @override
  String get healthDashboardSyncChangesSubtitle =>
      'Lädt nur, was sich seit dem letzten Abgleich geändert hat';

  @override
  String get healthDashboardNoTypesFound =>
      'Noch nichts gesucht. Starte eine Suche, um zu sehen, was verfügbar ist.';

  @override
  String get healthDashboardNoSourcesFound =>
      'Noch keine Apps für diesen Typ gefunden.';

  @override
  String healthDashboardTypeRecordCount(int count) {
    return '$count importiert';
  }

  @override
  String get healthDashboardDataSourcesHint =>
      'Apps, aus denen dieser Datentyp gelesen wird. Eine abzuschalten behält die bisherigen Daten - sie wird nur nicht mehr gelesen und zählt nicht mehr in Summen.';

  @override
  String get healthDashboardApps => 'Apps';

  @override
  String get healthDashboardAppsSubtitle =>
      'Schreibende Apps ein- oder ausschalten und Vorrang festlegen';

  @override
  String get healthDashboardNoAppsFound =>
      'Noch keine schreibenden Apps bekannt. Zuerst nach Quellen suchen.';

  @override
  String get healthDashboardAppPriority => 'Rangfolge';

  @override
  String get healthDashboardAppPriorityHint =>
      'Die oberste App mit Daten für einen Tag liefert die Tageswerte. Apps darunter bleiben Reserve für Tage, die sie nicht abgedeckt hat.';

  @override
  String healthDashboardAppRowCount(int count) {
    return '$count Zeilen gespeichert';
  }

  @override
  String healthDashboardAppTypeCount(int count) {
    return '$count Datentypen';
  }

  @override
  String get healthDashboardAppMoveUp => 'Höherer Vorrang';

  @override
  String get healthDashboardAppMoveDown => 'Niedrigerer Vorrang';

  @override
  String get healthDashboardAppDeleteData => 'Gespeicherte Daten löschen';

  @override
  String get healthDashboardAppDeleteDataConfirm =>
      'Alle Zeilen dieser App löschen und die Datenbank verkleinern. Die App stattdessen auszuschalten behält die Daten und ist jederzeit umkehrbar.';

  @override
  String get healthDashboardAppDeleteHere =>
      'Speicher auf diesem Gerät freigeben';

  @override
  String get healthDashboardAppDeleteHereHint =>
      'Löscht die Zeilen nur hier. Andere Geräte behalten ihre Kopie, und dieses Gerät holt sie beim nächsten Abgleich zurück, solange die App nicht ausgeschaltet ist.';

  @override
  String get healthDashboardAppDeleteEverywhere =>
      'Von allen Geräten entfernen';

  @override
  String get healthDashboardAppDeleteEverywhereHint =>
      'Erklärt die Daten für falsch und löscht auch die Kopie auf dem Server, sodass alle Geräte sie verwerfen. Nicht umkehrbar.';

  @override
  String get healthDashboardAutoSync => 'Änderungen beim Öffnen abgleichen';

  @override
  String get healthDashboardAutoSyncSubtitle =>
      'Bei jedem Öffnen holen, was Health Connect als geändert meldet. Aus bedeutet: Daten kommen nur beim manuellen Import.';

  @override
  String get healthDashboardImportConfirmTitle =>
      'Gesamte Historie importieren?';

  @override
  String healthDashboardImportConfirmBody(int count) {
    return '$count Datentypen sind ausgewählt. Deren vollständige Historie zu lesen kann bei großem Bestand Stunden dauern. Der Import läuft im Hintergrund weiter und kann abgebrochen werden.';
  }

  @override
  String get healthDashboardImportConfirmNoTypes =>
      'Es ist kein Datentyp ausgewählt, ein Import würde also nichts speichern. Zuerst nach Quellen suchen und dann auswählen, was gesammelt wird.';

  @override
  String get healthDashboardScanFirstHint =>
      'Es wurde noch nichts gefunden. Health Connect durchsuchen, um zu sehen, welche Datentypen Daten enthalten und welche Apps sie geschrieben haben.';

  @override
  String healthDashboardSourceRecordCount(int count) {
    return '$count gesehen';
  }

  @override
  String healthDashboardStoreSummary(int points, int sessions) {
    return '$points Messwerte, $sessions Sitzungen';
  }

  @override
  String get healthDashboardStoreEmptyHint =>
      'Noch nichts gespeichert. Erst suchen, dann importieren.';

  @override
  String healthDashboardStoreRollupRows(int rows) {
    return '$rows Tageszusammenfassungen';
  }

  @override
  String get healthDashboardBaselineEstablished =>
      'Änderungsverfolgung gestartet. Starte einen Import für die Historie.';

  @override
  String healthDashboardSyncChangesResult(int updated, int removed) {
    return '$updated aktualisiert, $removed entfernt';
  }

  @override
  String get healthDashboardFullImportNeeded =>
      'Änderungsverfolgung abgelaufen, Wiederherstellung fehlgeschlagen. Ein vollständiger Import ist notwendig.';

  @override
  String healthDashboardSyncRecovered(int imported) {
    return 'Änderungsverfolgung abgelaufen. Letzte Historie neu gelesen: $imported Datensätze.';
  }

  @override
  String get healthDashboardShowTreadmill => 'Laufband-Workouts';

  @override
  String get healthDashboardShowTreadmillSubtitle =>
      'Lokale Laufbandläufe in Dashboard-Werte und Aktivitäten aufnehmen.';

  @override
  String get healthDashboardSync => 'Synchronisierung';

  @override
  String get healthDashboardSyncNow => 'Jetzt synchronisieren';

  @override
  String get healthDashboardSyncEnabled =>
      'Gesundheitsdaten mit dem eingerichteten Backend synchronisieren.';

  @override
  String get healthDashboardSyncDisabled =>
      'Backend-Synchronisierung zuerst in Einstellungen aktivieren.';

  @override
  String healthDashboardSyncSuccess(int pushed, int pulled) {
    return 'Synchronisiert: $pushed hochgeladen, $pulled geladen';
  }

  @override
  String get healthDashboardSyncFailed =>
      'Synchronisierung der Gesundheitsdaten fehlgeschlagen';

  @override
  String get healthDashboardHealthConnectWorkout => 'Health-Connect-Workout';

  @override
  String get healthDashboardLastSevenDays => 'Letzte 7 Tage';

  @override
  String get healthDashboardHistory => 'Verlauf';

  @override
  String get healthDashboardDetails => 'Details';

  @override
  String get healthDashboardDate => 'Datum';

  @override
  String get healthDashboardTime => 'Zeit';

  @override
  String get healthDashboardSource => 'Quelle';

  @override
  String get healthDashboardData => 'Daten';

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
  String get healthDashboardSourceUnknown => 'Unbekannte App';

  @override
  String get healthDashboardSourcePreferences => 'Bevorzugte Datenquellen';

  @override
  String get healthDashboardSourcePreferencesSubtitle =>
      'Bei überlappenden Daten eine bevorzugte App je Messwert verwenden.';

  @override
  String get healthDashboardAnySource => 'Beliebige Quelle';

  @override
  String get healthDashboardNap => 'Nickerchen';

  @override
  String get healthDashboardNaps => 'Nickerchen';

  @override
  String get healthDashboardAllData => 'Alle Gesundheitsdaten';

  @override
  String get healthDashboardSleepDetails => 'Schlafdetails';

  @override
  String get healthDashboardSleepDuration => 'Dauer';

  @override
  String get healthDashboardSleepStart => 'Beginn';

  @override
  String get healthDashboardSleepEnd => 'Ende';

  @override
  String healthDashboardSleepStageTimes(int count) {
    return '×$count';
  }

  @override
  String healthDashboardSleepStageDuration(Object duration, Object count) {
    return '$duration ($count Mal)';
  }

  @override
  String get healthDashboardSleepStages => 'Schlafphasen';

  @override
  String get healthDashboardTrends => 'Trends';

  @override
  String get healthDashboardWeightTrend => 'Gewicht · letzte 7 Tage';

  @override
  String get healthDashboardPreviousDay => 'Vorheriger Tag';

  @override
  String get healthDashboardNextDay => 'Nächster Tag';

  @override
  String get healthDashboardSleepAwake => 'Wach';

  @override
  String get healthDashboardSleepRem => 'REM';

  @override
  String get healthDashboardSleepLight => 'Leicht';

  @override
  String get healthDashboardSleepDeep => 'Tief';

  @override
  String get healthDashboardHeartRate => 'Herzfrequenz';

  @override
  String get healthDashboardNoSleepHeartRate =>
      'Keine Herzfrequenzwerte während dieser Schlafphase';

  @override
  String get healthDashboardSectionBackground => 'Automatischer Abgleich';

  @override
  String get healthDashboardBackgroundSync => 'Im Hintergrund abgleichen';

  @override
  String get healthDashboardBackgroundSyncSubtitle =>
      'Health-Connect-Änderungen importieren und an das Backend senden, während die App geschlossen ist.';

  @override
  String get healthDashboardBackup => 'Datensicherung';

  @override
  String get healthDashboardExportBackup => 'Gesundheitsdatenbank exportieren';

  @override
  String get healthDashboardExportBackupSubtitle =>
      'Health-Dashboard-Daten als SQLite-Datenbank speichern.';

  @override
  String get healthDashboardExportBackupWarning =>
      'Das Exportieren einer großen Gesundheitsdatenbank kann dauern. Der Vorgang läuft weiter, wenn Sie die App verlassen, und die Datei wird am Ende gespeichert.';

  @override
  String get healthDashboardExportBackupProgressTitle =>
      'Gesundheitsdatenbank wird exportiert';

  @override
  String get healthDashboardExportBackupProgressStatus =>
      'Datenbank wird vermessen...';

  @override
  String get healthDashboardExportBackupStatusWriting =>
      'Sicherungsdatei wird geschrieben...';

  @override
  String get healthDashboardExportBackupStatusSaving =>
      'Wird im Downloads-Ordner gespeichert...';

  @override
  String healthDashboardExportBackupProgressCount(int processed, int total) {
    return '$processed von $total Zeilen geschrieben';
  }

  @override
  String get healthDashboardExportBackupProgressHint =>
      'Sie können die App verlassen; die Sicherung wird im Hintergrund weiter geschrieben.';

  @override
  String get healthDashboardExportBackupFailed =>
      'Gesundheitsdatenbank konnte nicht exportiert werden';

  @override
  String get healthDashboardExportBackupSavedDownloads =>
      'Gesundheitsdatenbank im Downloads-Ordner gespeichert';

  @override
  String healthDashboardExportBackupSavedTo(String path) {
    return 'Gesundheitsdatenbank gespeichert unter $path';
  }

  @override
  String get healthDashboardImportBackup => 'Gesundheitsdatenbank importieren';

  @override
  String get healthDashboardImportBackupSubtitle =>
      'Alle gespeicherten Daten durch eine Health-Dashboard-SQLite-Sicherung ersetzen.';

  @override
  String get healthDashboardImportBackupWarning =>
      'Dabei werden alle gespeicherten Gesundheitsdaten gelöscht und durch den Inhalt der Sicherung ersetzt. Alles, was seit der Sicherung erfasst wurde, geht verloren. Health Connect bleibt unberührt, ein neuer Import kann diese Daten wieder holen.';

  @override
  String get healthDashboardImportBackupReplace =>
      'Löschen und wiederherstellen';

  @override
  String get healthDashboardImportBackupTooNew =>
      'Diese Sicherung stammt aus einer neueren App-Version und kann nicht wiederhergestellt werden';

  @override
  String healthDashboardImportBackupSuccess(int count) {
    return '$count Gesundheitsdaten wiederhergestellt';
  }

  @override
  String get healthDashboardImportBackupFailed =>
      'Gesundheitsdatenbank konnte nicht importiert werden';

  @override
  String get healthDashboardSelectedDay => 'Ausgewählter Tag';

  @override
  String get healthDashboardImportBackupProgressTitle =>
      'Gesundheitsdatenbank wird wiederhergestellt';

  @override
  String healthDashboardImportBackupProgressStatus(int processed, int total) {
    return 'Tabelle $processed von $total wird ersetzt...';
  }

  @override
  String healthDashboardImportBackupProgressCount(int processed, int total) {
    return '$processed von $total Tabellen wiederhergestellt';
  }

  @override
  String get healthDashboardImportBackupProgressHint =>
      'Sie können die App verlassen; die Wiederherstellung läuft im Hintergrund weiter.';

  @override
  String get healthDashboardImportHealthConnectProgressTitle =>
      'Gesundheitsdaten werden importiert';

  @override
  String get healthDashboardImportHealthConnectProgressStatus =>
      'Daten aus Health Connect werden abgerufen...';

  @override
  String healthDashboardImportHealthConnectProgressCount(int count) {
    return 'Bisher $count Daten abgerufen';
  }

  @override
  String get healthDashboardImportHealthConnectProgressHint =>
      'Der Import läuft mit einer Benachrichtigung im Hintergrund weiter. Du kannst wechseln oder den Bildschirm ausschalten.';

  @override
  String get healthDashboardHealthConnectAnalysisProgressTitle =>
      'Health-Connect-Analyse wird exportiert';

  @override
  String get healthDashboardHealthConnectAnalysisProgressStatus =>
      'Health-Connect-Daten werden gelesen...';

  @override
  String healthDashboardHealthConnectAnalysisProgressCount(int count) {
    return '$count Daten analysiert';
  }

  @override
  String get healthDashboardHealthConnectAnalysisProgressHint =>
      'Dies ändert keine Dashboard-Daten. Der Export läuft mit einer Benachrichtigung im Hintergrund weiter.';

  @override
  String get healthDashboardSevenDayTotal => '7-Tage Summe';

  @override
  String get healthDashboardSevenDayAvg => '7-Tage Schnitt';

  @override
  String get healthDashboardSevenDayMin => '7-Tage Min';

  @override
  String get healthDashboardSevenDayMax => '7-Tage Max';

  @override
  String get healthDashboardNightAvg => 'Nacht Schnitt';

  @override
  String get healthDashboardNightMin => 'Nacht Min';

  @override
  String get healthDashboardNightMax => 'Nacht Max';

  @override
  String get healthDashboardDayTotal => 'Tag Summe';

  @override
  String get healthDashboardDayAvg => 'Tag Schnitt';

  @override
  String get healthDashboardDayMin => 'Tag Min';

  @override
  String get healthDashboardDayMax => 'Tag Max';

  @override
  String get healthDashboardWorkoutDayTotals => 'Tagesgesamt';

  @override
  String get healthDashboardWorkoutSessions => 'Einheiten';

  @override
  String get healthDashboardPace => 'Pace';

  @override
  String get healthDashboardAverage => 'Durchschnitt';

  @override
  String get healthDashboardMinimum => 'Minimum';

  @override
  String get healthDashboardMaximum => 'Maximum';

  @override
  String get healthDashboardAvgHeartRate => 'Ø Herzfrequenz';

  @override
  String get healthDashboardMaxHeartRate => 'Max. Herzfrequenz';

  @override
  String get healthDashboardAvgSpeed => 'Ø Geschwindigkeit';

  @override
  String get healthDashboardMaxSpeed => 'Max. Geschwindigkeit';

  @override
  String get healthDashboardCadence => 'Trittfrequenz';

  @override
  String get healthDashboardPower => 'Leistung';

  @override
  String get healthDashboardDuringWorkout => 'Während des Workouts';

  @override
  String get healthDashboardLaps => 'Runden';

  @override
  String healthDashboardLap(int number) {
    return 'Runde $number';
  }

  @override
  String get healthDashboardSpeed => 'Geschwindigkeit';

  @override
  String get healthDashboardCount => 'Anzahl';

  @override
  String get healthDashboardBloodPressure => 'Blutdruck';

  @override
  String get healthDashboardPercentage => 'Prozentsatz';

  @override
  String get healthDashboardFloors => 'Stockwerke';

  @override
  String get healthDashboardDuration => 'Dauer';

  @override
  String get treadmillSyncToHealthConnect =>
      'Workouts mit Health Connect synchronisieren';

  @override
  String get treadmillSyncToHealthConnectSubtitle =>
      'Laufband-Workouts nach Abschluss in Health Connect eintragen.';

  @override
  String get healthDashboardCloudBackendSync =>
      'Cloud-Backend-Synchronisierung';

  @override
  String get healthDashboardHealthConnectSettings => 'Health Connect';

  @override
  String get healthDashboardHealthConnectSettingsSubtitle =>
      'Berechtigungen, Import, automatische Synchronisierung beim Öffnen und Neustart des Imports.';

  @override
  String get healthDashboardHealthConnectOpenFailed =>
      'Health-Connect-Einstellungen konnten nicht geöffnet werden';

  @override
  String get healthDashboardHealthConnectImportFailed =>
      'Health-Connect-Import fehlgeschlagen';

  @override
  String get healthDashboardHealthConnectRepairFailed =>
      'Health-Connect-Reparatur fehlgeschlagen';

  @override
  String get healthDashboardHrv => 'HRV (RMSSD)';

  @override
  String get healthDashboardOxygenSaturation => 'Sauerstoffsättigung';

  @override
  String get healthDashboardRespiratoryRate => 'Atemfrequenz';

  @override
  String get healthDashboardBodyFat => 'Körperfett';

  @override
  String get healthDashboardBloodGlucose => 'Blutzucker';

  @override
  String get healthDashboardBmr => 'Grundumsatz';

  @override
  String get healthDashboardVo2Max => 'VO2max';

  @override
  String get healthDashboardLatestOxygenSaturation =>
      'Letzte Sauerstoffsättigung';

  @override
  String get healthDashboardLatestRespiratoryRate => 'Letzte Atemfrequenz';

  @override
  String get healthDashboardLatestBodyFat => 'Letzter Körperfettanteil';

  @override
  String get healthDashboardHrvTrend => 'HRV (RMSSD) · letzte 7 Tage';

  @override
  String get healthDashboardOxygenSaturationTrend =>
      'Sauerstoffsättigung (SpO2) · letzte 7 Tage';

  @override
  String get healthDashboardRespiratoryRateTrend =>
      'Atemfrequenz · letzte 7 Tage';

  @override
  String get healthDashboardWeightBodyFatTrend =>
      'Gewicht & Körperfett · letzte 7 Tage';

  @override
  String get healthDashboardChartNoData => 'Keine Daten';

  @override
  String get healthDashboardLoadMore => 'Mehr laden';

  @override
  String get healthDashboardScrollToTop => 'Nach oben';

  @override
  String healthDashboardShowMoreRecords(int count) {
    return '100 weitere anzeigen ($count übrig)';
  }

  @override
  String get healthDashboardLoadMoreRecords => 'Weitere Daten laden…';

  @override
  String get healthDashboardHeight => 'Körpergröße';

  @override
  String get healthDashboardHydration => 'Flüssigkeit';

  @override
  String get healthDashboardBmi => 'BMI';

  @override
  String healthDashboardNoMetricDataInWeek(String metric) {
    return 'Kein Wert für $metric in diesen 7 Tagen';
  }

  @override
  String get healthDashboardNoMetricDataInWeekHint =>
      'Wähle einen anderen Tag oder prüfe, ob der Typ und seine Quelle eingeschaltet sind.';

  @override
  String get healthDashboardBackToToday => 'Zurück zu heute';

  @override
  String healthDashboardNoMetricHistory(String metric) {
    return 'Für $metric ist nichts gespeichert';
  }

  @override
  String get healthDashboardNoMetricHistoryHint =>
      'Importiere diesen Typ aus Health Connect, um den Verlauf zu füllen.';

  @override
  String get healthDashboardNoWorkoutsOnDay => 'Keine Workouts an diesem Tag';

  @override
  String get healthDashboardNoSleepOnDay =>
      'Für diesen Tag ist kein Schlaf aufgezeichnet';

  @override
  String get healthDashboardSleepQuality => 'Schlafqualität';

  @override
  String get healthDashboardSleepQualityDisclaimer =>
      'Verglichen mit allgemeinen Referenzwerten aus Schlafstudien für Erwachsene. Keine medizinische Beurteilung.';

  @override
  String get healthDashboardSleepRatingGood => 'Gut';

  @override
  String get healthDashboardSleepRatingFair => 'Mittel';

  @override
  String get healthDashboardSleepRatingPoor => 'Schlecht';

  @override
  String healthDashboardSleepScore(int score) {
    return '$score von 100';
  }

  @override
  String get healthDashboardSleepAsleep => 'Geschlafen';

  @override
  String get healthDashboardSleepTimeInBed => 'Im Bett';

  @override
  String get healthDashboardSleepEfficiency => 'Effizienz';

  @override
  String get healthDashboardSleepAwakenings => 'Wach';

  @override
  String get healthDashboardSleepFindingAllInRange =>
      'Dauer, Effizienz und Phasenanteile liegen alle im üblichen Bereich.';

  @override
  String get healthDashboardSleepFindingDurationShort =>
      'Weniger als 7 h geschlafen. Erwachsene brauchen meist 7-9 h.';

  @override
  String get healthDashboardSleepFindingDurationLong =>
      'Mehr als 10 h geschlafen, deutlich über den üblichen 7-9 h.';

  @override
  String get healthDashboardSleepFindingEfficiencyLow =>
      'Schlafeffizienz unter 85 %: ein großer Teil der Zeit im Bett war wach.';

  @override
  String get healthDashboardSleepFindingDeepLow =>
      'Tiefschlaf unter 13 % der Nacht (üblich 13-23 %).';

  @override
  String get healthDashboardSleepFindingDeepHigh =>
      'Tiefschlaf über 23 % der Nacht (üblich 13-23 %).';

  @override
  String get healthDashboardSleepFindingRemLow =>
      'REM unter 20 % der Nacht (üblich 20-25 %).';

  @override
  String get healthDashboardSleepFindingRemHigh =>
      'REM über 25 % der Nacht (üblich 20-25 %).';

  @override
  String get healthDashboardSleepFindingAwakeHigh =>
      'Mehr als 30 Minuten wach nach dem Einschlafen.';

  @override
  String get healthDashboardSectionMaintenance => 'Wartung';

  @override
  String get healthDashboardSectionMaintenanceHint =>
      'Gibt Speicher frei. Diese Aktionen löschen gespeicherte Zeilen.';

  @override
  String get healthDashboardPruneUnused =>
      'Aufräumen und Datenbank verkleinern';

  @override
  String get healthDashboardPruneUnusedSubtitle =>
      'Löscht Zeilen, die nichts mehr liest, und schreibt die Datei neu';

  @override
  String healthDashboardPruneUnusedConfirm(String apps) {
    return 'Löscht alle Zeilen von ausgeschalteten Apps ($apps), dazu verwaiste Zeilen und unbenutzte Bezeichnungen, und schreibt die Datenbankdatei neu. Diese Apps wieder einzuschalten bringt die Daten nicht zurück - dafür ist ein neuer Import nötig. Das kann nicht widerrufen werden.';
  }

  @override
  String get healthDashboardPruneUnusedConfirmNoApps =>
      'Keine App ist ausgeschaltet, es werden also nur verwaiste Zeilen und unbenutzte Bezeichnungen entfernt, bevor die Datenbankdatei neu geschrieben wird. Das kann nicht widerrufen werden.';

  @override
  String get healthDashboardPruneUnusedConfirmAction => 'Aufräumen';

  @override
  String healthDashboardPruneUnusedDone(int rows) {
    return '$rows Zeilen entfernt, Datenbank neu geschrieben';
  }

  @override
  String get healthDashboardPruneUnusedFailed =>
      'Aufräumen der Gesundheitsdatenbank fehlgeschlagen';

  @override
  String get healthDashboardManageFellBack =>
      'Dieses Gerät hat keinen Health-Connect-Einstellungsbildschirm, daher wurde die App-Info geöffnet.';

  @override
  String get healthDashboardPermissionNeeded => 'Health-Connect-Zugriff nötig';

  @override
  String get healthDashboardPermissionNeededBody =>
      'Es wurde nichts freigegeben, also gibt es nichts zu lesen. Gib den Lesezugriff in Health Connect frei und starte den Import erneut.';

  @override
  String get healthDashboardOpenHealthConnect => 'Health Connect öffnen';

  @override
  String get healthDashboardMetaApp => 'App';

  @override
  String get healthDashboardMetaPackage => 'Paket';

  @override
  String get healthDashboardMetaOurType => 'Unser Typ';

  @override
  String get healthDashboardMetaMetricKey => 'Messwert-Schlüssel';

  @override
  String get healthDashboardMetaRecordType => 'Health-Connect-Typ';

  @override
  String get healthDashboardMetaActivity => 'Aktivität';

  @override
  String get healthDashboardMetaUnit => 'Gespeicherte Einheit';

  @override
  String get healthDashboardMetaAggregation => 'Tageszusammenfassung';

  @override
  String get healthDashboardMetaShape => 'Speicherform';

  @override
  String get healthDashboardMetaSource => 'Erfasst über';

  @override
  String get healthDashboardMetaRowId => 'Zeilen-ID';

  @override
  String get healthDashboardMetaOrigin => 'Health-Connect-Datensatz-ID';

  @override
  String get healthDashboardMetaClientId => 'Client-Datensatz-ID';

  @override
  String get healthDashboardMetaDevice => 'Gerät';

  @override
  String get healthDashboardMetaDuplicateOf => 'Duplikat von';

  @override
  String get healthDashboardMetaStart => 'Beginnt';

  @override
  String get healthDashboardMetaEnd => 'Endet';

  @override
  String get healthDashboardMetaDuration => 'Dauer';

  @override
  String get healthDashboardMetaAggregateIncluded => 'Zählt in Summen';

  @override
  String get healthDashboardMetaSynced => 'Mit Backend synchronisiert';

  @override
  String get healthDashboardMetaDeleted => 'Gelöscht';

  @override
  String get healthDashboardMetaRawValues => 'Gespeicherte Werte';

  @override
  String get healthDashboardSectionDebug => 'Debug';

  @override
  String get healthDebugSourceGenerated => 'Generierte Testdaten';

  @override
  String get healthDebugSeedTitle => 'Generierte Testdaten';

  @override
  String get healthDebugSeedSubtitle =>
      'Health Connect mit einer erzeugten Historie füllen';

  @override
  String get healthDebugSeedWarning =>
      'Nur in Debug-Builds. Die Einträge werden als diese App nach Health Connect geschrieben, sind als generiert markiert und lassen sich unten wieder entfernen.';

  @override
  String get healthDebugSeedRange => 'Zeitraum';

  @override
  String healthDebugSeedDays(int count) {
    return '$count Tage';
  }

  @override
  String get healthDebugSeedPresets => 'Voreinstellungen';

  @override
  String get healthDebugSeedPresetsHint =>
      'Eine Voreinstellung wählt nur eine Gruppenmenge aus — unten anpassbar.';

  @override
  String get healthDebugSeedGroups => 'Datengruppen';

  @override
  String get healthDebugSeedActions => 'Aktionen';

  @override
  String get healthDebugSeedGenerate => 'Daten erzeugen';

  @override
  String get healthDebugSeedGenerateSubtitle =>
      'Schreibt Tag für Tag und ersetzt bereits erzeugte Tage';

  @override
  String healthDebugSeedGenerateConfirm(int days, int groups) {
    return '$days Tag(e) generierte Daten aus $groups Gruppe(n) nach Health Connect schreiben?';
  }

  @override
  String get healthDebugSeedGenerateAction => 'Erzeugen';

  @override
  String healthDebugSeedProgress(int count) {
    return '$count Eintrag/Einträge...';
  }

  @override
  String healthDebugSeedDone(int count) {
    return '$count Eintrag/Einträge geschrieben';
  }

  @override
  String healthDebugSeedPartial(int written, int failed) {
    return '$written Eintrag/Einträge geschrieben, $failed fehlgeschlagen';
  }

  @override
  String get healthDebugSeedClear => 'Generierte Daten entfernen';

  @override
  String get healthDebugSeedClearSubtitle =>
      'Löscht nur Einträge, die dieser Generator geschrieben hat';

  @override
  String get healthDebugSeedClearConfirm =>
      'Alle generierten Einträge aus Health Connect löschen und ihre Zeilen aus dem Speicher entfernen? Echte Daten bleiben erhalten.';

  @override
  String get healthDebugSeedClearAction => 'Entfernen';

  @override
  String healthDebugSeedClearDone(int count) {
    return '$count Eintrag/Einträge entfernt';
  }

  @override
  String get healthDebugSeedNoGroups => 'Mindestens eine Datengruppe auswählen';

  @override
  String get healthDebugSeedNoPermission =>
      'Der Zugriff auf Health Connect wurde abgelehnt';

  @override
  String get healthDebugSeedFailed =>
      'Health Connect hat den Lauf abgelehnt — siehe Log';

  @override
  String get healthDebugSeedUnsupported =>
      'Health Connect gibt es nur unter Android';

  @override
  String get healthDebugSeedImportHint =>
      'Generierte Daten landen in Health Connect, nicht im Dashboard. Erst Quellen suchen, dann Import neu starten.';

  @override
  String get healthDebugPresetEveryday => 'Alltag';

  @override
  String get healthDebugPresetAthlete => 'Sportlich';

  @override
  String get healthDebugPresetClinical => 'Klinisch';

  @override
  String get healthDebugPresetEverything => 'Alles';

  @override
  String get healthDebugGroupActivity =>
      'Aktivität — Schritte, Distanz, Energie, Etagen';

  @override
  String get healthDebugGroupHeart => 'Herz — Messreihe, Ruhepuls, HRV';

  @override
  String get healthDebugGroupSleep => 'Schlaf — eine Nacht pro Tag mit Phasen';

  @override
  String get healthDebugGroupWorkouts => 'Workouts — drei Einheiten pro Woche';

  @override
  String get healthDebugGroupBody =>
      'Körper — Gewicht, Fettanteil, Magermasse, Größe';

  @override
  String get healthDebugGroupVitals =>
      'Vitalwerte — Sauerstoff, Atmung, Blutdruck, Glukose';

  @override
  String get healthDebugGroupHydration =>
      'Flüssigkeit — Getränke über den Tag verteilt';

  @override
  String get toolNameSqliteViewer => 'SQLite Viewer';

  @override
  String get toolDescSqliteViewer =>
      'SQLite-Datenbanken ansehen: Schema, Tabellen und freies SQL';

  @override
  String get sqliteViewerOpenTitle => 'SQLite-Datenbank öffnen';

  @override
  String get sqliteViewerDropSubtitle =>
      'Eine .db-Datei hierher ziehen oder auswählen';

  @override
  String get sqliteViewerTypeLabel => 'SQLite-Datenbank';

  @override
  String get sqliteViewerInternalTitle => 'ToolLab-Datenbanken';

  @override
  String get sqliteViewerInternalSubtitle =>
      'Wird als schreibgeschützte Kopie geöffnet, damit die laufende App unberührt bleibt';

  @override
  String get sqliteViewerNoInternal => 'Keine ToolLab-Datenbanken gefunden';

  @override
  String get sqliteViewerAppDatabase => 'App-Datenbank';

  @override
  String get sqliteViewerErrorMissing => 'Die Datei existiert nicht mehr.';

  @override
  String get sqliteViewerErrorNotSqlite =>
      'Diese Datei ist keine SQLite-Datenbank.';

  @override
  String get sqliteViewerErrorLocked =>
      'Die Datenbank ist gesperrt oder nicht lesbar.';

  @override
  String sqliteViewerErrorUnknown(String detail) {
    return 'Die Datenbank konnte nicht geöffnet werden: $detail';
  }

  @override
  String get sqliteViewerTabOverview => 'Übersicht';

  @override
  String get sqliteViewerTabData => 'Daten';

  @override
  String get sqliteViewerTabSql => 'SQL';

  @override
  String get sqliteViewerSectionFile => 'Datei';

  @override
  String get sqliteViewerSectionPragmas => 'Datenbank-Parameter';

  @override
  String get sqliteViewerFileName => 'Name';

  @override
  String get sqliteViewerFileSize => 'Größe';

  @override
  String get sqliteViewerFilePath => 'Pfad';

  @override
  String get sqliteViewerSqliteVersion => 'SQLite-Version';

  @override
  String get sqliteViewerPageSize => 'Seitengröße';

  @override
  String get sqliteViewerPageCount => 'Seiten';

  @override
  String get sqliteViewerFreelistPages => 'Freie Seiten';

  @override
  String get sqliteViewerEncoding => 'Kodierung';

  @override
  String get sqliteViewerJournalMode => 'Journal-Modus';

  @override
  String get sqliteViewerAutoVacuum => 'Auto-Vacuum';

  @override
  String get sqliteViewerUserVersion => 'Benutzerversion';

  @override
  String get sqliteViewerApplicationId => 'Anwendungs-ID';

  @override
  String get sqliteViewerObjects => 'Objekte';

  @override
  String get sqliteViewerTables => 'Tabellen';

  @override
  String get sqliteViewerViews => 'Views';

  @override
  String get sqliteViewerIndexes => 'Indizes';

  @override
  String get sqliteViewerTriggers => 'Trigger';

  @override
  String get sqliteViewerNoObjects =>
      'Diese Datenbank enthält keine Tabellen oder Views.';

  @override
  String get sqliteViewerSelectObject => 'Tabelle oder View auswählen.';

  @override
  String get sqliteViewerIntegrityTitle => 'Integrität';

  @override
  String get sqliteViewerRunIntegrityCheck => 'Integritätsprüfung starten';

  @override
  String get sqliteViewerIntegrityOk => 'Unversehrt';

  @override
  String get sqliteViewerIntegrityFailed => 'Probleme gefunden';

  @override
  String get sqliteViewerIntegrityEmpty => 'Noch nicht geprüft';

  @override
  String get sqliteViewerSchema => 'Schema';

  @override
  String get sqliteViewerDdl => 'Definition (DDL)';

  @override
  String get sqliteViewerForeignKeys => 'Fremdschlüssel';

  @override
  String get sqliteViewerPrimaryKey => 'PK';

  @override
  String get sqliteViewerNotNull => 'NOT NULL';

  @override
  String get sqliteViewerUnique => 'UNIQUE';

  @override
  String sqliteViewerDefaultValue(String value) {
    return 'Standard $value';
  }

  @override
  String get sqliteViewerSearchHint => 'Zeilen filtern…';

  @override
  String sqliteViewerRowRange(String start, String end, String total) {
    return '$start – $end von $total';
  }

  @override
  String get sqliteViewerPreviousPage => 'Vorherige Seite';

  @override
  String get sqliteViewerNextPage => 'Nächste Seite';

  @override
  String get sqliteViewerNoRows => 'Keine Zeilen';

  @override
  String get sqliteViewerAddRow => 'Zeile einfügen';

  @override
  String get sqliteViewerDeleteRow => 'Zeile löschen';

  @override
  String get sqliteViewerDeleteRowConfirm =>
      'Diese Zeile löschen? Das lässt sich nicht rückgängig machen.';

  @override
  String get sqliteViewerWriteFailed =>
      'Die Änderung konnte nicht geschrieben werden.';

  @override
  String get sqliteViewerNull => 'NULL';

  @override
  String get sqliteViewerSetNull => 'Auf NULL setzen';

  @override
  String get sqliteViewerEmptyValue => 'Leerer Wert';

  @override
  String get sqliteViewerShowImage => 'Bild öffnen';

  @override
  String get sqliteViewerEditModeOn => 'Bearbeitung aktiv';

  @override
  String get sqliteViewerEditModeOff => 'Schreibgeschützt';

  @override
  String get sqliteViewerEditModeBanner =>
      'Bearbeitungsmodus: Änderungen werden sofort geschrieben und lassen sich nicht rückgängig machen.';

  @override
  String get sqliteViewerReadOnlyNotice =>
      'Schreibgeschützt. Für Änderungen den Bearbeitungsmodus aktivieren.';

  @override
  String get sqliteViewerSnapshotNotice =>
      'Es wird auf einer Kopie gearbeitet — Änderungen erreichen die Originaldatei nicht.';

  @override
  String get sqliteViewerInternalNotice =>
      'Eine ToolLab-Datenbank, schreibgeschützt als Kopie geöffnet.';

  @override
  String get sqliteViewerEnableEditTitle => 'Bearbeitungsmodus aktivieren?';

  @override
  String get sqliteViewerEnableEditMessage =>
      'Schreibvorgänge gehen direkt in die Datenbankdatei und lassen sich nicht rückgängig machen.';

  @override
  String get sqliteViewerEnableEditMessageCopy =>
      'Schreibvorgänge gehen in die Arbeitskopie, nicht in die Originaldatei. Danach eine Kopie speichern, um die Änderungen zu behalten.';

  @override
  String get sqliteViewerEnable => 'Aktivieren';

  @override
  String get sqliteViewerEditNotPossible =>
      'Diese Datenbank lässt sich nicht zum Schreiben öffnen.';

  @override
  String get sqliteViewerEditNotAllowedInternal =>
      'ToolLabs eigene Datenbanken bleiben hier schreibgeschützt.';

  @override
  String get sqliteViewerSaveCopy => 'Geänderte Kopie speichern';

  @override
  String get sqliteViewerSaveCopyFailed =>
      'Die Arbeitskopie ist nicht mehr verfügbar.';

  @override
  String get sqliteViewerSqlHint => 'SELECT * FROM ...';

  @override
  String get sqliteViewerSqlIdle =>
      'Anweisung ausführen, um das Ergebnis zu sehen.';

  @override
  String get sqliteViewerRun => 'Ausführen';

  @override
  String get sqliteViewerQueryEmpty => 'Zuerst eine Anweisung eingeben.';

  @override
  String get sqliteViewerReadOnlyRefusal =>
      'Schreibgeschützt: nur SELECT, EXPLAIN und lesende PRAGMA-Anweisungen laufen.';

  @override
  String get sqliteViewerConfirmWriteTitle => 'Diese Anweisung ausführen?';

  @override
  String get sqliteViewerConfirmWriteMessage =>
      'Sie ändert die Datenbank und lässt sich nicht rückgängig machen.';

  @override
  String sqliteViewerRowsReturned(String count, String ms) {
    return '$count Zeilen in $ms ms';
  }

  @override
  String sqliteViewerRowsAffected(String count, String ms) {
    return '$count Zeilen geändert in $ms ms';
  }

  @override
  String sqliteViewerStatementDone(String ms) {
    return 'Anweisung ausgeführt in $ms ms';
  }

  @override
  String sqliteViewerTruncated(String count) {
    return 'Nur die ersten $count Zeilen werden angezeigt.';
  }

  @override
  String get sqliteViewerSqlError => 'SQL-Fehler';

  @override
  String get toolNameRenphoScale => 'Renpho Waage';

  @override
  String get toolDescRenphoScale =>
      'Lokale MorphoScan-Nova-Körperanalyse, auf diesem Gerät gespeichert';

  @override
  String get renphoStartScan => 'Waage suchen';

  @override
  String get renphoStopScan => 'Stopp';

  @override
  String get renphoStatusIdle =>
      'Stell dich kurz auf die Waage, um sie zu wecken, und starte dann die Suche.';

  @override
  String get renphoStatusDiscovering => 'Suche nach der Waage...';

  @override
  String get renphoStatusConnecting => 'Verbinde...';

  @override
  String get renphoStatusPreparing => 'Messung wird vorbereitet...';

  @override
  String get renphoStatusReady =>
      'Barfuß auf die Waage stellen und beide Griffe halten, bis das Ergebnis erscheint.';

  @override
  String get renphoStatusSaving => 'Messung wird gespeichert...';

  @override
  String get renphoStatusRetrying =>
      'Die Waage hat nicht geantwortet. Einrichtung wird wiederholt...';

  @override
  String get renphoErrorBluetooth =>
      'Bluetooth ist nicht verfügbar oder die Berechtigung wurde verweigert.';

  @override
  String get renphoErrorNotFound =>
      'Keine Waage gefunden. Kurz drauftreten, um sie zu wecken, dann erneut suchen.';

  @override
  String get renphoErrorScan => 'Die Bluetooth-Suche ist fehlgeschlagen.';

  @override
  String get renphoErrorConnect =>
      'Verbindung zur Waage nicht möglich. Kurz drauftreten, um sie zu wecken, dann erneut versuchen.';

  @override
  String get renphoErrorSetup =>
      'Die Waage hat während der Einrichtung nicht mehr geantwortet. Kurz drauftreten, um sie zu wecken, dann erneut suchen.';

  @override
  String get renphoErrorSave => 'Die Messung konnte nicht gespeichert werden.';

  @override
  String get renphoPhaseComplete => 'Fertig';

  @override
  String get renphoStatusComplete => 'Messung abgeschlossen und gespeichert.';

  @override
  String get renphoStepWeight => 'Gewicht';

  @override
  String get renphoStepImpedance => 'Griffe';

  @override
  String get renphoStepResult => 'Ergebnis';

  @override
  String get renphoStepHintWeight =>
      'Barfuß auf die Waage stellen und ruhig stehen bleiben.';

  @override
  String get renphoStepHintImpedance =>
      'Beide Griffe fassen, Arme gestreckt, ruhig halten.';

  @override
  String get renphoStepHintComputing =>
      'Körperzusammensetzung wird berechnet...';

  @override
  String get renphoImportTitle => 'Alte Daten importieren';

  @override
  String get renphoImportSubtitle =>
      'Renpho-JSON-Export in die lokale Historie einlesen';

  @override
  String get renphoImportNothing =>
      'In dieser Datei ist nichts zum Importieren.';

  @override
  String renphoImportDone(int added, int duplicates, int skipped) {
    return '$added importiert, $duplicates bereits vorhanden übersprungen, $skipped unbrauchbar.';
  }

  @override
  String get renphoSourceImported => 'Aus einem Export importiert';

  @override
  String get renphoPhaseIdle => 'Inaktiv';

  @override
  String get renphoPhaseDiscovering => 'Suche';

  @override
  String get renphoPhaseConnecting => 'Verbinde';

  @override
  String get renphoPhasePreparing => 'Vorbereitung';

  @override
  String get renphoPhaseReady => 'Messbereit';

  @override
  String get renphoPhaseSaving => 'Speichern';

  @override
  String renphoImportedStored(int count) {
    return 'Zusätzlich $count ältere Messung(en) aus dem Speicher der Waage importiert';
  }

  @override
  String get renphoSyncNow => 'Jetzt synchronisieren';

  @override
  String get renphoSectionLatest => 'Letzte Messung';

  @override
  String get renphoSectionHistory => 'Verlauf';

  @override
  String get renphoDevicesTitle => 'Waage';

  @override
  String get renphoAutoConnect => 'Automatisch verbinden';

  @override
  String get renphoAutoConnectSubtitle =>
      'Mit der bekannten Waage verbinden, sobald sie gefunden wird';

  @override
  String get renphoNoDevices =>
      'Noch keine Waage gefunden. Stell dich kurz drauf, um sie zu wecken.';

  @override
  String get renphoConnect => 'Verbinden';

  @override
  String get renphoConnected => 'Verbunden';

  @override
  String get renphoForgetDevice => 'Diese Waage vergessen';

  @override
  String get renphoNoRememberedDevice => 'Noch keine Waage gekoppelt';

  @override
  String get renphoProfileTitle => 'Messprofil';

  @override
  String get renphoProfileFirstRunHint =>
      'Geschlecht, Größe und Geburtsdatum bestimmen jeden berechneten Wert. Bitte vor der ersten Messung eintragen.';

  @override
  String get renphoProfileName => 'Name';

  @override
  String get renphoProfileNameHelper =>
      'Wird an die Waage gesendet, um den Benutzerplatz zu wählen';

  @override
  String get renphoProfileSex => 'Geschlecht';

  @override
  String get renphoProfileHeight => 'Größe (cm)';

  @override
  String get renphoProfileHeightInvalid =>
      'Bitte eine Größe zwischen 80 und 250 cm eingeben';

  @override
  String get renphoProfileBirthDate => 'Geburtsdatum';

  @override
  String get renphoSexMale => 'Männlich';

  @override
  String get renphoSexFemale => 'Weiblich';

  @override
  String get renphoSettingsTitle => 'Waagen-Einstellungen';

  @override
  String get renphoSyncToHealthConnect => 'In Health Connect schreiben';

  @override
  String get renphoSyncToHealthConnectSubtitle =>
      'Gewicht, Körperfett, Magermasse, Knochenmasse, Körperwasser und Grundumsatz';

  @override
  String get renphoBackendSyncHint =>
      'Die Backend-Synchronisierung folgt dem globalen Schalter in den App-Einstellungen.';

  @override
  String get renphoPublishNow => 'Jetzt übertragen';

  @override
  String get renphoPublishNowSubtitle =>
      'Alle noch nicht übertragenen Messungen in Health Connect schreiben';

  @override
  String get renphoRemoveFromHealthConnect => 'Aus Health Connect entfernen';

  @override
  String get renphoRemoveFromHealthConnectSubtitle =>
      'Alle von dieser App geschriebenen Waagen-Einträge löschen';

  @override
  String get renphoRemoveFromHealthConnectConfirm =>
      'Alle von dieser App in Health Connect geschriebenen Körperanalyse-Einträge löschen? Der lokale Verlauf bleibt erhalten und kann erneut übertragen werden.';

  @override
  String get renphoRemoveFromHealthConnectFailed =>
      'Die Health-Connect-Einträge konnten nicht entfernt werden';

  @override
  String renphoRemoveFromHealthConnectDone(int count) {
    return 'Einträge entfernt; $count Messung(en) koennen erneut übertragen werden';
  }

  @override
  String get renphoPublishNothing => 'Health Connect ist bereits aktuell';

  @override
  String get renphoPublishUnsupported =>
      'Health Connect gibt es nur unter Android';

  @override
  String get renphoPublishDisabled =>
      'Das Schreiben in Health Connect ist ausgeschaltet';

  @override
  String get renphoPublishNoPermission =>
      'Die Schreibberechtigung für Health Connect wurde nicht erteilt';

  @override
  String get renphoPublishThrottled => 'Wurde gerade eben schon übertragen';

  @override
  String renphoPublishFailed(int count) {
    return '$count Messung(en) konnten nicht übertragen werden';
  }

  @override
  String renphoPublishDone(int count) {
    return '$count Messung(en) an Health Connect übertragen';
  }

  @override
  String get renphoMetricWeight => 'Gewicht';

  @override
  String get renphoMetricBodyFat => 'Körperfett';

  @override
  String get renphoMetricMuscle => 'Muskeln';

  @override
  String get renphoMetricBmi => 'BMI';

  @override
  String get renphoMetricBmiOnScale => 'BMI laut Waage';

  @override
  String get renphoMetricFatMass => 'Fettmasse';

  @override
  String get renphoMetricFatFreeMass => 'Fettfreie Masse';

  @override
  String get renphoMetricBodyWater => 'Körperwasser';

  @override
  String get renphoMetricVisceralFat => 'Viszeralwert';

  @override
  String get renphoMetricSkeletalMuscleMass => 'Skelettmuskelmasse';

  @override
  String get renphoMetricProtein => 'Protein';

  @override
  String get renphoMetricLeanSoftTissue => 'Magerweichgewebe';

  @override
  String get renphoMetricSubcutaneousFat => 'Subkutanes Fett';

  @override
  String get renphoMetricBoneMass => 'Knochenmasse';

  @override
  String get renphoMetricBmr => 'Grundumsatz';

  @override
  String get renphoMetricBodyScore => 'Körperwertung';

  @override
  String get renphoMetricBodyType => 'Körpertyp';

  @override
  String get renphoMetricObesityDegree => 'Adipositasgrad';

  @override
  String get renphoMetricWeightControl => 'Gewichtskontrolle';

  @override
  String get renphoMetricTargetWeight => 'Zielgewicht';

  @override
  String get renphoMetricSmi => 'Skelettmuskelindex';

  @override
  String get renphoTrendWeightBodyFat =>
      'Gewicht und Körperfett, letzte 7 Tage';

  @override
  String get renphoTrendMuscleWater =>
      'Muskeln und Körperwasser, letzte 7 Tage';

  @override
  String get renphoHistoryEmpty =>
      'Noch keine Messungen. Alles Gemessene bleibt auf diesem Gerät.';

  @override
  String get renphoDeleteMeasurement => 'Messung löschen';

  @override
  String get renphoDeleteMeasurementConfirm =>
      'Diese Messung löschen? Sie wird bei der nächsten Synchronisierung auch aus dem Backend und aus Health Connect entfernt.';

  @override
  String get renphoSectionReported => 'Von der Waage gemeldet';

  @override
  String get renphoSectionReportedHint =>
      'Diese fünf Werte und die zehn Segmentimpedanzen sind die gesamte Messung. Der Viszeralwert ist eine Gerätekennzahl, keine Fettmasse.';

  @override
  String get renphoSectionExact => 'Exakte Berechnungen';

  @override
  String get renphoSectionModel => 'Renpho-Modell';

  @override
  String get renphoModelUncalibrated =>
      'Diese Koeffizienten stammen aus einem einzigen Profil (männlich, 173 cm). Für einen anderen Körper sind sie ein Anhaltspunkt, keine Messung.';

  @override
  String get renphoSectionSegments => 'Segmentanalyse';

  @override
  String get renphoSectionImpedance => 'Impedanz';

  @override
  String get renphoSectionEnergy => 'Grundumsatz-Schätzungen';

  @override
  String get renphoEnergyHint =>
      'Schätzungen des Ruheumsatzes, kein gemessener Stoffwechsel.';

  @override
  String get renphoSectionPublished => 'Unabhängige veröffentlichte Formeln';

  @override
  String renphoPublishedHint(String ohms) {
    return 'Peer-reviewte Formeln als Gegenprobe. Sie gelten für den 50-kHz-Widerstand, den diese Waage nicht misst; die 50-kHz-Spalte interpoliert auf $ohms Ohm und ist die schwächste Annahme hier.';
  }

  @override
  String get renphoSectionRecord => 'Datensatz';

  @override
  String get renphoWholeBody20 => 'Ganzkörper bei 20 kHz';

  @override
  String get renphoWholeBody100 => 'Ganzkörper bei 100 kHz';

  @override
  String get renphoImpedanceRatio => 'Verhältnis 100/20 kHz';

  @override
  String get renphoArmDifference => 'Unterschied Arm links/rechts';

  @override
  String get renphoLegDifference => 'Unterschied Bein links/rechts';

  @override
  String get renphoImpedanceHint =>
      'Der Ganzkörperwert nähert den Pfad Arm + Rumpf + Bein an. Das Verhältnis 100/20 kHz ist ein Indikator für Extrazellulärwasser und Zellintegrität.';

  @override
  String get renphoEquation => 'Formel';

  @override
  String get renphoAgeAtScan => 'Alter bei der Messung';

  @override
  String get renphoSource => 'Quelle';

  @override
  String get renphoSourceStored => 'Aus dem Speicher der Waage';

  @override
  String get renphoSourceLive => 'Live-Messung';

  @override
  String get renphoRawPacket => 'Rohpaket';

  @override
  String get renphoCopyPacket => 'Paket kopieren';

  @override
  String get renphoPacketCopied => 'Paket kopiert';

  @override
  String get renphoSegment => 'Segment';

  @override
  String get renphoSegmentMuscle => 'Muskeln';

  @override
  String get renphoSegmentOfStandard => 'Vom Standard';

  @override
  String get renphoSegmentFat => 'Fett';

  @override
  String get renphoSegmentLeftArm => 'Arm links';

  @override
  String get renphoSegmentRightArm => 'Arm rechts';

  @override
  String get renphoSegmentLeftLeg => 'Bein links';

  @override
  String get renphoSegmentRightLeg => 'Bein rechts';

  @override
  String get renphoSegmentTrunk => 'Rumpf';

  @override
  String get renphoSegmentMuscleOfStandard => 'Muskeln vom Standard';

  @override
  String get renphoSegmentFatOfStandard => 'Fett vom Standard';

  @override
  String get renphoSegmentMapHint =>
      'Tippe auf einen Körperteil oder seine Beschriftung für die vollständige Aufschlüsselung.';

  @override
  String get renphoSegmentTable => 'Alle Segmente als Tabelle';

  @override
  String get renphoReportTooltip => 'PDF-Bericht erstellen';

  @override
  String get renphoReportTitle => 'Körperanalyse-Bericht';

  @override
  String get renphoReportGenerated => 'Erstellt';

  @override
  String get renphoReportMeasured => 'Gemessen';

  @override
  String get renphoReportYears => 'Jahre';

  @override
  String get renphoReportAssessment => 'Bewertung';

  @override
  String get renphoReportMetric => 'Messwert';

  @override
  String get renphoReportValue => 'Ergebnis';

  @override
  String get renphoReportReference => 'Referenz';

  @override
  String get renphoReportRating => 'Einstufung';

  @override
  String get renphoReportTrends => 'Letzte 7 Tage';

  @override
  String get renphoReportDisclaimer =>
      'Bioimpedanz-Schätzungen einer Verbraucherwaage, keine klinische Messung. Die Referenzbereiche folgen Bevölkerungsdaten (WHO für den BMI, ACE für den Körperfettanteil, EWGSOP2 für den Muskelindex) und ersetzen keine ärztliche Diagnose.';

  @override
  String get renphoReportFailed => 'Bericht konnte nicht erstellt werden';

  @override
  String get renphoReportNoMeasurement =>
      'Noch keine Messung für einen Bericht';

  @override
  String get renphoAssessmentSegmentMuscle =>
      'Schwächstes Segment vom Standard';

  @override
  String get renphoAssessmentSymmetry => 'Unterschied links/rechts';

  @override
  String get renphoRatingLow => 'Niedrig';

  @override
  String get renphoRatingOptimal => 'Optimal';

  @override
  String get renphoRatingElevated => 'Erhöht';

  @override
  String get renphoRatingHigh => 'Hoch';

  @override
  String get treadmillHistoryDeleteTitle => 'Workout löschen?';

  @override
  String get treadmillHistoryDeleteMessage =>
      'Möchtest du diese Trainingseinheit endgültig löschen?';

  @override
  String get treadmillHistoryExportEmpty => 'Keine Einheiten zum Exportieren';

  @override
  String get treadmillHistoryExportSaved =>
      'Workout-Backup in Downloads gespeichert';

  @override
  String treadmillHistoryExportFailed(String error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String treadmillHistoryImportFailed(String error) {
    return 'Import fehlgeschlagen: $error';
  }

  @override
  String get treadmillHistoryJsonLabel => 'JSON-Backup';

  @override
  String get treadmillSimulateDevice => 'Gerät simulieren';

  @override
  String get treadmillConnectedDevices => 'Verbundene Geräte';

  @override
  String get treadmillFallbackName => 'Laufband';

  @override
  String get treadmillHrmFallbackName => 'Herzfrequenzmesser';

  @override
  String treadmillConnectedStatus(String id) {
    return 'Verbunden | $id';
  }

  @override
  String get treadmillDisconnect => 'Trennen';

  @override
  String get treadmillConnect => 'Verbinden';

  @override
  String get treadmillScanTreadmills => 'Laufbänder';

  @override
  String get treadmillScanNoTreadmills => 'Keine Laufbänder gefunden';

  @override
  String get treadmillScanHrms => 'Herzfrequenzmesser';

  @override
  String get treadmillScanNoHrms => 'Keine Herzfrequenzmesser gefunden';

  @override
  String get treadmillHrHistoryTitle => 'Herzfrequenzverlauf';

  @override
  String get treadmillHrHistoryEmpty =>
      'Noch keine Herzfrequenzdaten aufgezeichnet.';

  @override
  String get treadmillHrCurrent => 'Aktuell';

  @override
  String get treadmillHrMax => 'Max';

  @override
  String get treadmillHrMin => 'Min';

  @override
  String get treadmillHrAccumulating =>
      'Daten für das Diagramm werden gesammelt …';

  @override
  String get treadmillLabel => 'Laufband';

  @override
  String get codeHighlightCreateBlankFile => 'Leere Datei erstellen';

  @override
  String get imageViewerFormatPng => 'PNG (.png)';

  @override
  String get imageViewerFormatJpeg => 'JPEG (.jpg)';

  @override
  String get imageViewerFormatBmp => 'BMP (.bmp)';

  @override
  String get imageViewerFormatWebp => 'WebP (.webp)';

  @override
  String noteFailedToProcessImage(String error) {
    return 'Bild konnte nicht verarbeitet werden: $error';
  }

  @override
  String get fastDropNotificationTitle => 'Fast-Drop-Übertragung';

  @override
  String get fastDropUploading => 'Wird hochgeladen';

  @override
  String get fastDropDownloading => 'Wird heruntergeladen';

  @override
  String get sfMorseLiveTranslate => 'Live-Übersetzung';

  @override
  String get sfMorseDecodingAudioFile => 'Audiodatei wird dekodiert …';

  @override
  String get toolNameTextEditor => 'Texteditor';

  @override
  String get toolDescTextEditor =>
      'Textdateien bearbeiten – lokal oder aus dem Netzwerk';

  @override
  String get textEditorOpenTitle => 'Textdatei öffnen';

  @override
  String get textEditorDropSubtitle =>
      'Datei hierher ziehen oder zum Auswählen klicken';

  @override
  String get textEditorTypeLabel => 'Text- und Quellcodedateien';

  @override
  String get textEditorNewBlank => 'Neue Datei';

  @override
  String get textEditorPasteClipboard => 'Text einfügen';

  @override
  String get textEditorClipboardEmpty =>
      'Zwischenablage ist leer oder enthält keinen Text';

  @override
  String get textEditorRecentFiles => 'Zuletzt geöffnet';

  @override
  String get textEditorNoRecentFiles => 'Noch keine zuletzt geöffneten Dateien';

  @override
  String get textEditorReopenFailed =>
      'Datei konnte nicht erneut geöffnet werden';

  @override
  String get textEditorUnsavedTitle => 'Ungespeicherte Änderungen';

  @override
  String get textEditorUnsavedMessage =>
      'Das Dokument hat ungespeicherte Änderungen. Vor dem Schließen speichern?';

  @override
  String get textEditorDiscardChanges => 'Verwerfen';

  @override
  String get textEditorSaveAndClose => 'Speichern & schließen';

  @override
  String get textEditorFileNameTitle => 'Dateiname';

  @override
  String get textEditorSaveAs => 'Speichern unter…';

  @override
  String textEditorSavedTo(Object path) {
    return 'Gespeichert unter $path';
  }

  @override
  String get textEditorFind => 'Suchen';

  @override
  String get textEditorFindHint => 'Suchen';

  @override
  String get textEditorReplaceHint => 'Ersetzen durch';

  @override
  String get textEditorFindNoResults => 'Keine Treffer';

  @override
  String get textEditorFindSearching => 'Suche…';

  @override
  String get textEditorFindPrevious => 'Vorheriger Treffer';

  @override
  String get textEditorFindNext => 'Nächster Treffer';

  @override
  String get textEditorReplaceOne => 'Ersetzen';

  @override
  String get textEditorReplaceAll => 'Alle ersetzen';

  @override
  String get textEditorFindMode => 'Suchmodus';

  @override
  String get textEditorReplaceMode => 'Ersetzen-Modus';

  @override
  String get textEditorUndo => 'Rückgängig';

  @override
  String get textEditorRedo => 'Wiederholen';

  @override
  String get textEditorFontSmaller => 'Kleinere Schrift';

  @override
  String get textEditorFontLarger => 'Größere Schrift';

  @override
  String get textEditorWordWrap => 'Umbruch';

  @override
  String get textEditorSyntaxHighlight => 'Hervorhebung';

  @override
  String get textEditorUnsavedChanges => 'Ungespeicherte Änderungen';

  @override
  String get textEditorRemote => 'Remote';

  @override
  String get textEditorTools => 'Werkzeuge';

  @override
  String get textEditorSettings => 'Einstellungen';

  @override
  String get textEditorDefaultsSubtitle =>
      'Standardwerte beim Öffnen einer Datei';

  @override
  String get textEditorFontSize => 'Schriftgröße';

  @override
  String get commonCut => 'Ausschneiden';

  @override
  String get commonPaste => 'Einfügen';

  @override
  String get textEditorSelectAll => 'Alles auswählen';

  @override
  String get fileManagerChooseDestination => 'Zielordner wählen';

  @override
  String get fileManagerSelectFolder => 'Ordner auswählen';

  @override
  String get fileManagerMoveTitle => 'Ausgewählte Dateien verschieben?';

  @override
  String fileManagerMoveMessage(int count, String folder) {
    return '$count ausgewählte(s) Element(e) nach \"$folder\" verschieben?';
  }

  @override
  String get fileManagerDateToday => 'Heute';

  @override
  String get fileManagerDateYesterday => 'Gestern';

  @override
  String get fileManagerZoomIn => 'Größere Vorschau';

  @override
  String get fileManagerZoomOut => 'Kleinere Vorschau';

  @override
  String get fileManagerUnknownDate => 'Unbekanntes Datum';

  @override
  String get fileManagerDeselectAll => 'Auswahl aufheben';

  @override
  String get fileManagerImagePreviews => 'Bildvorschau';

  @override
  String get fileManagerCropPreviews => 'Kachel ausfüllen';

  @override
  String get fileManagerCropPreviewsHint =>
      'Vorschau quadratisch beschneiden. Aus zeigt das ganze Bild und braucht weniger Speicher.';
}
