import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/x_feed/api/x_api.dart';
import 'package:tool_lab/tools/x_feed/models/x_post.dart';
import 'package:tool_lab/tools/x_feed/models/x_user.dart';
import 'package:tool_lab/tools/x_feed/x_timeline_controller.dart';

XPost _post(String id) => XPost(
  id: id,
  author: const XUser(id: 'u', name: 'Someone', screenName: 'someone'),
  text: id,
  links: const [],
  createdAt: null,
  media: const [],
  engagement: const XEngagement(
    liked: false,
    reposted: false,
    bookmarked: false,
    likes: 0,
    reposts: 0,
  ),
);

XTimelinePage _page(List<String> ids, String cursor) => XTimelinePage(
  posts: [for (final id in ids) _post(id)],
  bottomCursor: cursor,
);

void main() {
  test('a refresh during loadMore does not block later pages', () async {
    final pending = Completer<XTimelinePage>();
    var calls = 0;
    final controller = XTimelineController((cursor) async {
      calls++;
      if (cursor == null) return _page(['a'], 'c1');
      if (calls == 2) return pending.future;
      return _page(['b'], 'c2');
    });
    await controller.refresh();
    final stale = controller.loadMore();
    await controller.refresh();
    pending.complete(_page(['x'], 'cx'));
    await stale;
    expect(controller.isLoadingMore, isFalse);
    await controller.loadMore();
    expect(controller.posts.map((p) => p.id), ['a', 'b']);
  });

  test('a non-API failure in loadMore becomes an error', () async {
    final controller = XTimelineController((cursor) async {
      if (cursor == null) return _page(['a'], 'c1');
      throw TypeError();
    });
    await controller.refresh();
    await controller.loadMore();
    expect(controller.error?.kind, XApiErrorKind.server);
    expect(controller.isLoadingMore, isFalse);
  });
}
