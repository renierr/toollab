# Local rhttp patch

This is a vendored copy of `rhttp` 0.18.0 from pub.dev.

The app needs Android SDK extension level 19 for Health Connect. That makes
Android Gradle report the compile SDK as `android-36-ext19`. rhttp's CargoKit
Gradle script assumed the value was always `android-<number>` and failed while
parsing the extension suffix.

`cargokit/gradle/plugin.gradle` is patched to extract only the numeric API
level before passing it to Cargo. The rhttp Dart and Rust networking code is
otherwise unchanged.

Remove this vendor copy and restore the hosted dependency once upstream rhttp
supports Android SDK extension version strings.
