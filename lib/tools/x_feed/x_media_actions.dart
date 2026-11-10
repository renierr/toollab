import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tool_lab/helpers/clipboard_helper.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/app_http_client.dart';
import 'package:tool_lab/widgets/video_player/video_backend.dart';
import 'package:tool_lab/widgets/video_player/video_player_page.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/x_media.dart';
import 'models/x_post.dart';
import 'widgets/x_photo_viewer_page.dart';
import 'x_feed_state.dart';

/// Opening, sharing, saving and copying a post's media and link.
class XMediaActions {
  XMediaActions._();

  static Future<void> openMedia(
    BuildContext context,
    XPost post,
    int index,
  ) async {
    final media = post.allMedia;
    if (index < 0 || index >= media.length) return;
    final item = media[index];
    final video = item.videoUrl;
    if (video == null) {
      final photos = media.where((m) => !m.isPlayable).toList();
      await XPhotoViewerPage.open(
        context,
        post: post,
        photos: photos,
        initialIndex: photos.indexOf(item).clamp(0, photos.length - 1),
      );
      return;
    }
    if (!VideoBackend.isSupported) {
      await openUrl(context, Uri.parse(video));
      return;
    }
    final l10n = AppLocalizations.of(context);
    await VideoPlayerPage.open(
      context,
      source: Uri.parse(video),
      title: '@${post.author.screenName}',
      loop: item.type == XMediaType.gif,
      actions: [
        VideoPlayerAction(
          icon: Icons.share_outlined,
          label: l10n.xFeedShareMedia,
          onPressed: (c) => shareMedia(c, post, item),
        ),
        VideoPlayerAction(
          icon: Icons.download_outlined,
          label: l10n.xFeedSaveMedia,
          onPressed: (c) => saveMedia(c, post, item),
        ),
        VideoPlayerAction(
          icon: Icons.link,
          label: l10n.xFeedCopyMediaLink,
          onPressed: (c) => copyText(c, video, l10n.xFeedLinkCopied),
        ),
      ],
    );
  }

  static String fileName(XPost post, XMedia media) {
    final index = post.allMedia.indexOf(media);
    final suffix = index > 0 ? '_${index + 1}' : '';
    return 'x_${post.author.screenName}_${post.id}$suffix.${media.fileExtension}';
  }

  /// Streams the file to a temp path so a long video never sits in memory.
  static Future<String?> download(
    BuildContext context,
    XPost post,
    XMedia media,
  ) async {
    final scope = context.read<XFeedState>().tempScope;
    final url = media.videoUrl ?? media.originalUrl;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = AppLocalizations.of(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(l10n.xFeedDownloading),
        duration: const Duration(seconds: 30),
      ),
    );
    HttpClient? client;
    try {
      final path = await scope.createFile(fileName(post, media));
      client = await AppHttpClient.createIoClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final sink = File(path).openWrite();
      await response.pipe(sink);
      messenger?.hideCurrentSnackBar();
      return path;
    } catch (e) {
      errorLog('[XMediaActions] Download of $url failed: $e');
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.xFeedDownloadFailed)));
      return null;
    } finally {
      client?.close();
    }
  }

  static Future<void> shareMedia(
    BuildContext context,
    XPost post,
    XMedia media,
  ) async {
    final path = await download(context, post, media);
    if (path == null || !context.mounted) return;
    await FileSaveHelper.showShareChooser(
      context: context,
      path: path,
      mimeType: media.mimeType,
    );
  }

  static Future<void> saveMedia(
    BuildContext context,
    XPost post,
    XMedia media,
  ) async {
    final path = await download(context, post, media);
    if (path == null || !context.mounted) return;
    await FileSaveHelper.saveFileFromPath(
      context: context,
      suggestedName: fileName(post, media),
      sourcePath: path,
    );
  }

  static Future<void> copyImage(
    BuildContext context,
    XPost post,
    XMedia media,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    var copied = false;
    try {
      final client = await AppHttpClient.client;
      final res = await client.get(Uri.parse(media.fullUrl));
      if (res.statusCode == 200) {
        copied = await ClipboardHelper.copyImageBytes(res.bodyBytes);
      }
    } catch (e) {
      errorLog('[XMediaActions] Copying image failed: $e');
    }
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          copied ? l10n.widgetImageCopied : l10n.widgetImageCopyFailed,
        ),
      ),
    );
  }

  static Future<void> sharePostLink(BuildContext context, XPost post) async {
    try {
      await SharePlus.instance.share(ShareParams(uri: Uri.parse(post.url)));
    } catch (e) {
      errorLog('[XMediaActions] Sharing link failed: $e');
      if (context.mounted) {
        await copyText(
          context,
          post.url,
          AppLocalizations.of(context).xFeedLinkCopied,
        );
      }
    }
  }

  static Future<void> copyText(
    BuildContext context,
    String text,
    String message,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await ClipboardHelper.setText(text);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  static Future<void> openUrl(BuildContext context, Uri uri) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (e) {
      debugLog('[XMediaActions] Opening $uri failed: $e');
    }
    messenger?.showSnackBar(SnackBar(content: Text(l10n.xFeedOpenFailed)));
  }
}
