import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/info_card.dart';

class TranslatorUnsupportedView extends StatelessWidget {
  const TranslatorUnsupportedView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: InfoCard(
            icon: Icons.translate,
            title: l10n.toolNameTranslator,
            child: Text(l10n.translatorUnsupportedPlatform),
          ),
        ),
      ),
    );
  }
}
