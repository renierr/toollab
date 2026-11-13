import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/sharing_service.dart';
import 'package:tool_lab/services/translation/translation_service.dart';
import 'package:tool_lab/widgets/responsive_layout.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'config.dart';
import 'translator_state.dart';
import 'widgets/translator_input_card.dart';
import 'widgets/translator_language_bar.dart';
import 'widgets/translator_models_sheet.dart';
import 'widgets/translator_output_card.dart';
import 'widgets/translator_unsupported_view.dart';

class TranslatorPage extends StatefulWidget {
  final SharedData? sharedData;

  const TranslatorPage({super.key, this.sharedData});

  @override
  State<TranslatorPage> createState() => _TranslatorPageState();
}

class _TranslatorPageState extends State<TranslatorPage> with DisposeCleanup {
  static const double _minPanelHeight = 200;

  late final TranslatorState _state;

  @override
  void initState() {
    super.initState();
    _state = context.read<TranslatorState>();
    if (!TranslationService.isSupported) return;
    unawaited(
      _state.init().then((_) {
        final shared = widget.sharedData;
        if (shared != null) return _state.loadSharedData(shared);
      }),
    );
    final sharing = SharingService.instance.onSharedData.listen(
      _state.loadSharedData,
    );
    onDispose(sharing.cancel);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _state.uiLanguageCode = Localizations.localeOf(context).languageCode;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final supported = TranslationService.isSupported;
    return ToolLayout(
      title: TranslatorTool.config.localizedName(l10n),
      fullscreen: false,
      actions: [
        if (supported)
          IconButton(
            icon: const Icon(Icons.download_for_offline_outlined),
            tooltip: l10n.translatorModelsTitle,
            onPressed: () => TranslatorModelsSheet.show(context),
          ),
      ],
      child: supported
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: _TranslatorBody(minPanelHeight: _minPanelHeight),
            )
          : const TranslatorUnsupportedView(),
    );
  }
}

class _TranslatorBody extends StatelessWidget {
  final double minPanelHeight;

  const _TranslatorBody({required this.minPanelHeight});

  @override
  Widget build(BuildContext context) {
    // Branches on width only, so the keyboard opening keeps the input's focus.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.canSplit) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TranslatorLanguageBar(),
              SizedBox(height: 12),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: TranslatorInputCard()),
                    SizedBox(width: 12),
                    Expanded(child: TranslatorOutputCard()),
                  ],
                ),
              ),
            ],
          );
        }
        final panelHeight = ((constraints.maxHeight - 90) / 2).clamp(
          minPanelHeight,
          double.infinity,
        );
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TranslatorLanguageBar(),
              const SizedBox(height: 12),
              SizedBox(height: panelHeight, child: const TranslatorInputCard()),
              const SizedBox(height: 12),
              SizedBox(
                height: panelHeight,
                child: const TranslatorOutputCard(),
              ),
            ],
          ),
        );
      },
    );
  }
}
