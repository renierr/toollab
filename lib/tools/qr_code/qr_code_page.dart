import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'config.dart';
import 'widgets/qr_create_tab.dart';
import 'widgets/qr_scan_tab.dart';

class QrCodePage extends StatefulWidget {
  const QrCodePage({super.key});

  @override
  State<QrCodePage> createState() => _QrCodePageState();
}

class _QrCodePageState extends State<QrCodePage>
    with DisposeCleanup, SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    onDispose(() => _tabController.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = QrCodeTool.config.accentColor;

    return ToolLayout(
      title: QrCodeTool.config.localizedName(l10n),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            indicatorColor: accent,
            labelColor: accent,
            tabs: [
              Tab(
                icon: const Icon(Icons.qr_code_scanner),
                text: l10n.qrTabScan,
              ),
              Tab(icon: const Icon(Icons.qr_code_2), text: l10n.qrTabCreate),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [QrScanTab(), QrCreateTab()],
            ),
          ),
        ],
      ),
    );
  }
}
