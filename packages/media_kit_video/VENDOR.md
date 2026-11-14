# Local media_kit_video patch

This is a vendored copy of `media_kit_video` 2.0.1 from pub.dev. Only
`linux/video_output.cc` and `linux/texture_gl.cc` differ
(`media_kit_video.patch`); the Dart code, Windows and Android are unchanged.

## GPU rendering on Wayland (`video_output.cc`)

Flutter 3.50+ on Wayland draws through its own EGL subsurface and leaves no EGL
context current on the platform thread. Upstream media_kit_video reads Flutter's
display from the current context, finds none, logs
`EGL display or context is invalid` and falls back to software rendering: every
frame goes through a CPU buffer capped at 1920x1080, and VA-API can only decode
with a copy back. 4K video stutters.

The patch opens the Wayland EGL display itself (`eglGetPlatformDisplayEXT` on
GDK's `wl_display`), which EGL returns as the same display Flutter uses, so
mpv's EGLImage still reaches Flutter's texture. The log then shows
`Using the Wayland EGL display` and `H/W rendering with isolated EGL context`.

## Frame pacing (`texture_gl.cc`)

Flutter pulls each video frame by calling the texture's `populate` on its
raster thread. mpv's render call defaults to `BLOCK_FOR_TARGET_TIME`, so it
slept there until the frame's due time: 8 to 17 ms per frame on average, up to
30 ms, stalling everything Flutter draws, and 4 to 14 % of frames of a 30 fps
stream reached the screen 45 ms or more after the previous one. The patch
renders without blocking and reports each swap to mpv, which feeds its frame
timing. Measured on the same stream: about 0.2 ms per render call and about
1 % late frames.

## Pubspec changes

Pubspec changes for the workspace: `resolution: workspace`, the SDK constraint,
and no `dev_dependencies`. `example/` is left out.

## Updating

1. Check whether a newer upstream release reads the display without a current
   context (search `linux/video_output.cc` for `eglGetCurrentDisplay`). If it
   does, drop this folder, remove it from `workspace:` and restore the hosted
   dependency in the root `pubspec.yaml`.
2. Otherwise copy the new release over this folder (without `example/`),
   reapply the pubspec changes above and run
   `patch -p1 < media_kit_video.patch` here.
3. On Linux under Wayland, play a video and look for the two log lines above;
   playback of a 30 fps stream should look even.
