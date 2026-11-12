#ifndef RUNNER_WINDOW_PLACEMENT_H_
#define RUNNER_WINDOW_PLACEMENT_H_

#include <windows.h>

#include <optional>

struct WindowPlacement {
  // Restored (non-maximized) outer frame in physical screen pixels.
  RECT frame;
  bool maximized;
};

// Empty when nothing is saved or the frame no longer fits a connected monitor.
std::optional<WindowPlacement> LoadWindowPlacement();

void SaveWindowPlacement(const WindowPlacement& placement);

#endif  // RUNNER_WINDOW_PLACEMENT_H_
