import 'package:flutter/material.dart';
import 'package:provider/single_child_widget.dart';

import 'shared_file.dart';
import '../services/sync_service.dart';

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
  final Widget Function(SharedFile? sharedFile) createPage;
  final SyncDelegate Function()? syncDelegateFactory;
  final List<SingleChildWidget> Function()? stateProviders;

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
    Widget Function(SharedFile? sharedFile)? createPage,
  }) : createPage = createPage ?? ((_) => const SizedBox.shrink());
}

class ToolSection {
  final String id;
  final String title;
  final IconData icon;
  final String? description;

  const ToolSection({
    required this.id,
    required this.title,
    required this.icon,
    this.description,
  });
}
