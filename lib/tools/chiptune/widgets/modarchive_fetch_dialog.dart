import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../chiptune_colors.dart';
import '../modarchive_service.dart';
import 'chiptune_modarchive_info.dart';

/// Modal that fetches a random tune from The Mod Archive, shows its details
/// and source credits, and returns the [ModArchiveTune] when the user plays it.
///
/// When [autoPlay] is true, the modal only shows fetch progress and returns
/// the tune as soon as it loads (no details or play/shuffle buttons) — used
/// for skip-next where playback should resume immediately.
///
/// Returns the chosen tune via `Navigator.pop`, or `null` if cancelled.
class ModArchiveFetchDialog extends StatefulWidget {
  final ModArchiveService service;
  final bool autoPlay;

  const ModArchiveFetchDialog({
    super.key,
    required this.service,
    this.autoPlay = false,
  });

  static Future<ModArchiveTune?> show(
    BuildContext context,
    ModArchiveService service, {
    bool autoPlay = false,
  }) {
    return showDialog<ModArchiveTune>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          ModArchiveFetchDialog(service: service, autoPlay: autoPlay),
    );
  }

  @override
  State<ModArchiveFetchDialog> createState() => _ModArchiveFetchDialogState();
}

class _ModArchiveFetchDialogState extends State<ModArchiveFetchDialog> {
  ModArchiveTune? _tune;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
      _tune = null;
    });
    try {
      final tune = await widget.service.fetchRandom();
      if (!mounted) return;
      if (widget.autoPlay) {
        Navigator.of(context).pop(tune);
        return;
      }
      setState(() {
        _tune = tune;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ResponsiveAlertDialog(
      icon: const Icon(Icons.casino_outlined, color: ChiptuneColors.accent),
      title: Text(l10n.chipRandomTitle),
      scrollable: true,
      content: _buildContent(l10n),
      actions: _buildActions(l10n),
    );
  }

  Widget _buildContent(AppLocalizations l10n) {
    if (_loading) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: CircularProgressIndicator(color: ChiptuneColors.accent),
          ),
          Text(l10n.chipRandomFetching, textAlign: TextAlign.center),
        ],
      );
    }
    if (_error != null) {
      return Text(l10n.chipRandomFetchFailed(_error!));
    }
    return ChiptuneModArchiveInfo(tune: _tune!, showCredits: true);
  }

  List<Widget> _buildActions(AppLocalizations l10n) {
    if (_loading) {
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
      ];
    }
    if (_error != null) {
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _fetch, child: Text(l10n.chipRandomRetry)),
      ];
    }
    return [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(l10n.commonCancel),
      ),
      TextButton(onPressed: _fetch, child: Text(l10n.chipRandomShuffleAgain)),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_tune),
        child: Text(l10n.chipPlayTooltip),
      ),
    ];
  }
}
