#include "flutter_window.h"

#include <optional>
#include <vector>
#include <initguid.h>
#include <setupapi.h>
#include <batclass.h>
#include <winioctl.h>

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>

#include "flutter/generated_plugin_registrant.h"

// Helper to query battery details via Win32 APIs
flutter::EncodableMap GetBatteryDetailsWin32() {
    flutter::EncodableMap result;
    result[flutter::EncodableValue("voltage")] = flutter::EncodableValue(-1);
    result[flutter::EncodableValue("current")] = flutter::EncodableValue(0);
    result[flutter::EncodableValue("isCharging")] = flutter::EncodableValue(false);
    result[flutter::EncodableValue("pluggedType")] = flutter::EncodableValue(-1);

    HDEVINFO hdev = SetupDiGetClassDevs(&GUID_DEVICE_BATTERY, NULL, NULL, DIGCF_PRESENT | DIGCF_DEVICEINTERFACE);
    if (hdev == INVALID_HANDLE_VALUE) {
        return result;
    }

    SP_DEVICE_INTERFACE_DATA did = { sizeof(SP_DEVICE_INTERFACE_DATA) };
    for (DWORD i = 0; SetupDiEnumDeviceInterfaces(hdev, NULL, &GUID_DEVICE_BATTERY, i, &did); ++i) {
        DWORD cbRequired = 0;
        SetupDiGetDeviceInterfaceDetail(hdev, &did, NULL, 0, &cbRequired, NULL);
        if (cbRequired == 0) continue;

        std::vector<BYTE> buffer(cbRequired);
        PSP_DEVICE_INTERFACE_DETAIL_DATA pdidd = reinterpret_cast<PSP_DEVICE_INTERFACE_DETAIL_DATA>(buffer.data());
        pdidd->cbSize = sizeof(SP_DEVICE_INTERFACE_DETAIL_DATA);

        if (SetupDiGetDeviceInterfaceDetail(hdev, &did, pdidd, cbRequired, NULL, NULL)) {
            HANDLE hBattery = CreateFile(pdidd->DevicePath, GENERIC_READ | GENERIC_WRITE,
                FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);

            if (hBattery != INVALID_HANDLE_VALUE) {
                BATTERY_QUERY_INFORMATION bqi = { 0 };
                DWORD dwOut = 0;
                DWORD dwWait = 0;

                if (DeviceIoControl(hBattery, IOCTL_BATTERY_QUERY_TAG, &dwWait, sizeof(dwWait),
                    &bqi.BatteryTag, sizeof(bqi.BatteryTag), &dwOut, NULL) && bqi.BatteryTag) {

                    BATTERY_WAIT_STATUS bws = { 0 };
                    bws.BatteryTag = bqi.BatteryTag;
                    BATTERY_STATUS bs = { 0 };

                    if (DeviceIoControl(hBattery, IOCTL_BATTERY_QUERY_STATUS, &bws, sizeof(bws),
                        &bs, sizeof(bs), &dwOut, NULL)) {

                        bool isCharging = (bs.PowerState & BATTERY_CHARGING) != 0;
                        bool onLine = (bs.PowerState & BATTERY_POWER_ON_LINE) != 0;

                        // Rate is in milliwatts. If discharging, it is negative.
                        // We convert rate/power in mW to current in microamperes:
                        // Current (A) = Power (W) / Voltage (V)
                        // Current (uA) = (Rate (mW) * 1000) / (Voltage (mV) / 1000) = Rate (mW) * 1000000 / Voltage (mV)
                        long long currentMicroAmps = 0;
                        if (bs.Voltage > 0) {
                            currentMicroAmps = (static_cast<long long>(bs.Rate) * 1000000LL) / static_cast<long long>(bs.Voltage);
                        }

                        result[flutter::EncodableValue("voltage")] = flutter::EncodableValue(static_cast<int>(bs.Voltage));
                        result[flutter::EncodableValue("current")] = flutter::EncodableValue(static_cast<int>(currentMicroAmps));
                        result[flutter::EncodableValue("isCharging")] = flutter::EncodableValue(isCharging || (onLine && bs.Rate > 0));
                        result[flutter::EncodableValue("pluggedType")] = flutter::EncodableValue(onLine ? 1 : 0);
                        CloseHandle(hBattery);
                        break; // Just use the first battery
                    }
                }
                CloseHandle(hBattery);
            }
        }
    }

    SetupDiDestroyDeviceInfoList(hdev);
    return result;
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  // Register battery details MethodChannel
  const std::string battery_channel_name("de.renier.tool_lab/battery_details");
  auto battery_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      battery_channel_name,
      &flutter::StandardMethodCodec::GetInstance());

  battery_channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name().compare("getBatteryDetails") == 0) {
          result->Success(flutter::EncodableValue(GetBatteryDetailsWin32()));
        } else {
          result->NotImplemented();
        }
      });

  // Register device info MethodChannel
  const std::string device_info_channel_name("de.renier.tool_lab/device_info");
  auto device_info_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      device_info_channel_name,
      &flutter::StandardMethodCodec::GetInstance());

  device_info_channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name().compare("getStorageInfo") == 0) {
          ULARGE_INTEGER freeBytesAvailableToCaller;
          ULARGE_INTEGER totalNumberOfBytes;
          ULARGE_INTEGER totalNumberOfFreeBytes;
          if (GetDiskFreeSpaceExW(L"C:\\", &freeBytesAvailableToCaller, &totalNumberOfBytes, &totalNumberOfFreeBytes)) {
            flutter::EncodableMap storage_map = {
              {flutter::EncodableValue("free"), flutter::EncodableValue(static_cast<int64_t>(freeBytesAvailableToCaller.QuadPart))},
              {flutter::EncodableValue("total"), flutter::EncodableValue(static_cast<int64_t>(totalNumberOfBytes.QuadPart))}
            };
            result->Success(flutter::EncodableValue(storage_map));
          } else {
            result->Error("STORAGE_ERROR", "Failed to query storage info via GetDiskFreeSpaceExW");
          }
        } else if (call.method_name().compare("getSensorInfo") == 0) {
          flutter::EncodableMap sensor_map = {
            {flutter::EncodableValue("accelerometer"), flutter::EncodableValue(false)},
            {flutter::EncodableValue("gyroscope"), flutter::EncodableValue(false)},
            {flutter::EncodableValue("magnetometer"), flutter::EncodableValue(false)},
            {flutter::EncodableValue("barometer"), flutter::EncodableValue(false)},
            {flutter::EncodableValue("light"), flutter::EncodableValue(false)}
          };
          result->Success(flutter::EncodableValue(sensor_map));
        } else {
          result->NotImplemented();
        }
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
