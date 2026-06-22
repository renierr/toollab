import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart' show XFile;
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/sharing_service.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'package:tool_lab/widgets/file_drop_zone.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';

import 'config.dart';
import 'doc_format.dart';
import 'file_converter_state.dart';
import 'widgets/conversion_panel.dart';

class FileConverterPage extends StatefulWidget {
  final SharedFile? sharedFile;

  const FileConverterPage({super.key, this.sharedFile});

  @override
  State<FileConverterPage> createState() => _FileConverterPageState();
}

class _FileConverterPageState extends State<FileConverterPage>
    with DisposeCleanup {
  late final TempFileScope _scope;

  @override
  void initState() {
    super.initState();
    _scope = TempFileManager.createScope();
    onDispose(() => _scope.cleanTracked());

    final state = context.read<FileConverterState>();
    onDispose(state.clear);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.sharedFile != null) {
        _loadSharedFile(widget.sharedFile!);
      }
    });

    final sharingSub = SharingService.instance.onSharedFile.listen(
      _loadSharedFile,
    );
    onDispose(sharingSub.cancel);
  }

  void _loadSharedFile(SharedFile file) {
    context.read<FileConverterState>().loadFile(file.path, file.name);
  }

  void _onFileSelected(XFile file) {
    context.read<FileConverterState>().loadFile(file.path, file.name);
  }

  void _onClose() {
    final state = context.read<FileConverterState>();
    final navigator = Navigator.of(context);
    state.clear();
    if (widget.sharedFile != null && navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<FileConverterState>();

    if (state.inputPath == null) {
      return ToolLayout(
        title: FileConverterTool.config.localizedName(l10n),
        fullscreen: false,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: FileDropZone(
            onFileSelected: _onFileSelected,
            allowedExtensions: DocFormat.allExtensions,
            typeLabel: l10n.fileConverterTypeLabel,
            accentColor: FileConverterTool.config.accentColor,
            title: l10n.fileConverterOpenTitle,
            subtitle: l10n.fileConverterDropSubtitle,
            icon: Icons.sync_alt,
          ),
        ),
      );
    }

    return ToolLayout(
      title: FileConverterTool.config.localizedName(l10n),
      fullscreen: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.commonClose,
          onPressed: _onClose,
        ),
      ],
      child: ConversionPanel(scope: _scope),
    );
  }
}
