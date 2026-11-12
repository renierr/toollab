#include "window_placement.h"

#include <flutter_windows.h>

#include <algorithm>

namespace {

constexpr wchar_t kRegistryKey[] = L"Software\\de.renier\\ToolLab\\Window";
constexpr LONG kMinExtent = 200;

bool ReadDword(HKEY key, const wchar_t* name, DWORD* value) {
  DWORD size = sizeof(DWORD);
  return RegGetValueW(key, nullptr, name, RRF_RT_REG_DWORD, nullptr, value,
                      &size) == ERROR_SUCCESS;
}

void WriteDword(HKEY key, const wchar_t* name, DWORD value) {
  RegSetValueExW(key, name, 0, REG_DWORD, reinterpret_cast<const BYTE*>(&value),
                 sizeof(value));
}

LONG Clamp(LONG value, LONG low, LONG high) {
  return std::max(low, std::min(value, high));
}

}  // namespace

std::optional<WindowPlacement> LoadWindowPlacement() {
  HKEY key;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, kRegistryKey, 0, KEY_READ, &key) !=
      ERROR_SUCCESS) {
    return std::nullopt;
  }
  DWORD left = 0, top = 0, width = 0, height = 0, maximized = 0;
  const bool complete =
      ReadDword(key, L"Left", &left) && ReadDword(key, L"Top", &top) &&
      ReadDword(key, L"Width", &width) && ReadDword(key, L"Height", &height) &&
      ReadDword(key, L"Maximized", &maximized);
  RegCloseKey(key);
  if (!complete) {
    return std::nullopt;
  }

  const LONG w = static_cast<LONG>(width);
  const LONG h = static_cast<LONG>(height);
  if (w < kMinExtent || h < kMinExtent) {
    return std::nullopt;
  }
  RECT frame = {static_cast<LONG>(left), static_cast<LONG>(top),
                static_cast<LONG>(left) + w, static_cast<LONG>(top) + h};

  // Null when the monitor the window was on is no longer connected.
  HMONITOR monitor = MonitorFromRect(&frame, MONITOR_DEFAULTTONULL);
  MONITORINFO info = {sizeof(info)};
  if (!monitor || !GetMonitorInfoW(monitor, &info)) {
    return std::nullopt;
  }

  // The outer frame includes invisible resize borders, so a window filling
  // the work area is slightly larger than it.
  const LONG slack =
      MulDiv(8, static_cast<int>(FlutterDesktopGetDpiForMonitor(monitor)), 96);
  const RECT& work = info.rcWork;
  if (w > work.right - work.left + 2 * slack ||
      h > work.bottom - work.top + slack) {
    return std::nullopt;
  }

  const LONG x = Clamp(frame.left, work.left - slack, work.right + slack - w);
  const LONG y = Clamp(frame.top, work.top, work.bottom + slack - h);
  return WindowPlacement{{x, y, x + w, y + h}, maximized != 0};
}

void SaveWindowPlacement(const WindowPlacement& placement) {
  HKEY key;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, kRegistryKey, 0, nullptr, 0,
                      KEY_WRITE, nullptr, &key, nullptr) != ERROR_SUCCESS) {
    return;
  }
  const RECT& frame = placement.frame;
  WriteDword(key, L"Left", static_cast<DWORD>(frame.left));
  WriteDword(key, L"Top", static_cast<DWORD>(frame.top));
  WriteDword(key, L"Width", static_cast<DWORD>(frame.right - frame.left));
  WriteDword(key, L"Height", static_cast<DWORD>(frame.bottom - frame.top));
  WriteDword(key, L"Maximized", placement.maximized ? 1 : 0);
  RegCloseKey(key);
}
