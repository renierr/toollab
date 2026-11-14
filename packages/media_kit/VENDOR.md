# Local media_kit patch

This is a vendored copy of `media_kit` 1.2.6 from pub.dev. Only
`lib/src/player/native/player/real.dart` differs (`no-lua-scripts.patch`).

libmpv loads its built-in Lua scripts (auto_profiles, ytdl_hook, osc, stats,
console, ...) at `mpv_initialize`. When one raises a Lua error, LuaJIT unwinds
with `_Unwind_RaiseException`, which on Linux resolves to the copy exported by
`libflutter_linux_gtk.so`, and the app segfaults at random on player start or
exit. The app uses none of these scripts, so the patch turns them all off in
the options set before `mpv_initialize`. libmpv ignores options it does not
know, so older builds (Windows) are unaffected.

Pubspec changes for the workspace: `resolution: workspace`, the SDK constraint,
no `screenshots:` and no `dev_dependencies`. `example/`, `test/` and
`screenshots/` are left out.

## Updating

Keep the version in step with `packages/media_kit_video` (see its VENDOR.md).

1. Check whether a newer upstream release disables the Lua scripts or the
   crash is gone (Flutter no longer exporting `_Unwind_RaiseException`). If so,
   drop this folder, remove it from `workspace:` and restore the hosted
   dependency in the root `pubspec.yaml`.
2. Otherwise copy the new release over this folder (without the left-out
   folders), reapply the pubspec changes above and run
   `patch -p1 < no-lua-scripts.patch` here.
3. On Linux, open and close a video player a few times: no segfault, and
   `coredumpctl list tool_lab` stays empty.
