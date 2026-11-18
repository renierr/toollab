# Local nfc_manager patch

This is a vendored copy of `nfc_manager` 4.4.0 from pub.dev, Android only.

`android/build.gradle.kts` no longer applies the Kotlin Gradle Plugin (KGP) or
declares its own buildscript. Upstream applies KGP unconditionally, which AGP 9
rejects once the app switches to built-in Kotlin, and Flutter warns that future
versions will fail to build with it. Without KGP in the file, AGP's built-in
Kotlin compiles the plugin, and while the app still sets
`android.builtInKotlin=false` Flutter's Gradle plugin applies KGP itself.

Also dropped: the iOS implementation, the example, the Dart and Kotlin unit
tests, the pigeon sources and the dev dependencies. `lib/` and
`android/src/main` are unchanged.

Remove this copy and restore the hosted dependency once upstream stops
applying KGP itself.
