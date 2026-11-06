#include "clipboard_handler.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <wincodec.h>
#include <wrl/client.h>

#include <climits>
#include <cstring>
#include <memory>
#include <vector>

using flutter::EncodableValue;
using Microsoft::WRL::ComPtr;

namespace {

bool DecodeToBgra(const std::vector<uint8_t>& png, UINT* width, UINT* height,
                  std::vector<uint8_t>* pixels) {
  ComPtr<IWICImagingFactory> factory;
  if (FAILED(CoCreateInstance(CLSID_WICImagingFactory, nullptr,
                              CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&factory)))) {
    return false;
  }
  ComPtr<IWICStream> stream;
  if (FAILED(factory->CreateStream(&stream)) ||
      FAILED(stream->InitializeFromMemory(const_cast<BYTE*>(png.data()),
                                          static_cast<DWORD>(png.size())))) {
    return false;
  }
  ComPtr<IWICBitmapDecoder> decoder;
  if (FAILED(factory->CreateDecoderFromStream(
          stream.Get(), nullptr, WICDecodeMetadataCacheOnDemand, &decoder))) {
    return false;
  }
  ComPtr<IWICBitmapFrameDecode> frame;
  if (FAILED(decoder->GetFrame(0, &frame))) return false;
  ComPtr<IWICBitmapSource> bgra;
  if (FAILED(WICConvertBitmapSource(GUID_WICPixelFormat32bppBGRA, frame.Get(),
                                    &bgra)) ||
      FAILED(bgra->GetSize(width, height))) {
    return false;
  }

  const uint64_t stride = static_cast<uint64_t>(*width) * 4;
  const uint64_t size = stride * *height;
  if (size == 0 || size > UINT_MAX) return false;
  pixels->resize(static_cast<size_t>(size));
  return SUCCEEDED(bgra->CopyPixels(nullptr, static_cast<UINT>(stride),
                                    static_cast<UINT>(size), pixels->data()));
}

HGLOBAL BuildDibV5(UINT width, UINT height, const std::vector<uint8_t>& bgra) {
  HGLOBAL handle =
      GlobalAlloc(GMEM_MOVEABLE, sizeof(BITMAPV5HEADER) + bgra.size());
  if (!handle) return nullptr;
  auto* header = static_cast<BITMAPV5HEADER*>(GlobalLock(handle));
  if (!header) {
    GlobalFree(handle);
    return nullptr;
  }

  std::memset(header, 0, sizeof(BITMAPV5HEADER));
  header->bV5Size = sizeof(BITMAPV5HEADER);
  header->bV5Width = static_cast<LONG>(width);
  // Positive height = bottom-up; several readers mishandle top-down DIBs.
  header->bV5Height = static_cast<LONG>(height);
  header->bV5Planes = 1;
  header->bV5BitCount = 32;
  header->bV5Compression = BI_BITFIELDS;
  header->bV5SizeImage = static_cast<DWORD>(bgra.size());
  header->bV5RedMask = 0x00FF0000;
  header->bV5GreenMask = 0x0000FF00;
  header->bV5BlueMask = 0x000000FF;
  header->bV5AlphaMask = 0xFF000000;
  header->bV5CSType = LCS_sRGB;
  header->bV5Intent = LCS_GM_IMAGES;

  const size_t stride = static_cast<size_t>(width) * 4;
  auto* dst = reinterpret_cast<uint8_t*>(header + 1);
  for (UINT y = 0; y < height; y++) {
    std::memcpy(dst + (height - 1 - y) * stride, bgra.data() + y * stride,
                stride);
  }
  GlobalUnlock(handle);
  return handle;
}

HGLOBAL CopyToGlobal(const std::vector<uint8_t>& data) {
  HGLOBAL handle = GlobalAlloc(GMEM_MOVEABLE, data.size());
  if (!handle) return nullptr;
  void* dst = GlobalLock(handle);
  if (!dst) {
    GlobalFree(handle);
    return nullptr;
  }
  std::memcpy(dst, data.data(), data.size());
  GlobalUnlock(handle);
  return handle;
}

bool OpenClipboardWithRetry(HWND owner) {
  // Clipboard managers briefly hold the clipboard after every change.
  for (int attempt = 0; attempt < 5; attempt++) {
    if (OpenClipboard(owner)) return true;
    Sleep(20);
  }
  return false;
}

bool WriteImagePng(HWND owner, const std::vector<uint8_t>& png) {
  UINT width = 0;
  UINT height = 0;
  std::vector<uint8_t> bgra;
  if (!DecodeToBgra(png, &width, &height, &bgra)) return false;

  HGLOBAL dib = BuildDibV5(width, height, bgra);
  bgra.clear();
  bgra.shrink_to_fit();
  HGLOBAL png_global = CopyToGlobal(png);
  const UINT png_format = RegisterClipboardFormatW(L"PNG");
  if (!dib || !png_global || !png_format || !OpenClipboardWithRetry(owner)) {
    if (dib) GlobalFree(dib);
    if (png_global) GlobalFree(png_global);
    return false;
  }

  EmptyClipboard();
  // On success the system owns the memory; only a rejected handle is ours.
  const bool dib_set = SetClipboardData(CF_DIBV5, dib) != nullptr;
  if (!dib_set) GlobalFree(dib);
  const bool png_set = SetClipboardData(png_format, png_global) != nullptr;
  if (!png_set) GlobalFree(png_global);
  CloseClipboard();
  return dib_set && png_set;
}

}  // namespace

void RegisterClipboardHandler(flutter::BinaryMessenger* messenger, HWND owner) {
  static std::unique_ptr<flutter::MethodChannel<EncodableValue>> channel;
  channel = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "de.renier.tool_lab/clipboard",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [owner](const flutter::MethodCall<EncodableValue>& call,
              std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        if (call.method_name() != "writeImagePng") {
          result->NotImplemented();
          return;
        }
        const auto* bytes = std::get_if<std::vector<uint8_t>>(call.arguments());
        if (!bytes || bytes->empty()) {
          result->Error("bad_args", "Missing PNG bytes.");
          return;
        }
        result->Success(EncodableValue(WriteImagePng(owner, *bytes)));
      });
}
