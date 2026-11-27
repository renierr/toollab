import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openTrimzUrl(BuildContext context, Uri uri) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (e) {
    debugLog('[Trimz] Opening $uri failed: $e');
  }
  messenger?.showSnackBar(SnackBar(content: Text(l10n.trimzOpenFailed)));
}
