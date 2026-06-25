import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_layout.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'config.dart';
import 'widgets/all_units_list.dart';
import 'widgets/category_selector.dart';
import 'widgets/conversion_card.dart';

import 'package:tool_lab/core/shared_file.dart';
import 'package:provider/provider.dart';
import 'unit_converter_state.dart';

class UnitConverterPage extends StatefulWidget {
  final SharedData? sharedData;

  const UnitConverterPage({super.key, this.sharedData});

  @override
  State<UnitConverterPage> createState() => _UnitConverterPageState();
}

class _UnitConverterPageState extends State<UnitConverterPage>
    with DisposeCleanup {
  @override
  void initState() {
    super.initState();
    if (widget.sharedData?.text != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<UnitConverterState>().setInputProgrammatic(
            widget.sharedData!.text!,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = UnitConverterTool.config.accentColor;

    return ToolLayout(
      title: l10n.toolNameUnitConverter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: CategorySelector(accent: accent),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              child: ResponsiveLayout(
                mobile: Column(
                  children: [
                    ConversionCard(accent: accent),
                    const SizedBox(height: 16),
                    AllUnitsList(accent: accent),
                  ],
                ),
                desktop: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: ConversionCard(accent: accent)),
                    const SizedBox(width: 16),
                    Expanded(child: AllUnitsList(accent: accent)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
