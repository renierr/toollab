import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/widgets/readable_width.dart';

import '../x_feed_state.dart';
import '../x_timeline_controller.dart';
import 'x_error_view.dart';
import 'x_post_card.dart';

class XTimelineView extends StatefulWidget {
  final XTimelineController controller;

  /// Home tabs honour the hide-reposts / hide-replies settings.
  final bool applyFilters;
  final Widget? header;
  final String? focalPostId;
  final String? emptyMessage;

  const XTimelineView({
    super.key,
    required this.controller,
    this.applyFilters = false,
    this.header,
    this.focalPostId,
    this.emptyMessage,
  });

  @override
  State<XTimelineView> createState() => _XTimelineViewState();
}

class _XTimelineViewState extends State<XTimelineView> with DisposeCleanup {
  static const double _maxWidth = 680;
  static const int _prefetchDistance = 5;

  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    onDispose(_scroll.dispose);
    unawaited(widget.controller.ensureLoaded());
  }

  @override
  void didUpdateWidget(covariant XTimelineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      unawaited(widget.controller.ensureLoaded());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tvMode = context.select<AppState, bool>((s) => s.tvMode);
    final state = context.watch<XFeedState>();
    final controller = widget.controller;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final posts = widget.applyFilters
            ? state.filtered(controller.posts)
            : controller.posts;
        final header = widget.header;
        final error = controller.error;

        if (posts.isEmpty) {
          final Widget placeholder;
          if (controller.isLoading || !controller.isLoaded && error == null) {
            placeholder = const Center(child: CircularProgressIndicator());
          } else if (error != null) {
            placeholder = Center(
              child: XErrorView(error: error, onRetry: controller.refresh),
            );
          } else {
            placeholder = Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  widget.emptyMessage ?? l10n.xFeedEmpty,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (header == null) return placeholder;
          return ListView(
            children: [
              ReadableWidth(maxWidth: _maxWidth, child: header),
              SizedBox(height: 240, child: placeholder),
            ],
          );
        }

        final offset = header == null ? 0 : 1;
        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: ReadableScrollPadding(
            maxWidth: _maxWidth,
            builder: (context, padding) => ListView.builder(
              controller: _scroll,
              padding: padding,
              itemCount: posts.length + offset + 1,
              itemBuilder: (context, index) {
                if (index < offset) return header;
                final i = index - offset;
                if (i == posts.length) {
                  return _Footer(controller: controller);
                }
                if (i >= posts.length - _prefetchDistance && error == null) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => unawaited(controller.loadMore()),
                  );
                }
                final post = posts[i];
                return DecoratedBox(
                  key: ValueKey(post.id),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: XPostCard(
                    post: post,
                    tvMode: tvMode,
                    autofocus: tvMode && i == 0,
                    focal: post.id == widget.focalPostId,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _Footer extends StatelessWidget {
  final XTimelineController controller;

  const _Footer({required this.controller});

  @override
  Widget build(BuildContext context) {
    final error = controller.error;
    if (error != null) {
      return XErrorView(
        error: error,
        onRetry: controller.loadMore,
        compact: true,
      );
    }
    if (controller.endReached) return const SizedBox(height: 48);
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
