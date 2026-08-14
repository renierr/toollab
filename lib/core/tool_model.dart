import 'package:flutter/material.dart';
import 'package:provider/single_child_widget.dart';

import 'shared_file.dart';
export 'shared_file.dart';
import 'background_task.dart';
import '../services/sync_service.dart';
import '../l10n/app_localizations.dart';

/// Resolves a localized string from the active [AppLocalizations].
/// Lives in `config.dart` per-tool so localization stays self-contained —
/// takes [AppLocalizations], never a `BuildContext`.
typedef ToolL10nResolver = String Function(AppLocalizations l10n);

class ShareTargetConfig {
  final List<String> accept;

  const ShareTargetConfig({required this.accept});
}

class ToolModel {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final String route;
  final Color accentColor;
  final String sectionId;
  final ShareTargetConfig? shareTarget;
  final List<String> fileExtensions;
  final Widget Function(SharedData? sharedData) createPage;
  final SyncDelegate Function()? syncDelegateFactory;
  final List<SingleChildWidget> Function()? stateProviders;

  /// Work the tool wants run on a schedule while the app is closed. Collected by
  /// `BackgroundTaskService`, which owns the scheduling and the execution.
  final List<BackgroundTask> Function()? backgroundTasks;

  /// Optional localized overrides. When set, [localizedName] /
  /// [localizedDescription] use them; otherwise the raw [name] /
  /// [description] are returned. Declared inline in each tool's `config.dart`.
  final ToolL10nResolver? nameL10n;
  final ToolL10nResolver? descriptionL10n;

  final bool androidProcessIsolated;

  ToolModel({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.route,
    required this.accentColor,
    required this.sectionId,
    this.shareTarget,
    this.fileExtensions = const [],
    this.syncDelegateFactory,
    this.stateProviders,
    this.backgroundTasks,
    this.nameL10n,
    this.descriptionL10n,
    this.androidProcessIsolated = false,
    Widget Function(SharedData? sharedData)? createPage,
  }) : createPage = createPage ?? ((_) => const SizedBox.shrink());

  String localizedName(AppLocalizations l10n) => nameL10n?.call(l10n) ?? name;

  String localizedDescription(AppLocalizations l10n) =>
      descriptionL10n?.call(l10n) ?? description;
}

class ToolSection {
  final String id;
  final String title;
  final IconData icon;
  final String? description;
  final ToolL10nResolver? titleL10n;

  const ToolSection({
    required this.id,
    required this.title,
    required this.icon,
    this.description,
    this.titleL10n,
  });

  String localizedTitle(AppLocalizations l10n) =>
      titleL10n?.call(l10n) ?? title;
}
