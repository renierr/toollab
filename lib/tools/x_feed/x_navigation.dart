import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/x_post.dart';
import 'x_feed_state.dart';
import 'widgets/x_post_detail_page.dart';
import 'widgets/x_user_page.dart';

class XNavigation {
  XNavigation._();

  /// An opened post counts as seen, as on x.com.
  static Future<void> openPost(BuildContext context, XPost post) {
    context.read<XFeedState>().markSeen([post.id]);
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => XPostDetailPage(post: post)),
    );
  }

  static Future<void> openUser(BuildContext context, String screenName) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => XUserPage(screenName: screenName),
        ),
      );
}
