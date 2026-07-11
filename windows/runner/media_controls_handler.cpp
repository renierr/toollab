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

#include "media_controls_handler.h"

using flutter::EncodableMap;
using flutter::EncodableValue;

struct MediaControlsContext {
  HWND hwnd;
  winrt::Windows::Media::SystemMediaTransportControls smtc{nullptr};
  winrt::event_token buttonToken{};
  std::unique_ptr<flutter::MethodChannel<EncodableValue>> channel;
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

static void UpdateSmtcMetadata(
    winrt::Windows::Media::SystemMediaTransportControls const& smtc,
    EncodableMap const& args) {
  auto updater = smtc.DisplayUpdater();
  updater.Type(winrt::Windows::Media::MediaPlaybackType::Music);
  auto music = updater.MusicProperties();

  auto it = args.find(EncodableValue("title"));
  if (it != args.end()) {
    music.Title(
        winrt::to_hstring(std::get<std::string>(it->second)));
  }
  it = args.find(EncodableValue("artist"));
  if (it != args.end()) {
    music.Artist(
        winrt::to_hstring(std::get<std::string>(it->second)));
  }
  it = args.find(EncodableValue("album"));
  if (it != args.end()) {
    music.AlbumTitle(
        winrt::to_hstring(std::get<std::string>(it->second)));
  }
  updater.Update();
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

    auto weak_ctx = ctx.get();
    ctx->buttonToken =
        smtc.ButtonPressed(
            [weak_ctx](
                const winrt::Windows::Media::
                    SystemMediaTransportControls&,
                const winrt::Windows::Media::
                    SystemMediaTransportControlsButtonPressedEventArgs&
                    args) {
              if (!weak_ctx || !weak_ctx->channel)
                return;
              auto btnName = ButtonToString(
                  args.Button());
              if (!btnName.empty()) {
                weak_ctx->channel->InvokeMethod(
                    "onButton",
                    std::make_unique<EncodableValue>(
                        btnName));
              }
            });

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
              UpdateSmtcMetadata(smtc, args);
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
                smtc.IsPlayEnabled(true);
                smtc.IsPauseEnabled(true);
                smtc.IsStopEnabled(true);
                smtc.IsNextEnabled(true);
                smtc.IsPreviousEnabled(true);
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
              result->Success();

            } else if (method == "clear") {
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
  try {
    if (context->smtc &&
        context->buttonToken.value !=
            -1) {
      context->smtc.ButtonPressed(
          context->buttonToken);
    }
    context->smtc = nullptr;
  } catch (...) {
  }
  delete context;
}

#pragma pop_macro("_HAS_EXCEPTIONS")
