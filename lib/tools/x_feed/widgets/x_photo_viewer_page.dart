import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/x_media.dart';
import '../models/x_post.dart';
import '../x_media_actions.dart';

/// Swipe (or left/right on a remote) through a post's photos, pinch to zoom.
class XPhotoViewerPage extends StatefulWidget {
  final XPost post;
  final List<XMedia> photos;
  final int initialIndex;

  const XPhotoViewerPage({
    super.key,
    required this.post,
    required this.photos,
    required this.initialIndex,
  });

  static Future<void> open(
    BuildContext context, {
    required XPost post,
    required List<XMedia> photos,
    required int initialIndex,
  }) {
    if (photos.isEmpty) return Future.value();
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => XPhotoViewerPage(
          post: post,
          photos: photos,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  State<XPhotoViewerPage> createState() => _XPhotoViewerPageState();
}

class _XPhotoViewerPageState extends State<XPhotoViewerPage>
    with DisposeCleanup {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void initState() {
    super.initState();
    onDispose(_pages.dispose);
  }

  void _go(int delta) {
    final target = (_index + delta).clamp(0, widget.photos.length - 1);
    if (target == _index) return;
    unawaited(
      _pages.animateToPage(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      ),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _go(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _go(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      unawaited(Navigator.of(context).maybePop());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final photo = widget.photos[_index];
    return Theme(
      data: ThemeData.dark(useMaterial3: true),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black54,
          title: Text(
            widget.photos.length > 1
                ? '${_index + 1} / ${widget.photos.length}'
                : '@${widget.post.author.screenName}',
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: l10n.xFeedShareMedia,
              onPressed: () =>
                  XMediaActions.shareMedia(context, widget.post, photo),
            ),
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: l10n.xFeedSaveMedia,
              onPressed: () =>
                  XMediaActions.saveMedia(context, widget.post, photo),
            ),
            IconButton(
              icon: const Icon(Icons.copy_all_outlined),
              tooltip: l10n.xFeedCopyImage,
              onPressed: () =>
                  XMediaActions.copyImage(context, widget.post, photo),
            ),
          ],
        ),
        extendBodyBehindAppBar: true,
        body: Focus(
          autofocus: true,
          onKeyEvent: _onKey,
          child: PageView.builder(
            controller: _pages,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => InteractiveViewer(
              maxScale: 6,
              child: Center(
                child: Semantics(
                  label: widget.photos[i].altText,
                  image: true,
                  child: Image.network(
                    widget.photos[i].fullUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                        ? child
                        : const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
