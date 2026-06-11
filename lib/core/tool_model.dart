import 'package:flutter/material.dart';

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
