import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'sketch_board_page.dart';
import 'sketch_board_state.dart';
import 'sketch_board_sync_delegate.dart';

class SketchBoardTool {
  SketchBoardTool._();

  static ToolModel get config => ToolModel(
    id: 'sketch-board',
    name: 'Sketch Board',
    description:
        'Infinite-canvas whiteboard with freehand, shapes, text, export and saved drawings',
    icon: Icons.design_services_outlined,
    route: '/sketch-board',
    accentColor: AppTheme.accentPurple,
    sectionId: 'utilities',
    nameL10n: (l10n) => l10n.toolNameSketchBoard,
    descriptionL10n: (l10n) => l10n.toolDescSketchBoard,
    fileExtensions: ['png'],
    createPage: (_) => const SketchBoardPage(),
    syncDelegateFactory: SketchBoardSyncDelegate.new,
    stateProviders: () => [
      ChangeNotifierProvider<SketchBoardState>(
        create: (_) => SketchBoardState(),
      ),
    ],
  );
}
