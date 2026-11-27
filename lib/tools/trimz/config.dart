import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'trimz_page.dart';
import 'trimz_state.dart';

class TrimzTool {
  TrimzTool._();

  static ToolModel get config => ToolModel(
    id: 'trimz',
    name: 'Trimz',
    description: 'Browse and watch AI-made series from trimz.tv',
    icon: Icons.movie_filter_outlined,
    route: '/trimz',
    accentColor: AppTheme.accentRed,
    sectionId: 'utilities',
    nameL10n: (l10n) => l10n.toolNameTrimz,
    descriptionL10n: (l10n) => l10n.toolDescTrimz,
    createPage: (_) => const TrimzPage(),
    onClose: (context) => context.read<TrimzState>().release(),
    stateProviders: () => [
      ChangeNotifierProvider<TrimzState>(create: (_) => TrimzState()),
    ],
  );
}
