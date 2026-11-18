# Local whisper_ggml patch

This is a vendored copy of `whisper_ggml` 2.10.0 from pub.dev, for Android,
Linux and Windows.

Upstream converts every input with FFmpeg before transcribing: through
`ffmpeg_kit_flutter_new_min` on Android, an `ffmpeg` executable from `PATH` on
desktop. Sound Finder already writes 16 kHz mono 16-bit PCM WAV chunks
(`convertMemoForWhisper`), so that second conversion only cost time and temp
files, and pulled in ffmpeg_kit (a large native library that also applies the
Kotlin Gradle Plugin).

Changes:

- `WhisperAudioConvert` is removed; `Whisper.transcribe` passes the audio file
  through unchanged and expects 16 kHz mono 16-bit PCM WAV.
- `ffmpeg_kit_flutter_new_min`, its R8 rules (`consumer-rules.pro`) and
  `plugin_platform_interface` are dropped; `universal_io` is replaced by
  `dart:io`.
- iOS, macOS, the example, the tests and the dev dependencies are dropped.
  The Android build's leftover `.cxx` output is not copied.

The whisper.cpp sources under `android/src/whisper` (also used by the Linux and
Windows CMake builds) and the rest of `lib/` are unchanged.

Remove this copy if upstream gains a way to skip conversion for WAV input.
