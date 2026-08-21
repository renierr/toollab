#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  // Impeller became the default renderer on Windows in Flutter 3.47, but the
  // only backend Windows builds is GLES over ANGLE, which cannot ship
  // precompiled shaders and recompiles its pipelines through the HLSL compiler
  // on every launch. Measured here: 1.9s to first frame with it, 0.35s without.
  project.set_impeller_switch(flutter::ImpellerSwitch::Disabled);

  FlutterWindow window(project);
  Win32Window::Size size(1280, 720);
  HMONITOR primary = MonitorFromPoint(POINT{0, 0}, MONITOR_DEFAULTTOPRIMARY);
  UINT dpi = FlutterDesktopGetDpiForMonitor(primary);
  double scale = dpi / 96.0;
  int screenWidthLog =
      static_cast<int>(GetSystemMetrics(SM_CXSCREEN) / scale);
  int screenHeightLog =
      static_cast<int>(GetSystemMetrics(SM_CYSCREEN) / scale);

  // Clamp window size to fit within screen bounds
  unsigned int windowWidth = size.width;
  unsigned int windowHeight = size.height;
  if (screenWidthLog < static_cast<int>(windowWidth)) {
    windowWidth = static_cast<unsigned int>(screenWidthLog);
  }
  if (screenHeightLog < static_cast<int>(windowHeight)) {
    windowHeight = static_cast<unsigned int>(screenHeightLog);
  }

  int originX =
      (screenWidthLog - static_cast<int>(windowWidth)) / 2;
  int originY =
      (screenHeightLog - static_cast<int>(windowHeight)) / 2;
  Win32Window::Point origin(
      originX < 0 ? 0u : static_cast<unsigned int>(originX),
      originY < 0 ? 0u : static_cast<unsigned int>(originY));

  Win32Window::Size clampedSize(windowWidth, windowHeight);
  if (!window.Create(L"ToolLab", origin, clampedSize)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
