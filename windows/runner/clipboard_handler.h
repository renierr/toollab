#ifndef RUNNER_CLIPBOARD_HANDLER_H_
#define RUNNER_CLIPBOARD_HANDLER_H_

#include <flutter/binary_messenger.h>
#include <windows.h>

// Registers the "de.renier.tool_lab/clipboard" MethodChannel. "writeImagePng"
// takes PNG bytes and places them as "PNG" plus an alpha-carrying CF_DIBV5.
void RegisterClipboardHandler(flutter::BinaryMessenger* messenger, HWND owner);

#endif  // RUNNER_CLIPBOARD_HANDLER_H_
