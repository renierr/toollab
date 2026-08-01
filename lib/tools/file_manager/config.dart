import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/tools/file_manager/file_manager_page.dart';
import 'package:tool_lab/tools/file_manager/file_manager_state.dart';

class FileManagerTool {
  FileManagerTool._();

  static ToolModel get config => ToolModel(
    id: 'file-manager',
    name: 'File Manager',
    description: 'Browse local files and FTP or SMB network shares',
    icon: Icons.folder_copy_outlined,
    route: '/file-manager',
    accentColor: AppTheme.accentTeal,
    sectionId: 'utilities',
    nameL10n: (l10n) => l10n.toolNameFileManager,
    descriptionL10n: (l10n) => l10n.toolDescFileManager,
    stateProviders: () => [
      ChangeNotifierProvider<FileManagerState>(
        create: (_) => FileManagerState(),
      ),
    ],
    createPage: (_) => const FileManagerPage(),
  );
}
