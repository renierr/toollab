import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/totp_auth/config.dart';

void main() {
  test('Android launcher and shortcut use the isolated authenticator', () {
    final tool = TotpAuthTool.config;
    expect(tool.androidProcessIsolated, isTrue);
    final parts = tool.id.split('-');
    final className = parts
        .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
        .join();
    final package = 'de.renier.tool_lab';
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
    expect(activity, contains('android:process=":totp_auth"'));
    expect(activity, contains('android:taskAffinity="$package.totp_auth"'));
    final alias = element('activity-alias', aliasName);
    expect(alias, contains('android:targetActivity="$activityName"'));
    expect(alias, contains('android:icon="@mipmap/$resource"'));
    expect(alias, contains('android.intent.category.LAUNCHER'));

    final res = Directory('android/app/src/main/res');
    expect(
      File('${res.path}/mipmap-anydpi-v26/$resource.xml').existsSync(),
      isTrue,
    );
    for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      expect(
        File('${res.path}/mipmap-$density/$resource.png').existsSync(),
        isTrue,
      );
      expect(
        File(
          '${res.path}/drawable-$density/${resource}_foreground.png',
        ).existsSync(),
        isTrue,
      );
    }
    final kotlin = 'android/app/src/main/kotlin/de/renier/tool_lab';
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
