// C++/WinRT needs exception support enabled. The project sets
// _HAS_EXCEPTIONS=0 globally, so override it for this file only.
#pragma push_macro("_HAS_EXCEPTIONS")
#undef _HAS_EXCEPTIONS
#define _HAS_EXCEPTIONS 1

// Silence the deprecated <experimental/coroutine> warning from C++/WinRT.
#define _SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS

#include "ocr_handler.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Storage.Streams.h>
#include <winrt/Windows.Graphics.Imaging.h>
#include <winrt/Windows.Media.Ocr.h>

#include <memory>
#include <string>
#include <vector>

using flutter::EncodableMap;
using flutter::EncodableValue;

namespace {

namespace wss = winrt::Windows::Storage::Streams;
namespace wgi = winrt::Windows::Graphics::Imaging;
namespace wmo = winrt::Windows::Media::Ocr;

// Runs the WinRT OCR pipeline off the UI thread, then resumes on the platform
// thread to deliver the reply. MethodResult must be used on the platform
// thread, and blocking the STA UI thread with .get() would deadlock — hence a
// coroutine with an apartment_context round-trip.
winrt::fire_and_forget RecognizeAsync(
    std::vector<uint8_t> bytes,
    std::shared_ptr<flutter::MethodResult<EncodableValue>> result) {
  winrt::apartment_context ui_thread;

  bool success = false;
  std::string text_utf8;
  std::string error_code;
  std::string error_message;

  // co_await is not allowed inside a catch block, so record the outcome here
  // and do the thread-hop + reply once, after the try/catch.
  try {
    wss::InMemoryRandomAccessStream stream;
    wss::DataWriter writer(stream);
    writer.WriteBytes(
        winrt::array_view<const uint8_t>(bytes.data(),
                                         bytes.data() + bytes.size()));
    co_await writer.StoreAsync();
    co_await writer.FlushAsync();
    writer.DetachStream();
    stream.Seek(0);

    auto decoder = co_await wgi::BitmapDecoder::CreateAsync(stream);
    auto software_bitmap = co_await decoder.GetSoftwareBitmapAsync();

    auto engine = wmo::OcrEngine::TryCreateFromUserProfileLanguages();
    if (!engine) {
      error_code = "ocr_unavailable";
      error_message = "No OCR language pack is installed on this system.";
    } else {
      auto ocr_result = co_await engine.RecognizeAsync(software_bitmap);

      std::wstring text;
      bool first = true;
      for (auto const& line : ocr_result.Lines()) {
        if (!first) {
          text += L"\n";
        }
        text += line.Text().c_str();
        first = false;
      }
      text_utf8 = winrt::to_string(text);
      success = true;
    }
  } catch (const winrt::hresult_error& e) {
    error_code = "ocr_error";
    error_message = winrt::to_string(e.message());
  } catch (...) {
    error_code = "ocr_error";
    error_message = "Unknown OCR failure.";
  }

  co_await ui_thread;
  if (success) {
    result->Success(EncodableValue(text_utf8));
  } else {
    result->Error(error_code, error_message);
  }
}

}  // namespace

void RegisterOcrHandler(flutter::BinaryMessenger* messenger) {
  // The channel outlives this call; the messenger keeps the handler registered.
  static std::unique_ptr<flutter::MethodChannel<EncodableValue>> channel;
  channel = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "de.renier.tool_lab/ocr",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        if (call.method_name() != "recognizeText") {
          result->NotImplemented();
          return;
        }

        const auto* args = std::get_if<EncodableMap>(call.arguments());
        const std::vector<uint8_t>* bytes = nullptr;
        if (args) {
          auto it = args->find(EncodableValue("bytes"));
          if (it != args->end()) {
            bytes = std::get_if<std::vector<uint8_t>>(&it->second);
          }
        }
        if (!bytes || bytes->empty()) {
          result->Error("bad_args", "Missing image bytes.");
          return;
        }

        // MethodResult is move-only; hand ownership to the coroutine.
        std::shared_ptr<flutter::MethodResult<EncodableValue>> shared(
            std::move(result));
        RecognizeAsync(*bytes, shared);
      });
}

#pragma pop_macro("_HAS_EXCEPTIONS")
