import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

class PaperlessTabBar extends StatelessWidget {
  final TabController controller;
  final int pendingUploads;

  const PaperlessTabBar({
    super.key,
    required this.controller,
    required this.pendingUploads,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TabBar(
      controller: controller,
      tabs: [
        _PaperlessTab(
          icon: Icons.description_outlined,
          label: l10n.paperlessTabDocuments,
        ),
        _PaperlessTab(
          icon: Icons.upload_file_outlined,
          label: l10n.paperlessTabUpload,
          badge: pendingUploads,
        ),
        _PaperlessTab(
          icon: Icons.insights_outlined,
          label: l10n.paperlessTabStats,
        ),
      ],
    );
  }
}

class _PaperlessTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final int badge;

  const _PaperlessTab({
    required this.icon,
    required this.label,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Badge(
            isLabelVisible: badge > 0,
            label: Text('$badge'),
            child: Icon(icon, size: 18),
          ),
          const SizedBox(width: 6),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
