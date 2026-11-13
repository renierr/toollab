import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/sharing_service.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'config.dart';
import 'string_transformer_state.dart';
import 'widgets/string_transformer_input.dart';
import 'widgets/string_transformer_output.dart';
import 'widgets/string_transformer_toolbar.dart';
import 'package:tool_lab/widgets/responsive_layout.dart';

class StringTransformerPage extends StatefulWidget {
  final SharedData? sharedData;

  const StringTransformerPage({super.key, this.sharedData});

  @override
  State<StringTransformerPage> createState() => _StringTransformerPageState();
}

class _StringTransformerPageState extends State<StringTransformerPage>
    with DisposeCleanup {
  static const double _minPanelHeight = 220;

  late final StringTransformerState _state;

  @override
  void initState() {
    super.initState();
    _state = context.read<StringTransformerState>();
    onDispose(() {
      _state.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.sharedData != null) {
        _state.loadSharedData(widget.sharedData!);
      }
    });

    final sharingSub = SharingService.instance.onSharedData.listen((data) {
      _state.loadSharedData(data);
    });
    onDispose(sharingSub.cancel);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _state.uiLanguageCode = Localizations.localeOf(context).languageCode;
  }

  void _onClose() {
    _state.clear();
    if (widget.sharedData != null) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // One scrollable tree in both states, so the keyboard opening never
    // rebuilds the fields and drops focus.
    final content = LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.canSplit) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StringTransformerToolbar(),
              SizedBox(height: 12),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: StringTransformerInput()),
                    SizedBox(width: 12),
                    Expanded(child: StringTransformerOutput()),
                  ],
                ),
              ),
            ],
          );
        }
        final panelHeight = ((constraints.maxHeight - 100) / 2).clamp(
          _minPanelHeight,
          double.infinity,
        );
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StringTransformerToolbar(),
              const SizedBox(height: 12),
              SizedBox(
                height: panelHeight,
                child: const StringTransformerInput(),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: panelHeight,
                child: const StringTransformerOutput(),
              ),
            ],
          ),
        );
      },
    );

    return ToolLayout(
      title: StringTransformerTool.config.localizedName(l10n),
      fullscreen: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.commonClose,
          onPressed: _onClose,
        ),
      ],
      child: Padding(padding: const EdgeInsets.all(16.0), child: content),
    );
  }
}
