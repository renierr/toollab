#ifndef RUNNER_MEDIA_CONTROLS_HANDLER_H_
#define RUNNER_MEDIA_CONTROLS_HANDLER_H_

#include <flutter/binary_messenger.h>
#include <windows.h>

struct MediaControlsContext;

MediaControlsContext* InitMediaControls(
    flutter::BinaryMessenger* messenger,
    HWND window_hwnd);

void DisposeMediaControls(MediaControlsContext* context);

#endif  // RUNNER_MEDIA_CONTROLS_HANDLER_H_
