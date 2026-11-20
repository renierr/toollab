// A hang should fail fast instead of after the 10-minute default.
@Timeout(Duration(minutes: 1))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/weather/config.dart';
import 'package:tool_lab/tools/weather/models/weather_condition.dart';
import 'package:tool_lab/tools/weather/weather_publisher.dart';

void main() {
  const package = 'de.renier.tool_lab';
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();

  test('Android launcher and shortcut use the isolated Weather activity', () {
    final tool = WeatherTool.config;
    expect(tool.androidProcessIsolated, isTrue);
    const activityName = '$package.WeatherActivity';
    const aliasName = '$package.WeatherAlias';
    final resource = 'ic_launcher_${tool.id}';
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
    }
    const kotlin = 'android/app/src/main/kotlin/de/renier/tool_lab';
    expect(
      File('$kotlin/MainActivity.kt').readAsStringSync(),
      contains('class WeatherActivity : MainActivity()'),
    );
    expect(
      File('$kotlin/ShortcutHelper.kt').readAsStringSync(),
      contains('"${tool.id}"'),
    );
  });

  test('Weather native components run in the Weather process', () {
    for (final name in [
      'WeatherWidgetConfigActivity',
      'WeatherReceiver',
      'WeatherWidgetProvider',
    ]) {
      final element = RegExp(
        'android:name="de\\.renier\\.tool_lab\\.weather\\.$name"[^>]*>',
      ).firstMatch(manifest);
      expect(element, isNotNull, reason: name);
      expect(element!.group(0), contains('android:process=":weather"'));
    }
    expect(manifest, contains(WeatherPublisher.actionRefresh));
    expect(manifest, contains(WeatherPublisher.actionNotify));
  });

  test('every condition has a widget icon for day and night', () {
    // Referenced directly, or release resource shrinking drops the icon.
    final icons = File(
      'android/app/src/main/kotlin/de/renier/tool_lab/weather/WeatherIcons.kt',
    ).readAsStringSync();
    for (final condition in WeatherCondition.values) {
      for (final isDay in [true, false]) {
        final key = WeatherPublisher.iconKey(condition, isDay);
        expect(
          File(
            'android/app/src/main/res/drawable-nodpi/weather_icon_$key.png',
          ).existsSync(),
          isTrue,
          reason: key,
        );
        expect(
          icons,
          contains('"$key" to R.drawable.weather_icon_$key'),
          reason: key,
        );
      }
    }
  });
}
