import 'package:flutter/material.dart';

import 'models/x_post.dart';
import 'widgets/x_post_detail_page.dart';
import 'widgets/x_user_page.dart';

class XNavigation {
  XNavigation._();

  static Future<void> openPost(BuildContext context, XPost post) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => XPostDetailPage(post: post)),
      );

  static Future<void> openUser(BuildContext context, String screenName) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => XUserPage(screenName: screenName),
        ),
      );
}
