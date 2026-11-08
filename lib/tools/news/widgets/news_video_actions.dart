import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/native_media_player.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class NewsVideoActions extends StatelessWidget {
  final List<String> videoUrls;

  const NewsVideoActions({super.key, required this.videoUrls});

  Future<void> _play(BuildContext context, String url) async {
    final l10n = AppLocalizations.of(context);
    try {
      if (NativeMediaPlayer.isSupported) {
        await NativeMediaPlayer.open(path: url, mimeType: 'video/*');
      } else if (!await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError('No video handler');
      }
    } catch (e) {
      errorLog('[NewsVideo] Failed to open video: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.newsVideoFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var index = 0; index < videoUrls.length; index++)
          FilledButton.tonalIcon(
            onPressed: () => _play(context, videoUrls[index]),
            icon: const Icon(Icons.play_arrow),
            label: Text(
              videoUrls.length == 1
                  ? l10n.newsPlayVideo
                  : l10n.newsPlayVideoNumber(index + 1),
            ),
          ),
      ],
    );
  }
}
