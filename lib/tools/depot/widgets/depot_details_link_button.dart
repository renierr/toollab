import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../depot_details_link.dart';
import '../depot_state.dart';
import '../models/depot_holding.dart';

/// Opens the holding on the details site configured in the depot settings.
class DepotDetailsLinkButton extends StatelessWidget {
  final DepotHolding holding;
  final DepotDetailsLinkKind kind;

  const DepotDetailsLinkButton({
    super.key,
    required this.holding,
    required this.kind,
  });

  Future<void> _open(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).depotHoldingDetailsOpenFailed;
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      errorLog('[DepotDetailsLinkButton] Opening $uri failed: $e');
    }
    if (!opened) messenger.showSnackBar(SnackBar(content: Text(failed)));
  }

  @override
  Widget build(BuildContext context) {
    final template = context.select<DepotState, String>(
      (state) => state.detailsUrlTemplate(kind),
    );
    final uri = DepotDetailsLink.build(template, holding);
    if (uri == null) return const SizedBox.shrink();
    return TextButton.icon(
      onPressed: () => _open(context, uri),
      icon: const Icon(Icons.open_in_new_outlined),
      label: Text(AppLocalizations.of(context).depotHoldingOpenDetails),
    );
  }
}
