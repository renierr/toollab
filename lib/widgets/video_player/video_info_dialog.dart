import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/data_row.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import 'video_backend.dart';

class VideoInfoDialog extends StatelessWidget {
  final String? title;
  final Uri source;
  final Duration duration;
  final Future<VideoStreamInfo> info;

  const VideoInfoDialog({
    super.key,
    required this.title,
    required this.source,
    required this.duration,
    required this.info,
  });

  static Future<void> show(
    BuildContext context, {
    required String? title,
    required Uri source,
    required Duration duration,
    required Future<VideoStreamInfo> info,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => VideoInfoDialog(
        title: title,
        source: source,
        duration: duration,
        info: info,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final number = NumberFormat.decimalPattern(locale);
    return ResponsiveAlertDialog(
      title: Text(title ?? l10n.videoPlayerInfo),
      scrollable: true,
      content: FutureBuilder<VideoStreamInfo>(
        future: info,
        builder: (context, snapshot) {
          final info = snapshot.data;
          final rows = <(String, String?)>[
            (l10n.videoPlayerInfoSource, _source()),
            (l10n.videoPlayerInfoFileSize, _fileSize(number)),
            (
              l10n.videoPlayerInfoDuration,
              duration > Duration.zero ? _duration(duration) : null,
            ),
            (
              l10n.videoPlayerInfoResolution,
              info?.width != null && info?.height != null
                  ? '${info!.width} × ${info.height}'
                  : null,
            ),
            (l10n.videoPlayerInfoVideoCodec, info?.videoCodec),
            (l10n.videoPlayerInfoDecoder, info?.decoder),
            (
              l10n.videoPlayerInfoFrameRate,
              info?.frameRate != null
                  ? '${NumberFormat('0.##', locale).format(info!.frameRate)} fps'
                  : null,
            ),
            (
              l10n.videoPlayerInfoVideoBitrate,
              _bitrate(info?.videoBitrate, number),
            ),
            (l10n.videoPlayerInfoAudioCodec, info?.audioCodec),
            (
              l10n.videoPlayerInfoSampleRate,
              info?.sampleRate != null
                  ? '${number.format(info!.sampleRate)} Hz'
                  : null,
            ),
            (l10n.videoPlayerInfoChannels, info?.channels?.toString()),
            (
              l10n.videoPlayerInfoAudioBitrate,
              _bitrate(info?.audioBitrate, number),
            ),
          ];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (label, value) in rows)
                if (value != null && value.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: InfoRow(label: label, value: value),
                  ),
              if (snapshot.connectionState != ConnectionState.done)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }

  String _source() => source.isScheme('file')
      ? File.fromUri(source).path
      : '${source.host}${source.path}';

  String? _fileSize(NumberFormat number) {
    if (!source.isScheme('file')) return null;
    try {
      final bytes = File.fromUri(source).lengthSync();
      const units = ['B', 'KB', 'MB', 'GB'];
      var value = bytes.toDouble();
      var unit = 0;
      while (value >= 1024 && unit < units.length - 1) {
        value /= 1024;
        unit++;
      }
      return '${NumberFormat('0.#', number.locale).format(value)} ${units[unit]}';
    } catch (_) {
      return null;
    }
  }

  static String? _bitrate(int? bitsPerSecond, NumberFormat number) {
    if (bitsPerSecond == null || bitsPerSecond <= 0) return null;
    if (bitsPerSecond >= 1000000) {
      return '${NumberFormat('0.#', number.locale).format(bitsPerSecond / 1000000)} Mbit/s';
    }
    return '${number.format((bitsPerSecond / 1000).round())} kbit/s';
  }

  static String _duration(Duration d) {
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return d.inHours > 0
        ? '${d.inHours}:$minutes:$seconds'
        : '${d.inMinutes}:$seconds';
  }
}
