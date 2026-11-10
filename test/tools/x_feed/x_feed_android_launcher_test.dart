import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/x_feed/config.dart';

void main() {
  test('Android launcher and shortcut use the isolated X Feed activity', () {
    final tool = XFeedTool.config;
    expect(tool.androidProcessIsolated, isTrue);

    const package = 'de.renier.tool_lab';
    const activityName = '$package.XFeedActivity';
    final resource = 'ic_launcher_${tool.id.replaceAll('-', '_')}';
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    String element(String tag, String name) => RegExp(
      '<$tag\\s+android:name="${RegExp.escape(name)}"[\\s\\S]*?</$tag>',
    ).firstMatch(manifest)!.group(0)!;

    final activity = element('activity', activityName);
    expect(activity, contains('android:process=":x_feed"'));
    final alias = element('activity-alias', '$package.XFeedAlias');
    expect(alias, contains('android:targetActivity="$activityName"'));
    expect(alias, contains('android:icon="@mipmap/$resource"'));

    expect(File('assets/logo/standalone/${tool.id}.png').existsSync(), isTrue);
    for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      expect(
        File(
          'android/app/src/main/res/mipmap-$density/$resource.png',
        ).existsSync(),
        isTrue,
      );
    }

    final shortcuts = File(
      'android/app/src/main/kotlin/de/renier/tool_lab/ShortcutHelper.kt',
    ).readAsStringSync();
    expect(shortcuts, contains('"${tool.id}"'));
    final activities = File(
      'android/app/src/main/kotlin/de/renier/tool_lab/MainActivity.kt',
    ).readAsStringSync();
    expect(activities, contains('class XFeedActivity : MainActivity()'));
  });
}
