# Local desktop_drop patch

This is a vendored copy of `desktop_drop` 0.8.4 from pub.dev. Only
`android/build.gradle` differs: it follows Flutter 3.50's plugin template, with
the Kotlin Gradle Plugin (KGP) on the buildscript classpath but never applied.
AGP 9 compiles the plugin's Kotlin itself; while the app sets
`android.builtInKotlin=false`, Flutter's Gradle plugin applies KGP for us.

## Why not upstream 0.9.x

0.9.2 fixes Kotlin upstream (KGP only when built-in Kotlin is off), so the
fork could go. It cannot be used yet: 0.9 needs `cross_file` ^0.4, while
`file_selector`, `image_picker`, `camera`, `share_plus` and `file_picker` all
still need `cross_file` ^0.3 (checked 2026-11-18). Re-check those constraints on
each update.

## Moving to 0.9

0.9 replaces `onDragDone` with an async `onDrop` and delivers typed items
(`DropFileItem`, `DropDirectoryItem`, `DropStringItem`). See upstream's
"Migrating from 0.8.x to 0.9.0".

The plugin deletes its temporary transfer files when `onDrop` returns. This
only affects provider-backed drops without a local path (Android content URIs,
Windows virtual files, macOS promised files); dragged local files keep their
original path. Our drop zones pass paths on and read them later, and Images to
PDF deliberately references dropped files instead of copying them. Keep that:

- Pass `item.localPath` through unchanged whenever it is set. No copy.
- Make the drop callbacks async (`FileDropZone` and its 23 callers, the File
  Manager, Images to PDF and Notes drop zones) and await the consumer inside
  `onDrop`, so a provider-backed file is read or streamed while it still
  exists.
- Copy to a `TempFileManager` scope only for a tool that must keep a
  provider-backed file beyond the drop.
