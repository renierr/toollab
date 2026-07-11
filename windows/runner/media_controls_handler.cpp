// C++/WinRT needs exception support enabled. The project sets
// _HAS_EXCEPTIONS=0 globally, so override it for this file only.
#pragma push_macro("_HAS_EXCEPTIONS")
#undef _HAS_EXCEPTIONS
#define _HAS_EXCEPTIONS 1

// Silence the deprecated <experimental/coroutine> warning from C++/WinRT.
#define _SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Media.h>
#include <winrt/Windows.Media.Playback.h>
#include <systemmediatransportcontrolsinterop.h>
#include <shobjidl.h>

#include <chrono>
#include <commctrl.h>

#include "media_controls_handler.h"

#pragma comment(lib, "comctl32.lib")
#define WM_USER_MEDIA_BUTTON (WM_USER + 101)

using flutter::EncodableMap;
using flutter::EncodableValue;

struct MediaControlsContext {
  HWND hwnd;
  winrt::Windows::Media::SystemMediaTransportControls smtc{nullptr};
  winrt::event_token buttonToken{};
  std::unique_ptr<flutter::MethodChannel<EncodableValue>> channel;
  int64_t duration_ms = 0;
  bool play_supported = true;
  bool pause_supported = true;
  bool stop_supported = true;
  bool next_supported = true;
  bool prev_supported = true;
};

static std::string
ButtonToString(
    winrt::Windows::Media::SystemMediaTransportControlsButton btn) {
  switch (btn) {
  case winrt::Windows::Media::SystemMediaTransportControlsButton::Play:
    return "play";
  case winrt::Windows::Media::SystemMediaTransportControlsButton::Pause:
    return "pause";
  case winrt::Windows::Media::SystemMediaTransportControlsButton::Stop:
    return "stop";
  case winrt::Windows::Media::SystemMediaTransportControlsButton::Next:
    return "next";
  case winrt::Windows::Media::SystemMediaTransportControlsButton::Previous:
    return "previous";
  default:
    return "";
  }
}

static std::string GetStringOrEmpty(const EncodableValue& val) {
  if (std::holds_alternative<std::string>(val)) {
    return std::get<std::string>(val);
  }
  return "";
}

static LRESULT CALLBACK MediaControlsSubclassProc(
    HWND hwnd,
    UINT uMsg,
    WPARAM wParam,
    LPARAM lParam,
    UINT_PTR uIdSubclass,
    DWORD_PTR dwRefData) {
  if (uMsg == WM_USER_MEDIA_BUTTON) {
    auto* ctx = reinterpret_cast<MediaControlsContext*>(dwRefData);
    if (ctx && ctx->channel) {
      auto btn = static_cast<winrt::Windows::Media::SystemMediaTransportControlsButton>(wParam);
      auto btnName = ButtonToString(btn);
      if (!btnName.empty()) {
        ctx->channel->InvokeMethod(
            "onButton",
            std::make_unique<EncodableValue>(btnName));
      }
    }
    return 0;
  }
  return DefSubclassProc(hwnd, uMsg, wParam, lParam);
}

static void UpdateSmtcMetadata(
    MediaControlsContext* ctx,
    EncodableMap const& args) {
  auto& smtc = ctx->smtc;
  auto updater = smtc.DisplayUpdater();
  updater.Type(winrt::Windows::Media::MediaPlaybackType::Music);
  auto music = updater.MusicProperties();

  auto it = args.find(EncodableValue("title"));
  if (it != args.end()) {
    auto val = GetStringOrEmpty(it->second);
    if (!val.empty()) {
      music.Title(winrt::to_hstring(val));
    }
  }
  it = args.find(EncodableValue("artist"));
  if (it != args.end()) {
    auto val = GetStringOrEmpty(it->second);
    if (!val.empty()) {
      music.Artist(winrt::to_hstring(val));
    }
  }
  it = args.find(EncodableValue("album"));
  if (it != args.end()) {
    auto val = GetStringOrEmpty(it->second);
    if (!val.empty()) {
      music.AlbumTitle(winrt::to_hstring(val));
    }
  }
  updater.Update();

  it = args.find(EncodableValue("durationMs"));
  if (it != args.end() && !it->second.IsNull()) {
    int64_t durationMs = 0;
    if (std::holds_alternative<int32_t>(it->second)) {
      durationMs = std::get<int32_t>(it->second);
    } else if (std::holds_alternative<int64_t>(it->second)) {
      durationMs = std::get<int64_t>(it->second);
    }
    ctx->duration_ms = durationMs;

    if (durationMs > 0) {
      winrt::Windows::Media::SystemMediaTransportControlsTimelineProperties timeline;
      timeline.StartTime(winrt::Windows::Foundation::TimeSpan::zero());
      timeline.MinSeekTime(winrt::Windows::Foundation::TimeSpan::zero());
      timeline.MaxSeekTime(std::chrono::milliseconds(durationMs));
      timeline.EndTime(std::chrono::milliseconds(durationMs));
      timeline.Position(winrt::Windows::Foundation::TimeSpan::zero());
      smtc.UpdateTimelineProperties(timeline);
    }
  } else {
    ctx->duration_ms = 0;
  }

  it = args.find(EncodableValue("supportedButtons"));
  if (it != args.end() && !it->second.IsNull()) {
    ctx->play_supported = false;
    ctx->pause_supported = false;
    ctx->stop_supported = false;
    ctx->next_supported = false;
    ctx->prev_supported = false;

    if (std::holds_alternative<std::vector<EncodableValue>>(it->second)) {
      const auto& list = std::get<std::vector<EncodableValue>>(it->second);
      for (const auto& item : list) {
        if (std::holds_alternative<std::string>(item)) {
          const auto& name = std::get<std::string>(item);
          if (name == "play") ctx->play_supported = true;
          else if (name == "pause") ctx->pause_supported = true;
          else if (name == "stop") ctx->stop_supported = true;
          else if (name == "next") ctx->next_supported = true;
          else if (name == "previous") ctx->prev_supported = true;
        }
      }
    }

    if (smtc.PlaybackStatus() == winrt::Windows::Media::MediaPlaybackStatus::Playing) {
      smtc.IsPlayEnabled(ctx->play_supported);
      smtc.IsPauseEnabled(ctx->pause_supported);
      smtc.IsStopEnabled(ctx->stop_supported);
      smtc.IsNextEnabled(ctx->next_supported);
      smtc.IsPreviousEnabled(ctx->prev_supported);
    }
  }
}

MediaControlsContext*
InitMediaControls(
    flutter::BinaryMessenger* messenger,
    HWND window_hwnd) {
  auto ctx = std::make_unique<MediaControlsContext>();
  ctx->hwnd = window_hwnd;

  try {
    auto interop =
        winrt::get_activation_factory<
            winrt::Windows::Media::SystemMediaTransportControls,
            ISystemMediaTransportControlsInterop>();

    winrt::Windows::Media::SystemMediaTransportControls smtc =
        nullptr;
    HRESULT hr = interop->GetForWindow(
        window_hwnd,
        winrt::guid_of<
            winrt::Windows::Media::SystemMediaTransportControls>(),
        winrt::put_abi(smtc));
    if (FAILED(hr) || smtc == nullptr) {
      OutputDebugStringW(
          L"[MediaControls] GetForWindow failed\n");
      return nullptr;
    }
    ctx->smtc = smtc;

    // Keep buttons disabled until we have active playback.
    smtc.IsPlayEnabled(false);
    smtc.IsPauseEnabled(false);
    smtc.IsStopEnabled(false);
    smtc.IsNextEnabled(false);
    smtc.IsPreviousEnabled(false);

    ctx->channel = std::make_unique<
        flutter::MethodChannel<EncodableValue>>(
        messenger,
        "de.renier.tool_lab/media_controls",
        &flutter::StandardMethodCodec::GetInstance());

    SetWindowSubclass(window_hwnd, MediaControlsSubclassProc, 1, reinterpret_cast<DWORD_PTR>(ctx.get()));

    HWND hwnd = window_hwnd;
    ctx->buttonToken =
        smtc.ButtonPressed(
            [hwnd](
                const winrt::Windows::Media::
                    SystemMediaTransportControls&,
                const winrt::Windows::Media::
                    SystemMediaTransportControlsButtonPressedEventArgs&
                    args) {
              auto btn = args.Button();
              PostMessage(hwnd, WM_USER_MEDIA_BUTTON, static_cast<WPARAM>(btn), 0);
            });

    auto weak_ctx = ctx.get();
    ctx->channel->SetMethodCallHandler(
        [weak_ctx](
            const flutter::MethodCall<EncodableValue>&
                call,
            std::unique_ptr<
                flutter::MethodResult<EncodableValue>>
                result) {
          if (!weak_ctx) {
            result->NotImplemented();
            return;
          }
          auto& smtc = weak_ctx->smtc;

          try {
            const auto& method =
                call.method_name();

            if (method == "updateMetadata") {
              const auto& args =
                  std::get<EncodableMap>(
                      *call.arguments());
              UpdateSmtcMetadata(weak_ctx, args);
              result->Success();

            } else if (
                method ==
                "updatePlaybackStatus") {
              const auto& status =
                  std::get<std::string>(
                      *call.arguments());
              if (status == "playing") {
                smtc.PlaybackStatus(
                    winrt::Windows::Media::
                        MediaPlaybackStatus::Playing);
                smtc.IsPlayEnabled(weak_ctx->play_supported);
                smtc.IsPauseEnabled(weak_ctx->pause_supported);
                smtc.IsStopEnabled(weak_ctx->stop_supported);
                smtc.IsNextEnabled(weak_ctx->next_supported);
                smtc.IsPreviousEnabled(weak_ctx->prev_supported);
              } else if (
                  status == "paused") {
                smtc.PlaybackStatus(
                    winrt::Windows::Media::
                        MediaPlaybackStatus::Paused);
              } else {
                smtc.PlaybackStatus(
                    winrt::Windows::Media::
                        MediaPlaybackStatus::Stopped);
              }
              result->Success();

            } else if (
                method == "updatePosition") {
              int64_t positionMs = 0;
              const auto* args = call.arguments();
              if (args) {
                if (std::holds_alternative<int32_t>(*args)) {
                  positionMs = std::get<int32_t>(*args);
                } else if (std::holds_alternative<int64_t>(*args)) {
                  positionMs = std::get<int64_t>(*args);
                }
              }
              if (weak_ctx->duration_ms > 0) {
                winrt::Windows::Media::SystemMediaTransportControlsTimelineProperties timeline;
                timeline.StartTime(winrt::Windows::Foundation::TimeSpan::zero());
                timeline.MinSeekTime(winrt::Windows::Foundation::TimeSpan::zero());
                timeline.MaxSeekTime(std::chrono::milliseconds(weak_ctx->duration_ms));
                timeline.EndTime(std::chrono::milliseconds(weak_ctx->duration_ms));
                timeline.Position(std::chrono::milliseconds(positionMs));
                smtc.UpdateTimelineProperties(timeline);
              }
              result->Success();

            } else if (method == "clear") {
              weak_ctx->duration_ms = 0;
              weak_ctx->play_supported = true;
              weak_ctx->pause_supported = true;
              weak_ctx->stop_supported = true;
              weak_ctx->next_supported = true;
              weak_ctx->prev_supported = true;
              smtc.PlaybackStatus(
                  winrt::Windows::Media::
                      MediaPlaybackStatus::Stopped);
              smtc.IsPlayEnabled(false);
              smtc.IsPauseEnabled(false);
              smtc.IsStopEnabled(false);
              smtc.IsNextEnabled(false);
              smtc.IsPreviousEnabled(false);
              auto updater =
                  smtc.DisplayUpdater();
              updater.Type(
                  winrt::Windows::Media::
                      MediaPlaybackType::Music);
              auto music =
                  updater.MusicProperties();
              music.Title(L"");
              music.Artist(L"");
              music.AlbumTitle(L"");
              updater.Update();

              winrt::Windows::Media::SystemMediaTransportControlsTimelineProperties timeline;
              timeline.StartTime(winrt::Windows::Foundation::TimeSpan::zero());
              timeline.MinSeekTime(winrt::Windows::Foundation::TimeSpan::zero());
              timeline.MaxSeekTime(winrt::Windows::Foundation::TimeSpan::zero());
              timeline.EndTime(winrt::Windows::Foundation::TimeSpan::zero());
              timeline.Position(winrt::Windows::Foundation::TimeSpan::zero());
              smtc.UpdateTimelineProperties(timeline);

              result->Success();

            } else if (
                method == "dispose") {
              result->Success();

            } else {
              result->NotImplemented();
            }
          } catch (
              const winrt::hresult_error& e) {
            result->Error(
                "SMTC_ERROR",
                winrt::to_string(
                    e.message()));
          } catch (
              const std::exception& e) {
            result->Error(
                "SMTC_ERROR", e.what());
          }
        });

  } catch (
      const winrt::hresult_error& e) {
    OutputDebugStringW(
        (L"[MediaControls] Init failed: " +
         e.message() + L"\n")
            .c_str());
    return nullptr;
  }

  return ctx.release();
}

void DisposeMediaControls(
    MediaControlsContext* context) {
  if (!context)
    return;
  RemoveWindowSubclass(context->hwnd, MediaControlsSubclassProc, 1);
  try {
    if (context->smtc &&
        context->buttonToken.value != 0) {
      context->smtc.ButtonPressed(
          context->buttonToken);
    }
    context->smtc = nullptr;
  } catch (...) {
  }
  delete context;
}

#pragma pop_macro("_HAS_EXCEPTIONS")
