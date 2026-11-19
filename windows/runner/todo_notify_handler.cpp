#include "todo_notify_handler.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <shellapi.h>
#include <wchar.h>

#include <memory>
#include <string>

#include "resource.h"

using flutter::EncodableMap;
using flutter::EncodableValue;

namespace {

constexpr UINT kTrayIconId = 0x7D0;

HWND g_owner = nullptr;
bool g_icon_added = false;

std::wstring Utf16FromUtf8(const std::string& utf8) {
  if (utf8.empty()) return std::wstring();
  const int length = MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                                         static_cast<int>(utf8.size()),
                                         nullptr, 0);
  if (length <= 0) return std::wstring();
  std::wstring utf16(static_cast<size_t>(length), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                      utf16.data(), length);
  return utf16;
}

std::string StringArg(const EncodableMap& args, const char* key) {
  const auto it = args.find(EncodableValue(key));
  if (it == args.end()) return std::string();
  const auto* value = std::get_if<std::string>(&it->second);
  return value ? *value : std::string();
}

HICON AppIcon(int size) {
  return static_cast<HICON>(LoadImageW(GetModuleHandleW(nullptr),
                                       MAKEINTRESOURCEW(IDI_APP_ICON),
                                       IMAGE_ICON, size, size, LR_SHARED));
}

NOTIFYICONDATAW BaseData() {
  NOTIFYICONDATAW data = {};
  data.cbSize = sizeof(data);
  data.hWnd = g_owner;
  data.uID = kTrayIconId;
  return data;
}

bool EnsureTrayIcon() {
  if (g_icon_added) return true;
  if (!g_owner) return false;
  NOTIFYICONDATAW data = BaseData();
  data.uFlags = NIF_ICON | NIF_TIP;
  data.hIcon = AppIcon(GetSystemMetrics(SM_CXSMICON));
  wcsncpy_s(data.szTip, L"ToolLab", _TRUNCATE);
  if (!Shell_NotifyIconW(NIM_ADD, &data)) return false;
  data.uVersion = NOTIFYICON_VERSION_4;
  Shell_NotifyIconW(NIM_SETVERSION, &data);
  g_icon_added = true;
  return true;
}

bool ShowBalloon(const std::wstring& title, const std::wstring& body) {
  if (!EnsureTrayIcon()) return false;
  NOTIFYICONDATAW data = BaseData();
  data.uFlags = NIF_INFO;
  wcsncpy_s(data.szInfoTitle, title.c_str(), _TRUNCATE);
  // An empty szInfo removes the balloon instead of showing one.
  wcsncpy_s(data.szInfo, body.empty() ? L" " : body.c_str(), _TRUNCATE);
  data.dwInfoFlags = NIIF_USER | NIIF_LARGE_ICON;
  data.hBalloonIcon = AppIcon(GetSystemMetrics(SM_CXICON));
  return Shell_NotifyIconW(NIM_MODIFY, &data) != FALSE;
}

}  // namespace

void RegisterTodoNotifyHandler(flutter::BinaryMessenger* messenger,
                               HWND owner) {
  g_owner = owner;
  static std::unique_ptr<flutter::MethodChannel<EncodableValue>> channel;
  channel = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "de.renier.tool_lab/todo_desktop",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        if (call.method_name() != "notify") {
          result->NotImplemented();
          return;
        }
        const auto* args = std::get_if<EncodableMap>(call.arguments());
        if (!args) {
          result->Error("bad_args", "Expected a map with title and body.");
          return;
        }
        const bool shown = ShowBalloon(Utf16FromUtf8(StringArg(*args, "title")),
                                       Utf16FromUtf8(StringArg(*args, "body")));
        result->Success(EncodableValue(shown));
      });
}

void DisposeTodoNotifyHandler() {
  if (g_icon_added) {
    NOTIFYICONDATAW data = BaseData();
    Shell_NotifyIconW(NIM_DELETE, &data);
    g_icon_added = false;
  }
  g_owner = nullptr;
}
