# Local rhttp patch

This is a vendored copy of `rhttp` 0.18.0 from pub.dev.

Android Gradle can report the compile SDK with a suffix: a minor API level
(`android-37.0`) or an SDK extension (`android-36-ext19`). rhttp's CargoKit
Gradle script assumed the value was always `android-<number>` and failed while
parsing the suffix.

`cargokit/gradle/plugin.gradle` is patched to extract only the numeric API
level before passing it to Cargo. The rhttp Dart and Rust networking code is
otherwise unchanged.

`rust/src/api/init.rs` also includes upstream commit `2770724`, which initializes
Android's process-global native TLS context once when multiple Flutter engines
attach.

Remove this vendor copy and restore the hosted dependency once upstream rhttp
parses compile SDK strings with a minor level or extension suffix.
