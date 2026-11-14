# Local media_kit_video patch

This is a vendored copy of `media_kit_video` 2.0.1 from pub.dev. Only
`linux/video_output.cc` differs (`wayland-egl.patch`); the Dart code, Windows
and Android are unchanged.

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

Pubspec changes for the workspace: `resolution: workspace`, the SDK constraint,
and no `dev_dependencies`. `example/` is left out.

## Updating

1. Check whether a newer upstream release reads the display without a current
   context (search `linux/video_output.cc` for `eglGetCurrentDisplay`). If it
   does, drop this folder, remove it from `workspace:` and restore the hosted
   dependency in the root `pubspec.yaml`.
2. Otherwise copy the new release over this folder (without `example/`),
   reapply the pubspec changes above and run
   `patch -p1 < wayland-egl.patch` here.
3. On Linux under Wayland, play a video and look for the two log lines above.
