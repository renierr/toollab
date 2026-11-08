import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/news/config.dart';

void main() {
  test('Android launcher and shortcut use the isolated News activity', () {
    final tool = NewsTool.config;
    expect(tool.androidProcessIsolated, isTrue);

    final className = tool.id
        .split('-')
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join();
    const package = 'de.renier.tool_lab';
    final activityName = '$package.${className}Activity';
    final aliasName = '$package.${className}Alias';
    final resource = 'ic_launcher_${tool.id.replaceAll('-', '_')}';
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    String element(String tag, String name) => RegExp(
      '<$tag\\s+android:name="${RegExp.escape(name)}"[\\s\\S]*?</$tag>',
    ).firstMatch(manifest)!.group(0)!;

    final activity = element('activity', activityName);
    expect(activity, contains('android:process=":${tool.id}"'));
    expect(activity, contains('android:taskAffinity="$package.${tool.id}"'));
    final alias = element('activity-alias', aliasName);
    expect(alias, contains('android:targetActivity="$activityName"'));
    expect(alias, contains('android:icon="@mipmap/$resource"'));
    expect(alias, contains('android.intent.category.LAUNCHER'));

    expect(File('assets/logo/standalone/${tool.id}.png').existsSync(), isTrue);
    for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      expect(
        File(
          'android/app/src/main/res/mipmap-$density/$resource.png',
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          'android/app/src/main/res/drawable-$density/${resource}_foreground.png',
        ).existsSync(),
        isTrue,
      );
    }
    expect(
      File(
        'android/app/src/main/res/mipmap-anydpi-v26/$resource.xml',
      ).readAsStringSync(),
      contains('@drawable/${resource}_foreground'),
    );
    const kotlin = 'android/app/src/main/kotlin/de/renier/tool_lab';
    expect(
      File('$kotlin/MainActivity.kt').readAsStringSync(),
      contains('class ${className}Activity : MainActivity()'),
    );
    expect(
      File('$kotlin/ShortcutHelper.kt').readAsStringSync(),
      contains('"${tool.id}"'),
    );
  });
}
